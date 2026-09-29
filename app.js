/* UC San Diego Student Founder Funding – front-end logic
 * Data source priority:
 *  1. Airtable (source of truth) if CONFIG.airtable.apiKey is set (local testing only)
 *  2. data/opportunities.dat – gzip + XOR + base64 payload written by export_site_data.ps1 / scripts/sync-airtable.mjs
 */
const CONFIG = {
  dataUrl: 'data/opportunities.dat',
  airtable: {
    apiKey: '',            // Personal access token with data.records:read scope
    baseId: '',            // e.g. appXXXXXXXXXXXXXX
    tableName: 'Opportunities',
    view: 'Website'
  },
  // POST endpoint that stores alert subscriptions (Airtable form automation, Formspree, Power Automate, ...).
  // Receives JSON: { email, kinds[], view, viewUrl, summary, source }. Leave empty to fall back to a mailto: draft.
  subscribeEndpoint: '',
  subscribeFallbackEmail: 'innovation@ucsd.edu',
  closingSoonDays: 21,
  recentlyClosedDays: 120,
  defaultPageSize: 20,
  defaultTiers: [1, 2]
};

// Must match $payloadKey in export_site_data.ps1 and PAYLOAD_KEY in scripts/sync-airtable.mjs
const PAYLOAD_KEY = 'ucsd-founder-funding-2026';
const STORAGE_KEY = 'ucsdFunding.savedViews.v1';

const TIER_INFO = {
  1: 'Tier 1 · Excellent student-startup fit',
  2: 'Tier 2 · Strong fit',
  3: 'Tier 3 · Moderate fit',
  4: 'Tier 4 · Secondary / low priority'
};

const defaultState = () => ({
  status: 'open',
  search: '',
  type: '',
  model: '',
  stage: '',
  geo: '',
  ucsdOnly: false,
  sort: 'deadline',
  tiers: CONFIG.defaultTiers.slice(),
  pageSize: CONFIG.defaultPageSize
});

const state = Object.assign({ all: [], shown: CONFIG.defaultPageSize }, defaultState());

const els = {};
const DAY = 24 * 60 * 60 * 1000;

document.addEventListener('DOMContentLoaded', init);

async function init() {
  [
    'status', 'opportunities', 'resultsCount', 'trackedCount', 'updatedAt',
    'searchInput', 'typeFilter', 'modelFilter', 'stageFilter', 'geoFilter', 'sortSelect', 'pageSizeSelect', 'ucsdOnly',
    'tierFieldset', 'tierHelpToggle', 'tierHelp', 'countTier1', 'countTier2', 'countTier3', 'countTier4',
    'resetFilters', 'countOpen', 'countUpcoming', 'countClosed', 'countAll',
    'signupForm', 'signupEmail', 'signupNote',
    'saveViewBtn', 'copyLinkBtn', 'alertsBtn', 'saveViewForm', 'saveViewName', 'saveViewCancel', 'savedViews', 'savedViewsList',
    'pager', 'showMoreBtn', 'pagerNote',
    'alertDialog', 'alertForm', 'alertEmail', 'alertViewSummary', 'alertError', 'alertCancel'
  ].forEach((id) => { els[id] = document.getElementById(id); });

  // Headless / automated browsers (Selenium, Puppeteer, Playwright defaults) flag themselves here.
  if (navigator.webdriver) {
    setStatus('This database is available to people using a regular web browser. Automated access is not supported.', true);
    els.resultsCount.textContent = '';
    return;
  }

  bindEvents();
  renderSavedViews();
  await loadData();
}

