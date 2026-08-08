using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Bakes <c>scenes/outpost/outpost_vegetation.tscn</c> from the scatter manifest the outpost backdrop's
/// stripped billboard vegetation left behind (<c>assets/models/environment/outpost_scatter.json</c>:
/// one <c>{kind, x, z, y, w, h}</c> record per removed card, world metres, y = terrain height under the
/// card). Every record is replanted as a PSX-nature model instance packed into a
/// <see cref="MultiMeshInstance3D"/> — one node per (kind, model) pairing, so a kind that mixes
/// variants for silhouette variety still costs one draw call per variant.
///
/// Re-running regenerates the same scene (no <see cref="Random"/> anywhere — per-instance yaw and
/// variant choice come from an FNV-1a hash of the record's quantised x/z; every transform, resource id
/// and buffer comes out byte-identical, only Godot's own per-node "unique_id=" values churn):
///   godot --path bulwark res://scenes/dev/vegetation_bake_spike.tscn
/// Must run RENDERED, not --headless: MultiMesh instance transforms live in the rendering server, and
/// the headless dummy driver hands back an empty buffer — the scene saves and loads fine but draws
/// nothing. The spike fails fast rather than baking an invisible forest.
///
/// Geometry notes:
///  * Every glb in assets/models/psx_nature/ is authored Z-up with the mass hanging toward -Z from a
///    base-of-trunk origin. <see cref="PsxRotation"/> (+90 deg about X) is the pack-wide upright
///    correction; it is baked into every instance transform, so the scene needs no runtime fixup.
///  * Model height and the offset from origin to the model's lowest point are measured from the mesh
///    AABB at bake time, not hardcoded — adding a variant to <see cref="Plans"/> needs no other edit.
///  * Per-instance scale is card height / measured model height, times the variant's size bias, with
///    the card height first clamped to 0.6x-1.4x the kind's median so a degenerate record can't
///    produce a giant or a speck.
///  * Instances are seated exactly on the manifest's terrain height (origin.Y = y - lowestPoint*scale).
/// No colliders: the cards had none, and the forest sits outside the walls.
///  * <see cref="TreatFoliageMaterials"/> lowers the alpha-scissor cutoff on leaf/branch/frond surfaces
///    and switches them to alpha-to-coverage so the treeline holds its density at distance instead of
///    thinning out as its mips lose alpha (see method doc for detail).
/// </summary>
public partial class VegetationBakeSpike : SpikeBase
{
    private const string ManifestPath = "res://assets/models/environment/outpost_scatter.json";
    private const string OutScenePath = "res://scenes/outpost/outpost_vegetation.tscn";
    private const string ModelDir = "res://assets/models/psx_nature/";

    /// <summary>Pack-wide upright correction: the models are authored with -Z as "up".</summary>
    private static readonly Basis PsxRotation = new(Vector3.Right, Mathf.DegToRad(90f));

    /// <summary>One model choice for a kind. <paramref name="SizeBias"/> multiplies the card-height-derived
    /// scale (used where a card's proportions don't match the model's — see the per-kind comments);
    /// <paramref name="Weight"/> is the relative share of the kind's instances this variant takes.</summary>
    private readonly record struct Variant(string Model, float SizeBias, int Weight);

    /// <summary>A kind's replanting rule. <paramref name="FlattenY"/> squashes the instance vertically
    /// after scaling (1 = untouched) — only rock_flat uses it, to turn a boulder into a slab.</summary>
    private readonly record struct KindPlan(string Kind, Variant[] Variants, float FlattenY);

