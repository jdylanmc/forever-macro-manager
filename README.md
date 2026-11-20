# Forever Macro Manager

A macro-editor companion for World of Warcraft: Forever.

Open Blizzard's standard macro editor (`/macro`). A scrolling cheat sheet
automatically accompanies it, including general commands, conditions, targeting,
modifiers, limitations, and druid/healer examples. Closing the editor hides the
companion; reopening it retains your scroll position.

The panel is reference-only: it does not create, change, delete, or execute your
macros. There are no saved variables, configuration, or custom editor.
Icon picker search/filter/sort is a later feature, not included.

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
