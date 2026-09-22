class_name AdventureRules
extends RefCounted
## The adventure-only rules a duel runs under, kept away from the screens so a headless runner can
## read them. `Session` is an autoload and a SceneTree script cannot see it, which is why the lives
## numbers live here and not in session.gd.

## Adventure lives (2026-09-22): points the rival must score to beat that seat.
const PLAYER_LIVES: int = 2
const OPPONENT_LIVES: int = 1
const BOSS_LIVES: int = 2


## Lives for one ladder stage, player first. The player always has two; an opponent has one unless
## the stage is the boss, who also has two. `row` is an `AdventureLadder` stage row; an empty row
## is read as an ordinary stage.
static func lives_for(row: Dictionary) -> Array[int]:
	return [PLAYER_LIVES, BOSS_LIVES if str(row.get("tier", "")) == "boss" else OPPONENT_LIVES]
