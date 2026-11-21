import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { test } from 'node:test';
import { renderKeywords } from './build-icon-keywords.mjs';
import { importScreenshotReview, integrateNativeReviews, loadScreenshotCapture } from './import-native-icon-keywords.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
let sequence = 0;

function fixture(t) {
  const directory = fileURLToPath(new URL(
    `../.tools/native-integration-ff5a994e/tests/screenshot-${process.pid}-${++sequence}/`, import.meta.url,
  ));
  mkdirSync(directory, { recursive: true });
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const file = name => path.join(directory, name);
  const save = (name, value) => {
    const bytes = JSON.stringify(value);
    writeFileSync(file(name), bytes);
    return hash(bytes);
  };
  // Test-only byte fixtures exercise accepted metadata/hash boundaries, not PNG decoding.
  const screenshotBytes = Buffer.from('explicit test-only screenshot bytes');
  writeFileSync(file('screenshot.png'), screenshotBytes);
  const anchorSHA256 = save('extraction.json', {});
  const gaps = [2147656, 2741548, 2892271, 8119728];
  const acquisition = {
    build: '71037', manifestSHA256: anchorSHA256, gapIds: gaps, assets: new Map([[134400, {}]]),
  };
  const screenshot = { preservedPath: file('screenshot.png'), sha256: hash(screenshotBytes), width: 100, height: 20 };
  const records = [134400, ...gaps].map((id, index) => {
    const imageBytes = Buffer.from(`explicit test-only crop bytes ${id}`);
    writeFileSync(file(`${id}.png`), imageBytes);
    return {
      textureId: id, memberTextureIds: [id], role: index ? 'target' : 'render-control',
      addsTargetCoverage: index > 0, labelInOriginal: String(id),
      sourceKind: 'user-executed-native-UI-Texture-SetTexture-screenshot',
      sourceScreenshotPath: screenshot.preservedPath, sourceScreenshotSHA256: screenshot.sha256,
      cropBox: [index * 15, 1, index * 15 + 10, 11],
      cropBoxConvention: 'zero-based source pixels [left, top, rightExclusive, bottomExclusive]',
      width: 10, height: 10, imagePath: file(`${id}.png`), imageSHA256: hash(imageBytes),
      rgbaPixelSHA256: String(index + 1).repeat(64), normalizedPixelSHA256: String(index + 2).repeat(64),
      normalizedPixelHashContract: 'SHA256(uint32le width + uint32le height + RGBA row-major screenshot-crop bytes)',
      originalPath: null, extractedBLPPath: null, extractedSourceSHA256: null, CKey: null,
      directArchiveFileDataIdPixelVerification: false, directFileDataIdPixelVerification: false,
      nativeIdentityEvidence: 'test-only visible label and user Texture:SetTexture identity',
      losslessCrop: true, resamplingAppliedByIngest: false,
    };
  });
  const manifest = {
    schemaVersion: 2, build: '71037', buildEvidence: 'test-only separately established client build',
    sourceKind: 'normal-client-UI-rendered-screenshot', screenshot,
    targetIds: gaps, targetCount: 4, controlId: 134400, controlAddsTargetCoverage: false,
    sealedExtractionAnchors: [{ path: file('extraction.json'), sha256: anchorSHA256, unchangedVerified: true }],
    records,
  };
  const review = {
    schemaVersion: 2, build: '71037', shardId: 'native-screenshot-gaps', sourceKind: manifest.sourceKind,
    sourceScreenshotSHA256: screenshot.sha256, reviewedImageCount: 4,
    sourceLimit: 'test screenshot scaling/compositing; not extracted BLP/CKey pixels',
    exactRenderCommand: 'test-only Texture:SetTexture render identity command',
    controlTextureId: 134400, controlCountsAsNewCoverage: false, skipped: [],
    records: records.slice(1).map(record => ({
      textureId: record.textureId, memberTextureIds: [record.textureId], originalPath: null,
      imageSHA256: record.imageSHA256, normalizedPixelSHA256: record.normalizedPixelSHA256,
      label: record.labelInOriginal, colors: ['blue'], objects: [], visualThemes: ['glow'],
      keywords: [], confidence: 'low', uncertain: ['test-only uncertain candidate'], notes: '',
    })),
  };
  return {
    manifest, review, file, acquisition,
    load() {
      const digest = save('manifest.json', manifest);
      review.sourceManifestSHA256 = digest;
      return loadScreenshotCapture(file('manifest.json'), digest, acquisition);
    },
    saveReview: () => ({ path: file('review.json'), sha256: save('review.json', review) }),
  };
}

