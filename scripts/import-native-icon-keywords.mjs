import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validScreenshotCrop, validateAnnotations, validateNativeCoverage } from './build-icon-keywords.mjs';

const hashPattern = /^[a-f0-9]{64}$/;
const visualFields = ['colors', 'objects', 'visualThemes', 'keywords', 'confidence', 'uncertain', 'notes'];
const same = (left, right) => JSON.stringify(left) === JSON.stringify(right);
const sorted = ids => [...ids].sort((a, b) => a - b);
const positiveId = id => Number.isSafeInteger(id) && id > 0;
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const screenshotKind = 'normal-client-UI-rendered-screenshot';
const nonemptyText = value => typeof value === 'string' && value.trim().length > 0;

function noArchiveProof(record) {
  return ['sourceSHA256', 'contentKey', 'CKey', 'extractedSourceSHA256', 'extractedBLPPath']
    .every(field => record[field] === null || record[field] === undefined)
    && record.provenance?.CKey == null
    && record.directArchiveFileDataIdPixelVerification !== true
    && record.directFileDataIdPixelVerification !== true;
}

function requireThat(condition, message) {
  if (!condition) throw new Error(message);
}

function verifiedBytes(file, expected) {
  requireThat(typeof expected === 'string' && hashPattern.test(expected), 'Invalid expected SHA256');
  const bytes = readFileSync(file);
  requireThat(digest(bytes) === expected, 'Acquisition/review bytes differ from accepted SHA256');
  return bytes;
}

function verifiedJSON(file, expected) {
  return JSON.parse(verifiedBytes(file, expected).toString('utf8'));
}

function contentKey(record) {
  const key = record.provenance?.CKey;
  requireThat(typeof key === 'string' && /^[a-f0-9]{1,32}$/.test(key), 'Invalid native content key');
  return key.padStart(32, '0');
}

function assetIdentity(record) {
  return [
    record.textureId, record.originalPath, record.sourceSHA256, record.imageSHA256,
    record.normalizedPixelSHA256, contentKey(record), record.provenance?.requestedFileDataId,
  ];
}

function groupIdentity(group) {
  return [
    assetIdentity(group), group.memberTextureIds, group.memberIds, group.label,
    group.localLabel, group.sheet, group.shardId, group.members?.map(assetIdentity),
  ];
}

function validateGroup(group, assets, seenIds) {
  const representative = assets.get(group.textureId);
  requireThat(representative && same(assetIdentity(group), assetIdentity(representative)),
    'Representative does not match acquired identity');
  requireThat(Array.isArray(group.members) && group.members.length > 0
    && same(group.memberTextureIds, group.members.map(member => member.textureId))
    && same(group.memberIds, group.memberTextureIds)
    && group.memberTextureIds.includes(group.textureId), 'Invalid exact-pixel member list');
  for (const member of group.members) {
    const asset = assets.get(member.textureId);
    requireThat(asset && same(assetIdentity(member), assetIdentity(asset)),
      'Alias member does not match per-ID acquisition provenance');
    requireThat(asset.normalizedPixelSHA256 === representative.normalizedPixelSHA256
      && asset.imageSHA256 === representative.imageSHA256
      && asset.width === representative.width && asset.height === representative.height,
    'Alias is not an acquisition-proven exact-pixel match');
    requireThat(!seenIds.has(member.textureId), 'Duplicate acquired member across visual groups');
    seenIds.add(member.textureId);
  }
}

