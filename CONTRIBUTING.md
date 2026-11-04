# Contributing to OpenNoiseNet

OpenNoiseNet is not in a blank planning phase. The repository already contains substantial software, and the current priority is to stabilize that existing codebase before expanding scope.

Read [docs/current-status.md](docs/current-status.md) before starting work. It defines the supported MVP surface and the intentionally unreleased areas for this milestone.

The commercialization direction is documented in [docs/opennoisenet-pro-roadmap.md](docs/opennoisenet-pro-roadmap.md). That roadmap does **not** change current repo truth, but it does define what the stabilization phase is preparing for: a Hybrid Public + Pro platform with a tenant-bound Pro layer for housing and property workflows.

The repo now also contains initial pre-release Pro slices. They still need hardening and do **not** mean the stabilization gate is closed.

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
- `docs/execution-backlog.md` tells you the ordered remaining work from gate closure to commercial readiness.
- `docs/opennoisenet-pro-roadmap.md` tells you the ordered next phases after stabilization.

Contributors should treat **Phase 0: Stabilization Exit and Commercial Baseline** as the active gate. Work on existing Pro slices is allowed and expected, but those slices must be treated as **pre-release** until the gate is explicitly closed.

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

Create branches from `develop` and use descriptive names such as
`docs/contribution-guidelines`, `backend/device-heartbeat-tests`, or
`mobile/backend-sync-cleanup`. Keep one concern per pull request so review can
focus on the affected surface.

## Code Style By Surface

### Backend Python

- Use `uv` for dependency and command execution.
- Prefer Black-compatible formatting and keep Ruff issues addressed for changed files.
- Add or update pytest coverage for backend behavior changes.
- Keep migrations and model changes tied to the current MVP surface.

### Frontend And Landing TypeScript

- Keep TypeScript strict enough for `npm run type-check`.
- Prefer small typed components over broad placeholder screens.
- Keep dashboard routes aligned to `/auth`, `/devices`, `/events`, and `/map`.
- For landing changes, preserve the current public narrative and avoid promising unreleased features.

### Mobile Dart

- Follow the Flutter lint rules in `mobile/analysis_options.yaml`.
- Keep backend-facing flows real; avoid adding placeholder-only paths to active app screens.
- Run `flutter analyze` and `flutter test` for mobile changes.

## Pull Request Checklist

Before opening a pull request:

- Link the issue or planning document that defines the scope.
- State whether the change touches backend, dashboard, landing, mobile, docs, or infrastructure.
- List the checks you ran and any checks you could not run.
- Update relevant documentation when user-visible behavior, setup, or workflow changes.
- Note any follow-up work that remains outside the current PR.

Reviewers should check that the PR stays within the stabilization gate, uses the
right validation commands, and does not describe unreleased work as shipped.

## Issue Reporting Guidelines

When opening an issue, include:

- Which surface is affected: backend, dashboard, landing, mobile, docs, infrastructure, or full stack.
- The expected behavior and the actual behavior.
- Steps to reproduce, including commands, URLs, or screen flow where relevant.
- Environment details such as OS, Python/Node/Flutter versions, and Docker usage.
- Logs, screenshots, or API responses when they are safe to share.

Do not include secrets, private addresses, production credentials, or personal data in public issues.

## Verification Expectations

Backend changes should keep imports, auth, devices, events, and map behavior working.

Dashboard changes should keep `npm run type-check` and `npm run build` green.

Landing changes should keep `npm run build` working without network access for fonts.

Mobile changes should improve the real backend path and avoid introducing more placeholder behavior into the active app flow.
