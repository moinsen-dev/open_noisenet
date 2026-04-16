# OpenNoiseNet Dashboard

This package contains the React dashboard used during the current software stabilization milestone.

The dashboard is intentionally scoped to the supported MVP backend surface:

- `/api/v1/auth`
- `/api/v1/devices`
- `/api/v1/events`
- `/api/v1/map`

Unsupported in this milestone:

- admin tooling
- snippet management
- AI workflows

## Local Development

```bash
npm ci
npm run type-check
npm run dev
```

Default local URL:

- Dashboard: `http://localhost:3100`
- Backend API base: `http://localhost:8100/api/v1`

You can override the API base URL with:

```env
VITE_API_URL=http://localhost:8100/api/v1
```

## Verification

```bash
npm run type-check
npm run build
```
