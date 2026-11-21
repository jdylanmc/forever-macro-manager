import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { renderKeywords, validateAnnotations, validateNativeCoverage } from './build-icon-keywords.mjs';

const read = file => readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const data = JSON.parse(read('docs/icon-keywords.json'));
const nativeTarget = JSON.parse(read('docs/native-icons-71037.json'));
const fixture = () => ({
  schemaVersion: 1,
  provenance: { mappingRevision: 'example', identityLimit: 'not client pixel proof' },
  records: [{
    textureId: 123, originalPath: 'Interface/ICONS/example.blp', imageSHA256: 'a'.repeat(64),
    mappingLine: 1, batch: 'sheet-01', label: 1, confidence: 'low',
    colors: ['cyan'], objects: ['shield'], visualThemes: ['mist'],
    keywords: ['spiral'], uncertain: ['dragon candidate'], notes: '',
  }],
});

test('shipped corpus covers every real native target with reviewed source proof and preserves original non-native work', () => {
  const coverage = validateNativeCoverage(data, nativeTarget);
  const byId = new Map(data.records.map(record => [record.textureId, record]));
  const screenshots = new Set([2147656, 2741548, 2892271, 8119728]);
  const reviewedVisuals = new Set();
  const acceptedSheets = new Set();
  for (const id of nativeTarget.textureIds) {
    const record = byId.get(id);
    const source = record.source;
    assert.equal(source?.build, nativeTarget.build, `native source build: ${id}`);
    if (screenshots.has(id)) {
      assert.equal(source.kind, 'normal-client-UI-rendered-screenshot');
      assert.equal(source.captureManifestSHA256, '69e5f46c7aad1d2f805266f476a37c06a35afae9d86f505b3cc7654dfdf0b24c');
      assert.equal(source.screenshotSHA256, '55dc94af56508aecd0349ce5262e72c4c3f1449f6b7e621b431b89cabca1ed43');
      assert.equal(source.annotationSHA256, '8c9fe68d5906fe41ab308101cb3b6ff488fc2ffdbfc68cf4818c60f0ecabd582');
    } else {
      assert.equal(source.kind, 'client-file-data-id');
      assert.match(source.sourceSHA256, /^[a-f0-9]{64}$/);
      assert.match(source.contentKey, /^[a-f0-9]{32}$/);
      assert.equal(source.acquisitionManifestSHA256, '24216ad1a256bcd0d2933218cac9458016b088345e761b3aa2287a6bc460ed77');
      const representative = byId.get(source.reviewedTextureId);
      assert.equal(representative?.source.reviewedTextureId, source.reviewedTextureId);
      assert.equal(representative?.imageSHA256, record.imageSHA256);
      assert.equal(representative?.source.normalizedPixelSHA256, source.normalizedPixelSHA256);
      reviewedVisuals.add(source.reviewedTextureId);
      acceptedSheets.add(source.annotationSHA256);
    }
  }
  assert.equal(reviewedVisuals.size, 27225);
  const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
  assert.equal(digest([...acceptedSheets].sort()), '8b5193baf308efb09072e93477a9d4bafb899b6fb39434cf926690fa4ea52bee');
  assert.equal(digest(coverage.extraIds.map(id => byId.get(id))), '70756bbfb18417de28887abb467da4239956c37a1a335785138de62a5c52330c');
});

test('packaged keyword data reproducibly includes all supported fields, never uncertainty or provenance', () => {
  const output = renderKeywords(fixture());
  assert.ok(output.includes('[123] = "cyan shield mist spiral"'));
  for (const excluded of ['dragon candidate', 'example.blp', 'aaaaaa', '"low"']) {
    assert.ok(!output.includes(excluded));
  }
  assert.equal(renderKeywords(data), read('IconKeywords.lua'));
  assert.equal(renderKeywords({ ...data, records: [...data.records].reverse() }), renderKeywords(data));
});

test('canonical annotations reject ambiguous identities and malformed searchable fields', () => {
  for (const mutate of [
    value => value.records.push({ ...value.records[0] }),
    value => { value.records[0].imageSHA256 = 'unverified'; },
    value => { value.records[0].textureId = 0; },
    value => { value.records[0].confidence = 'certain'; },
    value => { value.records[0].colors = ['Cyan']; },
    value => { value.records[0].keywords = ['']; },
    value => { delete value.provenance.identityLimit; },
  ]) {
    const value = fixture();
    mutate(value);
    assert.throws(() => validateAnnotations(value));
  }
});

