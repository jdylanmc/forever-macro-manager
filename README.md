# Forever Macro Manager

A macro-editor companion for World of Warcraft: Forever.

Open Blizzard's standard macro editor (`/macro`). A scrolling cheat sheet
automatically accompanies it, including general commands, conditions, targeting,
modifiers, limitations, and druid/healer examples. Closing the editor hides the
companion; reopening it retains your scroll position.

Each standalone example is light blue, with a **+** control at the far right.
Select an existing macro, place its editor cursor (or select text), then click
**+** to insert that exact line, like typing/pasting. No line breaks are added.
Prose and condition explanations are not insertable commands.

Insertion changes only the current native draft. The addon never creates,
deletes, executes, or directly saves a macro. Blizzard's **Save** button saves
the draft, and its normal editor also saves when closing or switching macros/tabs.
Review your changes before those actions; insertion does not add a separate
save/confirmation step. There are no saved variables, configuration, or custom editor.

Insertion reports an error without changing the draft/cursor/selection if no
editable macro is selected, the name/icon picker is open, text composition is
active, combat prevents editing, or the whole example cannot fit. Native letter
and byte limits apply, including multibyte text. Because the client exposes no
selection-range getter, the space check conservatively requires room without
subtracting selected text: shorten a near-limit draft first, even if replacing
its selection would fit. Otherwise native selection replacement is preserved.

## Native icon picker

Use Blizzard's **New** or **Change Name/Icon** popup. Search and sorting live
inside that popup; the macro name, selected icon, drag/drop, **Okay**, and
**Cancel** remain native. Searching or filtering never changes the selected
texture, even when it disappears from the grid. Clicking a result selects its
actual texture; only the normal native confirmation performs the name/icon save.

- Search is case-insensitive, literal partial matching against icon IDs and
  associated names. IDs are **texture file IDs**, not spell or item IDs.
- **Names are partial:** only learned player spells and currently equipped/bag
  items supply names. All available names sharing a texture can match it.
  This is not whole-game spell/item name search.
- Paths resolve to numeric IDs when the client supports resolution. Unresolved
  paths have no claimed numeric ID/name; search their path text instead. The
  status reports unresolved paths in the current category (even when search
  hides them), plus unavailable item/spell names.
- Filters: **All Icons**, **Spell Icons**, **Item Icons**, and
  **My Character's Spells**. The first three keep Blizzard's own source
  sequences, including duplicates. My Spells includes learned player spells,
  passives, low ranks, and known flyout members/overrides, not pet or future
  spells. It ignores spellbook display settings. It retains native matches in
  native order and appends any missing learned textures in spellbook order.
- **Blizzard Order** is the default. **Name A-Z** uses the first known name in
  case-insensitive alphabetical order, with unnamed icons last. **Icon ID**
  sorts numerically, unresolved paths last. Ties retain their source order.

Metadata is session-only. Opening the popup indexes bounded player spellbook,
equipment, and carried bag slots; relevant events refresh that metadata while
open. Missing item/spell data loads asynchronously without blocking or retry loops.
Typing searches the existing index, not item/spell ID spaces. Closing and
reopening resets search, filter and sort; nothing is persisted or downloaded.

## Compatibility and placement

Targets World of Warcraft: Forever, Interface **16001**; API source reviewed at
client build **1.60.1.70959**. English examples require localized spell names and
appropriate learned ranks. Form numbers are character-specific, not universal.
Examples are source-reviewed, not claimed to be tested in game.

The companion prefers the editor's right side, moves past its icon popup when
space permits, then tries the left, below, or above. It stays screen-clamped.
Extremely small viewports may not fit both windows without overlap; move the
editor or increase available screen space. No Blizzard handlers are replaced.
Actual in-game readability, UI scaling, popup interaction, and other-addon
compatibility still need manual verification. Nothing here installs into a client.

## Development

Node 22 or newer and npm are required for release tooling. Lua 5.1/LuaJIT,
LuaRocks, luacheck, and busted are required for Lua validation.

```text
npm ci
npm run test:scripts
npm run changelog:check
luacheck .
busted
```

