/* UC San Diego Student Founder Funding – front-end logic
 * Data source priority:
 *  1. Airtable (source of truth) if CONFIG.airtable.apiKey is set
 *  2. data/opportunities.json (exported from the reviewed workbook / Airtable sync)
 */
const CONFIG = {
  dataUrl: 'data/opportunities.json',
  airtable: {
    apiKey: '',            // Personal access token with data.records:read scope
    baseId: '',            // e.g. appXXXXXXXXXXXXXX
    tableName: 'Opportunities',
    view: 'Website'
  },
  closingSoonDays: 21,
  recentlyClosedDays: 120
};

const state = {
  all: [],
  status: 'open',
  search: '',
  type: '',
  model: '',
  stage: '',
  geo: '',
  ucsdOnly: false,
  sort: 'deadline'
};

const els = {};
const DAY = 24 * 60 * 60 * 1000;

document.addEventListener('DOMContentLoaded', init);

async function init() {
  [
    'status', 'opportunities', 'resultsCount', 'trackedCount', 'updatedAt',
    'searchInput', 'typeFilter', 'modelFilter', 'stageFilter', 'geoFilter', 'sortSelect', 'ucsdOnly',
    'resetFilters', 'countOpen', 'countUpcoming', 'countClosed', 'countAll', 'signupForm', 'signupEmail', 'signupNote'
  ].forEach((id) => { els[id] = document.getElementById(id); });

  bindEvents();
  await loadData();
}

function bindEvents() {
  els.searchInput.addEventListener('input', (e) => { state.search = e.target.value.trim().toLowerCase(); render(); });
  els.typeFilter.addEventListener('change', (e) => { state.type = e.target.value; render(); });
  els.modelFilter.addEventListener('change', (e) => { state.model = e.target.value; render(); });
  els.stageFilter.addEventListener('change', (e) => { state.stage = e.target.value; render(); });
  els.geoFilter.addEventListener('change', (e) => { state.geo = e.target.value; render(); });
  els.sortSelect.addEventListener('change', (e) => { state.sort = e.target.value; render(); });
  els.ucsdOnly.addEventListener('change', (e) => { state.ucsdOnly = e.target.checked; render(); });
  els.resetFilters.addEventListener('click', resetFilters);

  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      state.status = tab.dataset.status;
      document.querySelectorAll('.tab').forEach((t) => {
        const active = t === tab;
        t.classList.toggle('is-active', active);
        t.setAttribute('aria-selected', String(active));
      });
      render();
    });
  });

  els.signupForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const email = els.signupEmail.value.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      els.signupNote.textContent = 'Please enter a valid email address.';
      els.signupNote.classList.remove('is-success');
      return;
    }
    // Placeholder until the Airtable form / newsletter endpoint is connected.
    window.location.href = 'mailto:innovation@ucsd.edu?subject=' + encodeURIComponent('Subscribe: student founder funding digest') +
      '&body=' + encodeURIComponent('Please add ' + email + ' to the weekly funding opportunities digest.');
    els.signupNote.textContent = 'Thanks! Your email client should open so you can confirm the subscription.';
    els.signupNote.classList.add('is-success');
  });
}

function resetFilters() {
  state.search = ''; state.type = ''; state.model = ''; state.stage = ''; state.geo = ''; state.ucsdOnly = false; state.sort = 'deadline';
  els.searchInput.value = ''; els.typeFilter.value = ''; els.modelFilter.value = ''; els.stageFilter.value = '';
  els.geoFilter.value = ''; els.sortSelect.value = 'deadline'; els.ucsdOnly.checked = false;
  render();
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
      payload = await res.json();
    }
    state.all = (payload.opportunities || []).map(decorate);
    els.trackedCount.textContent = state.all.length;
    els.updatedAt.textContent = payload.generatedAt ? formatDate(payload.generatedAt) : 'recently';
    populateFilters();
    setStatus('');
    render();
  } catch (err) {
    console.error(err);
    setStatus('Could not load the opportunity list (' + err.message + '). Please refresh or try again later.', true);
    els.resultsCount.textContent = '';
  }
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
        tierRank: f['Priority Tier'] === 'Tier 1' ? 1 : 2,
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
    deadlineDate: deadline,
    amountValue: parseAmount(o.amount),
    searchText: [o.title, o.organizer, o.summary, o.type, o.bestFor, o.audience, o.industry, o.geography, (o.eligibility || []).join(' ')].join(' ').toLowerCase()
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
  els.resultsCount.textContent = 'Showing ' + items.length + ' of ' + state.all.length + ' opportunities';

  els.opportunities.innerHTML = '';
  if (!items.length) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = 'No opportunities match these filters. Try another status tab or reset the filters.';
    els.opportunities.appendChild(empty);
    return;
  }
  items.forEach((o) => els.opportunities.appendChild(buildCard(o)));
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
        '<h3 class="card-title">' + (o.url ? '<a href="' + escapeAttr(o.url) + '" target="_blank" rel="noopener">' + escapeHtml(o.title) + '</a>' : escapeHtml(o.title)) + '</h3>' +
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
      (o.url ? '<a class="card-link" href="' + escapeAttr(o.url) + '" target="_blank" rel="noopener">View opportunity →</a>' : '<span></span>') +
      '<span class="card-tier">' + escapeHtml(o.tier || '') + '</span>' +
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
