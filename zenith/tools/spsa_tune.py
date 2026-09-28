"""SPSA tuning of the scorer's judgement weights through headless self-play.

Each step nudges every tuned weight up or down at random (as a multiplier, through the profile's
`scale` group, so every deck keeps its own values and style), plays the "plus" set against the
"minus" set over the full deck matrix with matchlab, and moves every weight toward whichever side
won, in proportion to the margin. Parameters are log-multipliers, so 0 is today's scorer.

The matrix is played `--paired`: every deal is played twice with the pilots swapped, so a deck
that wins its matchup either way, and the luck of the deal, cancel inside the pair and only
games the pilots decide move the weights.

State is written after every step to <out>/state.json and a run resumes from it.

    python zenith/tools/spsa_tune.py --out zenith/reports/spsa/shared --steps 100
    python zenith/tools/spsa_tune.py --out zenith/reports/spsa/shared --report

`--deck <name>` tunes one deck instead: only that deck's multipliers move, its playstyle keys
included, and plus and minus each play it against the whole field (on the shipped defaults) on the
same seeds. The result belongs in that deck's profile as a `scale` block.

    python zenith/tools/spsa_tune.py --deck shade_salvage --out zenith/reports/spsa/deck_shade_salvage \
        --start-from zenith/reports/spsa/shared_big_2026-09-28/state.json --repeats 20 --c 0.5 --a 2.5
"""
import argparse
import json
import math
import os
import random
import subprocess
import sys
from pathlib import Path

GODOT = r"G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe"
ZENITH = Path(__file__).resolve().parent.parent

# The weights AiScorer reads that express judgement. Style keys (declare_bias, declare_use,
# tutor_decay, bond_band, the *_self and *_foe splits, attack_cost_handover) stay as each deck set them.
PARAMS = [
    "play.damage_life", "play.damage_stage", "play.attack_cost", "play.defend_card", "play.defend_in_play",
    "play.use_cost", "play.final_strike_penalty", "play.grounds_skip",
    "effect.if_successful", "effect.if_stopped", "effect.conditional", "effect.energy", "effect.forbid",
    "effect.float", "effect.other", "effect.search", "effect.draw", "effect.discard_in_play",
    "effect.discard_hand", "effect.remove_discard", "effect.stop_all", "effect.recover", "effect.fervor",
    "effect.attach", "effect.capture_seal", "effect.discard_life",
    "own.aspect", "own.seal", "own.ally", "own.drill", "own.non_combat", "own.energy", "own.life_low",
    "foe.aspect", "foe.ally", "foe.seal", "foe.ascension",
]

# Tuned only per deck (`--deck`): the playstyle keys the scorer reads, which are that deck's own business.
STYLE_PARAMS = [
    "play.declare_bias", "play.declare_use", "play.tutor_decay", "play.bond_band", "play.control_ally",
    "play.attack_cost_handover", "effect.energy_self", "effect.fervor_self", "effect.fervor_foe",
    "own.ascension", "own.seal_guard", "own.ally_energy", "foe.ally_energy",
]

LIMIT = 1.0  # log-multiplier bound: 0.37x to 2.7x


def weights_arg(theta):
    return ";".join(f"scale.{k}={math.exp(v):.4f}" for k, v in theta.items())


def matchlab(args, out, flags):
    """Runs one sharded matchlab over `flags` into `out` and returns side a's and side b's wins."""
    out.mkdir(parents=True, exist_ok=True)
    try:
        rel = os.path.relpath(out.resolve(), ZENITH).replace("\\", "/")
        target = f"res://{rel}" if not rel.startswith("..") else str(out.resolve()).replace("\\", "/")
    except ValueError:
        target = str(out.resolve()).replace("\\", "/")
    procs = []
    for i in range(args.shards):
        cmd = [args.godot, "--headless", "--path", str(ZENITH), "-s", "tests/matchlab.gd", "--"] + flags + [
            f"--shard={i}/{args.shards}", f"--json={target}/s{i}.json"]
        log = open(out / f"s{i}.log", "w")
        procs.append((subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT), log))
    for p, log in procs:
        p.wait()
        log.close()
    a = b = 0
    for i in range(args.shards):
        data = json.load(open(out / f"s{i}.json"))
        a += data["side_wins"][0]
        b += data["side_wins"][1]
    return a, b


