# UCSD Startup Opportunities Demo

This demo shows how to keep Airtable as the source of truth while serving a public website view with the same data.

## How it works

- Airtable is the source of truth for all opportunity records.
- The website reads from Airtable through the Airtable API.
- The newsletter or other downstream surfaces can read the same Airtable view or a filtered export.
- The site falls back to a sample dataset so it still works in a demo without Airtable credentials.

## To connect to a real Airtable base

Edit `app.js` and set the Airtable credentials and table/view:

```js
const CONFIG = {
  airtableApiKey: 'your_api_key_here',
  baseId: 'appXXXXXXXXXXXX',
  tableName: 'Opportunities',
  view: 'Top Opportunities',
  useSampleData: false
};
```

Then publish the folder with GitHub Pages.

## Local preview

From this folder, run:

```bash
python -m http.server 8000
```

Then open `http://localhost:8000`.

## Why this pattern is useful

- One source of truth
- No duplicate opportunity entries across systems
- Easy website browsing
- Newsletter and website can use the same filter logic
- Demo-ready and easy to extend
