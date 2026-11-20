import assert from 'node:assert/strict';
import { test } from 'node:test';
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parseChangelog, renderLua } from './build-changelog.mjs';

const root = new URL('../', import.meta.url);
const sample = `# forever-macro-manager

## 0.1.1

### Patch Changes

- 6cb6f11: Fix the **panel** in \`combat\`.
  Continues on a second line.
- Plain "quoted" entry with a | pipe.

## 0.1.0

- Entry without a section.
`;

test('parses releases, sections, commit prefixes, and continued entries', () => {
  const releases = parseChangelog(sample.replaceAll('\n', '\r\n'));
  assert.deepEqual(releases.map(r => r.version), ['0.1.1', '0.1.0']);
  assert.equal(releases[0].sections[0].title, 'Patch Changes');
  assert.deepEqual(releases[0].sections[0].entries, [
    'Fix the **panel** in `combat`. Continues on a second line.',
    'Plain "quoted" entry with a | pipe.',
  ]);
  assert.equal(releases[1].sections[0].title, 'Changes');
});

test('escapes Lua, control characters, and game markup without Markdown', () => {
  const releases = parseChangelog(sample);
  releases[0].sections[0].entries.push('path\\name\t\r\n\0' + '1');
  const lua = renderLua(releases);
  assert.match(lua, /"Fix the panel in combat\. Continues on a second line\."/);
  assert.match(lua, /"Plain \\"quoted\\" entry with a \|\| pipe\."/);
  assert.ok(lua.includes('"path\\\\name\\009\\013\\010\\0001"'));
  assert.doesNotMatch(lua, /6cb6f11/);
});

test('generated addon data matches the canonical changelog', () => {
  assert.equal(
    readFileSync(new URL('Changelog.lua', root), 'utf8'),
    renderLua(parseChangelog(readFileSync(new URL('CHANGELOG.md', root), 'utf8'))),
  );
  const result = spawnSync(process.execPath, [
    fileURLToPath(new URL('scripts/build-changelog.mjs', root)), '--check',
  ], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /up to date/);
});

test('CLI detects missing/stale output and preserves real filesystem errors', () => {
  const fixture = new URL(`.tools/changelog-test-${process.pid}/`, root);
  mkdirSync(new URL('.tools/', root), { recursive: true });
  mkdirSync(fixture);
  try {
    mkdirSync(new URL('scripts/', fixture));
    const script = new URL('scripts/build-changelog.mjs', fixture);
    const markdown = new URL('CHANGELOG.md', fixture);
    const target = new URL('Changelog.lua', fixture);
    copyFileSync(new URL('scripts/build-changelog.mjs', root), script);
    writeFileSync(markdown, sample);
    const run = (...args) => spawnSync(process.execPath, [fileURLToPath(script), ...args],
      { encoding: 'utf8' });

    assert.equal(run('--check').status, 1, 'missing output must fail');
    assert.equal(run().status, 0, 'generation must succeed');
    assert.equal(run('--check').status, 0, 'fresh output must pass');
    writeFileSync(markdown, sample + '- Another change.\n');
    assert.equal(run('--check').status, 1, 'stale output must fail');
    rmSync(target);
    mkdirSync(target);
    const invalidTarget = run('--check');
    assert.notEqual(invalidTarget.status, 0);
    assert.match(invalidTarget.stderr, /EISDIR/);
    assert.doesNotMatch(invalidTarget.stderr, /out of date/);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});
