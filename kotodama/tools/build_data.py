"""Build Kotodama's data files from open sources.

Run from the kotodama folder:  python tools/build_data.py
Downloads are cached in tools/cache. Outputs go to data/ and assets/glyphs/.
"""
import io
import json
import re
import sys
import urllib.request
import zipfile
import gzip
import xml.etree.ElementTree as ET
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
DATA = ROOT / "data"
GLYPHS = ROOT / "assets" / "glyphs"
FONT = ROOT / "assets" / "fonts" / "NotoSansJP-Bold.ttf"
UA = {"User-Agent": "kotodama-build"}

KANJIDIC2_URL = "https://www.edrdg.org/kanjidic/kanjidic2.xml.gz"
KRADFILE_URL = "http://ftp.edrdg.org/pub/Nihongo/kradfile.gz"
KANJIVG_RELEASE_URL = "https://api.github.com/repos/KanjiVG/kanjivg/releases/latest"
OPENJLPT_PYPI_URL = "https://pypi.org/pypi/openjlpt/json"

LEVELS = ["N5", "N4", "N3", "N2", "N1"]
GLYPH_BOX = 32
GLYPH_SIZE = 22
INK = (255, 255, 255, 255)  # white, tinted at runtime

# id, name, tint, Kangxi radical numbers
ZONES = [
    ("pond", "Pond", "#4a8cdc", [85, 15, 195, 137]),
    ("sky", "Sky field", "#ecba3c", [72, 74, 173, 84, 36, 182]),
    ("hearth", "Hearth", "#e25834", [86, 184]),
    ("grove", "Grove", "#60a854", [75, 140, 118, 115, 119, 199]),
    ("path", "Path", "#c8b494", [9, 60, 162, 157, 156, 77]),
    ("hill", "Hill", "#a47c54", [46, 32, 112, 170, 163, 102]),
    ("hall", "Hall", "#9664c8", [149, 30, 61, 180, 147, 113]),
    ("forge", "Forge", "#8c98a8", [167, 18, 57, 111, 62, 159, 69]),
    ("house", "House", "#e07896", [40, 169, 38, 39, 53, 63, 116]),
    ("body", "Body", "#f0a888", [64, 109, 128, 130, 158, 132, 181, 185, 176]),
    ("beasts", "Beasts", "#7c9c5c", [94, 187, 196, 142, 93, 123, 152, 198]),
    ("loom", "Loom", "#48a8a0", [120, 145, 50, 107, 177]),
    ("meadow", "Meadow", "#8c9c74", []),
]

# KRADFILE writes some radicals with a stand-in JIS kanji. Display glyph and name.
STANDIN = {
    "化": ("亻", "person"), "刈": ("刂", "knife"), "込": ("辶", "walk"),
    "忙": ("忄", "heart"), "扎": ("扌", "hand"), "汁": ("氵", "water"),
    "犯": ("犭", "dog"), "艾": ("艹", "grass"), "邦": ("阝", "village"),
    "阡": ("阝", "hill"), "杰": ("灬", "flames"), "礼": ("礻", "altar"),
    "初": ("衤", "clothes"), "買": ("罒", "net"), "尚": ("⺌", "small crown"),
    "老": ("耂", "old"), "并": ("丷", "horns"), "个": ("⺈", "knife top"),
    "乞": ("𠂉", "person top"),
}
# Readings the source lacks or garbles. Hiragana only.
READING_EXTRA = {
    "日本": ["にほん"],
    "賛成": ["さんせい"],
}
SYMBOL_NAMES = {
    "｜": "stick", "ノ": "slash", "ハ": "split", "マ": "hook", "ユ": "yu",
    "ヨ": "comb", "ム": "nose", "乃": "of", "九": "nine", "也": "also",
    "冂": "box", "冖": "cover", "凵": "open box", "勹": "wrap", "匚": "basket",
    "卩": "seal", "厂": "cliff", "厶": "private", "亠": "lid", "丶": "dot",
    "亅": "barb", "乙": "fishhook", "儿": "legs", "入": "enter", "几": "table",
    "卜": "divine", "又": "again", "廴": "stride", "彐": "snout", "彡": "hair",
    "疒": "sickness", "癶": "footsteps", "⺌": "small crown", "无": "nothing",
    "艮": "stop", "襾": "west top", "黽": "frog", "鼓": "drum",
}


