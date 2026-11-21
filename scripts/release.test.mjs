import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { test } from 'node:test';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import path from 'node:path';
import { parseChangelog } from './build-changelog.mjs';

const root = new URL('../', import.meta.url);
const read = file => readFileSync(new URL(file, root), 'utf8');
const require = createRequire(import.meta.url);

function childDiagnostics(command, result) {
  return `${command} failed (status ${result.status}, signal ${result.signal}):\n`
    + `${result.error?.stack ?? ''}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`;
}

test('approved first release is pending as 0.1.0 or present in versioned history', () => {
  if (JSON.parse(read('package.json')).version !== '0.0.0') {
    assert.ok(parseChangelog(read('CHANGELOG.md')).some(release => release.version === '0.1.0'),
      'Version Packages must retain the approved first actual release');
    return;
  }
  const cli = require.resolve('@changesets/cli/bin.js');
  const gitDir = fileURLToPath(new URL(`.tools/release-refs-${process.pid}/`, root));
  const git = (args, env = process.env) => {
    const result = spawnSync('git', args, { cwd: root, env, encoding: 'utf8' });
    assert.equal(result.status, 0, childDiagnostics(`git ${args.join(' ')}`, result));
    return result.stdout.trim();
  };
  const head = git(['rev-parse', 'HEAD']);
  const base = git(['rev-parse', 'origin/main']);
  const objects = path.join(git(['rev-parse', '--path-format=absolute', '--git-common-dir']), 'objects');
  mkdirSync(new URL('.tools/', root), { recursive: true });
  let plan;
  try {
    // Match checkout@v7 PR refs without switching or editing the real checkout.
    git(['init', '--bare', '--quiet', gitDir]);
    const env = {
      ...process.env,
      GIT_DIR: gitDir,
      GIT_WORK_TREE: fileURLToPath(root),
      GIT_ALTERNATE_OBJECT_DIRECTORIES: [objects, process.env.GIT_ALTERNATE_OBJECT_DIRECTORIES]
        .filter(Boolean).join(path.delimiter),
    };
    git(['update-ref', '--no-deref', 'HEAD', head], env);
    git(['update-ref', 'refs/remotes/origin/main', base], env);
    assert.equal(git(['for-each-ref', '--format=%(refname)', 'refs/heads'], env), '');
    const result = spawnSync(process.execPath, [cli, 'status', '--output=.release-plan.json'], {
      cwd: root, env, encoding: 'utf8',
    });
    assert.equal(result.status, 0, childDiagnostics('changeset status', result));
    // Status writes a report, never versions or consumes changesets.
    plan = JSON.parse(read('.release-plan.json'));
  } finally {
    rmSync(new URL('.release-plan.json', root), { force: true });
    rmSync(gitDir, { recursive: true, force: true });
  }
  assert.deepEqual(plan.releases.map(({ name, type, oldVersion, newVersion }) =>
    ({ name, type, oldVersion, newVersion })), [{
    name: 'forever-macro-manager', type: 'minor', oldVersion: '0.0.0', newVersion: '0.1.0',
  }]);
});

test('release uses actual Changesets action v2 inputs/output and custom generator', () => {
  // Verified against https://github.com/changesets/action/blob/v2/action.yml.
  const workflow = read('.github/workflows/release.yml');
  assert.match(workflow, /uses: changesets\/action@v2/);
  for (const [input, value] of [
    ['version-script', 'npm run version'],
    ['commit-message', "'chore: version packages'"],
    ['pr-title', "'chore: version packages'"],
    ['github-token', '${{ secrets.GITHUB_TOKEN }}'],
  ]) {
    assert.ok(workflow.includes(`${input}: ${value}`), input);
  }
  assert.ok(workflow.includes("steps.changesets.outputs.has-changesets == 'false'"));
  assert.doesNotMatch(workflow, /hasChangesets|^\s+(version|commit|title):/m);
  assert.equal(JSON.parse(read('package.json')).scripts.version,
    'changeset version && node scripts/build-changelog.mjs');
  assert.match(workflow, /v0\.0\.0/);
  assert.doesNotMatch(workflow, /--approve|pr merge/);
});

test('package contains all namespace modules in load order, without client configuration', () => {
  const toc = read('ForeverMacroManager.toc');
  assert.match(toc, /## Interface: 16001/);
  assert.match(toc, /## Version: @project-version@/);
  assert.doesNotMatch(toc, /SavedVariables|OptionalDeps|LoadOnDemand/i);
  const modules = toc.split(/\r?\n/).filter(line => line && !line.startsWith('#'));
  assert.deepEqual(modules, [
    'Changelog.lua', 'Reference.lua', 'Panel.lua',
    'IconKeywords.lua', 'IconMetadata.lua', 'IconCatalog.lua', 'IconPicker.lua', 'Core.lua',
  ]);
  for (const module of modules) assert.ok(read(module).length > 0);
  assert.match(read('.pkgmeta'), /^package-as: ForeverMacroManager/m);
  assert.deepEqual(readdirSync(fileURLToPath(root)).filter(name => name.endsWith('.toc')),
    ['ForeverMacroManager.toc']);
});
