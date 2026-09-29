# UCSD Startup Opportunities Demo

This is a GitHub Pages-ready demo for a student startup opportunity directory.

## Quick start

1. Push this folder to a GitHub repository.
2. Open the repo in GitHub.
3. Go to Settings > Pages.
4. Select Deploy from a branch.
5. Choose the main branch and the root folder.
6. Save.

Your site will be published at:

https://your-username.github.io/your-repo-name/

## Airtable source-of-truth pattern

The page is designed to read from Airtable when configured. In a real setup:

- Airtable holds the master records
- the website reads the filtered view
- the newsletter can read the same Airtable view or a CSV export

Edit `app.js` and set the Airtable configuration when you are ready:

```js
const CONFIG = {
  airtableApiKey: 'your_api_key_here',
  baseId: 'appXXXXXXXXXXXX',
  tableName: 'Opportunities',
  view: 'Top Opportunities',
  useSampleData: false
};
```

## Notes

- This is a lightweight static website, so no build step is required.
- For a real production system, do not expose a secret Airtable API key in browser JavaScript.
- For the demo, the sample data keeps the site working without credentials.