function bindEvents() {
  els.searchInput.addEventListener('input', (e) => { state.search = e.target.value.trim().toLowerCase(); onFilterChange(); });
  els.typeFilter.addEventListener('change', (e) => { state.type = e.target.value; onFilterChange(); });
  els.modelFilter.addEventListener('change', (e) => { state.model = e.target.value; onFilterChange(); });
  els.stageFilter.addEventListener('change', (e) => { state.stage = e.target.value; onFilterChange(); });
  els.geoFilter.addEventListener('change', (e) => { state.geo = e.target.value; onFilterChange(); });
  els.sortSelect.addEventListener('change', (e) => { state.sort = e.target.value; onFilterChange(); });
  els.ucsdOnly.addEventListener('change', (e) => { state.ucsdOnly = e.target.checked; onFilterChange(); });
  els.pageSizeSelect.addEventListener('change', (e) => { state.pageSize = Number(e.target.value); onFilterChange(); });
  els.tierFieldset.addEventListener('change', () => {
    state.tiers = tierInputs().filter((i) => i.checked).map((i) => Number(i.value));
    onFilterChange();
  });
  els.tierHelpToggle.addEventListener('click', () => {
    const open = els.tierHelp.hidden;
    els.tierHelp.hidden = !open;
    els.tierHelpToggle.setAttribute('aria-expanded', String(open));
    els.tierHelpToggle.textContent = open ? 'Hide tier guide' : 'What do tiers mean?';
  });
  els.resetFilters.addEventListener('click', resetFilters);
  els.showMoreBtn.addEventListener('click', () => { state.shown += state.pageSize || 0; render(); });

  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => { state.status = tab.dataset.status; syncTabs(); onFilterChange(); });
  });

  // Saved views
  els.saveViewBtn.addEventListener('click', () => {
    els.saveViewForm.hidden = false;
    els.saveViewName.value = describeView();
    els.saveViewName.focus();
    els.saveViewName.select();
  });
  els.saveViewCancel.addEventListener('click', () => { els.saveViewForm.hidden = true; });
  els.saveViewForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const name = els.saveViewName.value.trim();
    if (!name) return;
    const views = loadSavedViews().filter((v) => v.name !== name);
    views.unshift({ name, params: serializeState(), created: new Date().toISOString() });
    saveSavedViews(views.slice(0, 20));
    els.saveViewForm.hidden = true;
    renderSavedViews();
    flash('Saved “' + name + '” in this browser.');
  });
  els.copyLinkBtn.addEventListener('click', async () => {
    const url = viewUrl();
    try {
      await navigator.clipboard.writeText(url);
      flash('Link copied. Anyone opening it sees this exact view.');
    } catch (err) {
      window.prompt('Copy this link:', url);
    }
  });

  // Alerts
  els.alertsBtn.addEventListener('click', () => openAlertDialog(els.signupEmail.value.trim()));
  els.alertCancel.addEventListener('click', () => els.alertDialog.close());
  els.alertForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = els.alertEmail.value.trim();
    const kinds = Array.from(els.alertForm.querySelectorAll('input[name="alertKind"]:checked')).map((i) => i.value);
    if (!isEmail(email)) { els.alertError.textContent = 'Please enter a valid email address.'; return; }
    if (!kinds.length) { els.alertError.textContent = 'Choose at least one type of alert.'; return; }
    els.alertError.textContent = '';
    const result = await submitSubscription({ email, kinds, view: serializeState() });
    els.alertDialog.close();
    flash(result.message, !result.ok);
  });

  els.signupForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = els.signupEmail.value.trim();
    if (!isEmail(email)) {
      els.signupNote.textContent = 'Please enter a valid email address.';
      els.signupNote.classList.remove('is-success');
      return;
    }
    // Hero form = weekly digest + deadline reminders for the default view (Tier 1–2, open).
    const result = await submitSubscription({ email, kinds: ['weekly', 'deadline'], view: serializeState(defaultState()) });
    els.signupNote.textContent = result.message;
    els.signupNote.classList.toggle('is-success', result.ok);
  });
}

function tierInputs() {
  return Array.from(els.tierFieldset.querySelectorAll('input[name="tier"]'));
}

function onFilterChange() {
  state.shown = state.pageSize || Infinity;
  render();
}

