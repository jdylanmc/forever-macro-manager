import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { test } from 'node:test';
import { renderKeywords } from './build-icon-keywords.mjs';
import { importNativeSheet, integrateNativeReviews, loadNativeAcquisition } from './import-native-icon-keywords.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
let fixtureNumber = 0;

function fixture(t) {
  const directory = fileURLToPath(new URL(
    `../.tools/native-integration-ff5a994e/tests/import-${process.pid}-${++fixtureNumber}/`, import.meta.url,
  ));
  mkdirSync(directory, { recursive: true });
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const file = name => path.join(directory, name);
  const save = (name, value) => {
    const bytes = JSON.stringify(value);
    writeFileSync(file(name), bytes);
    return hash(bytes);
  };
  // Explicit test-only metadata and annotations; no game art or production records.
  const assets = [123, 456, 789].map((id, index) => ({
    textureId: id, originalPath: id === 456 ? null : `Interface/ICONS/test${id}.blp`,
    sourceSHA256: String(index + 1).repeat(64), imageSHA256: (id === 789 ? 'd' : 'b').repeat(64),
    normalizedPixelSHA256: (id === 789 ? 'e' : 'c').repeat(64),
    width: 64, height: 64, status: 'acquired', directFileDataIdPixelVerification: true,
    provenance: { CKey: String(index + 1).repeat(32), requestedFileDataId: id },
    sourcePath: file(`${id}.blp`), imagePath: file(`${id}.png`),
  }));
  const sheetPath = file('sheet-0001.png');
  const groups = [[assets[0], assets[1]], [assets[2]]].map((members, index) => ({
    ...members[0], members, memberTextureIds: members.map(member => member.textureId),
    memberIds: members.map(member => member.textureId), sheet: sheetPath,
    label: `0001-0${index + 1}`, localLabel: `0001-0${index + 1}`, shardId: 'native-01',
  }));
  const target = {
    schemaVersion: 1, build: '71037', source: 'test-only native export',
    exportSHA256: 'f'.repeat(64), providerRows: 4, duplicateRows: 0, textureIds: [123, 456, 789, 999],
  };
  const annotations = groups.map(group => ({
    textureId: group.textureId, originalPath: group.originalPath,
    memberTextureIds: group.memberTextureIds, label: group.label,
    imageSHA256: group.imageSHA256, normalizedPixelSHA256: group.normalizedPixelSHA256,
    colors: ['cyan'], objects: ['shield'], visualThemes: ['glow'], keywords: ['spiral'],
    confidence: 'low', uncertain: ['unconfirmed candidate'], notes: 'test-only review note',
  }));
  const review = {
    schemaVersion: 2, build: '71037', shardId: 'native-01', sheet: sheetPath,
    reviewedImageCount: 2, records: annotations, skipped: [],
  };
  const saveReview = () => ({ path: file('review.json'), sha256: save('review.json', review) });
  const seal = () => {
    const sheetBytes = Buffer.from('test-only contact-sheet bytes; not an actual image');
    writeFileSync(sheetPath, sheetBytes);
    const sheet = {
      imagePath: sheetPath, imageSHA256: hash(sheetBytes), mappingPath: file('mapping.json'),
      representativeCount: groups.length, memberIds: [123, 456, 789],
    };
    sheet.mappingSHA256 = save('mapping.json', { schemaVersion: 1, ...sheet, records: groups });
    const shard = {
      schemaVersion: 2, clientBuild: '71037', shardId: 'native-01',
      uniqueVisualCount: 2, uniqueIdCount: 3, memberIds: [123, 456, 789],
      records: groups, sheets: [sheet],
    };
    const index = {
      schemaVersion: 1, immutable: true, targetCount: 4, acquiredIdCount: 3,
      uniqueVisualCount: 2, gapIds: [999], assetsManifestPath: file('assets.json'),
      assetsManifestSHA256: save('assets.json', {
        schemaVersion: 2, build: '71037', targetCount: 4, acquiredIdCount: 3, failedIdCount: 1,
        records: [...assets, { textureId: 999, status: 'failed' }],
      }),
      visualsManifestPath: file('visuals.json'), visualsManifestSHA256: save('visuals.json', []),
      shards: [{
        shardId: 'native-01', manifestPath: file('shard.json'), manifestSHA256: save('shard.json', shard),
        uniqueVisualCount: 2, uniqueIdCount: 3, sheetCount: 1,
      }],
    };
    return save('index.json', index);
  };
  return {
    file, assets, groups, target, review, saveReview,
    load: () => loadNativeAcquisition(file('index.json'), seal(), target),
  };
}