    // Kind -> model mapping. Median card sizes (w x h, metres) from the manifest are quoted per kind;
    // model heights are the measured upright heights of the glbs.
    private static readonly KindPlan[] Plans =
    {
        // 3.84 x 7.69 — narrow tall conifer. The three pine_tree_n variants share one 1250-tri mesh and
        // differ only in bark/branch texture: n_2 green, n_3 olive, n_1 rust. Weighted green-heavy — the
        // billboards this replaces were a dark green treeline, and an even split turns the ring autumnal.
        new("pine", new Variant[] { new("pine_tree_n_2", 1f, 4), new("pine_tree_n_3", 1f, 2), new("pine_tree_n_1", 1f, 1) }, 1f),
        // 4.73 x 7.10 — same models, slightly shorter: stratifies the treeline instead of one flat canopy.
        new("pine_large", new Variant[] { new("pine_tree_n_2", 1f, 4), new("pine_tree_n_3", 1f, 2), new("pine_tree_n_1", 1f, 1) }, 1f),
        // 4.23 x 5.29 — the short broad conifers that filled gaps under the tall ones.
        new("pine_broad", new Variant[] { new("pine_tree_n_2", 1f, 4), new("pine_tree_n_3", 1f, 2), new("pine_tree_n_1", 1f, 1) }, 1f),
        // 5.41 x 8.12 — broadleaf. tree_5 is green, tree_7 yellowing, tree_6 orange: green canopy with a
        // late-summer scatter of turning trees.
        new("oak", new Variant[] { new("tree_5", 1f, 5), new("tree_7", 1f, 1), new("tree_6", 1f, 1) }, 1f),
        // 1.09 x 2.18 — tree_1 is a slender young broadleaf (the pack's tree_9 is a bare dead trunk).
        new("sapling", new Variant[] { new("tree_1", 1f, 1) }, 1f),
        // 3.07 x 2.30 — the pack has no dedicated shrub, but fern_1's texture is a round leafy bush (the
        // name is the pack's, not the subject's) and reads exactly right scaled up to the cards' 2.3 m;
        // fern_2 is the same shape in flower, kept to roughly one bush in six as an accent.
        new("bush", new Variant[] { new("fern_1", 1f, 5), new("fern_2", 1f, 1) }, 1f),
        // 0.94 x 0.84 — the same shrub card at ground-cover size.
        new("fern", new Variant[] { new("fern_1", 1f, 1) }, 1f),
        // 1.05 x 1.24 — waterside grass by the pond (wheat_1 is a golden crop, wrong for a pond edge).
        new("reed", new Variant[] { new("grass_2", 1f, 2), new("grass_3", 1f, 1) }, 1f),
        // 1.28 x 0.69 — a card this small can't take the log's full 3.3 m length at card height; the bias
        // trades exact height for a believable ~2.3 m fallen trunk.
        new("log", new Variant[] { new("tree_log_1", 0.55f, 1) }, 1f),
        // 3.37 x 4.61 — the big cliff cards outside the walls. Biased down: these stones are as wide as
        // they are tall, so matching the card's height outright puts 6 m boulders through the treeline.
        new("crag", new Variant[] { new("stone_3", 0.8f, 1) }, 1f),
        // 2.11 x 1.91 — stone_2 is the flatter, longer boulder; mixing it in breaks up the silhouette
        // repetition across a hundred instances.
        new("boulder_large", new Variant[] { new("stone_3", 1f, 2), new("stone_2", 0.85f, 1) }, 1f),
        // 1.55 x 1.16 — stone_1 is wider than it is tall, so card height alone over-widens it.
        new("boulder_medium", new Variant[] { new("stone_1", 0.8f, 1) }, 1f),
        // 1.08 x 0.59 — same boulder squashed into a slab.
        new("rock_flat", new Variant[] { new("stone_1", 1f, 1) }, 0.6f),
        // 0.91 x 0.70 — stone_5 is a pebble; it takes a large multiplier to reach card size.
        new("rock_small", new Variant[] { new("stone_5", 0.85f, 1) }, 1f),
    };

    /// <summary>A manifest record.</summary>
    private readonly record struct Card(string Kind, float X, float Z, float Y, float W, float H);

    /// <summary>A model's bakeable geometry: the mesh, the upright-corrected transform that places it
    /// (glb node transform folded in), its height and the Y of its lowest point (0 for trunk-origin models,
    /// negative for rocks whose origin sits inside the mass).</summary>
    private sealed record ModelInfo(Mesh Mesh, Transform3D Correction, float Height, float LowestY, string MeshName);

