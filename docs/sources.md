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

## Offline visual keyword corpus

`icon-keywords.json` indexes **27,875 texture IDs**: every **27,715 unique
native ID** exported from build **71037**, plus **160 unchanged non-native
original sample records**. The export has **27,765 provider rows** and **50
duplicates**; offline review deduplicates identity, not runtime provider rows.

- **27,711 native IDs** use fresh unencrypted local FileDataID extraction,
  yielding **27,225 distinct visuals** and **486 exact-pixel alias IDs**. Source
  BLP hashes/content keys, review-image hashes and dimension-prefixed unscaled
  first-mipmap RGBA hashes retain per-ID provenance. Only byte-identical decoded
  pixels of the same dimensions share a reviewed representative. Acquisition
  acceptance independently verified every source/image and alias; visual owners
  reviewed every representative across **13 shards / 572 sheets**.
- **Four native IDs** (2147656, 2741548, 2892271, 8119728) use separately
  supplied normal-interface screenshot crops. The original is **2883×1501**;
  each target crop is **80×80**. Parent capture acceptance independently checked
  exact RGBA crop equality and image/pixel hashes. These are UI-scaled/composited
  screenshot pixels, not extracted BLP/content-key proof. Visible labels and the
  user-executed `Texture:SetTexture` command establish render identity; build
  evidence is separate, not text printed in the screenshot. The actual
  question-mark control 134400 adds no screenshot coverage and retains its
  ordinary extracted review.
- **160 original non-native records** retain their earlier community-source
  limitations and exact original annotations/provenance. All **416** native
  overlaps from that pilot were replaced by fresh native review, not unioned
  with unsupported older guesses.

`IconKeywords.lua` is the canonical data's compact generated
search-only projection: the deduplicated union of `colors`, `objects`,
`visualThemes` and `keywords`. Confidence, explicit `uncertain` candidates and
notes remain in the canonical JSON, not in the searchable projection. Supported
concrete tags remain searchable even when the overall interpretation has
medium/low confidence. Empty `keywords` is valid when another supported field
is nonempty; there is no separate keyword quota. No names or gameplay mechanics
are inferred from art. **296 native IDs have the explicit `fish` tag**; that is
an annotation statistic, not an exact live UI result count for literal `fish`.
The matcher can also match substrings, names and the current provider's rows.

Coverage is specific to the exported provider/build and its extras. Future
builds, every character's additional learned icons, runtime rendering, client
taint/layout and installed behavior are not proved by offline review/tests.
Keywords annotate only existing native/learned rows; no runtime catalogue
download, ID scan or sample-icon injection occurs.

### Original community sample provenance

