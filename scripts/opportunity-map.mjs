/**
 * Shared mapping from the curated "Opportunities" table (20261026 Airtable import schema) to the
 * opportunity objects consumed by app.js, plus the payload encoder. Used by sync-airtable.mjs
 * (Airtable API) and build-from-csv.mjs (CSV export of the workbook / Airtable table).
 */
import { gzipSync } from 'node:zlib';

// Must match PAYLOAD_KEY in app.js
export const PAYLOAD_KEY = 'ucsd-founder-funding-2026';

export function protectPayload(json) {
  const bytes = gzipSync(Buffer.from(json, 'utf8'));
  const key = Buffer.from(PAYLOAD_KEY, 'utf8');
  for (let i = 0; i < bytes.length; i++) bytes[i] ^= key[i % key.length];
  return 'UCSDF1.' + bytes.toString('base64');
}

const str = (v) => (v == null ? '' : Array.isArray(v) ? v.map(str).filter(Boolean).join(', ') : String(v).trim());
const list = (v) => (Array.isArray(v) ? v.map(str) : str(v).split(',')).map((s) => s.trim()).filter(Boolean);
const isoDate = (v) => {
  const s = str(v);
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  const d = s ? new Date(s) : null;
  return d && !isNaN(d) ? d.toISOString().slice(0, 10) : '';
};

const tierRank = (t) => ({ 'Tier 1': 1, 'Tier 2': 2, 'Tier 3': 3 }[t] || 4);

const DEADLINE_KIND = {
  Fixed: 'confirmed',
  Window: 'confirmed',
  'Recurring-estimated': 'expected',
  Rolling: 'rolling'
};

const EQUITY_LABEL = {
  'No equity': 'Non-dilutive',
  Equity: 'Takes equity',
  'Not stated': 'Equity not stated'
};

const ALL_STAGES = ['Idea', 'Prototype', 'Traction'];

/** @param {Record<string, unknown>} f field map keyed by Airtable column name */
export function toOpportunity(f, id) {
  const title = str(f['Program']);
  const description = str(f['Description']);
  const summary = description.length > 260 ? description.slice(0, 257).trimEnd() + '...' : description;
  const tier = str(f['Tier']);
  const affiliation = str(f['Affiliation']);
  const stages = list(f['Stage']);
  const deadline = isoDate(f['Next Deadline']);
  const deadlineType = str(f['Deadline Type']);

  return {
    id: id || title,
    title,
    organizer: '',
    summary,
    notes: str(f['Notes']),
    type: str(f['Type']),
    fundingModel: EQUITY_LABEL[str(f['Equity'])] || '',
    amount: str(f['Funding / Benefit']) || 'Varies',
    deadline,
    deadlineKind: DEADLINE_KIND[deadlineType] || (deadline ? 'expected' : 'unknown'),
    deadlineNote: str(f['Deadline Label']) || str(f['Deadline / Cadence (text)']),
    recurring: str(f['Recurrence']),
    windowOpens: isoDate(f['Window Opens']),
    audience: str(f['Student Friendly']) === 'Yes' ? 'Student friendly' : '',
    geography: affiliation,
    industry: list(f['Sectors']).join(', '),
    stage: ALL_STAGES.every((s) => stages.includes(s)) ? 'Any stage' : stages.join(', '),
    bestFor: '',
    fit: '',
    tier,
    tierRank: tierRank(tier),
    ucsdRun: affiliation === 'UCSD only' || /\bUCSD\b|UC San Diego/.test(title),
    recordStatus: str(f['Status']) || 'Active',
    verifiedOn: isoDate(f['Verified On']),
    eligibility: str(f['Eligibility']).split(/\r?\n|;\s*/).map((s) => s.trim()).filter(Boolean).slice(0, 6),
    url: (str(f['Website']).match(/https?:\/\/\S+/) || [''])[0].replace(/[;,]$/, '')
  };
}

export function buildPayload(rows, source) {
  const opportunities = rows
    .filter((o) => o.title)
    .sort((a, b) => a.tierRank - b.tierRank || (a.deadline || '9999-12-31').localeCompare(b.deadline || '9999-12-31'));
  return {
    generatedAt: new Date().toISOString(),
    source,
    count: opportunities.length,
    opportunities
  };
}
