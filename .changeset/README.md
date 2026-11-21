# Changesets

Add one player-facing changeset per notable change, with `npm run changeset`
or a file like:

```md
---
"forever-macro-manager": patch
---

Fix the player-visible problem.
```

Version policy is **major.minor.revision**: new features use `minor`, fixes use
Changesets `patch` (revision). Use `major` **only on Dylan's explicit direction**;
an incompatible change does not independently authorize a major bump.

The comparison ref is `origin/main`, available in both normal clones and CI's
detached pull-request checkout. Keep remote refs fetched; a local `main` branch
is not required for release-plan validation.

`package.json` starts at **0.0.0 as a tooling seed**, not a released addon.
The pending initial minor changeset plans the first actual release, **0.1.0**.
Do not pre-bump the seed to 0.1.0 or consume the initial changeset during
development.

Changesets is the release-note source. Its Version Packages pull request consumes
pending changesets and generates `CHANGELOG.md`; `npm run version` also generates
`Changelog.lua` as data. There is no separate changelog interface in the addon.
Do not hand-edit released entries or the generated Lua file.