    public override void _Ready()
    {
        GD.Print("==================== VEGETATION BAKE SPIKE ====================");

        if (DisplayServer.GetName() == "headless")
        {
            AbortFail("[vegbake] run this spike rendered — headless returns empty MultiMesh buffers, "
                      + "which bakes a scene that loads clean and draws nothing.");
            return;
        }

        List<Card> cards = LoadManifest();
        Check($"manifest loaded ({cards.Count} instances)", cards.Count > 0);
        if (cards.Count == 0)
        {
            AbortFail("[vegbake] scatter manifest empty or unreadable.");
            return;
        }

        var models = new Dictionary<string, ModelInfo>();
        foreach (string name in Plans.SelectMany(p => p.Variants).Select(v => v.Model).Distinct().OrderBy(n => n, StringComparer.Ordinal))
        {
            ModelInfo? info = LoadModel(name);
            if (info == null)
            {
                AbortFail($"[vegbake] model {name} missing or has no mesh.");
                return;
            }
            models[name] = info;
            GD.Print($"  model {name,-16} height {info.Height,6:F2} m  lowestY {info.LowestY,6:F2}  mesh {info.MeshName} path '{info.Mesh.ResourcePath}'");
        }

        var root = new Node3D { Name = "OutpostVegetation" };
        int planted = 0;
        int nodes = 0;

        foreach (KindPlan plan in Plans)
        {
            List<Card> kindCards = cards.Where(c => c.Kind == plan.Kind).ToList();
            if (kindCards.Count == 0)
            {
                Check($"kind '{plan.Kind}' present in manifest", false);
                continue;
            }

            float medianH = Median(kindCards.Select(c => c.H).ToList());
            float minH = medianH * 0.6f;
            float maxH = medianH * 1.4f;

            // Expand the variant weights once so the per-instance pick is a single modulo.
            var lottery = new List<int>();
            for (int i = 0; i < plan.Variants.Length; i++)
                for (int w = 0; w < plan.Variants[i].Weight; w++)
                    lottery.Add(i);

            var buckets = new List<Transform3D>[plan.Variants.Length];
            for (int i = 0; i < buckets.Length; i++) buckets[i] = new List<Transform3D>();

            foreach (Card card in kindCards)
            {
                int variantIndex = lottery[(int)(Hash(card.X, card.Z, 0x9E3779B9u) % (uint)lottery.Count)];
                Variant variant = plan.Variants[variantIndex];
                ModelInfo info = models[variant.Model];

                float scale = Mathf.Clamp(card.H, minH, maxH) / info.Height * variant.SizeBias;
                float scaleY = scale * plan.FlattenY;
                float yaw = Hash(card.X, card.Z, 0x85EBCA6Bu) % 4096u / 4096f * Mathf.Tau;

                // diag(scale) * yaw * upright-correction — the squash is applied along world Y, after the
                // model is stood up, so a flattened rock stays flat whatever its yaw.
                var scaling = new Vector3(scale, scaleY, scale);
                Basis placement = new Basis(Vector3.Up, yaw).Scaled(scaling);
                Basis basis = (new Basis(Vector3.Up, yaw) * info.Correction.Basis).Scaled(scaling);
                // LowestY is measured in corrected model space, so seating only needs the vertical scale.
                Vector3 seat = new(card.X, card.Y - info.LowestY * scaleY, card.Z);

                buckets[variantIndex].Add(new Transform3D(basis, seat + placement * info.Correction.Origin));
            }

            for (int i = 0; i < plan.Variants.Length; i++)
            {
                if (buckets[i].Count == 0) continue;
                Variant variant = plan.Variants[i];
                ModelInfo info = models[variant.Model];

                var multi = new MultiMesh
                {
                    TransformFormat = MultiMesh.TransformFormatEnum.Transform3D,
                    Mesh = info.Mesh,
                    InstanceCount = buckets[i].Count,
                };
                for (int n = 0; n < buckets[i].Count; n++)
                    multi.SetInstanceTransform(n, buckets[i][n]);

                // The saver reads the transforms back out of the rendering server; an empty read means
                // the bake would ship an invisible forest.
                if (multi.Buffer.Length != buckets[i].Count * 12)
                {
                    AbortFail($"[vegbake] {plan.Kind}/{variant.Model}: multimesh buffer read back "
                              + $"{multi.Buffer.Length} floats, expected {buckets[i].Count * 12}.");
                    return;
                }

                var node = new MultiMeshInstance3D
                {
                    Name = $"{plan.Kind}_{variant.Model}",
                    Multimesh = multi,
                };
                root.AddChild(node);
                node.Owner = root;
                nodes++;
                planted += buckets[i].Count;

                float medianScale = Mathf.Clamp(medianH, minH, maxH) / info.Height * variant.SizeBias;
                GD.Print($"  {plan.Kind,-15} -> {variant.Model,-14} x{buckets[i].Count,4}  median scale {medianScale:F3}"
                         + $"  height {info.Height * medianScale * plan.FlattenY:F2} m");
            }
        }

        Check($"every manifest instance planted ({planted}/{cards.Count})", planted == cards.Count);
        Check($"multimesh node count sane ({nodes})", nodes > 0 && nodes == root.GetChildCount());

        var packed = new PackedScene();
        Error packError = packed.Pack(root);
        Check("PackedScene.pack succeeded", packError == Error.Ok);

        Error saveError = ResourceSaver.Save(packed, OutScenePath);
        Check($"saved {OutScenePath}", saveError == Error.Ok);
        Check("saved scene reloads", saveError == Error.Ok && GD.Load<PackedScene>(OutScenePath) != null);

        root.Free();
        FinishAndQuit("VegetationBakeSpike");
    }