def fetch(name: str, url: str) -> bytes:
    CACHE.mkdir(parents=True, exist_ok=True)
    p = CACHE / name
    if p.exists():
        return p.read_bytes()
    print("download", url)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=600) as r:
        data = r.read()
    p.write_bytes(data)
    return data


def is_kanji(c: str) -> bool:
    o = ord(c)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF or 0x20000 <= o <= 0x2A6DF


def kata_to_hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if 0x30A1 <= ord(c) <= 0x30F6 else c for c in s)


def norm_reading(r: str) -> str:
    return kata_to_hira(r.replace("-", "").split(".")[0])


def cp(ch: str) -> str:
    return f"{ord(ch):05x}"


def is_hiragana(s: str) -> bool:
    return bool(s) and all(0x3041 <= ord(c) <= 0x309F or c == "ー" for c in s)


def split_readings(raw: str) -> list:
    """'きゅう / く' -> ['きゅう', 'く'], 'あたたか(い)' -> ['あたたかい', 'あたたか']. Drops junk."""
    out = []
    for piece in re.split(r"[/／、,，\s]+", kata_to_hira(raw)):
        piece = piece.strip()
        if not piece:
            continue
        variants = [piece]
        m = re.fullmatch(r"(.*)[(（](.*)[)）](.*)", piece)
        if m:
            variants = [m.group(1) + m.group(2) + m.group(3), m.group(1) + m.group(3)]
        for v in variants:
            if is_hiragana(v) and v not in out:
                out.append(v)
    return out


def clean_meaning(m: str) -> str:
    return re.sub(r"\s*radical\s*\(no\.\s*\d+\)", "", m).strip()


# ---------------------------------------------------------------- sources

def load_openjlpt():
    meta = json.loads(fetch("openjlpt_pypi.json", OPENJLPT_PYPI_URL))
    version = meta["info"]["version"]
    wheel = next(f for f in meta["releases"][version] if f["filename"].endswith(".whl"))
    z = zipfile.ZipFile(io.BytesIO(fetch(wheel["filename"], wheel["url"])))
    kanji = {}
    vocab = {}
    for lv in LEVELS:
        kanji[lv] = json.loads(z.read(f"openjlpt/data/json/kanji/{lv.lower()}.json").decode("utf-8"))
        vocab[lv] = json.loads(z.read(f"openjlpt/data/json/vocab/{lv.lower()}.json").decode("utf-8"))
    return version, kanji, vocab


def load_kanjidic2():
    raw = gzip.decompress(fetch("kanjidic2.xml.gz", KANJIDIC2_URL))
    root = ET.fromstring(raw)
    out = {}
    for c in root.iter("character"):
        lit = c.findtext("literal")
        rad = None
        for rv in c.iter("rad_value"):
            if rv.get("rad_type") == "classical":
                rad = int(rv.text)
        meanings = [m.text for m in c.iter("meaning") if m.get("m_lang") is None and m.text]
        strokes = c.findtext("misc/stroke_count")
        freq = c.findtext("misc/freq")
        out[lit] = {
            "radical": rad,
            "strokes": int(strokes) if strokes else None,
            "freq": int(freq) if freq else None,
            "meanings": meanings,
        }
    return out


def load_kradfile():
    raw = gzip.decompress(fetch("kradfile.gz", KRADFILE_URL)).decode("euc_jp", "replace")
    krad = {}
    for line in raw.splitlines():
        if not line or line.startswith("#") or " : " not in line:
            continue
        k, comps = line.split(" : ", 1)
        krad[k.strip()] = comps.split()
    return krad


def load_kanjivg():
    rel = json.loads(fetch("kanjivg_release.json", KANJIVG_RELEASE_URL))
    asset = next(a for a in rel["assets"] if a["name"].endswith("-main.zip"))
    z = zipfile.ZipFile(io.BytesIO(fetch(asset["name"], asset["browser_download_url"])))
    names = {}
    for n in z.namelist():
        base = n.rsplit("/", 1)[-1]
        if base.endswith(".svg") and "-" not in base:
            names[base[:-4]] = n
    return rel["tag_name"], z, names


# ---------------------------------------------------------------- strokes

TOKEN = re.compile(r"[MmCcSsLlZzHhVv]|-?\d*\.?\d+(?:e-?\d+)?")


