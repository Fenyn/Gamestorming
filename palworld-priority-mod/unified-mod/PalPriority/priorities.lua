-- PalPriority config. Auto-managed: the mod REWRITES this file when you toggle a
-- work type in-game on a configured pal, so hand-written comments inside the
-- pals table will not survive. Edit priorities freely; keep the structure below.
--
-- FORMAT
--   return {
--     pals = {
--       ["<palkey>"] = {
--         name = "display name",         -- optional, cosmetic only
--         anchor = "Species|hp/sh/df/g", -- optional, set by the mod, do not edit:
--                                        --   species + immutable IVs + gender, used
--                                        --   to re-adopt this entry when the game
--                                        --   re-instances the pal (restart/redeploy)
--         owner = "<32-hex PlayerUId>",  -- optional, set by the mod: the managing
--                                        --   player (last attested clicker) whose own
--                                        --   component carries this pal's writes
--         prio = { [8]=5, [12]=1 },      -- [worktype]=priority (0-5); missing => 0
--         raw  = { PlayerUId={A,B,C,D}, InstanceId={A,B,C,D} }, -- identity, do not edit
--       },
--     },
--   }
--
-- PRIORITY (RimWorld scale): 0 = never do this work. 1 = most important,
--   5 = least important. A pal only works its most-important types that
--   currently have pending work.
-- WORK TYPES: 1 EmitFlame(Kindling) 2 Watering 3 Seeding 4 GenerateElectricity
--   5 Handcraft 6 Collection 7 Deforest 8 Mining 9 OilExtraction
--   10 ProductMedicine 11 Cool 12 Transport 13 MonsterFarm
--
-- Press F9 in-game to print every base pal's key + a ready-to-paste skeleton entry.
return {
  pals = {
    -- Add pals here (auto-managed: clicking a work cell in-game creates entries).
    -- Empty = every pal is vanilla / untouched.
  },
}