    /// <summary>Reads the scatter manifest. Records with an unplanned kind are reported, not silently dropped.</summary>
    private List<Card> LoadManifest()
    {
        var cards = new List<Card>();
        using FileAccess file = FileAccess.Open(ManifestPath, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError($"[vegbake] cannot open {ManifestPath}");
            return cards;
        }

        var json = new Json();
        if (json.Parse(file.GetAsText()) != Error.Ok)
        {
            GD.PushError($"[vegbake] {ManifestPath}: {json.GetErrorMessage()} (line {json.GetErrorLine()})");
            return cards;
        }

        var root = json.Data.AsGodotDictionary();
        var instances = root["instances"].AsGodotArray();
        var planned = Plans.Select(p => p.Kind).ToHashSet();
        var unknown = new HashSet<string>();

        foreach (Godot.Variant entry in instances)
        {
            var record = entry.AsGodotDictionary();
            string kind = record["kind"].AsString();
            if (!planned.Contains(kind))
            {
                unknown.Add(kind);
                continue;
            }
            cards.Add(new Card(
                kind,
                (float)record["x"].AsDouble(),
                (float)record["z"].AsDouble(),
                (float)record["y"].AsDouble(),
                (float)record["w"].AsDouble(),
                (float)record["h"].AsDouble()));
        }

        if (unknown.Count > 0)
            GD.PushError($"[vegbake] manifest kinds with no plan: {string.Join(", ", unknown.OrderBy(k => k, StringComparer.Ordinal))}");

        return cards;
    }

    /// <summary>Instances a psx_nature glb once to harvest its mesh, its node transform and its measured
    /// upright bounds. The instance is freed before returning — only the shared Mesh resource is kept.</summary>
    private static ModelInfo? LoadModel(string name)
    {
        var scene = GD.Load<PackedScene>($"{ModelDir}{name}.glb");
        if (scene == null) return null;

        Node3D instance = scene.Instantiate<Node3D>();
        var found = new List<(Mesh Mesh, Transform3D Xform, string Name)>();
        CollectMeshes(instance, Transform3D.Identity, found, isRoot: true);

        if (found.Count == 0)
        {
            instance.Free();
            return null;
        }
        if (found.Count > 1)
            GD.PushWarning($"[vegbake] {name} has {found.Count} mesh nodes; only '{found[0].Name}' is baked.");

        (Mesh mesh, Transform3D xform, string meshName) = found[0];
        Mesh bakedMesh = TreatFoliageMaterials(mesh);
        Transform3D correction = new Transform3D(PsxRotation, Vector3.Zero) * xform;
        Aabb bounds = TransformAabb(correction, mesh.GetAabb());
        instance.Free();

        return new ModelInfo(bakedMesh, correction, bounds.Size.Y, bounds.Position.Y, meshName);
    }

