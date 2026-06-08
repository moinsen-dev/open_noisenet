## Summary

<!-- What changed, and why? Link the issue or planning document. -->

## Surface

- [ ] Backend
- [ ] Dashboard frontend
- [ ] Landing site
- [ ] Mobile app
- [ ] Documentation
- [ ] Infrastructure / deployment

## Scope Check

- [ ] Change stays inside the current stabilization gate or explains why it does not.
- [ ] User-visible docs or setup steps were updated where relevant.
- [ ] No unreleased placeholder behavior is described as shipped.

## Validation

<!-- List commands run and results. Mark any not run with a reason. -->

- [ ] Backend: `cd backend && uv run pytest -q`
- [ ] Dashboard: `cd frontend && npm run type-check && npm run build`
- [ ] Landing: `cd landing && npm run build`
- [ ] Mobile: `cd mobile && flutter analyze && flutter test`

## Review Notes

<!-- Call out risks, follow-up work, migrations, or manual verification. -->
