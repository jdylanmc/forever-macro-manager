import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = new URL('../', import.meta.url);
const fields = ['colors', 'objects', 'visualThemes', 'keywords'];
const nonemptyText = value => typeof value === 'string' && value.trim().length > 0;
const nativeProofHashes = [
  'sourceSHA256', 'normalizedPixelSHA256', 'acquisitionManifestSHA256',
  'shardManifestSHA256', 'sheetSHA256', 'sheetMappingSHA256', 'annotationSHA256',
];
const screenshotKind = 'normal-client-UI-rendered-screenshot';

export function validScreenshotCrop(box, width, height) {
  return Number.isSafeInteger(width) && width > 0 && Number.isSafeInteger(height) && height > 0
    && Array.isArray(box) && box.length === 4 && box.every(Number.isSafeInteger)
    && box[0] >= 0 && box[1] >= 0 && box[2] > box[0] && box[3] > box[1]
    && box[2] <= width && box[3] <= height;
}

function validSource(source) {
  const validIdentity = source && ['client-file-data-id', 'public-filename', screenshotKind].includes(source.kind)
    && nonemptyText(source.reference) && nonemptyText(source.identityLimit)
    && (source.kind !== 'client-file-data-id'
      || (typeof source.build === 'string' && /^\d+$/.test(source.build)));
  if (!validIdentity) return false;
  if (source.kind === screenshotKind) {
    return typeof source.build === 'string' && /^\d+$/.test(source.build)
      && ['captureManifestSHA256', 'annotationSHA256', 'screenshotSHA256',
        'rgbaPixelSHA256', 'normalizedPixelSHA256']
        .every(field => typeof source[field] === 'string' && /^[a-f0-9]{64}$/.test(source[field]))
      && ['buildEvidence', 'nativeIdentityEvidence', 'renderCommand'].every(field => nonemptyText(source[field]))
      && source.pixelHashScope === 'screenshot-crop-rgba'
      && validScreenshotCrop(source.cropBox, source.screenshotWidth, source.screenshotHeight)
      && Number.isSafeInteger(source.renderedTextureId) && source.renderedTextureId > 0
      && source.renderLabel === String(source.renderedTextureId)
      && source.reference === `sha256:${source.captureManifestSHA256}`
      && ['sourceSHA256', 'contentKey', 'CKey', 'extractedSourceSHA256', 'extractedBLPPath',
        'acquisitionManifestSHA256', 'shardManifestSHA256', 'sheetSHA256', 'sheetMappingSHA256',
        'reviewedTextureId', 'directArchiveFileDataIdPixelVerification',
        'directFileDataIdPixelVerification'].every(field => source[field] === undefined);
  }
  if (source.screenshotSHA256 !== undefined || source.captureManifestSHA256 !== undefined) return false;
  const hasProof = [...nativeProofHashes, 'contentKey', 'reviewedTextureId']
    .some(field => source[field] !== undefined);
  return !hasProof || (source.kind === 'client-file-data-id'
    && nativeProofHashes.every(field => typeof source[field] === 'string' && /^[a-f0-9]{64}$/.test(source[field]))
    && typeof source.contentKey === 'string' && /^[a-f0-9]{32}$/.test(source.contentKey)
    && Number.isSafeInteger(source.reviewedTextureId) && source.reviewedTextureId > 0
    && source.reference === `sha256:${source.acquisitionManifestSHA256}`);
}

export function validateAnnotations(data) {
  if (data.schemaVersion !== 1 || !data.provenance?.mappingRevision
    || !data.provenance?.identityLimit || !Array.isArray(data.records) || !data.records.length) {
    throw new Error('Missing annotation schema, provenance or records');
  }
  const ids = new Set();
  for (const record of data.records) {
    if (!Number.isSafeInteger(record.textureId) || record.textureId <= 0 || ids.has(record.textureId)) {
      throw new Error(`Invalid or duplicate texture ID: ${record.textureId}`);
    }
    ids.add(record.textureId);
    const clientSource = record.source?.kind === 'client-file-data-id';
    const screenshotSource = record.source?.kind === screenshotKind;
    const mappedPath = typeof record.originalPath === 'string'
      && /^Interface\/ICONS\/[^/\\]+\.blp$/i.test(record.originalPath)
      && ((Number.isSafeInteger(record.mappingLine) && record.mappingLine > 0)
        || (record.mappingLine === null && clientSource));
    const unmappedClientId = record.originalPath === null && record.mappingLine === null
      && (clientSource || screenshotSource);
    const validLabel = (Number.isSafeInteger(record.label) && record.label > 0)
      || (clientSource && typeof record.label === 'string' && /^\d{4}-\d{2}$/.test(record.label))
      || (screenshotSource && record.label === String(record.textureId));
    if ((!mappedPath && !unmappedClientId)
      || (screenshotSource && (record.originalPath !== null || record.mappingLine !== null
        || record.source.renderedTextureId !== record.textureId || record.source.renderLabel !== record.label))
      || (record.source !== undefined && !validSource(record.source))
      || !/^[a-f0-9]{64}$/.test(record.imageSHA256)
      || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(record.batch)
      || !validLabel
      || !['high', 'medium', 'low'].includes(record.confidence)) {
      throw new Error(`Invalid identity or review provenance: ${record.textureId}`);
    }
    for (const field of [...fields, 'uncertain']) {
      if (!Array.isArray(record[field]) || record[field].some(value =>
        typeof value !== 'string' || !value.trim() || /[\u0000-\u001f\u007f]/.test(value)
        || (field !== 'uncertain' && value !== value.toLowerCase()))) {
        throw new Error(`Invalid ${field}: ${record.textureId}`);
      }
    }
    if (!fields.some(field => record[field].length > 0) || typeof record.notes !== 'string') {
      throw new Error(`Missing visual observations or notes: ${record.textureId}`);
    }
  }
  return data;
}