export function loadNativeAcquisition(indexPath, expectedSHA256, target) {
  const index = verifiedJSON(indexPath, expectedSHA256);
  const targetIds = new Set(target.textureIds);
  requireThat(target.schemaVersion === 1 && typeof target.build === 'string'
    && target.textureIds.length === targetIds.size && target.textureIds.every(positiveId),
  'Invalid native target');
  requireThat(index.schemaVersion === 1 && index.immutable === true
    && index.targetCount === targetIds.size && Array.isArray(index.shards), 'Invalid sealed acquisition index');
  const assetManifest = verifiedJSON(index.assetsManifestPath, index.assetsManifestSHA256);
  verifiedBytes(index.visualsManifestPath, index.visualsManifestSHA256);
  requireThat(assetManifest.schemaVersion === 2 && assetManifest.build === target.build
    && assetManifest.targetCount === targetIds.size && Array.isArray(assetManifest.records),
  'Acquisition build or target differs');
  const assets = new Map();
  const gaps = [];
  const allIds = new Set();
  for (const asset of assetManifest.records) {
    requireThat(targetIds.has(asset.textureId) && !allIds.has(asset.textureId),
      'Unknown or duplicate acquired target ID');
    allIds.add(asset.textureId);
    if (asset.status === 'failed') {
      gaps.push(asset.textureId);
      continue;
    }
    requireThat(asset.status === 'acquired' && asset.directFileDataIdPixelVerification === true
      && asset.provenance?.requestedFileDataId === asset.textureId
      && [asset.sourceSHA256, asset.imageSHA256, asset.normalizedPixelSHA256]
        .every(value => typeof value === 'string' && hashPattern.test(value))
      && positiveId(asset.width) && positiveId(asset.height)
      && (asset.originalPath === null || (typeof asset.originalPath === 'string'
        && /^Interface\/ICONS\/[^/\\]+\.blp$/i.test(asset.originalPath))),
    'Invalid direct native asset provenance');
    contentKey(asset);
    assets.set(asset.textureId, asset);
  }
  requireThat(allIds.size === targetIds.size
    && same(sorted(gaps), sorted(index.gapIds))
    && assets.size === index.acquiredIdCount && assets.size === assetManifest.acquiredIdCount
    && gaps.length === assetManifest.failedIdCount, 'Acquisition target/gap partition differs');

  const sheets = new Map();
  const seenIds = new Set();
  const representatives = new Set();
  const shardIds = new Set();
  for (const entry of index.shards) {
    const shard = verifiedJSON(entry.manifestPath, entry.manifestSHA256);
    requireThat(shard.schemaVersion === 2 && shard.clientBuild === target.build
      && shard.shardId === entry.shardId && !shardIds.has(shard.shardId)
      && Array.isArray(shard.records) && Array.isArray(shard.sheets), 'Invalid or duplicate native shard');
    shardIds.add(shard.shardId);
    const groups = new Map();
    const shardMembers = [];
    for (const group of shard.records) {
      requireThat(!representatives.has(group.textureId), 'Duplicate visual representative');
      validateGroup(group, assets, seenIds);
      representatives.add(group.textureId);
      groups.set(group.textureId, group);
      shardMembers.push(...group.memberTextureIds);
    }
    requireThat(same(sorted(shardMembers), sorted(shard.memberIds))
      && shardMembers.length === shard.uniqueIdCount && shardMembers.length === entry.uniqueIdCount
      && groups.size === shard.uniqueVisualCount && groups.size === entry.uniqueVisualCount
      && shard.sheets.length === entry.sheetCount, 'Shard identity counts differ');
    const mappedRepresentatives = new Set();
    for (const sheet of shard.sheets) {
      requireThat(!sheets.has(sheet.imagePath), 'Duplicate contact sheet');
      verifiedBytes(sheet.imagePath, sheet.imageSHA256);
      const mapping = verifiedJSON(sheet.mappingPath, sheet.mappingSHA256);
      requireThat(mapping.schemaVersion === 1 && mapping.imagePath === sheet.imagePath
        && mapping.imageSHA256 === sheet.imageSHA256 && Array.isArray(mapping.records)
        && mapping.records.length === sheet.representativeCount
        && mapping.records.length === mapping.representativeCount, 'Sheet mapping differs');
      const labels = new Set();
      const members = [];
      for (const group of mapping.records) {
        requireThat(groups.has(group.textureId) && !mappedRepresentatives.has(group.textureId)
          && same(groupIdentity(group), groupIdentity(groups.get(group.textureId)))
          && group.sheet === sheet.imagePath && group.shardId === shard.shardId
          && typeof group.label === 'string' && /^\d{4}-\d{2}$/.test(group.label)
          && group.localLabel === group.label && !labels.has(group.label), 'Sheet group identity/label differs');
        labels.add(group.label);
        mappedRepresentatives.add(group.textureId);
        members.push(...group.memberTextureIds);
      }
      requireThat(same(sorted(members), sorted(sheet.memberIds))
        && same(sorted(members), sorted(mapping.memberIds)), 'Sheet member IDs differ');
      sheets.set(sheet.imagePath, {
        shardId: shard.shardId, groups: new Map(mapping.records.map(group => [group.textureId, group])),
        sheetSHA256: sheet.imageSHA256, mappingSHA256: sheet.mappingSHA256,
        shardSHA256: entry.manifestSHA256,
      });
    }
    requireThat(mappedRepresentatives.size === groups.size, 'Unmapped visual representative');
  }
  requireThat(seenIds.size === assets.size && representatives.size === index.uniqueVisualCount,
    'Acquired IDs or unique visuals are missing from review sheets');
  return { build: target.build, manifestSHA256: expectedSHA256, assets, sheets, gapIds: sorted(gaps) };
}