function syncTabs() {
  document.querySelectorAll('.tab').forEach((t) => {
    const active = t.dataset.status === state.status;
    t.classList.toggle('is-active', active);
    t.setAttribute('aria-selected', String(active));
  });
}

function resetFilters() {
  applyState(defaultState());
  onFilterChange();
}

/* Push state -> form controls */
function applyState(s) {
  Object.assign(state, defaultState(), s);
  els.searchInput.value = state.search;
  els.typeFilter.value = state.type;
  els.modelFilter.value = state.model;
  els.stageFilter.value = state.stage;
  els.geoFilter.value = state.geo;
  els.sortSelect.value = state.sort;
  els.pageSizeSelect.value = String(state.pageSize);
  els.ucsdOnly.checked = state.ucsdOnly;
  tierInputs().forEach((i) => { i.checked = state.tiers.includes(Number(i.value)); });
  // If a select value was not among the options (e.g. stale link), fall back to "any"
  ['type', 'model', 'stage', 'geo'].forEach((k) => {
    const sel = els[k + 'Filter'];
    if (sel.value !== state[k]) { state[k] = ''; sel.value = ''; }
  });
  syncTabs();
}

/* ---------------- Data loading ---------------- */

async function loadData() {
  setStatus('Loading opportunities…');
  try {
    let payload;
    if (CONFIG.airtable.apiKey && CONFIG.airtable.baseId) {
      payload = await fetchAirtable();
    } else {
      const res = await fetch(CONFIG.dataUrl, { cache: 'no-cache' });
      if (!res.ok) throw new Error('HTTP ' + res.status + ' loading ' + CONFIG.dataUrl);
      payload = await unprotectPayload(await res.text());
    }
    state.all = (payload.opportunities || []).map(decorate);
    els.trackedCount.textContent = state.all.length;
    els.updatedAt.textContent = payload.generatedAt ? formatDate(payload.generatedAt) : 'recently';
    populateFilters();
    [1, 2, 3, 4].forEach((t) => { els['countTier' + t].textContent = state.all.filter((o) => o.tierRank === t).length; });
    applyState(parseState(new URLSearchParams(window.location.search)));
    state.shown = state.pageSize || Infinity;
    setStatus('');
    render();
  } catch (err) {
    console.error(err);
    setStatus('Could not load the opportunity list (' + err.message + '). Please refresh or try again later.', true);
    els.resultsCount.textContent = '';
  }
}

/* Reverse of Protect-Payload / protectPayload: base64 -> XOR key -> gunzip -> JSON */
async function unprotectPayload(text) {
  const trimmed = text.trim();
  if (trimmed.startsWith('{')) return JSON.parse(trimmed); // plain JSON (local dev)
  const dot = trimmed.indexOf('.');
  if (trimmed.slice(0, dot) !== 'UCSDF1') throw new Error('Unknown data format');
  const bin = atob(trimmed.slice(dot + 1));
  const bytes = new Uint8Array(bin.length);
  const key = new TextEncoder().encode(PAYLOAD_KEY);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i) ^ key[i % key.length];
  if (typeof DecompressionStream !== 'function') throw new Error('This browser is too old to read the database; please update it');
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));
  return JSON.parse(await new Response(stream).text());
}

