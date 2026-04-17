# Contributing to OpenNoiseNet

OpenNoiseNet is not in a blank planning phase. The repository already contains substantial software, and the current priority is to stabilize that existing codebase before expanding scope.

Read [docs/current-status.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/current-status.md) before starting work. It defines the supported MVP surface and the intentionally unreleased areas for this milestone.

The commercialization direction is documented in [docs/opennoisenet-pro-roadmap.md](/Users/udi/work/moinsen/ideas/open_noisenet/docs/opennoisenet-pro-roadmap.md). That roadmap does **not** change current repo truth, but it does define what the stabilization phase is preparing for: a Hybrid Public + Pro platform with a tenant-bound Pro layer for housing and property workflows.

## What We Need Right Now

The immediate audience for this phase is maintainers and contributors who can help make the current software stack reliable:

- backend API stabilization
- dashboard and landing consistency
- mobile backend integration cleanup
- documentation and developer workflow fixes
- verification across local and Docker-based setups

Not part of the current milestone:

- firmware implementation
- hardware BOM or enclosure work
- new AI features
- admin tooling
- notification systems

## How To Read The Roadmap

- `docs/current-status.md` tells you what exists and is supported today.
- `ImplementationPlan.md` tells you what the repository is actively executing now.
- `docs/opennoisenet-pro-roadmap.md` tells you the ordered next phases after stabilization.

Contributors should treat **Phase 0: Stabilization Exit and Commercial Baseline** as the active gate. Do not implement Pro-layer behavior as if it were already shipped unless the current implementation phase has explicitly moved there.

## Working Rules

- Prefer `uv` for Python dependency management and command execution.
- Treat `backend/pyproject.toml` and `backend/uv.lock` as the Python source of truth.
- Do not present TODO or placeholder endpoints as shipped features.
- Keep the React dashboard aligned to `/auth`, `/devices`, `/events`, and `/map`.
- Keep the landing site narrative consistent with the actual project state.
- If you touch docs, update the canonical status document or link back to it.

## Local Setup

### Backend

```bash
cd backend
uv sync --extra dev
uv run pytest -q
uv run uvicorn app.main:app --reload --port 8100
```

### Dashboard

```bash
cd frontend
npm ci
npm run type-check
npm run dev
```

### Landing

```bash
cd landing
npm install
npm run build
npm run dev
```

### Mobile

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

### Full Stack

```bash
docker compose up --build
```

## Contribution Flow

1. Start from an issue or a clearly scoped change.
2. Verify whether the work is inside the current MVP surface.
3. Make the smallest coherent change that improves stability or consistency.
4. Run the relevant checks for the surface you changed.
5. Update docs when the visible behavior or local workflow changes.

## Verification Expectations

Backend changes should keep imports, auth, devices, events, and map behavior working.

Dashboard changes should keep `npm run type-check` and `npm run build` green.

Landing changes should keep `npm run build` working without network access for fonts.

Mobile changes should improve the real backend path and avoid introducing more placeholder behavior into the active app flow.