    /// <summary>Distance-stability fix for the pack's alpha-scissored foliage surfaces (leaf/branch/frond
    /// textures — bark and stone surfaces are untouched, they're opaque). Mipmapped alpha falls off
    /// gradually toward the coarser levels sampled at distance; against the pack's authored 0.5 cutoff
    /// most of a far tree's canopy pixels fail the test and the treeline reads sparse and olive-brown
    /// even though the same trees are lush green up close. Lowering the cutoff to 0.25 and dithering the
    /// edge via alpha-to-coverage (instead of a hard discard) keeps far-mip coverage close to what the
    /// close mip shows. Works on a *duplicated* mesh with duplicated per-surface materials — nothing
    /// else in the project loads these glbs directly (only this spike does), but duplicating means the
    /// edit can never leak into the shared ArrayMesh/StandardMaterial3D Godot caches from the source
    /// .glb import even if that stops being true later.</summary>
    private const float FoliageAlphaScissorThreshold = 0.25f;

    private static Mesh TreatFoliageMaterials(Mesh mesh)
    {
        if (mesh is not ArrayMesh source) return mesh;

        var treated = (ArrayMesh)source.Duplicate();
        for (int surface = 0; surface < treated.GetSurfaceCount(); surface++)
        {
            if (treated.SurfaceGetMaterial(surface) is not StandardMaterial3D material) continue;
            if (material.Transparency != BaseMaterial3D.TransparencyEnum.AlphaScissor) continue;

            var foliage = (StandardMaterial3D)material.Duplicate();
            foliage.AlphaScissorThreshold = FoliageAlphaScissorThreshold;
            foliage.AlphaAntialiasingMode = BaseMaterial3D.AlphaAntiAliasing.AlphaToCoverage;
            treated.SurfaceSetMaterial(surface, foliage);
        }
        return treated;
    }

    /// <summary>Depth-first walk collecting every MeshInstance3D with its transform relative to the glb
    /// root (the root's own transform is ignored — it is replaced by the instance transform).</summary>
    private static void CollectMeshes(Node node, Transform3D parent, List<(Mesh, Transform3D, string)> found, bool isRoot)
    {
        Transform3D here = !isRoot && node is Node3D spatial ? parent * spatial.Transform : parent;
        if (node is MeshInstance3D meshNode && meshNode.Mesh != null)
        {
            if (meshNode.GetSurfaceOverrideMaterialCount() > 0)
                for (int i = 0; i < meshNode.GetSurfaceOverrideMaterialCount(); i++)
                    if (meshNode.GetSurfaceOverrideMaterial(i) != null)
                        GD.PushWarning($"[vegbake] {meshNode.Name} surface {i} has an override material; MultiMesh uses the mesh's own material.");
            found.Add((meshNode.Mesh, here, meshNode.Name));
        }
        foreach (Node child in node.GetChildren())
            CollectMeshes(child, here, found, isRoot: false);
    }

    /// <summary>Corner-by-corner AABB transform (Godot's operator isn't exposed on every binding version).</summary>
    private static Aabb TransformAabb(Transform3D xform, Aabb box)
    {
        var min = new Vector3(float.MaxValue, float.MaxValue, float.MaxValue);
        var max = new Vector3(float.MinValue, float.MinValue, float.MinValue);
        for (int corner = 0; corner < 8; corner++)
        {
            Vector3 point = xform * (box.Position + new Vector3(
                (corner & 1) != 0 ? box.Size.X : 0f,
                (corner & 2) != 0 ? box.Size.Y : 0f,
                (corner & 4) != 0 ? box.Size.Z : 0f));
            min = new Vector3(MathF.Min(min.X, point.X), MathF.Min(min.Y, point.Y), MathF.Min(min.Z, point.Z));
            max = new Vector3(MathF.Max(max.X, point.X), MathF.Max(max.Y, point.Y), MathF.Max(max.Z, point.Z));
        }
        return new Aabb(min, max - min);
    }

    private static float Median(List<float> values)
    {
        values.Sort();
        return values.Count == 0 ? 1f : values[values.Count / 2];
    }

    /// <summary>FNV-1a over the millimetre-quantised x/z, salted per use. Deterministic across runs and
    /// machines — the bake must be byte-stable, so nothing here may touch <see cref="Random"/>.</summary>
    private static uint Hash(float x, float z, uint salt)
    {
        unchecked
        {
            uint hash = 2166136261u ^ salt;
            foreach (int component in new[] { (int)MathF.Round(x * 1000f), (int)MathF.Round(z * 1000f) })
                for (int shift = 0; shift < 32; shift += 8)
                {
                    hash ^= (uint)(component >> shift) & 0xFFu;
                    hash *= 16777619u;
                }
            return hash;
        }
    }
}
