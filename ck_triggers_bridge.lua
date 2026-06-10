-- ck_triggers_bridge.lua
-- ----------------------------------------------------------------------
-- CK's converter disabled every trigger it tagged "multiline/multimatch".
-- Most of those are NOT genuinely multi-line — a Mudlet AND-trigger like
-- `You have learned (.+)!` is functionally a single-line regex with one
-- capture, and `multimatches[2][2]` is just that first capture group.
--
-- CKMud's native engine fires trigger callbacks as (line, cap1, cap2, ...)
-- and matches with LUA PATTERNS (not PCRE).  So the `(.+)` capture triggers
-- port directly; the few PCRE named-group ones are rewritten positionally.
--
-- This bridge re-registers the tractable, useful ones and writes straight
-- into CK's own data tables, so the rest of CK (autolearn, etc.) sees the
-- data exactly as if its native triggers had fired.
--
-- Load AFTER CK.lua — default alphabetical order already does this
-- (CK.lua < ck_triggers_bridge.lua).
--
-- NOT bridged (and why):
--   * main Prompt trigger's PL-suppression check — needs Mudlet
--     selectString/getFgColor buffer APIs CKMud doesn't implement; the
--     PL/Ki/Fatigue numbers come from MSDP anyway.
--   * "autolearn no target" — Mudlet exported it with no pattern lines,
--     so there's nothing to match on.
-- ----------------------------------------------------------------------

local CK = _G.CK
if not CK then
    mud.note("[CK-bridge] CK not loaded — put CK.lua in the plugins folder first.")
    return
end

-- Safe nested getter: tbl("Player","Skills","Learned") -> CK.Player.Skills.Learned
-- Returns nil (never errors) if any branch is missing, so a structural
-- change in CK can't turn every incoming line into an error note.
local function tbl(...)
    local t = CK
    for _, k in ipairs({ ... }) do
        if type(t) ~= "table" then return nil end
        t = t[k]
    end
    return t
end

-- CK normalizes skill names through API.Skills:translate; fall back to the
-- raw name if that helper isn't reachable for any reason.
local function translate(name)
    local ok, v = pcall(function() return CK.API.Skills:translate(name) end)
    if ok and v ~= nil then return v end
    return name
end

-- ── Skill tracking — this is what autolearn reads ──────────────────────
mud.trigger("You have learned (.+)!", function(_, name)
    local L = tbl("Player", "Skills", "Learned"); if L then L[translate(name)] = true end
end)
mud.trigger("You've learned the skill '(.+)' from .+%.", function(_, name)
    local L = tbl("Player", "Skills", "Learned"); if L then L[translate(name)] = true end
end)
mud.trigger("You have mastered the (.+) technique!", function(_, name)
    local M = tbl("Player", "Skills", "Mastered"); if M then M[translate(name)] = true end
end)

-- ── Prompt sub-flags ───────────────────────────────────────────────────
-- Kaioken: original was PCRE `^\[Kaioken: (?<CURR>\d+)/(?<MAX>\d+) ]`.
-- Lua patterns have no named groups, so use positional: cap1=CURR cap2=MAX.
mud.trigger("^%[Kaioken: (%d+)/(%d+) ]", function(_, curr, max)
    local P = tbl("Player")
    if P then P.Kaioken = tonumber(curr); P.MKaioken = tonumber(max) end
    local F = tbl("PromptFlags"); if F then F.Kaioken = true end
end)
mud.trigger("%[Target: ([^%]]+)%s?]", function()
    local T = tbl("Toggles");     if T then T.fighting = true end
    local F = tbl("PromptFlags"); if F then F.Target   = true end
end)

-- ── Auto-fruit on Nx gains (only when the feature is enabled) ──────────
-- Pattern's 2nd capture is the multiplier; eat fruit at 6x or higher.
local function eat_fruit_if(mult)
    local on = false
    pcall(function() on = CK.API:feature("auto_fruit") end)
    if on and (tonumber(mult) or 0) >= 6 then send("eat fruit all") end
end
mud.trigger("^%[CKMud Info]: (.+)'s donation has unlocked (.+)x Gains", function(_, _who, mult)
    eat_fruit_if(mult)
end)
mud.trigger("^%[CKMud Info]: (.+) has bestowed (.+)x Gains upon the universe for ", function(_, _who, mult)
    eat_fruit_if(mult)
end)

-- ── Auto-unravel gauntlet ──────────────────────────────────────────────
mud.trigger("^A door opens and (%w+).* walks in%.$", function(_, who)
    pcall(function() CK.API:auto_unravel(who) end)
end)

-- ── Tell-RPC (only acts when the feature is on) ────────────────────────
mud.trigger("^(%w+) tells you, '(!.+)'$", function(_, who, what)
    pcall(function()
        if CK.API:feature("tell_rpc") then CK.API.tell_rpc:handle(who, what) end
    end)
end)

mud.note("[CK-bridge] triggers bridge loaded: skills learn/master, kaioken/target flags, auto-fruit, auto-unravel, tell-rpc.")
