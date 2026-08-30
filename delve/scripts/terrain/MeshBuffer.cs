using System.Collections.Generic;
using Godot;

namespace Delve.Terrain;

/// <summary>
/// One mesh surface under construction: parallel vertex attributes plus an optional index list,
/// packed into the array layout <c>ArrayMesh.AddSurfaceFromArrays</c> expects. Every map mesh —
/// terrain surfaces, the collision mesh, the edge apron, tree props, tile highlights — accumulates
/// through this class so the packing rules live in one place.
///
/// The constructor flags say which attribute arrays the surface carries. A buffer that never gets
/// an index writes a non-indexed triangle soup (three vertices per triangle, in order).
/// </summary>
public sealed class MeshBuffer
{
    /// <summary>Default vertex colour: white, i.e. full wave on a water surface.</summary>
    private static readonly Color White = new(1f, 1f, 1f, 1f);

    private readonly List<Vector3> _verts = new();
    private readonly List<Vector3> _norms = new();
    private readonly List<Vector2> _uvs = new();
    private readonly List<Color> _colors = new();
    private readonly List<int> _indices = new();

    private readonly bool _withUv;
    private readonly bool _withColor;

    /// <param name="withUv">Emit a TexUV array. Off for surfaces whose material ignores UVs.</param>
    /// <param name="withColor">Emit a Color array. Off for surfaces that take no vertex tint.</param>
    public MeshBuffer(bool withUv = true, bool withColor = true)
    {
        _withUv = withUv;
        _withColor = withColor;
    }

    public int VertexCount => _verts.Count;

    /// <summary>Triangles emitted so far, indexed or not.</summary>
    public int TriangleCount => _indices.Count > 0 ? _indices.Count / 3 : _verts.Count / 3;

    public bool IsEmpty => _verts.Count == 0;

    /// <summary>Add a vertex with the default colour.</summary>
    public void Add(Vector3 vertex, Vector3 normal, Vector2 uv) => Add(vertex, normal, uv, White);

    /// <summary>Add a vertex with no UV.</summary>
    public void Add(Vector3 vertex, Vector3 normal, Color color) => Add(vertex, normal, Vector2.Zero, color);

    public void Add(Vector3 vertex, Vector3 normal, Vector2 uv, Color color)
    {
        _verts.Add(vertex);
        _norms.Add(normal);
        _uvs.Add(uv);
        _colors.Add(color);
    }

    public void AddIndices(int a, int b, int c)
    {
        _indices.Add(a);
        _indices.Add(b);
        _indices.Add(c);
    }

    /// <summary>
    /// One triangle with a shared normal, added to this buffer and to <paramref name="mirror"/> when
    /// one is given (the collision mesh, which takes the geometry but no vertex colours).
    /// <paramref name="reverse"/> swaps the 2nd and 3rd index, which points the face the other way.
    /// </summary>
    public void AddTriangle(
        MeshBuffer? mirror, Vector3 a, Vector3 b, Vector3 c, Vector3 normal,
        Vector2 uvA, Vector2 uvB, Vector2 uvC, bool reverse)
    {
        int i = _verts.Count;
        Add(a, normal, uvA);
        Add(b, normal, uvB);
        Add(c, normal, uvC);
        if (reverse) AddIndices(i, i + 2, i + 1);
        else AddIndices(i, i + 1, i + 2);

        mirror?.AddTriangle(null, a, b, c, normal, uvA, uvB, uvC, reverse);
    }

    /// <summary>
    /// Four vertices, two triangles wound (0,1,2) and (0,2,3), mirrored into
    /// <paramref name="mirror"/> when one is given. The caller supplies the shared normal, so a
    /// collapsed edge cannot produce a black face.
    /// </summary>
    public void AddQuad(
        MeshBuffer? mirror, Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3, Vector3 normal,
        Vector2 uv0, Vector2 uv1, Vector2 uv2, Vector2 uv3,
        Color c0, Color c1, Color c2, Color c3)
    {
        int b = _verts.Count;
        Add(v0, normal, uv0, c0);
        Add(v1, normal, uv1, c1);
        Add(v2, normal, uv2, c2);
        Add(v3, normal, uv3, c3);
        AddIndices(b, b + 1, b + 2);
        AddIndices(b, b + 2, b + 3);

        mirror?.AddQuad(null, v0, v1, v2, v3, normal, uv0, uv1, uv2, uv3, White, White, White, White);
    }

    /// <summary>Pack into the surface-array layout. int32 indices, no tangents.</summary>
    public Godot.Collections.Array ToSurfaceArrays()
    {
        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = _verts.ToArray();
        arrays[(int)Mesh.ArrayType.Normal] = _norms.ToArray();
        if (_withUv) arrays[(int)Mesh.ArrayType.TexUV] = _uvs.ToArray();
        if (_withColor) arrays[(int)Mesh.ArrayType.Color] = _colors.ToArray();
        if (_indices.Count > 0) arrays[(int)Mesh.ArrayType.Index] = _indices.ToArray();
        return arrays;
    }

    /// <summary>Append this buffer as one more surface of <paramref name="mesh"/>. Empty is a no-op.</summary>
    public void AppendTo(ArrayMesh mesh, Material? material)
    {
        if (IsEmpty) return;
        int surface = mesh.GetSurfaceCount();
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, ToSurfaceArrays());
        if (material != null) mesh.SurfaceSetMaterial(surface, material);
    }

    /// <summary>This buffer as a single-surface named mesh.</summary>
    public ArrayMesh ToArrayMesh(string resourceName, Material? material = null)
    {
        var mesh = new ArrayMesh { ResourceName = resourceName };
        AppendTo(mesh, material);
        return mesh;
    }
}
