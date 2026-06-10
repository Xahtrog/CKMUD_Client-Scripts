-- ck_loopfix_bridge.lua
-- ----------------------------------------------------------------------
-- Stops the CK score/status/learn init loop on CKMud.
--
-- WHY THE LOOP HAPPENS:
--   CK's onPrompt() runs PlayerLoad() (which sends `score` + `status`) on
--   EVERY prompt while:
--       Player.Health == nil  or  CK.Player.MaxGravity == nil
--   In Mudlet those fields are filled by the Prompt / status-scrape triggers,
--   which use buffer APIs (selectString / replace / getFgColor) that CKMud
--   doesn't implement — so the importer correctly DISABLES them. But then the
--   two fields stay nil and CK re-requests score/status forever.
--
--   CK's own code already falls back gracefully for these everywhere ELSE
--   (`Player.Health or 100`, `Player.MaxGravity or 2`); the only place a nil
--   actually hurts is that one loop guard. So we just need them set.
--
-- Load AFTER CK.lua (alphabetical order already does this:
--   CK.lua  <  ck_loopfix_bridge.lua).
-- ----------------------------------------------------------------------

local CK = _G.CK
if not CK then
    mud.note("[ck-loopfix] CK not loaded yet — put CK.lua in the plugins folder first.")
    return
end
CK.Player = CK.Player or {}

-- Seed immediately so the loop can't even start on the first prompts.
if CK.Player.Health     == nil then CK.Player.Health     = 100 end
if CK.Player.MaxGravity == nil then CK.Player.MaxGravity = 2   end

-- Pull the real Pl out of the prompt line so CK's number tracks the game.
-- Prompt looks like:  [Pl: 22,100,712,938 | Ki: 100% | GK: 100% | Fatigue: 0%]
mud.triggerRegex([[\[Pl: ([\d,]+) \| Ki:]], function(_, pl)
    CK.Player.Pl = tonumber((pl:gsub(",", ""))) or CK.Player.Pl
    if CK.Player.Health == nil then CK.Player.Health = 100 end
end)

-- Best-effort: if your `score`/`status` screen prints a numeric max gravity
-- (e.g. "Max Gravity: 40"), capture it so autotrain/zeta pick the right
-- gravity. Adjust this pattern to match your MUD's exact wording if needed;
-- if it never matches, MaxGravity just stays at the seeded default (2).
mud.trigger("Max Gravity:%s*(%d+)", function(_, g)
    CK.Player.MaxGravity = tonumber(g) or CK.Player.MaxGravity
end)

mud.note("[ck-loopfix] seeded Player.Health / MaxGravity — CK init loop disabled.")