def bezier(p0, p1, p2, p3, n=8):
    pts = []
    for i in range(1, n + 1):
        t = i / n
        u = 1 - t
        x = u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]
        y = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
        pts.append((x, y))
    return pts


def path_to_polyline(d: str):
    tokens = TOKEN.findall(d)
    pts = []
    cur = (0.0, 0.0)
    start = cur
    cmd = None
    prev_ctrl = None
    i = 0

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if tokens[i].isalpha():
            cmd = tokens[i]
            i += 1
        if cmd in ("M", "m"):
            x, y = num(), num()
            if cmd == "m":
                x, y = x + cur[0], y + cur[1]
            cur = (x, y)
            start = cur
            pts.append(cur)
            prev_ctrl = None
            cmd = "L" if cmd == "M" else "l"
        elif cmd in ("L", "l"):
            x, y = num(), num()
            if cmd == "l":
                x, y = x + cur[0], y + cur[1]
            cur = (x, y)
            pts.append(cur)
            prev_ctrl = None
        elif cmd in ("H", "h"):
            x = num()
            cur = (x + cur[0] if cmd == "h" else x, cur[1])
            pts.append(cur)
            prev_ctrl = None
        elif cmd in ("V", "v"):
            y = num()
            cur = (cur[0], y + cur[1] if cmd == "v" else y)
            pts.append(cur)
            prev_ctrl = None
        elif cmd in ("C", "c"):
            x1, y1, x2, y2, x, y = (num() for _ in range(6))
            if cmd == "c":
                x1, y1, x2, y2, x, y = x1 + cur[0], y1 + cur[1], x2 + cur[0], y2 + cur[1], x + cur[0], y + cur[1]
            pts += bezier(cur, (x1, y1), (x2, y2), (x, y))
            prev_ctrl = (x2, y2)
            cur = (x, y)
        elif cmd in ("S", "s"):
            x2, y2, x, y = (num() for _ in range(4))
            if cmd == "s":
                x2, y2, x, y = x2 + cur[0], y2 + cur[1], x + cur[0], y + cur[1]
            c1 = (2 * cur[0] - prev_ctrl[0], 2 * cur[1] - prev_ctrl[1]) if prev_ctrl else cur
            pts += bezier(cur, c1, (x2, y2), (x, y))
            prev_ctrl = (x2, y2)
            cur = (x, y)
        elif cmd in ("Z", "z"):
            cur = start
            pts.append(cur)
        else:
            raise ValueError(f"unknown path command {cmd!r} in {d[:40]}")
    return pts


def svg_strokes(svg: str):
    paths = re.findall(r'<path[^>]*?\sd="([^"]+)"', svg)
    return [[[round(x, 1), round(y, 1)] for x, y in path_to_polyline(d)] for d in paths]


# ---------------------------------------------------------------- glyphs

