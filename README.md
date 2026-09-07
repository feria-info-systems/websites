# websites

Marketing/public websites for the group, migrated off Odoo Website and hosted on **Netlify**.
Each site under `sites/<name>/` is an independent, pre-built **static** site and maps to its
own Netlify site (via that site's *Base directory* = `sites/<name>`).

## Layout

```
sites/
  prohomehealthcare/
    netlify.toml        # publish = "public"
    public/             # the deployable static site (HTML + assets + _redirects)
    .build/             # source of truth to regenerate public/ from the old Odoo pages
      build.sh          # capture -> localize -> emit public/
      serve.ps1         # local static preview server (PowerShell HttpListener)
      pages/            # raw HTML captured from the live Odoo site
      src-assets/       # downloaded images / fonts / shapes + the Odoo CSS bundle
      manifest.tsv, idmap.tsv
```

## Preview a site locally

```bash
# from sites/<name>/.build  (Windows PowerShell)
powershell -ExecutionPolicy Bypass -File serve.ps1 -Port 8791 -Root ../public
# then open http://localhost:8791/
```

## Migration status

| Site | Status | Notes |
|------|--------|-------|
| prohomehealthcare.com | Static mirror built & verified; **not yet cut over** | Forms POST to the ERP; `portal.` + Sign in stay on Odoo. DNS still points at Odoo. |

### Dynamic features that do NOT run on the static host
- **Contact form** (`/forms`) and **job applications** (`/jobs/apply/...`) → POST to the
  `findr-erp` ERP endpoint (see each site's forms wiring).
- **Sign in / customer portal** → `https://portal.prohomehealthcare.com/` (remains on Odoo).
- Site search is disabled (no static backend).

## Cutover checklist (per site, gated — do not automate)
1. Create the Netlify site, Base directory = `sites/<name>`, and deploy.
2. Verify the Netlify preview/prod URL renders correctly.
3. Confirm the ERP form endpoint is live and receiving submissions.
4. Repoint DNS (A/CNAME) from Odoo to Netlify; keep `portal.<domain>` on Odoo.
5. Add the custom domain + TLS in Netlify; verify; then decommission the Odoo website.