async function fetchAirtable() {
  const { apiKey, baseId, tableName, view } = CONFIG.airtable;
  const records = [];
  let offset;
  do {
    const url = new URL('https://api.airtable.com/v0/' + baseId + '/' + encodeURIComponent(tableName));
    if (view) url.searchParams.set('view', view);
    url.searchParams.set('pageSize', '100');
    if (offset) url.searchParams.set('offset', offset);
    const res = await fetch(url, { headers: { Authorization: 'Bearer ' + apiKey } });
    if (!res.ok) throw new Error('Airtable HTTP ' + res.status);
    const json = await res.json();
    records.push(...json.records);
    offset = json.offset;
  } while (offset);

  return {
    generatedAt: new Date().toISOString(),
    opportunities: records.map((r) => {
      const f = r.fields;
      return {
        id: r.id,
        title: f['Program Title'] || '',
        organizer: f['Organizer'] || '',
        summary: f['Program Description'] || '',
        type: f['Type'] || '',
        fundingModel: f['Funding Model'] || 'Non-dilutive',
        amount: f['Funding Amount/Prize Amount'] || 'Varies',
        deadline: f['Estimated Deadline Date'] || '',
        deadlineKind: f['Deadline Kind'] || 'expected',
        deadlineNote: f['Next Deadline'] || '',
        recurring: f['Recurring'] || '',
        audience: f['Eligibility Label'] || '',
        geography: f['Geography'] || '',
        industry: f['Industry'] || '',
        stage: f['Founder Stage'] || '',
        bestFor: f['Best For'] || '',
        fit: f['Student Startup Fit'] || '',
        tier: f['Priority Tier'] || '',
        tierRank: { 'Tier 1': 1, 'Tier 2': 2, 'Tier 3': 3 }[f['Priority Tier']] || 4,
        ucsdRun: !!f['UCSD Run'],
        eligibility: Array.isArray(f['Eligibility']) ? f['Eligibility'] : String(f['Eligibility'] || '').split('\n').filter(Boolean),
        url: f['Website link'] || ''
      };
    })
  };
}

/* ---------------- Derived fields ---------------- */

function decorate(o) {
  const today = startOfDay(new Date());
  const deadline = o.deadline ? startOfDay(new Date(o.deadline + 'T00:00:00')) : null;
  const daysLeft = deadline ? Math.round((deadline - today) / DAY) : null;
  const isRolling = o.deadlineKind === 'rolling' || !deadline;
  // PowerShell unrolls single-element arrays, so a lone eligibility item can arrive as a string.
  const eligibility = Array.isArray(o.eligibility) ? o.eligibility : (o.eligibility ? [String(o.eligibility)] : []);

  let status, badgeClass, badgeText;
  if (isRolling) {
    status = 'open'; badgeClass = 'badge-open'; badgeText = 'Open · rolling';
  } else if (daysLeft < 0) {
    status = 'closed'; badgeClass = 'badge-closed';
    badgeText = o.deadlineKind === 'expected' ? 'Cycle passed · next TBD' : 'Closed';
  } else if (o.deadlineKind === 'confirmed') {
    status = 'open';
    if (daysLeft === 0) { badgeClass = 'badge-soon'; badgeText = 'Closes today'; }
    else if (daysLeft <= CONFIG.closingSoonDays) { badgeClass = 'badge-soon'; badgeText = 'Closes in ' + daysLeft + ' day' + (daysLeft === 1 ? '' : 's'); }
    else { badgeClass = 'badge-open'; badgeText = 'Open'; }
  } else {
    status = 'upcoming'; badgeClass = 'badge-expected';
    badgeText = 'Expected · ' + (daysLeft <= CONFIG.closingSoonDays ? 'in ' + daysLeft + ' days' : formatMonth(deadline));
  }

  return Object.assign({}, o, {
    status, badgeClass, badgeText, daysLeft, isRolling,
    eligibility,
    deadlineDate: deadline,
    amountValue: parseAmount(o.amount),
    searchText: [o.title, o.organizer, o.summary, o.type, o.bestFor, o.audience, o.industry, o.geography, eligibility.join(' ')].join(' ').toLowerCase()
  });
}

function parseAmount(text) {
  if (!text) return 0;
  let max = 0;
  const re = /\$\s?([\d,.]+)\s*([kKmM]?)/g;
  let m;
  while ((m = re.exec(text))) {
    let n = parseFloat(m[1].replace(/,/g, ''));
    if (isNaN(n)) continue;
    if (/k/i.test(m[2])) n *= 1e3;
    if (/m/i.test(m[2])) n *= 1e6;
    if (n > max) max = n;
  }
  return max;
}

