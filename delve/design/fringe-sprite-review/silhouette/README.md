# Occluded creature silhouette

A muted pale silhouette shows the parts hidden behind opaque terrain or other opaque occluders. The visible body receives no overlay. A one-pixel inner contour helps distinguish feet and limb shapes without adding a glow.

The overlay uses the same Sprite3D geometry, UVs and fixed-Y billboard as the body. Its per-instance material receives the current texture and body alpha immediately before rendering, including frozen attack poses and death fades. Sprite removal releases the pre-draw callback. No sprite assets or gameplay rules changed.

Tune color, opacity and depth bias on the Silhouette material in `scenes/combat/billboard_sprite.tscn`. The shader compares linear view depths with a small bias to suppress self-occlusion. Transparent objects that do not write depth do not trigger the effect. See [Godot depth texture documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html).

`grizzly_bear_idle.png` and `grizzly_bear_contact.png` show the in-world result; `../grounded-prototype/` contains the previous version. `occlusion-check/` has three controlled camera-angle captures.

Validation: rendered CreatureSilhouetteSpike passed 10 checks (unobstructed pixels unchanged, occlusion-only changes from three angles including flipped art, current frozen attack texture, body fade and callback cleanup). The full 12-species capture suite passed 45 checks.
