"""Writes tests/fixtures/rating_golden.json from openskill's PlackettLuce model (dev only).

Needs the package once in your own environment: python -m pip install openskill
Then, from the repo root: python zenith/tools/rating_golden.py

Each case is a winner and a loser before one result and both after it, as the package rates them
with the constants `scripts/server/rating.gd` uses. `tests/run_tests.gd` holds the port to these
numbers to 1e-9.
"""

import json
import pathlib

import openskill
from openskill.models import PlackettLuce

MODEL = PlackettLuce(mu=25.0, sigma=25.0 / 3.0, beta=25.0 / 6.0, kappa=0.0001, tau=25.0 / 300.0,
                     limit_sigma=False, balance=False)
OUT = pathlib.Path(__file__).resolve().parent.parent / "tests" / "fixtures" / "rating_golden.json"


def pair(winner, loser):
    w = MODEL.rating(mu=winner[0], sigma=winner[1])
    l = MODEL.rating(mu=loser[0], sigma=loser[1])
    [[w_after], [l_after]] = MODEL.rate([[w], [l]])
    return {
        "winner": {"mu": winner[0], "sigma": winner[1]},
        "loser": {"mu": loser[0], "sigma": loser[1]},
        "after": [
            {"mu": w_after.mu, "sigma": w_after.sigma, "ordinal": w_after.ordinal()},
            {"mu": l_after.mu, "sigma": l_after.sigma, "ordinal": l_after.ordinal()},
        ],
    }


def main():
    new = (25.0, 25.0 / 3.0)
    cases = [
        ("new beats new", new, new),
        ("settled beats new", (31.0, 3.2), new),
        ("new beats settled", new, (31.0, 3.2)),
        ("favourite wins", (34.5, 4.1), (22.0, 4.4)),
        ("upset", (18.0, 5.0), (33.0, 2.9)),
        ("big upset", (5.0, 7.5), (48.0, 1.5)),
        ("close settled", (27.3, 2.1), (27.1, 2.2)),
        ("far apart settled", (41.0, 1.2), (12.0, 1.3)),
        ("tiny sigmas", (25.0, 0.4), (25.0, 0.4)),
        ("negative mu", (-3.0, 6.0), (2.0, 6.5)),
    ]
    out = [dict(pair(w, l), name=name) for name, w, l in cases]
    # Several matches in a row between the same two, each fed the ratings the last one gave.
    a, b = new, new
    for i, a_wins in enumerate([True, True, False, True, False, False, True, True, True, False]):
        winner, loser = (a, b) if a_wins else (b, a)
        case = pair(winner, loser)
        case["name"] = "run of ten, match %d" % (i + 1)
        out.append(case)
        after_w = (case["after"][0]["mu"], case["after"][0]["sigma"])
        after_l = (case["after"][1]["mu"], case["after"][1]["sigma"])
        a, b = (after_w, after_l) if a_wins else (after_l, after_w)
    OUT.write_text(json.dumps({"openskill": openskill.__version__, "model": "PlackettLuce",
                               "cases": out}, indent=1) + "\n", encoding="utf-8")
    print("wrote %d cases to %s" % (len(out), OUT))


if __name__ == "__main__":
    main()