/* ---------------- Filters & rendering ---------------- */

function populateFilters() {
  fillSelect(els.typeFilter, unique(state.all.map((o) => o.type)));
  fillSelect(els.modelFilter, unique(state.all.map((o) => o.fundingModel)));
  fillSelect(els.stageFilter, unique(state.all.map((o) => o.stage)), ['Idea', 'Prototype', 'Traction', 'Any stage']);
  fillSelect(els.geoFilter, unique(state.all.map((o) => o.geography)));
}

function fillSelect(select, values, order) {
  const sorted = order ? values.slice().sort((a, b) => order.indexOf(a) - order.indexOf(b)) : values.slice().sort();
  sorted.forEach((v) => {
    const opt = document.createElement('option');
    opt.value = v; opt.textContent = v;
    select.appendChild(opt);
  });
}

function unique(arr) {
  return Array.from(new Set(arr.filter(Boolean)));
}

function matchesFilters(o) {
  if (!state.tiers.includes(o.tierRank)) return false;
  if (state.type && o.type !== state.type) return false;
  if (state.model && o.fundingModel !== state.model) return false;
  if (state.stage && o.stage !== state.stage && o.stage !== 'Any stage') return false;
  if (state.geo && o.geography !== state.geo) return false;
  if (state.ucsdOnly && !o.ucsdRun) return false;
  if (state.search && !o.searchText.includes(state.search)) return false;
  return true;
}

function matchesStatus(o, status) {
  if (status === 'all') return true;
  if (status === 'closed') return o.status === 'closed' && (o.daysLeft === null || o.daysLeft >= -CONFIG.recentlyClosedDays);
  return o.status === status;
}

function sortItems(items) {
  const byDeadline = (a, b) => {
    const ad = a.isRolling ? Infinity : a.daysLeft;
    const bd = b.isRolling ? Infinity : b.daysLeft;
    if (ad !== bd) return ad - bd;
    return a.tierRank - b.tierRank;
  };
  const sorters = {
    deadline: byDeadline,
    relevance: (a, b) => (a.tierRank - b.tierRank) || (Number(b.ucsdRun) - Number(a.ucsdRun)) || fitRank(a) - fitRank(b) || byDeadline(a, b),
    amount: (a, b) => (b.amountValue - a.amountValue) || byDeadline(a, b),
    title: (a, b) => a.title.localeCompare(b.title)
  };
  return items.slice().sort(sorters[state.sort] || byDeadline);
}

function fitRank(o) {
  return ['Excellent', 'Strong', 'Moderate', 'Low'].indexOf(o.fit) + 1 || 9;
}

function render() {
  const filtered = state.all.filter(matchesFilters);
  els.countOpen.textContent = filtered.filter((o) => matchesStatus(o, 'open')).length;
  els.countUpcoming.textContent = filtered.filter((o) => matchesStatus(o, 'upcoming')).length;
  els.countClosed.textContent = filtered.filter((o) => matchesStatus(o, 'closed')).length;
  els.countAll.textContent = filtered.length;

  const items = sortItems(filtered.filter((o) => matchesStatus(o, state.status)));
  const limit = state.pageSize ? Math.min(state.shown, items.length) : items.length;
  const visible = items.slice(0, limit);

  els.resultsCount.textContent = state.tiers.length
    ? 'Showing ' + visible.length + ' of ' + items.length + ' matching · ' + state.all.length + ' tracked'
    : 'Select at least one tier to see opportunities';
  updateUrl();

  els.opportunities.innerHTML = '';
  if (!items.length) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = state.tiers.length
      ? 'No opportunities match these filters. Try another status tab, add a tier, or reset the filters.'
      : 'Tick one or more priority tiers above to show opportunities.';
    els.opportunities.appendChild(empty);
    els.pager.hidden = true;
    return;
  }
  visible.forEach((o) => els.opportunities.appendChild(buildCard(o)));

  const remaining = items.length - visible.length;
  els.pager.hidden = remaining <= 0;
  if (remaining > 0) {
    const step = Math.min(state.pageSize, remaining);
    els.showMoreBtn.textContent = 'Show ' + step + ' more';
    els.pagerNote.textContent = remaining + ' more match' + (remaining === 1 ? '' : 'es') + ' this view';
  }
}

