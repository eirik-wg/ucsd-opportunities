#!/usr/bin/env node
/**
 * Build data/opportunities.dat from a CSV of the "Opportunities" table, e.g. the Opportunities sheet of
 * "20261026_Funding Opportunities_Airtable import.xlsx" saved as CSV (UTF-8), or Airtable > Download CSV.
 *
 * Usage: node scripts/build-from-csv.mjs path/to/Opportunities.csv
 */
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { toOpportunity, buildPayload, protectPayload } from './opportunity-map.mjs';

const csvPath = process.argv[2];
if (!csvPath) {
  console.error('Usage: node scripts/build-from-csv.mjs <Opportunities.csv>');
  process.exit(1);
}
const outPath = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'data', 'opportunities.dat');

// RFC 4180 parser (quoted fields, escaped quotes, embedded newlines)
function parseCsv(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows.filter((r) => r.some((v) => v !== ''));
}

const [header, ...data] = parseCsv((await readFile(csvPath, 'utf8')).replace(/^\uFEFF/, ''));
if (!header.includes('Program')) throw new Error('CSV must have a "Program" column (20261026 Opportunities schema).');
const rows = data.map((cells) => toOpportunity(Object.fromEntries(header.map((h, i) => [h.trim(), cells[i] ?? '']))));
const payload = buildPayload(rows, basename(csvPath));

await mkdir(dirname(outPath), { recursive: true });
await writeFile(outPath, protectPayload(JSON.stringify(payload)), 'utf8');
console.log(`Read ${data.length} rows, wrote ${payload.count} -> ${outPath}`);