export function importNativeSheet(acquisition, reviewPath, expectedSHA256) {
  const review = verifiedJSON(reviewPath, expectedSHA256);
  const sheet = acquisition.sheets.get(review.sheet);
  requireThat(sheet && review.schemaVersion === 2 && review.build === acquisition.build
    && review.shardId === sheet.shardId && Array.isArray(review.records)
    && Array.isArray(review.skipped) && review.skipped.length === 0
    && review.reviewedImageCount === review.records.length
    && review.records.length === sheet.groups.size, 'Incomplete or unassigned visual review sheet');
  const seen = new Set();
  const records = [];
  for (const annotation of review.records) {
    const group = sheet.groups.get(annotation.textureId);
    requireThat(group && !seen.has(annotation.textureId)
      && annotation.label === group.label && annotation.originalPath === group.originalPath
      && annotation.imageSHA256 === group.imageSHA256
      && annotation.normalizedPixelSHA256 === group.normalizedPixelSHA256
      && same(annotation.memberTextureIds, group.memberTextureIds), 'Review identity/hash/label differs');
    seen.add(annotation.textureId);
    for (const id of group.memberTextureIds) {
      const asset = acquisition.assets.get(id);
      const record = {
        textureId: id, originalPath: asset.originalPath, mappingLine: null,
        imageSHA256: asset.imageSHA256, batch: `${sheet.shardId}-sheet-${annotation.label.slice(0, 4)}`,
        label: annotation.label,
        ...Object.fromEntries(visualFields.map(field => [field, annotation[field]])),
        source: {
          kind: 'client-file-data-id', build: acquisition.build,
          reference: `sha256:${acquisition.manifestSHA256}`,
          identityLimit: 'Exact extracted local pixels; not a runtime render capture.',
          contentKey: contentKey(asset), sourceSHA256: asset.sourceSHA256,
          normalizedPixelSHA256: asset.normalizedPixelSHA256, reviewedTextureId: group.textureId,
          acquisitionManifestSHA256: acquisition.manifestSHA256,
          shardManifestSHA256: sheet.shardSHA256, sheetSHA256: sheet.sheetSHA256,
          sheetMappingSHA256: sheet.mappingSHA256, annotationSHA256: expectedSHA256,
        },
      };
      requireThat(!/\b[a-z]:[\\/]|\\\\[^\\]+\\|session-state|\/(?:Users|home)\//i.test(JSON.stringify(record)),
        'Local/private path in original annotation text; return it for review');
      records.push(record);
    }
  }
  validateAnnotations({
    schemaVersion: 1, provenance: { mappingRevision: 'native', identityLimit: 'per-record source' }, records,
  });
  return { sheet: review.sheet, records };
}