test('native sheet import expands only proven aliases and preserves each ID source without private paths', t => {
  const value = fixture(t);
  const acquisition = value.load();
  const accepted = value.saveReview();
  const imported = importNativeSheet(acquisition, accepted.path, accepted.sha256).records;
  assert.deepEqual(imported.map(record => record.textureId), [123, 456, 789]);
  assert.equal(imported[1].originalPath, null);
  assert.equal(imported[0].mappingLine, null);
  assert.equal(imported[0].label, '0001-01');
  assert.equal(imported[1].source.reviewedTextureId, 123);
  assert.equal(imported[1].source.contentKey, '2'.repeat(32));
  assert.equal(imported[1].source.sourceSHA256, '2'.repeat(64));
  assert.equal(imported[1].source.annotationSHA256, accepted.sha256);
  assert.notEqual(imported[0].source.sourceSHA256, imported[1].source.sourceSHA256);
  assert.doesNotMatch(JSON.stringify(imported), /sourcePath|imagePath|archivePath|session-state|[a-z]:\\\\/i);
  const canonical = {
    schemaVersion: 1, provenance: { mappingRevision: 'test', identityLimit: 'test only' }, records: imported,
  };
  const lua = renderKeywords(canonical);
  assert.ok(lua.includes('[456] = "cyan shield glow spiral"'));
  assert.doesNotMatch(lua, /unconfirmed|test-only review note|71037|client-file-data-id|bbbbbb/);
  const incompleteProof = structuredClone(canonical);
  delete incompleteProof.records[0].source.sourceSHA256;
  assert.throws(() => renderKeywords(incompleteProof), /identity or review provenance/);
});

test('sealed acquisition still rejects false aliases, conflicting per-ID provenance and duplicate membership', t => {
  for (const mutate of [
    value => { value.assets[1].width = 128; },
    value => { value.assets[1].normalizedPixelSHA256 = 'f'.repeat(64); },
    value => { value.groups[0].members[1] = { ...value.assets[1], sourceSHA256: 'a'.repeat(64) }; },
    value => { value.assets[1].provenance.requestedFileDataId = 123; },
    value => { value.groups.push(value.groups[0]); },
  ]) {
    const value = fixture(t);
    mutate(value);
    assert.throws(() => value.load(), /exact-pixel|per-ID|provenance|Duplicate/);
  }
});

test('native review import accepts empty keywords without changing the original visual fields', t => {
  const value = fixture(t);
  const acquisition = value.load();
  Object.assign(value.review.records[0], {
    colors: ['purple', 'blue'], objects: ['face', 'hood'], visualThemes: ['shadow'], keywords: [],
  });
  const accepted = value.saveReview();
  const imported = importNativeSheet(acquisition, accepted.path, accepted.sha256).records;
  assert.deepEqual(imported[0].keywords, []);
  assert.deepEqual(imported[0].colors, ['purple', 'blue']);
  assert.deepEqual(imported[0].objects, ['face', 'hood']);
  assert.deepEqual(imported[0].visualThemes, ['shadow']);
});

test('review ingestion rejects wrong identities, labels, hashes, omissions and skipped art', t => {
  const value = fixture(t);
  const acquisition = value.load();
  for (const mutate of [
    review => { review.records[0].textureId = 999; },
    review => { review.records[0].label = '1'; },
    review => { review.records[0].originalPath = null; },
    review => { review.records[0].memberTextureIds = [123]; },
    review => { review.records[0].imageSHA256 = 'a'.repeat(64); },
    review => { review.records[0].normalizedPixelSHA256 = 'a'.repeat(64); },
    review => { review.build = '70959'; },
    review => { review.records.pop(); },
    review => { review.skipped.push({ textureId: 123, reason: 'not reviewed' }); },
    review => { review.records[0].notes = 'Inspected C:\\private\\account.png'; },
  ]) {
    const review = structuredClone(value.review);
    mutate(review);
    const bytes = JSON.stringify(review);
    writeFileSync(value.file('invalid-review.json'), bytes);
    assert.throws(() => importNativeSheet(acquisition, value.file('invalid-review.json'), hash(bytes)),
      /Review identity|Incomplete|Local\/private/);
  }
});

test('accepted annotation bytes are hash-bound, never trusted merely because the path matches', t => {
  const value = fixture(t);
  const acquisition = value.load();
  const accepted = value.saveReview();
  writeFileSync(accepted.path, readFileSync(accepted.path, 'utf8') + '\n');
  assert.throws(() => importNativeSheet(acquisition, accepted.path, accepted.sha256), /accepted SHA256/);
});

test('integration replaces old native guesses, retains non-native originals and keeps real gaps blocking', t => {
  const value = fixture(t);
  const acquisition = value.load();
  const accepted = value.saveReview();
  const old = {
    textureId: 123, originalPath: 'Interface/ICONS/old.blp', mappingLine: 1, imageSHA256: 'a'.repeat(64),
    batch: 'sheet-01', label: 1, colors: [], objects: [], visualThemes: [],
    keywords: ['obsolete guess'], confidence: 'low', uncertain: [], notes: '',
  };
  const extra = { ...old, textureId: 888 };
  const existing = {
    schemaVersion: 1, provenance: { mappingRevision: 'legacy', identityLimit: 'public sample' },
    records: [old, extra],
  };
  const candidate = integrateNativeReviews(existing, value.target, acquisition, [accepted], { requireComplete: false });
  assert.deepEqual(candidate.records.find(record => record.textureId === 123).keywords, ['spiral']);
  assert.deepEqual(candidate.records.find(record => record.textureId === 888), extra);
  assert.throws(() => integrateNativeReviews(existing, value.target, acquisition, [accepted]), /Missing 1.*999/);
  assert.throws(() => integrateNativeReviews(existing, value.target, acquisition, [accepted, accepted]),
    /Duplicate accepted review sheet/);
});
