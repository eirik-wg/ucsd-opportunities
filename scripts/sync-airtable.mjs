#!/usr/bin/env node
/**
 * Pull opportunities from Airtable (source of truth) and write data/opportunities.dat
 * (gzip + XOR + base64 payload) in the shape consumed by app.js.
 * Field mapping lives in opportunity-map.mjs (20261026 "Opportunities" table schema).
 *
 * Env vars:
 *   AIRTABLE_TOKEN   personal access token, scope data.records:read
 *   AIRTABLE_BASE_ID appXXXXXXXXXXXXXX
 *   AIRTABLE_TABLE   default "Opportunities"
 *   AIRTABLE_VIEW    default "Website"
 *   MAX_ROWS         default 0 (= no limit)
 */
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { toOpportunity, buildPayload, protectPayload } from './opportunity-map.mjs';

const token = process.env.AIRTABLE_TOKEN;
const baseId = process.env.AIRTABLE_BASE_ID;
const table = process.env.AIRTABLE_TABLE || 'Opportunities';
const view = process.env.AIRTABLE_VIEW || 'Website';
const maxRows = Number(process.env.MAX_ROWS || 0);

if (!token || !baseId) {
  console.error('AIRTABLE_TOKEN and AIRTABLE_BASE_ID are required.');
  process.exit(1);
}

const outPath = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'data', 'opportunities.dat');

async function fetchAll() {
  const records = [];
  let offset;
  do {
    const url = new URL(`https://api.airtable.com/v0/${baseId}/${encodeURIComponent(table)}`);
    url.searchParams.set('view', view);
    url.searchParams.set('pageSize', '100');
    if (offset) url.searchParams.set('offset', offset);
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) throw new Error(`Airtable ${res.status}: ${await res.text()}`);
    const json = await res.json();
    records.push(...json.records);
    offset = json.offset;
  } while (offset);
  return records;
}

const records = await fetchAll();
if (records.length && !records.some((r) => r.fields && r.fields['Program'])) {
  // Protects the live site from being emptied when the secrets still point at a base with the old schema.
  throw new Error(`No "Program" field in ${baseId} / ${table} / ${view}; expected the 20261026 Opportunities schema. Leaving data unchanged.`);
}
const payload = buildPayload(records.map((r) => toOpportunity(r.fields, r.id)), `Airtable ${baseId} / ${table} / ${view}`);
if (!payload.count) throw new Error('Airtable returned no opportunities; leaving data unchanged.');
if (maxRows > 0) {
  payload.opportunities = payload.opportunities.slice(0, maxRows);
  payload.count = payload.opportunities.length;
}

await mkdir(dirname(outPath), { recursive: true });
await writeFile(outPath, protectPayload(JSON.stringify(payload)), 'utf8');
console.log(`Fetched ${records.length} records, wrote ${payload.count} -> ${outPath}`);
