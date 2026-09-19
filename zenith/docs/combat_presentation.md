# Combat presentation

The active card remains a camera-facing 3D preview. Live damage and decision controls attach directly below it in one column, without a separate information panel. The printed name, type and rules are not repeated. Cardless decisions use compact controls in the same space. The field connects the attack source to its target with a directional filament. A transverse cap indicates a stopped attack; a double arrow indicates damage landing. These indicators remain readable with reduced motion.

Incoming damage comes from the public attack breakdown. Hovering an offered defense or Endurance choice shows an explicitly labeled preview supplied by the referee in the same compact display; leaving the choice restores the baseline. It never modifies the game. Once damage starts resolving, the display distinguishes damage already dealt from wounds still remaining. Stop progress appears when more than one stop is needed.

An announced card awaiting a response is exposed as `SeatView.pending_card`, including its public face even before it leaves the hand. Other hand cards remain private. Nested response windows identify that pending card separately from the underlying attack. The resolving-zone list is not a resolution-order contract and is never presented as an ordered stack.

Interaction remains driven by offered `PromptView` options. Waiting for an opponent does not prevent inspecting visible cards. The preview and its attached controls block picking of field cards underneath them. The client does not add automatic passing or extra response windows.

Verification uses `tests/combat_presentation_tests.gd`, the existing UI smoke tests, and the pending-card privacy/serialization regression in `tests/run_tests.gd`. Windowed autoplay captures should include a defense window, an Endurance choice with its preview, and a card response window. Use `--dev-stop-at=defense`, `--dev-stop-at=endurance --dev-hover=0`, or `--dev-stop-at=respond` with the autoplay flags documented in the README.