/* ---------------- View state: URL, saved views, alerts ---------------- */

const PARAM_KEYS = { status: 'status', search: 'q', type: 'type', model: 'model', stage: 'stage', geo: 'geo', sort: 'sort' };

function serializeState(s) {
  s = s || state;
  const d = defaultState();
  const p = new URLSearchParams();
  Object.keys(PARAM_KEYS).forEach((k) => { if (s[k] && s[k] !== d[k]) p.set(PARAM_KEYS[k], s[k]); });
  if (s.ucsdOnly) p.set('ucsd', '1');
  if (s.tiers.join(',') !== d.tiers.join(',')) p.set('tiers', s.tiers.join(','));
  if (s.pageSize !== d.pageSize) p.set('n', String(s.pageSize));
  return p.toString();
}

function parseState(params) {
  const s = {};
  Object.keys(PARAM_KEYS).forEach((k) => { const v = params.get(PARAM_KEYS[k]); if (v) s[k] = v; });
  if (s.status && !['open', 'upcoming', 'closed', 'all'].includes(s.status)) delete s.status;
  if (s.sort && !['deadline', 'relevance', 'amount', 'title'].includes(s.sort)) delete s.sort;
  if (s.search) s.search = s.search.toLowerCase();
  if (params.get('ucsd') === '1') s.ucsdOnly = true;
  if (params.has('tiers')) {
    s.tiers = params.get('tiers').split(',').map(Number).filter((n) => n >= 1 && n <= 4);
  }
  if (params.has('n')) {
    const n = Number(params.get('n'));
    if ([0, 20, 50, 100].includes(n)) s.pageSize = n;
  }
  return s;
}

function updateUrl() {
  const qs = serializeState();
  const url = window.location.pathname + (qs ? '?' + qs : '') + window.location.hash;
  if (url !== window.location.pathname + window.location.search + window.location.hash) {
    history.replaceState(null, '', url);
  }
}

function viewUrl(params) {
  const qs = params === undefined ? serializeState() : params;
  return window.location.origin + window.location.pathname + (qs ? '?' + qs : '') + '#database';
}

function describeView(s) {
  s = s || state;
  const parts = [];
  const statusLabel = { open: 'Open now', upcoming: 'Upcoming', closed: 'Recently closed', all: 'All statuses' }[s.status];
  parts.push(statusLabel);
  parts.push(s.tiers.length === 4 ? 'all tiers' : s.tiers.length ? 'Tier ' + s.tiers.join(' + ') : 'no tiers');
  if (s.search) parts.push('“' + s.search + '”');
  if (s.type) parts.push(s.type);
  if (s.model) parts.push(s.model);
  if (s.stage) parts.push(s.stage + ' stage');
  if (s.geo) parts.push(s.geo);
  if (s.ucsdOnly) parts.push('UC San Diego only');
  return parts.join(' · ');
}

function loadSavedViews() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
    return Array.isArray(raw) ? raw.filter((v) => v && typeof v.name === 'string' && typeof v.params === 'string') : [];
  } catch (err) { return []; }
}

function saveSavedViews(views) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(views)); } catch (err) { /* private mode / quota */ }
}

