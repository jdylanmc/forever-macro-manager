import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { renderKeywords, validateAnnotations } from './build-icon-keywords.mjs';

const read = file => readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const data = JSON.parse(read('docs/icon-keywords.json'));
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

test('original text annotations retain review provenance without bundling art or local session paths', () => {
  validateAnnotations(data);
  assert.ok(data.records.some(record => record.uncertain.length && record.confidence !== 'high'));
  const raw = read('docs/icon-keywords.json');
  assert.doesNotMatch(raw, /"[A-Z]:[\\/]|session-state|\.png|imagePath|manifestPath/i);
  assert.ok(data.records.every(record => Number.isInteger(record.mappingLine)));
});