export function validateNativeCoverage(data, target, { requireComplete = true } = {}) {
  validateAnnotations(data);
  if (target.schemaVersion !== 1 || !/^\d+$/.test(target.build)
    || !nonemptyText(target.source) || !/^[a-f0-9]{64}$/.test(target.exportSHA256)
    || !Array.isArray(target.textureIds) || !target.textureIds.length
    || target.textureIds.some((id, index, ids) => !Number.isSafeInteger(id) || id <= 0
      || (index > 0 && id <= ids[index - 1]))
    || !Number.isSafeInteger(target.duplicateRows) || target.duplicateRows < 0
    || !Number.isSafeInteger(target.providerRows)
    || target.providerRows !== target.textureIds.length + target.duplicateRows) {
    throw new Error('Invalid native target export');
  }
  const indexed = new Set(data.records.map(record => record.textureId));
  const nativeIds = new Set(target.textureIds);
  const missingIds = target.textureIds.filter(id => !indexed.has(id));
  const extraIds = [...indexed].filter(id => !nativeIds.has(id)).sort((a, b) => a - b);
  if (requireComplete && missingIds.length) {
    throw new Error(`Missing ${missingIds.length} native annotations for build ${target.build}: `
      + `${missingIds.slice(0, 10).join(', ')}${missingIds.length > 10 ? ', ...' : ''}`);
  }
  return {
    build: target.build, indexed: indexed.size, target: nativeIds.size,
    covered: nativeIds.size - missingIds.length, missingIds, extraIds,
  };
}

function luaString(value) {
  return `"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"`;
}

export function renderKeywords(data) {
  validateAnnotations(data);
  const lines = [
    '-- Generated by scripts/build-icon-keywords.mjs; edit docs/icon-keywords.json instead.',
    '-- Original English visual annotations, not spell/item names. See docs/sources.md.',
    'local _, ns = ...',
    '',
    'ns.IconKeywords = {',
  ];
  for (const record of [...data.records].sort((a, b) => a.textureId - b.textureId)) {
    const tags = [...new Set(fields.flatMap(field => record[field]))];
    lines.push(`\t[${record.textureId}] = ${luaString(tags.join(' '))},`);
  }
  return `${lines.join('\n')}\n}\n`;
}

function main() {
  const args = process.argv.slice(2);
  if (new Set(args).size !== args.length || args.some(arg => !['--check', '--require-native'].includes(arg))) {
    throw new Error('Usage: node scripts/build-icon-keywords.mjs [--check] [--require-native]');
  }
  const data = JSON.parse(readFileSync(new URL('docs/icon-keywords.json', root), 'utf8'));
  const targetSet = JSON.parse(readFileSync(new URL('docs/native-icons-71037.json', root), 'utf8'));
  const coverage = validateNativeCoverage(data, targetSet, { requireComplete: args.includes('--require-native') });
  const expected = renderKeywords(data);
  const target = new URL('IconKeywords.lua', root);
  if (args.includes('--check')) {
    let actual;
    try { actual = readFileSync(target, 'utf8'); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
    if (actual !== expected) throw new Error('IconKeywords.lua is stale; run node scripts/build-icon-keywords.mjs');
    console.log('IconKeywords.lua is up to date.');
  } else {
    writeFileSync(target, expected);
    console.log(`Generated ${data.records.length} visual keyword records.`);
  }
  console.log(`Native build ${coverage.build}: ${coverage.covered}/${coverage.target} indexed; `
    + `${coverage.missingIds.length} missing; ${coverage.extraIds.length} non-native records retained.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