test('empty keywords retain supported native-shaped visual observations', () => {
  const value = fixture();
  Object.assign(value.records[0], {
    colors: ['purple', 'blue'], objects: ['face', 'hood'], visualThemes: ['shadow'], keywords: [],
  });
  assert.ok(renderKeywords(value).includes('[123] = "purple blue face hood shadow"'));
});

test('annotations require a nonempty supported-field union and string notes', () => {
  const empty = fixture();
  for (const field of ['colors', 'objects', 'visualThemes', 'keywords']) empty.records[0][field] = [];
  assert.throws(() => validateAnnotations(empty));
  for (const field of ['colors', 'objects', 'visualThemes', 'keywords']) {
    const supported = structuredClone(empty);
    supported.records[0][field] = ['glow'];
    assert.doesNotThrow(() => validateAnnotations(supported));
    delete supported.records[0].notes;
    assert.throws(() => validateAnnotations(supported));
  }
});

test('original text annotations retain review provenance without bundling art or local session paths', () => {
  validateAnnotations(data);
  assert.ok(data.records.some(record => record.uncertain.length && record.confidence !== 'high'));
  const raw = read('docs/icon-keywords.json');
  assert.doesNotMatch(raw, /"[A-Z]:[\\/]|session-state|\.png|imagePath|manifestPath/i);
});

test('unmapped client IDs require explicit source identity, with metadata excluded from runtime', () => {
  const value = fixture();
  Object.assign(value.records[0], {
    originalPath: null, mappingLine: null, batch: 'native-01-sheet-001',
    source: {
      kind: 'client-file-data-id', build: '71037',
      reference: 'test-only extraction evidence', identityLimit: 'test-only source identity limit',
    },
    notes: 'test-only reviewer note',
  });
  assert.ok(renderKeywords(value).includes('[123] = "cyan shield mist spiral"'));
  assert.doesNotMatch(renderKeywords(value), /test-only|71037|client-file-data-id|dragon candidate/);
  for (const mutate of [
    record => { delete record.source; },
    record => { delete record.source.build; },
    record => { record.source.reference = ''; },
    record => { record.source.identityLimit = ''; },
    record => { record.source.kind = 'public-filename'; },
    record => { record.mappingLine = 1; },
  ]) {
    const invalid = structuredClone(value);
    mutate(invalid.records[0]);
    assert.throws(() => validateAnnotations(invalid), /identity or review provenance/);
  }
});

test('native coverage uses actual exported IDs, not corpus size or replacement IDs', () => {
  const target = {
    schemaVersion: 1, build: '71037', source: 'explicit test fixture',
    exportSHA256: 'b'.repeat(64), providerRows: 3, duplicateRows: 1, textureIds: [123, 456],
  };
  const complete = fixture();
  complete.records.push({ ...complete.records[0], textureId: 456 });
  assert.equal(validateNativeCoverage(complete, target).covered, 2);
  const replacement = structuredClone(complete);
  replacement.records[1].textureId = 789;
  assert.throws(() => validateNativeCoverage(replacement, target), /Missing 1 native annotations.*456/);
  for (const textureIds of [[123, 123], [456, 123], [123, '456']]) {
    assert.throws(() => validateNativeCoverage(complete, { ...target, textureIds }), /Invalid native target/);
  }
});

test('real native target detects loss of an existing annotation and retains non-native originals', () => {
  const before = validateNativeCoverage(data, nativeTarget, { requireComplete: false });
  assert.equal(before.indexed, before.covered + before.extraIds.length);
  assert.ok(before.extraIds.length > 0);
  const nativeIds = new Set(nativeTarget.textureIds);
  const removed = data.records.find(record => nativeIds.has(record.textureId));
  assert.ok(removed, 'real corpus must overlap the independent native export');
  const after = validateNativeCoverage({
    ...data, records: data.records.filter(record => record.textureId !== removed.textureId),
  }, nativeTarget, { requireComplete: false });
  const priorMissing = new Set(before.missingIds);
  assert.deepEqual(after.missingIds.filter(id => !priorMissing.has(id)), [removed.textureId]);
  assert.equal(after.covered, before.covered - 1);
  assert.deepEqual(after.extraIds, before.extraIds);
});
