# UC San Diego Student Founder Funding Opportunities

Static GitHub Pages site listing curated grants, pitch competitions, accelerators and fellowships for
UC San Diego student founders. Design follows ucsd.edu branding (navy / gold, condensed uppercase headings)
and the card/tab layout of studentfounderhq.com.

Live: https://eirik-wg.github.io/ucsd-opportunities/

## How the data flows

```
20261026_Funding Opportunities_Airtable import.xlsx ──import once──► Airtable base, table "Opportunities" (source of truth)
                                                                      │            │
                                   Slack deadline notifier (weekly) ◄─┘            │ view "Website"
                                                                                   ▼
                                       GitHub Action (daily) ── scripts/sync-airtable.mjs
                                                                                   │
                                                                                   └──► data/opportunities.dat ──► website
```

- The website and the Slack notifier read the **same** Airtable `Opportunities` table (schema of the
  20261026 import workbook: `Program`, `Tier`, `Type`, `Status`, `Next Deadline`, `Deadline Type`, `Affiliation`,
  `Stage`, `Sectors`, `Equity`, ...). The field mapping is in `scripts/opportunity-map.mjs`.
- `data/opportunities.dat` contains every row of the `Website` view, sorted by tier then deadline.
  Rows with `Status` Site down / Discontinued / Inactive are shown as closed (listed under "Recently closed");
  `Unverified` rows get an "Unverified" badge.
- The file is not plain JSON: it is `gzip → XOR(PAYLOAD_KEY) → base64` with a `UCSDF1.` prefix. `app.js`
  reverses this in `unprotectPayload()`. The key lives in `app.js` and `scripts/opportunity-map.mjs`
  (and the legacy `export_site_data.ps1`) and must match.
- The site computes status client-side from `Next Deadline` + `Deadline Type`:
  - `Rolling` → **Open · rolling**
  - no deadline and not rolling (`Not assessed` / `Unknown`) → **Check dates on website** (listed under Open now)
  - `Fixed` / `Window` and date in the future → **Open** / **Closes in N days**
  - `Recurring-estimated` and date in the future → **Upcoming / expected**
  - date in the past → **Closed** (shown in "Recently closed" for 120 days)

### Refreshing the data

Normally nothing is needed: edit Airtable and the daily sync updates the site (or run the
**Sync opportunities from Airtable** workflow manually). To build the data from a spreadsheet instead, save the
`Opportunities` sheet of the import workbook (or Airtable → *Download CSV*) as UTF-8 CSV, then:

```powershell
node scripts/build-from-csv.mjs "C:\path\to\Opportunities.csv"
git add data/opportunities.dat
git commit -m "Refresh opportunities data"
git push
```

`export_site_data.ps1` and `data/airtable_import.csv` belong to the previous (20260929) schema and are no longer used.

## Portal features

- **Tiers** – Founders tick which priority tiers to include (default Tier 1 + 2). A “What do tiers mean?” toggle
  in the toolbar explains the four tiers; tier counts are shown next to each checkbox.
- **Page size** – Default view is the 20 nearest deadlines (Open now · Tier 1–2 · sorted by deadline).
  Users can switch to 50 / 100 / all, or click “Show more”.
- **Shareable state** – Every filter/sort/tier/page-size choice is mirrored into the URL query string
  (`?status=&q=&type=&model=&stage=&geo=&sort=&ucsd=1&tiers=1,2,3&n=50`), so “Copy link” shares the exact view.
- **Saved views** – “Save this view” stores the current query string under a name in `localStorage`
  (`ucsdFunding.savedViews.v1`, max 20). Saved views render as chips above the results.
- **Alerts** – “Alerts for this view” opens a dialog (email + weekly digest / deadline reminders / new matches).
  The hero form subscribes to the default view. Both call `submitSubscription()`:
  - If `CONFIG.subscribeEndpoint` is set, it POSTs JSON
    `{ email, kinds[], view, viewUrl, summary, source, submittedAt }` (CORS-enabled endpoint such as an
    Airtable form automation, Formspree, Make/Zapier webhook or Power Automate HTTP trigger). Store `view` as-is;
    the digest job can re-apply it with the same rules as `app.js` (`parseState` / `matchesFilters`).
  - Otherwise it falls back to a pre-filled `mailto:` to `CONFIG.subscribeFallbackEmail`.

## Scraping deterrents (and their limits)

This is a static GitHub Pages site, so nothing here is a hard security boundary. The measures in place raise
the cost of casual/automated harvesting:

- Data ships as an obfuscated payload (`data/opportunities.dat`), not plain JSON; no public JSON/CSV endpoint.
- `robots.txt` disallows `/data/` for all crawlers and blocks common AI training bots.
- Only the current page of results is rendered in the DOM (default 20); outbound links are `rel="nofollow"`.
- `app.js` refuses to load data when `navigator.webdriver` is true (Selenium / Puppeteer / Playwright defaults).
- A usage notice on the page and in the footer states that automated harvesting is not permitted.

A determined scraper can still read `app.js` and reverse the payload. **Note that the repository itself is
public**, so `data/opportunities.dat` (and `data/airtable_import.csv`) are visible to anyone who clones it —
if that matters, make the repo private (GitHub Pages from a private repo needs a paid plan) or move the data
behind a small API (e.g. Cloudflare Worker + Turnstile) that serves paged results.

## Airtable as source of truth

### 1. Create the base

1. Use the base created from `20261026_Funding Opportunities_Airtable import.xlsx` (see `AIRTABLE_SETUP.md` next to that
   workbook; field types are listed in its `Field Types` sheet). The website reads its **Opportunities** table.
2. In that table add a grid view named **Website**: no filter (every status is shown; inactive ones appear as closed),
   sorted by `Tier` then `Next Deadline`. To hide rows from the site later, add a filter to this view only — the Slack
   notifier is unaffected.

### 2. Connect the sync

1. Create a personal access token at https://airtable.com/create/tokens with scope `data.records:read` and access to the base.
2. In the GitHub repo: Settings → Secrets and variables → Actions → add secrets **`AIRTABLE_TOKEN`** and **`AIRTABLE_BASE_ID`** (`app…`). Optional variables `AIRTABLE_TABLE`, `AIRTABLE_VIEW` override the defaults `Opportunities` / `Website`.
3. Run **Actions → Sync opportunities from Airtable → Run workflow** once. It runs `scripts/sync-airtable.mjs`, commits `data/opportunities.dat` if it changed, and redeploys Pages. It then repeats daily (06:15 UTC).

From then on, editing a record in Airtable updates the website on the next sync. If the secrets point at a base
without a `Program` field (old schema), the sync fails and leaves the published data unchanged.

### Field names expected by the sync

`Program`, `Tier`, `Type`, `Status`, `Description`, `Funding / Benefit`, `Eligibility` (items separated by `;` or new
lines), `Website`, `Notes`, `Affiliation`, `Stage` (multi), `Sectors` (multi), `Equity`, `Student Friendly`,
`Next Deadline`, `Deadline Type` (Fixed | Window | Recurring-estimated | Rolling | Unknown | Not assessed),
`Deadline Label`, `Deadline / Cadence (text)`, `Recurrence`, `Window Opens`, `Verified On`.

`app.js` can also read Airtable directly in the browser (`CONFIG.airtable`) for local testing, but do **not** commit a token there — the scheduled sync is the production path.

## Local preview

```powershell
python -m http.server 8765
# open http://127.0.0.1:8765/
```

## Deployment

Deployed via GitHub Actions (`.github/workflows/pages.yml`) on every push to `main`.
Settings → Pages → Source must be **GitHub Actions**.