- The community [wowdev interface listfile](https://raw.githubusercontent.com/wowdev/wow-listfile/fda564ff2795a7fb927e0c1d52fd755a847c6ee2/parts/interface.csv)
  is pinned to `fda564ff2795a7fb927e0c1d52fd755a847c6ee2`, downloaded SHA256
  `3ca3ad1f1b7698fad784ceab80f267793b1159b2d528c048e6f59b93c9ed8a91`.
  Rows retain exact FileDataID, original path and mapping line. Community
  filename mappings are not authoritative client pixel verification; see the
  [pinned source README](https://github.com/wowdev/wow-listfile/blob/fda564ff2795a7fb927e0c1d52fd755a847c6ee2/README.md).
- Each lowercase BLP filename stem was joined to
  `https://wow.zamimg.com/images/wow/icons/large/{stem}.jpg` for local visual
  inspection. Each record retains the acquired image SHA256 and original
  review batch/label. Filename matching does **not** prove byte/pixel equality
  with that FileDataID in an installed client.
- Eight filename-defined strata contributed 72 images each: abilities, spells,
  weapons, armor, food/consumables, miscellaneous inventory, achievements and
  other. Candidates were ordered by SHA256 of the lowercase original path;
  the first 120 per stratum were fetched and the first 72 successful distinct
  image hashes selected. This is a broad World of Warcraft sample, including
  modern expansions, **not an export of the native Forever picker**.
- This historical selection/mapping method is retained under canonical
  `provenance.legacySample` for the 160 preserved non-native records, not used
  as proof for the freshly reviewed native corpus. Source filenames are
  supplemental identity metadata, never a visual-keyword substitute.
- Public artwork access is not redistribution permission. No images, contact
  sheets, external descriptions, catalogue code or bulk DB2 tables are included.
  This delivery includes original text annotations and identity/provenance
  metadata only. The source filenames are evidence, not visual search claims.

### Native coverage and regeneration

`native-icons-71037.json` preserves the sorted unique numeric IDs from that
export, its row/duplicate counts and SHA256
`2f8d47178dcf4aa4d174bd923b46bb9961db5a91758259332341a7c969d4d9e3`.
It contains no account/character identifiers or artwork. The target is specific
to the exported provider and build, not a claim about all future builds or
every character's additional learned icons.

The generator reports native coverage separately from total indexed IDs:
**27,715/27,715**, zero missing, 160 non-native originals. `--require-native`
rejects an actually missing target even if unrelated IDs keep corpus size high.
Ordinary `npm run test:scripts` also enforces that entire independent target set,
appropriate source proof and exact accepted native-sheet hash set, validates
alias representatives, and checks unchanged original non-native records by
their independently captured hash. It does not rely on an optional CLI flag
or count alone. Lua tests load the real full generated lookup and use the
existing picker matcher for ID-specific fish/shield/sword regression queries
and known false-positive exclusions.

Canonical `provenance.nativeReview` records the accepted extraction, corrected
sheet receipt/worker-report pins, screenshot capture/annotation and screenshot
hashes. The native extraction manifest is
`24216ad1a256bcd0d2933218cac9458016b088345e761b3aa2287a6bc460ed77`;
the final corrected annotation receipt is
`111d360640526e84dcf0b223afc347d70b7eca921c29a7053b672733fdaa9be0`.
Review hashes identify the accepted original review bytes; they are not
artwork distribution or proof of every possible semantic interpretation.

The annotation schema retains the original records and their shared community
provenance. A new record may override source identity with `source`:
`kind` (`client-file-data-id`, `public-filename` or
`normal-client-UI-rendered-screenshot`), `reference` (publishable
source/evidence identifier) and `identityLimit` (actual remaining limitations).
Client-ID sources also require `build`. A client source can retain a known
`originalPath` with explicit `mappingLine: null` when no listfile line was
recovered; unknown paths are also explicit `null`. Public filename sources
still require the path and mapping line and do not prove native pixels.
Review batches use lowercase hyphen-separated identifiers; native labels retain
their exact string form, such as `0001-01`, without changing old numeric labels.

`scripts/import-native-icon-keywords.mjs` adapts the actual sealed acquisition
manifests and version 2 per-sheet reviews. Its read-only `--check-acquisition
INDEX EXPECTED_SHA256` command authenticates the supplied index, asset/visual
manifests, every shard, sheet mapping and contact-sheet image by their supplied
hashes. It verifies the complete success/gap partition against the target,
unique assignments, representative/member identities, per-ID source evidence
and exact-pixel hash/dimension agreement. Individual source/image bytes were
independently verified during acquisition acceptance; this adapter consumes
that trusted evidence, not an arbitrary unverified manifest.

The exported `importNativeSheet` reads a parent-accepted review path and its
expected SHA256, rejects missing/skipped/unassigned/mismatched reviews, and
expands only the acquisition-proven aliases. Its returned canonical records
retain each ID's original path, source BLP SHA256, content key, image hash,
normalized-pixel hash and build, plus reviewed representative and manifest,
sheet/mapping and annotation hashes. These proof fields must be complete when
present. Local source/image/archive/sheet paths are not copied into records;
private paths in original annotation text cause rejection, not silent rewriting.

`integrateNativeReviews` combines only explicitly accepted sheets with old
non-native originals, replacing rather than unioning old native guesses.
Completeness is required by default; a deliberately partial in-memory candidate
can be requested for review. Neither the adapter CLI nor these library functions
writes canonical or generated files. The final corpus consumes all 572
hash-bound corrected native reviews and the four hash-bound screenshot reviews.
The four extraction gaps are not excluded or given fallback annotations.

`loadScreenshotCapture` accepts the additive, hash-bound screenshot manifest,
verifies screenshot/crop bytes and sealed-extraction anchors, and requires its
target set to equal the extraction gaps exactly. Render control 134400 never
adds coverage; targets must remain singletons. Crop boxes use zero-based source
pixels with exclusive right/bottom bounds, checked against original screenshot
dimensions. Parent capture acceptance independently established exact RGBA crop
equality and pixel hashes; this metadata adapter does not decode or re-render
the screenshot.

`importScreenshotReview` binds actual reviewed annotation bytes to that capture.
Its distinct source type retains screenshot hash/dimensions, crop rectangle,
screenshot-scoped RGBA/normalized hashes, visible label, user render command,
identity/build evidence and source limitations. Local paths and artwork stay
out. No BLP source hash, content key or archive-verification claim is invented
or accepted for this type. Normal UI scaling/compositing already present in
the screenshot is explicit, and the separately established build is not
misrepresented as text printed in the capture. The optional `screenshotReview`
argument to `integrateNativeReviews` accepts only this same extraction's exact
gap set. Extraction proof for the other 27,711 IDs remains unchanged and strict.

Only the four supported visual fields enter generated Lua. Source metadata,
builds, paths, hashes, confidence, notes and uncertainty are not search terms.
Keep local paths, extraction response data, assets and contact sheets out of
canonical records. Revisions still require source identity and independent
semantic review; the membership gate cannot establish those facts by itself.

### Spell/item name research held back

Research inspected **28 factual name associations across 21 textures** from
Wago-served DB2 rows requested for build **1.60.1.70959**, observed English with
locale unspecified. Only one texture overlapped the original 576-image pilot. Relevant
tables were [SpellMisc](https://wago.tools/db2/SpellMisc/csv?build=1.60.1.70959),
[SpellName](https://wago.tools/db2/SpellName/csv?build=1.60.1.70959),
[ItemSparse](https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70959),
[ItemModifiedAppearance](https://wago.tools/db2/ItemModifiedAppearance/csv?build=1.60.1.70959)
and [ItemAppearance](https://wago.tools/db2/ItemAppearance/csv?build=1.60.1.70959).
Server-requested rows are not independently extracted client bytes or a
validated full-table catalogue. No source redistribution license was established.
These associations are **not shipped**: permission/provenance suitable for
publication was not established by that research. This conservative holdback
does not assert that individual factual associations are copyrightable.
Existing localized learned-player/equipped/bag names remain unchanged; this
feature does not claim additional or complete static spell/item names.

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
