# OpenNoiseNet Landing

This package contains the public-facing Next.js landing site for OpenNoiseNet.

Its job in the current milestone is to present the project truthfully and build reliably in constrained environments.

## Local Development

```bash
npm install
npm run build
npm run dev
```

Default local URL:

- Landing site: `http://localhost:3000`

## Current Expectations

- the build must not depend on fetching Google Fonts at build time
- the copy must stay aligned with the main repository status
- the landing site should not present unreleased product surfaces as current MVP features

## Public story and hosting (November 2026)

The German home page and `/story/` explain the founder's motivation, everyday noise burden, development limits and ways to contribute. Research links support the health context; the timeline is illustrative. No public app download or certified measurement accuracy is promised.

The custom domain serves the static export at `/`. For GitHub Pages only, build with `NEXT_PUBLIC_BASE_PATH=/open_noisenet`; the workflow sets this explicitly. `getAssetPath` uses the same setting. The Docker image serves the export via nginx on port 3000. No Next.js application server is required.

Checks: `npm ci`, `npm run lint`, `npm run type-check`, `npm test`, `npm run build`. Production dependencies: `npm audit --omit=dev`. Use `python3 -m http.server 8768 --bind 127.0.0.1 --directory out` to check the actual export, including assets and direct links.

Release evidence and the GitHub audit are in [the project review](../docs/website-story-and-github-review-2026-11-04.md).
