"""Bake Kenney CC0 .glb models into game-ready .glb files for Green Bean.

What it does to each model:
  - flattens the node hierarchy into one mesh (one surface per material)
  - applies a uniform scale so 1 unit = 1 metre in the game
  - moves the origin to the bottom centre of the model's bounding box
  - removes KHR_materials_unlit so Godot lights and shadows the model
  - sets every material to non-metallic with a fixed roughness

  - converts colours from sRGB to linear, because Kenney's exporter wrote sRGB
    values where glTF expects linear (Godot would otherwise wash them out)
  - optionally recolours materials by name (see "colors" in the manifest)

Every model is listed in tools/kenney_manifest.json. To add one, add an entry there
and run, from the green-bean folder:
  python3 tools/kenney_import.py <path to a checkout of the kenney mirror>

Get the mirror without downloading everything:
  git clone --filter=blob:none --no-checkout --depth 1 https://github.com/ETdoFresh/kenney.nl
  cd kenney.nl && git sparse-checkout set --no-cone furniturekit_updated foodKit_v1.2 && git checkout

Source used for the first import: the CC0 mirror at https://github.com/ETdoFresh/kenney.nl
(furniturekit_updated and foodKit_v1.2). Original packs: https://kenney.nl/assets
"""

import json
import os
import struct
import sys

import numpy as np

COMPONENT_DTYPES = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
TYPE_SIZES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
ROUGHNESS = 0.85


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2, path
    offset = 12
    gltf = None
    binary = b""
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        chunk = data[offset + 8: offset + 8 + chunk_len]
        if chunk_type == b"JSON":
            gltf = json.loads(chunk)
        elif chunk_type == b"BIN\x00":
            binary = chunk
        offset += 8 + chunk_len
    return gltf, binary


def read_accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    dtype = COMPONENT_DTYPES[acc["componentType"]]
    width = TYPE_SIZES[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0)
    item_bytes = np.dtype(dtype).itemsize * width
    count = acc["count"]
    if stride and stride != item_bytes:
        rows = [np.frombuffer(binary, dtype, width, start + i * stride) for i in range(count)]
        arr = np.array(rows)
    else:
        arr = np.frombuffer(binary, dtype, count * width, start).reshape(count, width)
    if acc.get("normalized") and dtype != np.float32:
        arr = arr.astype(np.float32) / np.iinfo(dtype).max
    return arr.copy()


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    t = np.array(node.get("translation", [0, 0, 0]), dtype=np.float64)
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    s = np.array(node.get("scale", [1, 1, 1]), dtype=np.float64)
    r = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    m = np.eye(4)
    m[:3, :3] = r * s
    m[:3, 3] = t
    return m


