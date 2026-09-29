const CONFIG = {
  airtableApiKey: 'demo-key',
  baseId: '',
  tableName: 'Opportunities',
  view: 'Top Opportunities',
  useSampleData: true
};

const elements = {
  typeFilter: document.getElementById('typeFilter'),
  fitFilter: document.getElementById('fitFilter'),
  stageFilter: document.getElementById('stageFilter'),
  searchInput: document.getElementById('searchInput'),
  cards: document.getElementById('opportunities'),
  status: document.getElementById('status')
};

const sampleData = [
  {
    title: 'UCSD von Liebig Proof of Concept Grant',
    type: 'Grant',
    fit: 'Excellent',
    stage: 'Prototype',
    bestFor: 'Research spinout',
    value: '$25K-$100K',
    nextDeadline: '2026-12-15',
    eligibility: 'UCSD-affiliated / Student-only / Research / academic',
    summary: 'Non-dilutive funding for early-stage technology validation and commercialization work.',
    url: 'https://example.com/ucsd-von-liebig'
  },
  {
    title: 'Institute for the Global Entrepreneur (IGE)',
    type: 'Accelerator',
    fit: 'Excellent',
    stage: 'Prototype',
    bestFor: 'Early-stage team',
    value: '$5K-$25K',
    nextDeadline: '2026-11-01',
    eligibility: 'UCSD-affiliated / Student-only',
    summary: 'Entrepreneurship support and startup programming designed for UCSD founders.',
    url: 'https://example.com/ige'
  },
  {
    title: 'NIWC Pacific SBIR/STTR Programs',
    type: 'Grant',
    fit: 'Strong',
    stage: 'Prototype',
    bestFor: 'Research spinout',
    value: '$100K+',
    nextDeadline: '2026-10-31',
    eligibility: 'UCSD-affiliated / Research / academic / Regional / local',
    summary: 'Federal innovation funding for research-based commercialization opportunities.',
    url: 'https://example.com/niwc'
  },
  {
    title: 'San Diego Startup Week',
    type: 'Competition',
    fit: 'Moderate',
    stage: 'Any stage',
    bestFor: 'Networking / support',
    value: 'Non-cash support',
    nextDeadline: '2027-01-15',
    eligibility: 'Open to all',
    summary: 'A major startup ecosystem event covering networking, investor access, and visibility.',
    url: 'https://example.com/sdsw'
  }
];

function formatDate(dateText) {
  if (!dateText) return 'No date listed';
  const date = new Date(dateText);
  if (Number.isNaN(date.getTime())) return dateText;
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function buildCard(item) {
  return `
    <article class="card">
      <div class="tag-row">
        <span class="tag">${item.type || 'Opportunity'}</span>
        <span class="tag good">${item.fit || 'Unrated'}</span>
      </div>
      <h2>${item.title}</h2>
      <div class="meta">
        <div>
          <strong>Best for</strong>
          ${item.bestFor || 'General startup support'}
        </div>
        <div>
          <strong>Stage</strong>
          ${item.stage || 'Any stage'}
        </div>
        <div>
          <strong>Value</strong>
          ${item.value || 'Varies'}
        </div>
        <div>
          <strong>Next deadline</strong>
          ${formatDate(item.nextDeadline)}
        </div>
      </div>
      <p>${item.summary || 'No summary available.'}</p>
      <p><strong>Eligibility:</strong> ${item.eligibility || 'Not specified'}</p>
      <a href="${item.url || '#'}" target="_blank" rel="noreferrer">Visit opportunity →</a>
    </article>
  `;
}

function getFilteredData() {
  const typeValue = elements.typeFilter.value;
  const fitValue = elements.fitFilter.value;
  const stageValue = elements.stageFilter.value;
  const query = elements.searchInput.value.trim().toLowerCase();

  return data.filter((item) => {
    const matchesType = typeValue === 'all' || item.type === typeValue;
    const matchesFit = fitValue === 'all' || item.fit === fitValue;
    const matchesStage = stageValue === 'all' || item.stage === stageValue;
    const matchesSearch = !query || (item.title || '').toLowerCase().includes(query);
    return matchesType && matchesFit && matchesStage && matchesSearch;
  });
}

function renderFilters() {
  const types = [...new Set(data.map((item) => item.type).filter(Boolean))].sort();
  elements.typeFilter.innerHTML = '<option value="all">All</option>' + types.map((type) => `<option value="${type}">${type}</option>`).join('');
}

function renderCards() {
  const filtered = getFilteredData();
  if (!filtered.length) {
    elements.cards.innerHTML = '<div class="empty">No opportunities match your current filters.</div>';
    return;
  }

  elements.cards.innerHTML = filtered.map(buildCard).join('');
}

function updateStatus(message) {
  elements.status.textContent = message;
}

async function loadData() {
  updateStatus('Loading opportunities...');

  try {
    let records = sampleData;

    if (!CONFIG.useSampleData && CONFIG.baseId && CONFIG.airtableApiKey !== 'demo-key') {
      const response = await fetch(`https://api.airtable.com/v0/${CONFIG.baseId}/${encodeURIComponent(CONFIG.tableName)}?view=${encodeURIComponent(CONFIG.view)}`, {
        headers: {
          Authorization: `Bearer ${CONFIG.airtableApiKey}`
        }
      });

      if (!response.ok) {
        throw new Error('Airtable API request failed');
      }

      const payload = await response.json();
      records = (payload.records || []).map((record) => ({
        title: record.fields['Program Title'] || record.fields.title || 'Untitled opportunity',
        type: record.fields.Type || 'Opportunity',
        fit: record.fields['Student Startup Fit'] || 'Strong',
        stage: record.fields['Founder Stage'] || 'Any stage',
        bestFor: record.fields['Best For'] || 'General startup support',
        value: record.fields['Funding Amount/Prize Amount'] || record.fields['Expected Monetary Value'] || 'Varies',
        nextDeadline: record.fields['Next Deadline'] || record.fields.Deadline || '',
        eligibility: record.fields['Eligibility Label'] || record.fields['Catered Toward'] || 'Not specified',
        summary: record.fields['Program Description'] || 'No summary available.',
        url: record.fields['Website link'] || record.fields['Visit Website'] || '#'
      }));
    }

    data = records;
    renderFilters();
    renderCards();
    updateStatus(`Showing ${records.length} opportunities from the source-of-truth feed.`);
  } catch (error) {
    console.error(error);
    data = sampleData;
    renderFilters();
    renderCards();
    updateStatus('Airtable could not be loaded, so the demo is showing sample data for preview.');
  }
}

let data = [];

[ elements.typeFilter, elements.fitFilter, elements.stageFilter ].forEach((control) => {
  control.addEventListener('change', renderCards);
});

elements.searchInput.addEventListener('input', renderCards);

loadData();