def play_deck(args, step, plus, minus):
    """Per-deck step: plus and minus each play the deck against the whole field on the same seeds.
    Returns plus's win share minus minus's win share, and a note for the log."""
    out = Path(args.out) / f"step_{step:03d}"
    shares = []
    for label, theta in (("plus", plus), ("minus", minus)):
        a, b = matchlab(args, out / label, ["--a=scorer", "--b=scorer", f"--a-field={args.deck}",
                                            f"--a-weights={weights_arg(theta)}", f"--repeats={args.repeats}",
                                            f"--seed={args.seed + step}"])
        shares.append(a / max(1, a + b))
    return shares[0] - shares[1], f"plus {shares[0]:.3f} minus {shares[1]:.3f}"


def play_shared(args, step, plus, minus):
    """Shared step: plus against minus over the paired full matrix. Returns plus's win share minus
    minus's, and a note for the log."""
    a, b = matchlab(args, Path(args.out) / f"step_{step:03d}", [
        "--a=scorer", "--b=scorer", f"--a-weights={weights_arg(plus)}", f"--b-weights={weights_arg(minus)}",
        f"--repeats={args.repeats}", f"--seed={args.seed + step}", "--paired=on"])
    share = a / max(1, a + b)
    return 2.0 * share - 1.0, f"plus {a} - minus {b} ({share:.3f})"


def params(args):
    return PARAMS + STYLE_PARAMS if args.deck else PARAMS


def load_state(args):
    path = Path(args.out) / "state.json"
    if path.exists():
        return json.load(open(path))
    theta = {k: 0.0 for k in params(args)}
    if args.start_from:
        theta.update(json.load(open(args.start_from))["theta"])
    return {"theta": theta, "step": 0, "history": [], "started_from": args.start_from}


def save_state(args, state):
    path = Path(args.out) / "state.json"
    tmp = path.with_suffix(".tmp")
    json.dump(state, open(tmp, "w"), indent=1)
    os.replace(tmp, path)


def report(state):
    print(f"steps done: {state['step']}")
    recent = state["history"][-20:]
    if recent:
        diffs = [h.get("diff", 2.0 * h.get("plus_share", 0.5) - 1.0) for h in recent]
        print(f"last {len(recent)} steps: mean |plus - minus win share| {sum(abs(d) for d in diffs) / len(diffs):.3f}")
    for k, v in sorted(state["theta"].items(), key=lambda kv: -abs(kv[1])):
        print(f"  {k:28s} x{math.exp(v):.3f}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--steps", type=int, default=100)
    ap.add_argument("--repeats", type=int, default=3, help="matrix repeats per step; 3 is 1092 games")
    ap.add_argument("--shards", type=int, default=8)
    ap.add_argument("--seed", type=int, default=20000)
    ap.add_argument("--a", type=float, default=0.6, help="step gain")
    ap.add_argument("--c", type=float, default=0.2, help="perturbation size, in log-multiplier")
    ap.add_argument("--big-a", type=float, default=10.0, help="step gain stability offset")
    ap.add_argument("--start-from", default="", help="another run's state.json to take the starting weights from")
    ap.add_argument("--deck", default="", help="tune one deck against the field, style keys included; "
                    "--repeats is then per side, 20 is 520 games each")
    ap.add_argument("--godot", default=GODOT)
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()
    Path(args.out).mkdir(parents=True, exist_ok=True)
    state = load_state(args)
    if args.report:
        report(state)
        return
    while state["step"] < args.steps:
        k = state["step"]
        ck = args.c / (k + 1) ** 0.101
        ak = args.a / (k + 1 + args.big_a) ** 0.602
        rng = random.Random(args.seed * 1000 + k)
        names = params(args)
        delta = {p: rng.choice((-1.0, 1.0)) for p in names}
        theta = state["theta"]
        plus = {p: theta[p] + ck * delta[p] for p in names}
        minus = {p: theta[p] - ck * delta[p] for p in names}
        diff, note = play_deck(args, k, plus, minus) if args.deck else play_shared(args, k, plus, minus)
        # Win-share difference between plus and minus, per unit of perturbation.
        grad_scale = diff / (2.0 * ck)
        for p in names:
            theta[p] = max(-LIMIT, min(LIMIT, theta[p] + ak * grad_scale * delta[p]))
        state["history"].append({"step": k, "diff": diff, "note": note, "ck": ck, "ak": ak})
        state["step"] = k + 1
        save_state(args, state)
        print(f"step {k}: {note}, largest moves: " + ", ".join(
            f"{p} x{math.exp(theta[p]):.2f}" for p in sorted(names, key=lambda q: -abs(theta[q]))[:4]), flush=True)


if __name__ == "__main__":
    sys.exit(main())
