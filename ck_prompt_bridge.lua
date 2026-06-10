-- ck_prompt_bridge.lua
-- CK's own "Prompt" trigger is a Mudlet multiline/multimatch trigger
-- (its first line is `local matches = multimatches[2]`), which CKMud
-- does not support — so it never fires and CK.onPrompt is never raised.
-- That left Toggles.firstprompt stuck false and the whole bot inert.
--
-- This bridge fires CK.onPrompt from a native CKMud trigger on each
-- prompt line, which (with the engine event-handler fix) reaches CK's
-- onPrompt() handler and sets firstprompt = true.
--
-- Load AFTER CK (CK.lua sorts before ck_prompt_bridge.lua, so default
-- alphabetical load order is correct). Delete ck_prompt_diag.lua once
-- this is in place.

-- Match YOUR prompt line. Yours looks like:
--   [Pl: 22,097,906,835 | Ki: 100% | GK: 100% | Fatigue: 0%]
-- Adjust this Lua pattern if your prompt format differs.
mud.trigger("Pl:.*Ki:.*Fatigue", function()
    raiseEvent("CK.onPrompt")
end)

mud.note("ck_prompt_bridge loaded — raising CK.onPrompt on each prompt.")