CI runs the Lua checks and Node/release-tooling checks as separate jobs.
Mocked lifecycle tests load files in TOC order, test delayed and existing editor
loads, inherited visibility, preserved native scripts, single attachment,
popup placement, scroll bounds, and screen/scale changes.
They also cover per-line controls, plain insert-at-cursor payloads, native
selection replacement, dynamic macro selection, limit failures, multibyte
drafts, unavailable/combat targets, and wrapped examples' button gutter.
Picker tests exercise native lifecycle/provider lookup, duplicate order,
associated names/IDs/paths, all filters, stable sorting, missing/asynchronous
metadata, hidden selections, native confirmation/Cancel, and fixed popup bounds.
These are source-contract simulations, **not in-game proof**.

### In-game acceptance still required

On the supported client, with no account macro-file edits:

1. Open New and Change Name/Icon; check name focus, grid scrolling and every
   filter/sort. Check layout on the current screen and at different UI scales.
   The native name, selected icon, Okay/Cancel and companion must remain usable.
2. Find an icon by a learned spell/passive/rank/flyout name, an equipped/bag
   item's name and a known texture ID. Try mixed case and literal `%`/`[`.
   Check partial-name and empty-result guidance.
3. Check My Spells with passives/low ranks hidden in the spellbook, and with a
   pet present. Learned player icons should remain; unlearned/pet-only icons
   should not enter that filter.
4. Select an icon, filter it out, and confirm: its texture/name must survive.
   Choose a sorted result and confirm its actual texture saves. Cancel another
   change and verify nothing was saved.
5. Drag a native supported spell/item onto the popup during a filtered search;
   verify its selected texture survives filtering and saves normally.
6. Equip/remove or acquire an item; learn/change a spell while open. Verify
   names refresh, including delayed item metadata, without typing stalls.
7. Reopen the popup, verify default order/reset, then recheck cyan **+**
   insertion with the picker closed and its non-destructive refusal while open.

## Releases

The first intended actual release is **0.1.0**. `package.json`'s **0.0.0** is only
a tooling seed: its pending minor changeset produces 0.1.0. Do not pre-bump it.

Versioning uses Changesets: features increment minor, fixes increment revision
(`patch`), and major increments require Dylan's explicit direction.

Changesets is the release-note source; see [.changeset/README.md](.changeset/README.md).
Do not run `npm run version` while preparing the initial feature: it consumes the
pending changeset. Version Packages uses that command to update `CHANGELOG.md`
and generate `Changelog.lua`. The Lua file is packaged data, not another feature.

Release automation follows Forever Radial Bars' new PR #1 setup, not its old
tag-only main: CI -> Version Packages pull request -> human merge -> annotated
version tag -> BigWigs packager -> GitHub release and CurseForge upload.
Tag pushes and manual workflow dispatch can also package. Existing GitHub releases
are skipped; a tagged version without a release can be retried. The 0.0.0 seed is
never released.

The port corrects the source workflow's obsolete Changesets inputs for
`changesets/action@v2`: `version-script`, `commit-message`, `pr-title`,
`github-token`, and `has-changesets` output. The custom version script must run
the changelog generator. Repository Actions settings must allow GitHub Actions
to create pull requests (the setting is named “Allow GitHub Actions to create
and approve pull requests”). No workflow approves or merges them.

**CurseForge upload wiring targets project `1819592`.** The TOC identifies this
Forever Macro Manager project, separate from Forever Radial Bars. The packager
step receives the repository's `CF_API_TOKEN` secret alongside its GitHub token.

Before authorizing a release, generate a CurseForge API token at
<https://authors.curseforge.com/#/settings/api-tokens> and add it as the repository
Actions secret `CF_API_TOKEN`. Never copy Radial Bars' credentials or store token
values in source. Wiring alone does not verify authentication or upload success;
the secret must be configured before publishing. A packaging preflight fails
before the workflow creates a tag or GitHub release if the token is missing;
pending Version Packages pull requests are unaffected. Development performs no
upload.

## Source notes

See [docs/sources.md](docs/sources.md) for pinned API evidence, macro references,
and inherited MIT release tooling.

## License

MIT. See [LICENSE](LICENSE).