test('screenshot review retains honest singleton crop proof, excludes control and never invents BLP identity', t => {
  const value = fixture(t);
  const capture = value.load();
  const accepted = value.saveReview();
  const records = importScreenshotReview(capture, accepted.path, accepted.sha256);
  assert.deepEqual(records.map(record => record.textureId), [2147656, 2741548, 2892271, 8119728]);
  assert.ok(records.every(record => record.keywords.length === 0 && record.originalPath === null));
  assert.equal(records[0].source.kind, 'normal-client-UI-rendered-screenshot');
  assert.deepEqual(records[0].source.cropBox, [15, 1, 25, 11]);
  assert.equal(records[0].source.pixelHashScope, 'screenshot-crop-rgba');
  assert.equal(records[0].source.annotationSHA256, accepted.sha256);
  assert.equal(records[0].source.sourceSHA256, undefined);
  assert.equal(records[0].source.contentKey, undefined);
  assert.doesNotMatch(JSON.stringify(records), /sourceScreenshotPath|imagePath|session-state|[a-z]:\\\\/i);
  const canonical = {
    schemaVersion: 1, provenance: { mappingRevision: 'test', identityLimit: 'test only' }, records,
  };
  const lua = renderKeywords(canonical);
  assert.ok(lua.includes('[2147656] = "blue glow"'));
  assert.doesNotMatch(lua, /134400|screenshot|uncertain|SetTexture|71037/);
  for (const mutate of [
    source => { source.sourceSHA256 = 'a'.repeat(64); },
    source => { source.contentKey = 'a'.repeat(32); },
    source => { source.kind = 'client-file-data-id'; },
    source => { source.pixelHashScope = 'native-blp-rgba'; },
    source => { source.cropBox = [-1, 1, 9, 11]; },
  ]) {
    const invalid = structuredClone(canonical);
    mutate(invalid.records[0].source);
    assert.throws(() => renderKeywords(invalid), /identity or review provenance/);
  }
});

test('capture validation rejects wrong targets/control, aliases, hashes, crop bounds and archive claims', t => {
  for (const mutate of [
    value => { value.manifest.targetIds = [134400, 2741548, 2892271, 8119728]; },
    value => { value.manifest.controlAddsTargetCoverage = true; },
    value => { value.manifest.records[0].role = 'target'; },
    value => { value.manifest.records[1].memberTextureIds.push(2741548); },
    value => { value.manifest.records[1].imageSHA256 = 'a'.repeat(64); },
    value => { value.manifest.screenshot.sha256 = 'a'.repeat(64); },
    value => { value.manifest.records[1].cropBox = [-1, 1, 9, 11]; },
    value => { value.manifest.records[1].cropBox = [95, 1, 105, 11]; },
    value => { value.manifest.records[1].cropBox = [15, 1, 15, 11]; },
    value => { value.manifest.records[1].extractedSourceSHA256 = 'a'.repeat(64); },
    value => { value.manifest.records[1].CKey = 'a'.repeat(32); },
    value => { value.manifest.records[1].directFileDataIdPixelVerification = true; },
  ]) {
    const value = fixture(t);
    mutate(value);
    assert.throws(() => value.load(), /Screenshot|screenshot|control|accepted SHA256/);
  }
});

test('screenshot annotations must preserve hash-bound target identities and cannot review the control', t => {
  const value = fixture(t);
  const capture = value.load();
  const original = structuredClone(value.review);
  for (const mutate of [
    review => { review.records[0].textureId = 134400; },
    review => { review.records[0].memberTextureIds = [2147656, 2741548]; },
    review => { review.records[0].imageSHA256 = 'a'.repeat(64); },
    review => { review.records[0].normalizedPixelSHA256 = 'a'.repeat(64); },
    review => { review.records[0].sourceSHA256 = 'a'.repeat(64); },
    review => { review.records[0].label = '134400'; },
    review => { review.records.pop(); },
    review => { review.sourceManifestSHA256 = 'a'.repeat(64); },
    review => { review.sourceScreenshotSHA256 = 'a'.repeat(64); },
  ]) {
    Object.assign(value.review, structuredClone(original));
    mutate(value.review);
    const accepted = value.saveReview();
    assert.throws(() => importScreenshotReview(capture, accepted.path, accepted.sha256), /Screenshot|screenshot/);
  }
  Object.assign(value.review, structuredClone(original));
  const accepted = value.saveReview();
  writeFileSync(accepted.path, '{}');
  assert.throws(() => importScreenshotReview(capture, accepted.path, accepted.sha256), /accepted SHA256/);
});

test('combined review coverage counts only screenshot targets and still requires the extracted control review', t => {
  const value = fixture(t);
  const capture = value.load();
  const accepted = { ...value.saveReview(), capture };
  const target = {
    schemaVersion: 1, build: '71037', source: 'test-only native export', exportSHA256: 'a'.repeat(64),
    providerRows: 5, duplicateRows: 0, textureIds: [134400, ...value.acquisition.gapIds],
  };
  const existing = {
    schemaVersion: 1, provenance: { mappingRevision: 'test', identityLimit: 'test only' }, records: [],
  };
  const candidate = integrateNativeReviews(existing, target, value.acquisition, [], {
    requireComplete: false, screenshotReview: accepted,
  });
  assert.deepEqual(candidate.records.map(record => record.textureId), value.acquisition.gapIds);
  assert.throws(() => integrateNativeReviews(existing, target, value.acquisition, [], {
    screenshotReview: accepted,
  }), /Missing 1.*134400/);
  assert.throws(() => integrateNativeReviews(existing, target, value.acquisition, [], {
    screenshotReview: { ...accepted, capture: { ...capture, acquisitionManifestSHA256: 'a'.repeat(64) } },
  }), /does not cover this extraction gap set/);
});