export function loadScreenshotCapture(manifestPath, expectedSHA256, acquisition) {
  const manifest = verifiedJSON(manifestPath, expectedSHA256);
  const screenshot = manifest.screenshot;
  requireThat(manifest.schemaVersion === 2 && manifest.build === acquisition.build
    && manifest.sourceKind === screenshotKind && nonemptyText(manifest.buildEvidence)
    && manifest.controlId === 134400 && acquisition.assets.has(manifest.controlId)
    && manifest.controlAddsTargetCoverage === false
    && same(sorted(manifest.targetIds), acquisition.gapIds)
    && manifest.targetCount === acquisition.gapIds.length
    && Array.isArray(manifest.records) && manifest.records.length === manifest.targetCount + 1,
  'Screenshot targets/control/build do not match exact acquisition gaps');
  requireThat(screenshot && Number.isSafeInteger(screenshot.width) && screenshot.width > 0
    && Number.isSafeInteger(screenshot.height) && screenshot.height > 0, 'Invalid screenshot dimensions');
  verifiedBytes(screenshot.preservedPath, screenshot.sha256);
  requireThat(Array.isArray(manifest.sealedExtractionAnchors)
    && manifest.sealedExtractionAnchors.some(anchor =>
      anchor.sha256 === acquisition.manifestSHA256 && anchor.unchangedVerified === true),
  'Screenshot capture is not bound to sealed extraction');
  for (const anchor of manifest.sealedExtractionAnchors) verifiedBytes(anchor.path, anchor.sha256);
  const records = new Map();
  let control;
  for (const record of manifest.records) {
    requireThat(!records.has(record.textureId) && record.originalPath === null
      && same(record.memberTextureIds, [record.textureId])
      && record.sourceKind === 'user-executed-native-UI-Texture-SetTexture-screenshot'
      && record.labelInOriginal === String(record.textureId)
      && record.sourceScreenshotSHA256 === screenshot.sha256
      && record.sourceScreenshotPath === screenshot.preservedPath
      && record.cropBoxConvention === 'zero-based source pixels [left, top, rightExclusive, bottomExclusive]'
      && validScreenshotCrop(record.cropBox, screenshot.width, screenshot.height)
      && record.width === record.cropBox[2] - record.cropBox[0]
      && record.height === record.cropBox[3] - record.cropBox[1]
      && record.losslessCrop === true && record.resamplingAppliedByIngest === false
      && record.directArchiveFileDataIdPixelVerification === false
      && record.directFileDataIdPixelVerification === false && noArchiveProof(record)
      && nonemptyText(record.nativeIdentityEvidence)
      && [record.rgbaPixelSHA256, record.normalizedPixelSHA256]
        .every(value => typeof value === 'string' && hashPattern.test(value))
      && record.normalizedPixelHashContract
        === 'SHA256(uint32le width + uint32le height + RGBA row-major screenshot-crop bytes)',
    'Invalid screenshot identity/crop/hash scope or forged archive proof');
    verifiedBytes(record.imagePath, record.imageSHA256);
    if (record.textureId === manifest.controlId) {
      requireThat(!control && record.role === 'render-control' && record.addsTargetCoverage === false,
        'Render control cannot add target coverage');
      control = record;
    } else {
      requireThat(manifest.targetIds.includes(record.textureId)
        && record.role === 'target' && record.addsTargetCoverage === true, 'Unknown screenshot target');
      records.set(record.textureId, record);
    }
  }
  requireThat(control && records.size === acquisition.gapIds.length
    && same(sorted([...records.keys()]), acquisition.gapIds)
    && [...records.values()].every(record => record.normalizedPixelSHA256 !== control.normalizedPixelSHA256),
  'Missing screenshot target or question-mark control used as target');
  return {
    build: manifest.build, manifestSHA256: expectedSHA256, screenshot,
    buildEvidence: manifest.buildEvidence, records, controlId: manifest.controlId,
    acquisitionManifestSHA256: acquisition.manifestSHA256,
  };
}