function renderSavedViews() {
  const views = loadSavedViews();
  els.savedViews.hidden = !views.length;
  els.savedViewsList.innerHTML = '';
  views.forEach((v) => {
    const chip = document.createElement('span');
    chip.className = 'saved-view';
    const apply = document.createElement('button');
    apply.type = 'button';
    apply.className = 'saved-view-apply';
    apply.textContent = v.name;
    apply.title = describeView(Object.assign(defaultState(), parseState(new URLSearchParams(v.params))));
    apply.addEventListener('click', () => {
      applyState(parseState(new URLSearchParams(v.params)));
      onFilterChange();
      flash('Applied “' + v.name + '”.');
    });
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.className = 'saved-view-remove';
    remove.setAttribute('aria-label', 'Delete saved view ' + v.name);
    remove.textContent = '×';
    remove.addEventListener('click', () => {
      saveSavedViews(loadSavedViews().filter((x) => x.name !== v.name));
      renderSavedViews();
    });
    chip.append(apply, remove);
    els.savedViewsList.appendChild(chip);
  });
}

function openAlertDialog(prefillEmail) {
  els.alertViewSummary.textContent = describeView();
  els.alertError.textContent = '';
  if (prefillEmail && !els.alertEmail.value) els.alertEmail.value = prefillEmail;
  if (typeof els.alertDialog.showModal === 'function') els.alertDialog.showModal();
  else els.alertDialog.setAttribute('open', '');
}

const KIND_LABELS = { weekly: 'weekly digest', deadline: 'deadline reminders (14 and 3 days before)', new: 'new matching opportunities' };

async function submitSubscription({ email, kinds, view }) {
  const viewState = Object.assign(defaultState(), parseState(new URLSearchParams(view)));
  const summary = describeView(viewState);
  const body = {
    email,
    kinds,
    view,
    viewUrl: viewUrl(view),
    summary,
    source: 'ucsd-founder-funding',
    submittedAt: new Date().toISOString()
  };

  if (CONFIG.subscribeEndpoint) {
    try {
      const res = await fetch(CONFIG.subscribeEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify(body)
      });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return { ok: true, message: 'You are subscribed. We will email ' + email + ' about: ' + summary + '.' };
    } catch (err) {
      console.error(err);
      return { ok: false, message: 'Could not save your subscription right now (' + err.message + '). Please try again later.' };
    }
  }

  // Fallback until an endpoint is connected: open a pre-filled email to the team.
  const text = [
    'Please subscribe ' + email + ' to funding alerts.',
    '',
    'Alerts: ' + kinds.map((k) => KIND_LABELS[k] || k).join('; '),
    'View: ' + summary,
    'Link: ' + body.viewUrl,
    'Filters: ' + (view || '(default)')
  ].join('\n');
  window.location.href = 'mailto:' + CONFIG.subscribeFallbackEmail +
    '?subject=' + encodeURIComponent('Subscribe: founder funding alerts') +
    '&body=' + encodeURIComponent(text);
  return { ok: true, message: 'Your email client should open with the subscription request pre-filled — just send it.' };
}

let flashTimer;
function flash(msg, isError) {
  setStatus(msg, isError);
  clearTimeout(flashTimer);
  flashTimer = setTimeout(() => { if (els.status.textContent === msg) setStatus(''); }, 6000);
}

function isEmail(s) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(s);
}

