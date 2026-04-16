# Mobile Analyzer Baseline

The mobile package still contains a sizable amount of legacy and experimental code outside the current stabilization focus.

For this milestone, analyzer diagnostics in the following categories are intentionally ignored so that `flutter analyze` can act as a usable regression gate again:

- unused imports, locals, fields, and elements
- strict inference noise in older service and UI code
- deprecated member usage in non-critical paths
- style-only cleanup warnings

This does not mean those issues are resolved. It means they are accepted debt for the current milestone while work is focused on:

- backend auth
- device registration
- event submission and sync
- MVP monitoring flow integrity