export function importScreenshotReview(capture, reviewPath, expectedSHA256) {
  const review = verifiedJSON(reviewPath, expectedSHA256);
  requireThat(review.schemaVersion === 2 && review.build === capture.build
    && review.sourceKind === screenshotKind && review.sourceManifestSHA256 === capture.manifestSHA256
    && review.sourceScreenshotSHA256 === capture.screenshot.sha256
    && review.shardId === 'native-screenshot-gaps' && review.controlTextureId === capture.controlId
    && review.controlCountsAsNewCoverage === false && nonemptyText(review.sourceLimit)
    && nonemptyText(review.exactRenderCommand) && Array.isArray(review.skipped) && review.skipped.length === 0
    && Array.isArray(review.records) && review.records.length === capture.records.size
    && review.reviewedImageCount === review.records.length, 'Incomplete or mismatched screenshot review');
  const records = [];
  const seen = new Set();
  for (const annotation of review.records) {
    const image = capture.records.get(annotation.textureId);
    requireThat(image && !seen.has(annotation.textureId) && annotation.originalPath === null
      && same(annotation.memberTextureIds, [annotation.textureId]) && noArchiveProof(annotation)
      && annotation.label === image.labelInOriginal && annotation.imageSHA256 === image.imageSHA256
      && annotation.normalizedPixelSHA256 === image.normalizedPixelSHA256,
    'Screenshot review target/control/hash/label differs or contains forged archive proof');
    seen.add(annotation.textureId);
    const record = {
      textureId: annotation.textureId, originalPath: null, mappingLine: null,
      imageSHA256: image.imageSHA256, batch: review.shardId, label: annotation.label,
      ...Object.fromEntries(visualFields.map(field => [field, annotation[field]])),
      source: {
        kind: screenshotKind, build: capture.build, reference: `sha256:${capture.manifestSHA256}`,
        identityLimit: review.sourceLimit, captureManifestSHA256: capture.manifestSHA256,
        annotationSHA256: expectedSHA256, screenshotSHA256: capture.screenshot.sha256,
        screenshotWidth: capture.screenshot.width, screenshotHeight: capture.screenshot.height,
        cropBox: image.cropBox, rgbaPixelSHA256: image.rgbaPixelSHA256,
        normalizedPixelSHA256: image.normalizedPixelSHA256, pixelHashScope: 'screenshot-crop-rgba',
        renderedTextureId: annotation.textureId, renderLabel: image.labelInOriginal,
        renderCommand: review.exactRenderCommand, nativeIdentityEvidence: image.nativeIdentityEvidence,
        buildEvidence: capture.buildEvidence,
      },
    };
    requireThat(!/\b[a-z]:[\\/]|\\\\[^\\]+\\|session-state|\/(?:Users|home)\//i.test(JSON.stringify(record)),
      'Local/private path in screenshot annotation text; return it for review');
    records.push(record);
  }
  validateAnnotations({
    schemaVersion: 1, provenance: { mappingRevision: 'screenshot', identityLimit: 'per-record source' }, records,
  });
  return records;
}

export function integrateNativeReviews(existing, target, acquisition, acceptedSheets,
  { requireComplete = true, screenshotReview } = {}) {
  const nativeIds = new Set(target.textureIds);
  const records = existing.records.filter(record => !nativeIds.has(record.textureId));
  const seen = new Set();
  for (const accepted of acceptedSheets) {
    const imported = importNativeSheet(acquisition, accepted.path, accepted.sha256);
    requireThat(!seen.has(imported.sheet), 'Duplicate accepted review sheet');
    seen.add(imported.sheet);
    records.push(...imported.records);
  }
  if (screenshotReview) {
    requireThat(screenshotReview.capture.acquisitionManifestSHA256 === acquisition.manifestSHA256
      && same(sorted([...screenshotReview.capture.records.keys()]), acquisition.gapIds),
    'Screenshot review does not cover this extraction gap set');
    records.push(...importScreenshotReview(screenshotReview.capture, screenshotReview.path, screenshotReview.sha256));
  }
  const candidate = { ...existing, records: records.sort((a, b) => a.textureId - b.textureId) };
  validateNativeCoverage(candidate, target, { requireComplete });
  return candidate;
}

function main() {
  const [mode, indexPath, expectedSHA256, ...extra] = process.argv.slice(2);
  requireThat(mode === '--check-acquisition' && indexPath && expectedSHA256 && extra.length === 0,
    'Usage: node scripts/import-native-icon-keywords.mjs --check-acquisition INDEX EXPECTED_SHA256');
  const target = JSON.parse(readFileSync(new URL('../docs/native-icons-71037.json', import.meta.url), 'utf8'));
  const acquisition = loadNativeAcquisition(indexPath, expectedSHA256, target);
  console.log(`Validated ${acquisition.assets.size} acquired IDs across ${acquisition.sheets.size} sheets; `
    + `unresolved native gaps: ${acquisition.gapIds.join(', ')}. No annotations imported or files written.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