def render_glyph(ch: str, font) -> Image.Image:
    b = font.getbbox(ch)
    m = Image.new("L", (b[2] - b[0] + 2, b[3] - b[1] + 2), 0)
    ImageDraw.Draw(m).text((1 - b[0], 1 - b[1]), ch, font=font, fill=255)
    m = m.point(lambda v: 255 if v > 110 else 0)
    out = Image.new("RGBA", (GLYPH_BOX, GLYPH_BOX), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", m.size, INK), ((GLYPH_BOX - m.width) // 2, (GLYPH_BOX - m.height) // 2), m)
    return out


# ---------------------------------------------------------------- build

def maximal_parts(ch: str, krad: dict) -> list:
    """The largest visible parts: drop a part when another listed part already contains it.
    KRADFILE lists some pairs as each other's part (母 and 毋); the later one is dropped."""
    comps = [c for c in krad.get(ch, []) if c != ch]
    comp_set = set(comps)
    drop = set()
    for c in comps:
        subs = set(krad.get(c, [])) - {c}
        if not subs or not subs <= comp_set:
            continue
        for s in subs:
            mutual = c in set(krad.get(s, []))
            if mutual:
                if comps.index(s) > comps.index(c):
                    drop.add(s)
            else:
                drop.add(s)
    return [c for c in comps if c not in drop]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    DATA.mkdir(exist_ok=True)
    GLYPHS.mkdir(parents=True, exist_ok=True)

    openjlpt_version, jl_kanji, jl_vocab = load_openjlpt()
    kdic = load_kanjidic2()
    krad = load_kradfile()
    kvg_tag, kvg_zip, kvg_names = load_kanjivg()
    font = ImageFont.truetype(str(FONT), GLYPH_SIZE)

    radical_zone = {}
    for zid, _, _, rads in ZONES:
        for r in rads:
            radical_zone[r] = zid

    def zone_of(ch: str) -> str:
        rad = kdic.get(ch, {}).get("radical")
        return radical_zone.get(rad, "meadow")

    # ---- kanji order
    kanji_out = []
    learned = set()
    introduced = {}
    cycles = 0
    for lv in LEVELS:
        pool = {k["character"]: k for k in jl_kanji[lv]}
        parts = {ch: maximal_parts(ch, krad) for ch in pool}
        deps = {ch: {c for c in parts[ch] if c in pool} for ch in pool}
        remaining = set(pool)

        def key(ch):
            k = pool[ch]
            return (k.get("strokes") or 99, k.get("freq") or 9999, ch)

        while remaining:
            ready = [ch for ch in remaining if not (deps[ch] & remaining)]
            if not ready:
                cycles += 1
                ready = [min(remaining, key=key)]
            ch = min(ready, key=key)
            remaining.remove(ch)
            k = pool[ch]
            new_parts = [c for c in parts[ch] if c not in learned and c not in introduced]
            for c in new_parts:
                introduced[c] = ch
            accept = []
            for r in k["onyomi"] + k["kunyomi"]:
                n = norm_reading(r)
                if n and n not in accept:
                    accept.append(n)
            meanings = []
            for m in k["meanings"]:
                m = clean_meaning(m)
                if m and m not in meanings:
                    meanings.append(m)
            k["meanings"] = meanings
            kanji_out.append({
                "ch": ch,
                "cp": cp(ch),
                "level": lv,
                "order": len(kanji_out),
                "zone": zone_of(ch),
                "strokes": k.get("strokes"),
                "freq": k.get("freq"),
                "on": k["onyomi"],
                "kun": k["kunyomi"],
                "accept": accept,
                "meanings": k["meanings"],
                "keyword": k["meanings"][0] if k["meanings"] else ch,
                "parts": parts[ch],
                "new_parts": new_parts,
            })
            learned.add(ch)
    kanji_index = {k["ch"]: k for k in kanji_out}

    # ---- parts
    parts_out = []
    for pid, by in introduced.items():
        glyph, name = STANDIN.get(pid, (pid, None))
        if name is None:
            if pid in SYMBOL_NAMES:
                name = SYMBOL_NAMES[pid]
            elif pid in kanji_index:
                name = kanji_index[pid]["keyword"]
            elif pid in kdic and kdic[pid]["meanings"]:
                name = clean_meaning(kdic[pid]["meanings"][0])
            else:
                name = "part"
        parts_out.append({
            "id": pid,
            "glyph": glyph,
            "cp": cp(glyph),
            "name": name,
            "is_kanji": pid in kanji_index,
            "introduced_by": by,
        })

    # ---- words
    kanji_set = set(kanji_index)
    words_by_word = {}
    dropped_kana = dropped_unknown = dropped_bad = merged = 0
    for lv in LEVELS:
        for idx, w in enumerate(jl_vocab[lv]):
            word = w["word"].split("/")[0].replace("～", "").replace("〜", "").strip()
            kanji = [c for c in word if is_kanji(c)]
            if not kanji:
                dropped_kana += 1
                continue
            if any(c not in kanji_set for c in kanji):
                dropped_unknown += 1
                continue
            readings = split_readings(w["reading"]) + READING_EXTRA.get(word, [])
            readings = list(dict.fromkeys(readings))
            if not readings:
                dropped_bad += 1
                print(f"  bad reading dropped: {word} {w['reading']!r}")
                continue
            meanings = []
            for m in w["meanings"]:
                m = re.sub(r"^\(\d+\)\s*", "", m.strip())
                if m and m not in meanings:
                    meanings.append(m)
            if word in words_by_word:
                prev = words_by_word[word]
                prev["readings"] += [r for r in readings if r not in prev["readings"]]
                prev["meanings"] += [m for m in meanings if m not in prev["meanings"]]
                merged += 1
                continue
            uniq = []
            for c in kanji:
                if c not in uniq:
                    uniq.append(c)
            words_by_word[word] = {
                "word": word,
                "readings": readings,
                "meanings": meanings,
                "level": lv,
                "kanji": uniq,
                "zone": kanji_index[uniq[0]]["zone"],
                "_sort": (LEVELS.index(lv), max(kanji_index[c]["order"] for c in uniq), len(uniq), idx),
            }
    words_out = list(words_by_word.values())
    words_out.sort(key=lambda w: w["_sort"])
    for i, w in enumerate(words_out):
        del w["_sort"]
        w["order"] = i

    # ---- strokes and glyph atlas
    glyph_chars = sorted({k["ch"] for k in kanji_out} | {p["glyph"] for p in parts_out})
    missing_strokes = []
    strokes_out = {}
    for ch in glyph_chars:
        name = cp(ch)
        n = kvg_names.get(name)
        if n:
            strokes_out[name] = svg_strokes(kvg_zip.read(n).decode("utf-8"))
        else:
            missing_strokes.append(ch)
    (DATA / "strokes.json").write_text(json.dumps(strokes_out, separators=(",", ":")), encoding="utf-8")

    columns = 48
    rows = (len(glyph_chars) + columns - 1) // columns
    atlas = Image.new("RGBA", (columns * GLYPH_BOX, rows * GLYPH_BOX), (0, 0, 0, 0))
    atlas_index = {}
    for i, ch in enumerate(glyph_chars):
        col, row = i % columns, i // columns
        atlas.paste(render_glyph(ch, font), (col * GLYPH_BOX, row * GLYPH_BOX))
        atlas_index[cp(ch)] = [col, row]
    atlas.save(GLYPHS / "glyphs.png")
    (DATA / "glyph_atlas.json").write_text(json.dumps({"cell": GLYPH_BOX, "columns": columns, "cells": atlas_index}, separators=(",", ":")), encoding="utf-8")

    # ---- write
    def write_list(path: Path, items: list):
        body = ",\n".join(json.dumps(x, ensure_ascii=False) for x in items)
        path.write_text("[\n" + body + "\n]\n", encoding="utf-8")

    write_list(DATA / "kanji.json", kanji_out)
    write_list(DATA / "parts.json", parts_out)
    write_list(DATA / "words.json", words_out)
    (DATA / "zones.json").write_text(json.dumps({
        "zones": [{"id": z, "name": n, "tint": t} for z, n, t, _ in ZONES],
        "radical_zone": {str(r): z for r, z in radical_zone.items()},
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    (DATA / "meta.json").write_text(json.dumps({
        "built": date.today().isoformat(),
        "openjlpt": openjlpt_version,
        "kanjivg": kvg_tag,
        "kanji": len(kanji_out),
        "parts": len(parts_out),
        "words": len(words_out),
    }, indent=1), encoding="utf-8")

    # ---- report
    print(f"openjlpt {openjlpt_version}, kanjivg {kvg_tag}")
    for lv in LEVELS:
        nk = sum(1 for k in kanji_out if k["level"] == lv)
        nw = sum(1 for w in words_out if w["level"] == lv)
        print(f"{lv}: {nk} kanji, {nw} words")
    print(f"parts introduced: {len(parts_out)} ({sum(1 for p in parts_out if not p['is_kanji'])} non-kanji)")
    print(f"words dropped: {dropped_kana} kana-only, {dropped_unknown} with kanji outside the lists, {dropped_bad} bad readings; {merged} duplicates merged")
    print(f"dependency cycles broken: {cycles}")
    for ch in ("海", "毎", "母", "毋", "聞"):
        print(f"  krad {ch}: {' '.join(krad.get(ch, []))}")
    print(f"kanjivg missing for: {''.join(missing_strokes) or 'none'}")
    no_parts = [k["ch"] for k in kanji_out if not k["parts"]]
    print(f"kanji without parts: {len(no_parts)} {''.join(no_parts[:40])}")
    zone_counts = {}
    for k in kanji_out:
        zone_counts[k["zone"]] = zone_counts.get(k["zone"], 0) + 1
    print("zones:", json.dumps(zone_counts))
    print("first 30:", " ".join(k["ch"] for k in kanji_out[:30]))


if __name__ == "__main__":
    main()
