local _, ns = ...

ns.REFERENCE = {
	{
		title = "Macro basics",
		text = [[One slash command per line. Long lines wrap in this sheet; keep each command on one line in the editor. Blizzard's editor allows 255 characters, including line breaks.

/cast Spell Name
Cast a known spell. Use your client's localized spell name; specify a rank explicitly when downranking.

/use Item Name
Use an item. /use 13 and /use 14 refer to equipped trinket slots, not bag slots.

#showtooltip Spell Name
Choose a tooltip/icon hint; this does not cast the spell.

/stopcasting
Interrupt your own current cast. Include only when you intend to lose that cast.

/cancelform
Leave your current shapeshift form.

/dismount
Dismount; this does not leave a druid form.]],
	},
	{
		title = "Conditions and priority",
		text = [[/cast [condition] Spell A; Spell B
The first matching option wins, not the first usable spell. A failed cast does not try the next option.

[help,nodead] means friendly AND alive.
[mod:shift] means Shift is held.
[mod:ctrl/alt] means Ctrl OR Alt.
[nomod] means no modifier is held.
[combat] / [nocombat] test your combat state.
[form:n] / [noform:n] test a form index.

[group1][group2] are alternative groups (OR).
[] is an unconditional fallback: normal targeting and self-cast settings apply.
The "no" prefix negates a condition, e.g. [nodead].

Form indices depend on the forms your character knows. Do not copy a number without checking it.]],
	},
	{
		title = "Targeting and modifiers",
		text = [[@mouseover: the unit under your pointer, including unit frames.
@focus: your previously assigned focus.
@player: yourself.
@target: your selected target.

An @unit option affects only that command; it does not change your selected target. help/harm also require the unit to exist. nodead alone does not mean friendly.

/focus
Set your current target as focus.
/clearfocus
Clear it.
/targetexact Name
Change your selected target by exact name.

Modifier keybinds can intercept Shift/Ctrl/Alt before the macro runs. Check your bindings if a modifier example does nothing.]],
	},
	{
		title = "Druid: mouseover healing",
		text = [[#showtooltip Rejuvenation
/cast [@mouseover,help,nodead][help,nodead][@player] Rejuvenation

Use a living friendly mouseover first, then a living friendly target, otherwise yourself. These are condition fallbacks, not range/cooldown fallbacks.

To leave a form before healing, add this line before /cast:
/cancelform [form]

Form cancellation is deliberate: this can leave you exposed. The spell must be learned and usable in your resulting form; a global cooldown may require another press.

Healing Touch can replace Rejuvenation. Choose a rank yourself; the macro cannot choose one from the target's missing health.]],
	},
	{
		title = "Druid: focus dispel",
		text = [[#showtooltip Remove Curse
/cast [@focus,help,nodead][help,nodead] Remove Curse

Try a living friendly focus, otherwise a living friendly selected target. No friendly unit means no cast. A valid focus out of range does not fall back to your target.

This does not test whether a curse is present. Learn the spell and leave any form that prevents casting it; add /cancelform [form] only if you want to leave that form.]],
	},
	{
		title = "Druid: Cat Form pattern",
		text = [[/dismount
/cancelform [noform:3]
/cast [noform:3] Cat Form

Operator-specific example: this pattern was used with Cat Form at index 3. That is NOT a universal index. Replace both 3s with your character's Cat Form index.

If already in that form, the form lines do nothing. Entering Cat Form can trigger the global cooldown. A later ability such as Cower may need a separate press; adding it does not bypass that cooldown.]],
	},
	{
		title = "Limits: player input still required",
		text = [[Macros cannot wait, delay a cast, or choose spells/ranks based on health or mana. Addon Lua cannot bypass protected casting rules.

Multiple /cast lines do not queue a rotation. Global cooldowns and cast times still apply; /castsequence also requires repeated player input and can stall on an unusable step.

Conditions do not test spell readiness, range, or whether a heal/cleanse is needed. You decide when to press.

The + beside each blue example inserts that exact line at the native editor's cursor, replacing selected text when space permits. It adds no line breaks. Review the result before using it. No macro is created, deleted, or executed.

Insertion needs enough room for the entire example without subtracting any selected text: the client exposes no selection-range getter. Shorten a near-limit draft first. Native Save, closing the editor, and switching macros/tabs can save your changes.

Examples were source-reviewed for Forever build 1.60.1.70959, not tested in game by this addon.

English spell names shown. Adapt names/ranks to your spellbook.]],
	},
}