def collect(gltf, binary):
    """Return {material_index: (positions, normals, uvs, indices)} in model space."""
    groups = {}

    def visit(node_index, parent):
        node = gltf["nodes"][node_index]
        world = parent @ node_matrix(node)
        if "mesh" in node:
            linear = world[:3, :3]
            normal_m = np.linalg.inv(linear).T
            flip = np.linalg.det(linear) < 0
            for prim in gltf["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                attrs = prim["attributes"]
                pos = read_accessor(gltf, binary, attrs["POSITION"]).astype(np.float64)
                pos = pos @ linear.T + world[:3, 3]
                if "NORMAL" in attrs:
                    nrm = read_accessor(gltf, binary, attrs["NORMAL"]).astype(np.float64) @ normal_m.T
                    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
                else:
                    nrm = np.zeros_like(pos)
                uv = read_accessor(gltf, binary, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else np.zeros((len(pos), 2))
                if "indices" in prim:
                    idx = read_accessor(gltf, binary, prim["indices"]).reshape(-1).astype(np.int64)
                else:
                    idx = np.arange(len(pos))
                tris = idx.reshape(-1, 3)
                if flip:
                    tris = tris[:, [0, 2, 1]]
                mat = prim.get("material", -1)
                groups.setdefault(mat, []).append((pos, nrm, uv, tris))
        for child in node.get("children", []):
            visit(child, world)

    scene = gltf["scenes"][gltf.get("scene", 0)]
    for root in scene["nodes"]:
        visit(root, np.eye(4))

    merged = {}
    for mat, parts in groups.items():
        base = 0
        p_list, n_list, u_list, i_list = [], [], [], []
        for pos, nrm, uv, tris in parts:
            p_list.append(pos)
            n_list.append(nrm)
            u_list.append(uv)
            i_list.append(tris + base)
            base += len(pos)
        merged[mat] = (np.vstack(p_list), np.vstack(n_list), np.vstack(u_list), np.vstack(i_list))
    return merged


def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def parse_color(value):
    if isinstance(value, str):
        value = value.lstrip("#")
        return [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return list(value)[:3]


def clean_material(mat, colors):
    out = {"name": mat.get("name", "material")}
    pbr = dict(mat.get("pbrMetallicRoughness", {}))
    rgba = list(pbr.get("baseColorFactor", [1, 1, 1, 1]))
    rgb = parse_color(colors[out["name"]]) if out["name"] in colors else rgba[:3]
    pbr["baseColorFactor"] = [float(x) for x in srgb_to_linear(rgb)] + [rgba[3]]
    pbr.pop("baseColorTexture", None)
    pbr.pop("metallicRoughnessTexture", None)
    pbr["metallicFactor"] = 0.0
    pbr["roughnessFactor"] = 0.35 if "glass" in out["name"].lower() else ROUGHNESS
    out["pbrMetallicRoughness"] = pbr
    if mat.get("alphaMode") in ("BLEND", "MASK"):
        out["alphaMode"] = mat["alphaMode"]
    if mat.get("doubleSided"):
        out["doubleSided"] = True
    return out


def write_glb(path, name, groups, materials, colors):
    blob = bytearray()
    views, accessors, primitives = [], [], []

    def add(array, target, acc_type, with_bounds=False):
        while len(blob) % 4:
            blob.append(0)
        raw = array.tobytes()
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(raw), "target": target})
        blob.extend(raw)
        acc = {
            "bufferView": len(views) - 1,
            "componentType": 5125 if array.dtype == np.uint32 else 5126,
            "count": int(array.shape[0]) if acc_type != "SCALAR" else int(array.size),
            "type": acc_type,
        }
        if with_bounds:
            acc["min"] = array.min(axis=0).tolist()
            acc["max"] = array.max(axis=0).tolist()
        accessors.append(acc)
        return len(accessors) - 1

    out_materials = []
    for mat_index, (pos, nrm, uv, tris) in sorted(groups.items()):
        attrs = {
            "POSITION": add(pos.astype(np.float32), 34962, "VEC3", True),
            "NORMAL": add(nrm.astype(np.float32), 34962, "VEC3"),
            "TEXCOORD_0": add(uv.astype(np.float32), 34962, "VEC2"),
        }
        prim = {"attributes": attrs, "indices": add(tris.astype(np.uint32).reshape(-1), 34963, "SCALAR"), "mode": 4}
        if mat_index >= 0:
            out_materials.append(clean_material(materials[mat_index], colors))
            prim["material"] = len(out_materials) - 1
        primitives.append(prim)

    while len(blob) % 4:
        blob.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "green-bean kenney_import.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": primitives}],
        "materials": out_materials,
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": views,
        "accessors": accessors,
    }
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode()
    while len(json_bytes) % 4:
        json_bytes += b" "
    total = 12 + 8 + len(json_bytes) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
        f.write(json_bytes)
        f.write(struct.pack("<I4s", len(blob), b"BIN\x00"))
        f.write(bytes(blob))


def bake(src, dst, scale, colors):
    gltf, binary = read_glb(src)
    groups = collect(gltf, binary)
    all_pos = np.vstack([g[0] for g in groups.values()]) * scale
    lo, hi = all_pos.min(axis=0), all_pos.max(axis=0)
    shift = np.array([-(lo[0] + hi[0]) / 2, -lo[1], -(lo[2] + hi[2]) / 2])
    for mat in groups:
        pos, nrm, uv, tris = groups[mat]
        groups[mat] = (pos * scale + shift, nrm, uv, tris)
    name = os.path.splitext(os.path.basename(dst))[0]
    write_glb(dst, name, groups, gltf.get("materials", []), colors)
    return hi - lo


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    kenney_root = sys.argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    manifest = json.load(open(os.path.join(here, "kenney_manifest.json")))
    out_dir = os.path.join(here, "..", manifest["out_dir"])
    os.makedirs(out_dir, exist_ok=True)
    for entry in manifest["models"]:
        pack = manifest["packs"][entry["pack"]]
        source = entry.get("source", entry["name"])
        src = os.path.join(kenney_root, pack["dir"], source + ".glb")
        dst = os.path.join(out_dir, entry["name"] + ".glb")
        size = bake(src, dst, pack["scale"] * entry.get("scale", 1.0), entry.get("colors", {}))
        print(f"{entry['name']:28s} {size[0]:.3f} x {size[1]:.3f} x {size[2]:.3f} m")


if __name__ == "__main__":
    main()
