# Source notes

## Forever client evidence

API evidence only; no Blizzard implementation is copied into this addon.
Source pinned to installed client build **1.60.1.70959**:

- [Blizzard_MacroUI](https://github.com/Gethe/wow-ui-source/tree/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_MacroUI):
  load-on-demand TOC; `MacroFrame` is 338×424, owns native OnShow/OnHide scripts,
  and its editor's `letters="255"` limit includes invisible characters.
  `MacroPopupFrame` is a child anchored to the editor's right side.
- [SharedUIPanelTemplates](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml):
  the icon-selector popup template is 525×495. The macro popup's anchor raises
  its top 5 units above the editor, so it extends below the 424-unit editor.
  Layout fallbacks reserve the combined visible editor/popup bounds.
- [Native macro edit/save behavior](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroUI.lua):
  `GetSelectedIndex()` identifies the current selection. The XML's
  `MacroFrameText` OnTextChanged handler marks the draft dirty and updates its
  count. Native Save, OnHide, tab changes, and macro-selection callbacks call
  SaveMacro; the addon does not invoke those handlers or persistence APIs.
- [Pinned EditBox API](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua):
  exposes Insert, GetNumLetters, GetMaxLetters, GetMaxBytes, IsEnabled,
  IsInIMECompositionMode, cursor accessors, and HighlightText. It exposes no
  readable selection-range getter. The companion calls Insert once, leaving
  cursor movement/selection replacement to the native editbox, and checks
  native letter counts plus byte ceilings before touching the buffer.
  Selection size cannot safely be subtracted: a near-limit draft is rejected
  even if replacing selected text would fit. There is no temporary buffer
  mutation, guessed highlight getter, clipboard, forced save, or truncation.
- [Shared slash handlers](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua):
  cast/use resolve `SecureCmdOptionParse` and pass its target to casting/item
  APIs; `/cast` prefers spells and `/use` prefers items. Stopcasting,
  cancelform, dismount, focus/clearfocus, and targetexact have native handlers.
  Dismount calls `Dismount`, not `CancelShapeshiftForm`.
- [SecureScrollTemplates](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.xml):
  the inherited `UIPanelScrollFrameTemplate` supplies its scrollbar and native
  scroll-range/vertical-scroll handlers. The companion retains those handlers.
- [UIParentPanelManager](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua):
  normal panel placement updates points before showing the panel. The companion
  is anchored to the editor so later editor movement carries it along.

General command/conditional semantics were cross-checked against:

- [Macro conditionals](https://warcraft.wiki.gg/wiki/Macro_conditionals):
  comma AND, slash alternatives, negation, temporary unit targeting, modifiers,
  friendly/alive checks, form indices.
- [Macro commands](https://warcraft.wiki.gg/wiki/Macro_commands):
  command purposes, tooltip directives, repeated-input sequences.
- [Secure command options](https://warcraft.wiki.gg/wiki/Secure_command_options):
  first matching group/option, rather than first castable spell.

The wiki includes other WoW versions. This reference deliberately omits
retail-only conditions/spells and does not infer a Classic Era form ordering.
Cat Form index 3 is an operator-supplied pattern, labeled character-specific.
The addon has not been run in game; source compatibility is not gameplay proof.

## Native icon picker extension

All links below use the same reference-only **1.60.1.70959** source pin.
No Blizzard implementation is copied:

- [IconDataProvider](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_FrameXMLBase/IconDataProvider.lua):
  `SetIconTypes`, `GetNumIcons`, `GetIconByIndex` and `GetIndexOfIcon` describe
  texture sequences, not entities or a name catalogue. Textures may be IDs or
  paths and duplicates are legal. The addon snapshots native All/Spell/Item
  sequences without deduplication, then presents a matching indexed view.
- [Shared picker lifecycle and menus](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua)
  and [selector callbacks](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_SharedXML/Shared/Selector/Blizzard_SelectorUI.lua):
  the popup already has All/Spell/Item menus. `SetupMenu`/`CreateRadio` extend
  that control; selector callbacks resolve through the popup's indexed provider.
  `ReevaluateSelectedIcon` updates the visible selection without changing the
  separate selected texture. Native `SetIconFromMouse` owns drag/drop.
- [Macro popup lifecycle and saving](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_MacroUI/Blizzard_MacroIconSelector.lua):
  OnShow obtains the macro frame's provider and installs selector callbacks.
  The addon attaches after native OnShow and restores that original provider
  after hide. Native Okay reads the selected-icon button and name after hiding;
  it does not save a reordered grid index. The addon never calls CreateMacro
  or EditMacro. Cancel remains native.
- [File assets](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/UIFileAssetAPIDocumentation.lua):
  `C_UIFileAsset.GetFileID(asset)` accepts an ID/path and may return nil.
  Unresolved paths stay explicit, searchable by path, and sort after IDs.
- [Spellbook API](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua)
  and [display filters](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_PlayerSpells/SpellBook/Blizzard_SpellBookFrame.lua):
  raw skill-line offsets/counts and `GetSpellBookItemInfo(slot,
  Enum.SpellBookSpellBank.Player)` include passive and low-rank entries
  independent of display filtering. `Enum.SpellBookItemType.Spell` excludes
  FutureSpell and PetAction; `isOffSpec` excludes inactive-specialization entries.
  `name`, `subName` and `iconID` provide localized name/rank associations.
  SPELLS_CHANGED and SPELL_TEXT_UPDATE invalidate this bounded index.
  A learned entry's base/overriding spell IDs also supply available names/icons.
- [Flyout API](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/FlyoutDocumentation.lua)
  and [spell metadata](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua):
  use **structured** `C_Flyout.GetFlyoutInfo`/`GetFlyoutSlotInfo`, checking
  flyout/member `isKnown`, then `C_Spell.GetSpellInfo` for base/override icons.
  Do not model these as the legacy multi-return globals in the provider override.
  My Spells appends learned textures absent from the native sequences; it does
  not invent textures for missing metadata. Missing known spell metadata uses
  `C_Spell.RequestLoadSpellData` once per ID per opening and listens for relevant
  SPELL_DATA_LOAD_RESULT events. Item/spell load-result events are documented as
  synchronous; a completion during a refresh is retained for the next frame.
- [Container API](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
  and [item metadata/events](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua):
  enumerate carried bags with `C_Container.GetContainerNumSlots`/
  `GetContainerItemID` and equipped slots with `GetInventoryItemID`. Read
  `C_Item.GetItemInfo`'s name/texture; request missing IDs once per opening via
  `RequestLoadItemDataByID`. Relevant ITEM_DATA_LOAD_RESULT,
  PLAYER_EQUIPMENT_CHANGED and BAG_UPDATE_DELAYED events coalesce refreshes.
  Missing/failed metadata is visible, not fabricated; bank/world catalogues
  are not scanned.
- [Inventory constants](https://github.com/Gethe/wow-ui-source/blob/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns/Blizzard_FrameXMLBase/Constants.lua):
  `INVSLOT_FIRST_EQUIPPED` through `INVSLOT_LAST_EQUIPPED` bound equipped gear;
  bags 0 through `NUM_TOTAL_EQUIPPED_BAG_SLOTS` include the backpack and
  equipped carried bags, including reagent bags when that client has them.

The adapter changes the popup's provider reference, dropdown contents and grid
anchors, not its native scripts or save callbacks. The popup stays 525×495;
extra controls use space reclaimed from the scrolling grid, leaving the native
header/footer in place. Character/item enumeration does not run on keystrokes.
Unit fixtures model these source contracts only. Actual client access, taint,
flyout/rank behavior, response time, layout, drag/drop and saving still require
the README's in-game acceptance checks.

## Release tooling

Adapted from Dylan McCurry's MIT-licensed
[Forever Radial Bars PR #1](https://github.com/jdylanmc/forever-radial-bars/pull/1),
commit [5911fb6904035ee2fa4fc48bd974a394182abe71](https://github.com/jdylanmc/forever-radial-bars/tree/5911fb6904035ee2fa4fc48bd974a394182abe71):
CI/release workflow shape, Changesets configuration, changelog generator and
its parsing/escaping tests. The repository MIT license is preserved. No radial
game code, media, or game tests are included.

The source workflow's Changesets API names do not match actual v2 metadata.
Verified [changesets/action v2 action.yml](https://github.com/changesets/action/blob/v2/action.yml)
uses `version-script`, `commit-message`, `pr-title`, `github-token`, and the
`has-changesets` output. This port uses those names and tests the wiring.
The generator additionally handles control characters and only treats a missing
target as stale; other filesystem failures remain visible. Release tag lookup
distinguishes an absent tag (Git exit 2) from transport/authentication errors.