function buildCard(o) {
  const card = document.createElement('article');
  card.className = 'card' + (o.status === 'closed' ? ' is-closed' : '') + (o.badgeClass === 'badge-soon' ? ' is-soon' : '');

  const eligibility = (o.eligibility || []).filter(Boolean);
  const visibleCount = 3;
  const eligibilityHtml = eligibility.length
    ? '<div class="eligibility"><h4>Key eligibility</h4><ul>' +
      eligibility.map((e, i) => '<li' + (i >= visibleCount ? ' class="is-hidden"' : '') + '>' + escapeHtml(e) + '</li>').join('') +
      '</ul>' +
      (eligibility.length > visibleCount ? '<button type="button" class="eligibility-toggle" data-expanded="false">Show all ' + eligibility.length + ' requirements</button>' : '') +
      '</div>'
    : '';

  const deadlineLabel = o.isRolling
    ? 'Rolling'
    : formatDate(o.deadlineDate);
  const deadlineSub = o.isRolling
    ? escapeHtml(o.deadlineNote || o.recurring || '')
    : (o.deadlineKind === 'expected' ? 'Expected · based on previous cycle' : 'Confirmed') + (o.recurring ? ' · ' + escapeHtml(o.recurring) : '');

  const tags = [
    ['tag-model', o.fundingModel],
    ['', o.audience],
    ['', o.geography],
    ['', o.industry],
    ['', o.stage && o.stage !== 'Any stage' ? o.stage + ' stage' : ''],
    ['tag-fit', o.fit ? o.fit + ' student fit' : '']
  ].filter((t) => t[1]);

  card.innerHTML =
    '<div class="card-head">' +
      '<div>' +
        '<h3 class="card-title">' + (o.url ? '<a href="' + escapeAttr(o.url) + '" target="_blank" rel="noopener nofollow">' + escapeHtml(o.title) + '</a>' : escapeHtml(o.title)) + '</h3>' +
        '<p class="card-org">' + escapeHtml(o.organizer || '') + (o.bestFor ? ' · Best for: ' + escapeHtml(o.bestFor) : '') + '</p>' +
      '</div>' +
      '<div class="badge-group">' +
        (o.ucsdRun ? '<span class="badge badge-ucsd">UC San Diego</span>' : '') +
        '<span class="badge ' + o.badgeClass + '">' + escapeHtml(o.badgeText) + '</span>' +
      '</div>' +
    '</div>' +
    (o.summary ? '<p class="card-summary">' + escapeHtml(o.summary) + '</p>' : '') +
    '<div class="card-facts">' +
      '<div><span class="fact-label">Deadline</span><span class="fact-value">' + escapeHtml(deadlineLabel) + '</span><span class="fact-sub">' + deadlineSub + '</span></div>' +
      '<div><span class="fact-label">Funding / prize</span><span class="fact-value">' + escapeHtml(o.amount || 'Varies') + '</span></div>' +
      '<div><span class="fact-label">Type</span><span class="fact-value">' + escapeHtml(o.type || '—') + '</span></div>' +
    '</div>' +
    '<div class="tags">' + tags.map((t) => '<span class="tag ' + t[0] + '">' + escapeHtml(t[1]) + '</span>').join('') + '</div>' +
    eligibilityHtml +
    '<div class="card-foot">' +
      (o.url ? '<a class="card-link" href="' + escapeAttr(o.url) + '" target="_blank" rel="noopener nofollow">View opportunity →</a>' : '<span></span>') +
      '<span class="card-tier tier-pill tier-' + o.tierRank + '" title="' + escapeHtml(TIER_INFO[o.tierRank] || '') + '">' + escapeHtml(o.tier || 'Tier ' + o.tierRank) + '</span>' +
    '</div>';

  const toggle = card.querySelector('.eligibility-toggle');
  if (toggle) {
    toggle.addEventListener('click', () => {
      const expanded = toggle.dataset.expanded === 'true';
      card.querySelectorAll('.eligibility li').forEach((li, i) => { if (i >= visibleCount) li.classList.toggle('is-hidden', expanded); });
      toggle.dataset.expanded = String(!expanded);
      toggle.textContent = expanded ? 'Show all ' + eligibility.length + ' requirements' : 'Show fewer';
    });
  }
  return card;
}

/* ---------------- Utilities ---------------- */

function setStatus(msg, isError) {
  els.status.textContent = msg;
  els.status.classList.toggle('is-error', !!isError);
}

function startOfDay(d) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

function formatDate(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (isNaN(d)) return String(value);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function formatMonth(d) {
  return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function escapeAttr(str) {
  const s = String(str).trim();
  if (!/^https?:\/\//i.test(s)) return '#';
  return escapeHtml(s);
}
