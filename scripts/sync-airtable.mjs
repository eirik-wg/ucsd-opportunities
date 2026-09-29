#!/usr/bin/env node
/**
 * Pull opportunities from Airtable (source of truth) and write data/opportunities.json
 * in the shape consumed by app.js.
 *
 * Env vars:
 *   AIRTABLE_TOKEN   personal access token, scope data.records:read
 *   AIRTABLE_BASE_ID appXXXXXXXXXXXXXX
 *   AIRTABLE_TABLE   default "Opportunities"
 *   AIRTABLE_VIEW    default "Website" (view should filter Show on Website = checked)
 *   MAX_ROWS         default 80
 */
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const token = process.env.AIRTABLE_TOKEN;
const baseId = process.env.AIRTABLE_BASE_ID;
const table = process.env.AIRTABLE_TABLE || 'Opportunities';
const view = process.env.AIRTABLE_VIEW || 'Website';
const maxRows = Number(process.env.MAX_ROWS || 80);

if (!token || !baseId) {
  console.error('AIRTABLE_TOKEN and AIRTABLE_BASE_ID are required.');
  process.exit(1);
}

const outPath = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'data', 'opportunities.json');

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

const str = (v) => (v == null ? '' : Array.isArray(v) ? v.join(', ') : String(v).trim());
const tierRank = (t) => ({ 'Tier 1': 1, 'Tier 2': 2, 'Tier 3': 3 }[t] || 4);

function toOpportunity(r) {
  const f = r.fields;
  const description = str(f['Program Description']);
  const summary = description.length > 260 ? description.slice(0, 257).trimEnd() + '...' : description;
  const eligibilityRaw = f['Eligibility'];
  const eligibility = Array.isArray(eligibilityRaw)
    ? eligibilityRaw.map(str).filter(Boolean)
    : str(eligibilityRaw).split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  const tier = str(f['Priority Tier']);
  const title = str(f['Program Title']);

  return {
    id: r.id,
    title,
    organizer: str(f['Organizer']),
    summary,
    type: str(f['Type']),
    fundingModel: str(f['Funding Model']) || 'Non-dilutive',
    amount: str(f['Funding Amount/Prize Amount']) || 'Varies',
    deadline: str(f['Estimated Deadline Date']).slice(0, 10),
    deadlineKind: str(f['Deadline Kind']) || 'expected',
    deadlineNote: str(f['Next Deadline']),
    recurring: str(f['Recurring']),
    audience: str(f['Eligibility Label']),
    geography: str(f['Geography']),
    industry: str(f['Industry']),
    stage: str(f['Founder Stage']),
    bestFor: str(f['Best For']),
    fit: str(f['Student Startup Fit']),
    tier,
    tierRank: tierRank(tier),
    ucsdRun: Boolean(f['UCSD Run']) || /UCSD|UC San Diego/.test(title),
    eligibility: eligibility.slice(0, 6),
    url: str(f['Website link'])
  };
}

const records = await fetchAll();
const opportunities = records
  .map(toOpportunity)
  .filter((o) => o.title)
  .sort((a, b) => a.tierRank - b.tierRank || (a.deadline || '9999-12-31').localeCompare(b.deadline || '9999-12-31'))
  .slice(0, maxRows);

const payload = {
  generatedAt: new Date().toISOString(),
  source: `Airtable ${baseId} / ${table} / ${view}`,
  count: opportunities.length,
  opportunities
};

await mkdir(dirname(outPath), { recursive: true });
await writeFile(outPath, JSON.stringify(payload, null, 2) + '\n', 'utf8');
console.log(`Fetched ${records.length} records, wrote ${opportunities.length} -> ${outPath}`);
