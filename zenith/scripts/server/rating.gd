class_name Rating
extends RefCounted
## The rating behind ranked play: the two-player case of the Plackett-Luce update from the Weng-Lin
## method (R. C. Weng and C.-J. Lin, "A Bayesian Approximation Method for Online Ranking", JMLR 12
## (2011) 267-300), ported from openskill.py's `PlackettLuce` model, MIT licence, Copyright (c) 2024
## Vivek Joshy. `tools/rating_golden.py` runs that package with these constants and writes
## `tests/fixtures/rating_golden.json`, which `tests/run_tests.gd` holds this port to.
##
## A rating is {"mu": float, "sigma": float}: the skill guess and how unsure it is. Both stay on the
## server; players see `shown`, which starts at 0 and climbs as sigma shrinks.

const MU: float = 25.0
const SIGMA: float = 25.0 / 3.0
const BETA: float = 25.0 / 6.0
const KAPPA: float = 0.0001
## Added to every sigma before each update, so no rating ever stops moving.
const TAU: float = 25.0 / 300.0
const PROVISIONAL_SIGMA: float = 6.0
const SHOWN_SCALE: float = 40.0


static func fresh() -> Dictionary:
	return {"mu": MU, "sigma": SIGMA}


## [winner after, loser after], each {"mu", "sigma"}, for one result between two players.
static func rate(winner: Dictionary, loser: Dictionary) -> Array[Dictionary]:
	var mu_w: float = float(winner["mu"])
	var mu_l: float = float(loser["mu"])
	var sigma_w: float = sqrt(float(winner["sigma"]) * float(winner["sigma"]) + TAU * TAU)
	var sigma_l: float = sqrt(float(loser["sigma"]) * float(loser["sigma"]) + TAU * TAU)
	var var_w: float = sigma_w * sigma_w
	var var_l: float = sigma_l * sigma_l
	var c: float = sqrt((var_w + BETA * BETA) + (var_l + BETA * BETA))
	var e_w: float = exp(mu_w / c)
	var e_l: float = exp(mu_l / c)
	# The winner's expected chance, and the loser's against the pair of them.
	var p_w: float = e_w / (e_w + e_l)
	var p_l: float = e_l / (e_w + e_l)
	var omega_w: float = (1.0 - p_w) * (var_w / c)
	var delta_w: float = p_w * (1.0 - p_w) * (var_w / (c * c)) * (sqrt(var_w) / c)
	var omega_l: float = -p_l * (var_l / c)
	var delta_l: float = p_l * (1.0 - p_l) * (var_l / (c * c)) * (sqrt(var_l) / c)
	return [
		{"mu": mu_w + omega_w, "sigma": sigma_w * sqrt(maxf(1.0 - delta_w, KAPPA))},
		{"mu": mu_l + omega_l, "sigma": sigma_l * sqrt(maxf(1.0 - delta_l, KAPPA))},
	]


static func ordinal(mu: float, sigma: float) -> float:
	return mu - 3.0 * sigma


## The number a player sees: 40 times the ordinal, never below 0.
static func shown(mu: float, sigma: float) -> int:
	return maxi(0, roundi(SHOWN_SCALE * ordinal(mu, sigma)))


static func provisional(sigma: float) -> bool:
	return sigma > PROVISIONAL_SIGMA
