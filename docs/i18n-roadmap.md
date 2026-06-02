# OpenNoiseNet — Internationalization Roadmap

**Status:** Planning · **Last updated:** 2026-06-02

This document defines the technical strategy and phased rollout for multi-language support across all OpenNoiseNet surfaces: landing page, dashboard, mobile app, API, and database. It aligns with the German Rollout and EU Expansion plans.

---

## 1. Current State (Audit)

| Surface | Framework | i18n Status |
|---|---|---|
| **Landing** (`landing/`) | Next.js 15 (static export) | Hardcoded English. `locale: 'en_US'` in layout metadata. No translation framework. |
| **Dashboard** (`frontend/`) | React 18 + Vite + MUI | English-only. Hardcoded `toLocaleTimeString('de-DE', …)` in DeviceTimelinePage. No i18n library. |
| **Mobile** (`mobile/`) | Flutter 3.x | `intl` package is a transitive dependency. `localizationsDelegates` + `supportedLocales` commented out in `main.dart`. No `.arb` files exist. |
| **Backend** (`backend/`) | FastAPI + SQLAlchemy | No i18n. `classification_label` is `String(100)` — single-language. No `Accept-Language` header handling. |
| **DB** | PostgreSQL | `events.classification_label` is a single string. No multi-language label support. |

---

## 2. Language Phases

### Phase 1 — Now (English + German)

| Language | Scope | Status |
|---|---|---|
| **English (EN)** | Default. All UIs, API messages, error strings, docs, device setup guide, BOM. | Already default. |
| **German (DE)** | Landing page, mobile app UI, public map labels, device setup guide, calibration manual, error messages. | **Target: Q3 2026** (before German rollout). |

### Phase 2 — Q1 2027 (French + Dutch)

| Language | Scope |
|---|---|
| **French (FR)** | Landing, mobile app, dashboard, setup guide. |
| **Dutch (NL)** | Landing, mobile app, setup guide. |

### Phase 3 — Q3 2027 (Spanish, Italian, Polish)

| Language | Scope |
|---|---|
| **Spanish (ES)** | Landing, mobile app, setup guide. |
| **Italian (IT)** | Landing, mobile app, setup guide. Community-driven. |
| **Polish (PL)** | Landing, mobile app, setup guide. Community-driven. |

---

## 3. Technical Implementation

### 3.1 Landing Page — `next-intl`

**Files affected**: `landing/src/app/`, `landing/src/components/`

**Setup**:
- Install `next-intl` (already the standard for Next.js App Router i18n)
- Create `landing/messages/{locale}.json` per language
- Configure `next.config.ts` with `createNextIntlPlugin`
- Add `[locale]` route segment: `landing/src/app/[locale]/`
- Middleware for locale detection (`Accept-Language` header → redirect)

**Message structure**:
```json
// landing/messages/de.json
{
  "hero": {
    "title": "Offene Lärmüberwachung für Ihre Stadt",
    "subtitle": "Messen. Verstehen. Handeln.",
    "cta": "Jetzt mitmachen"
  },
  "features": { … },
  "footer": { … }
}
```

**Static export consideration**: `next-intl` supports `output: 'export'` with `localePrefix: 'as-needed'`. No server runtime required — pages are pre-rendered per locale.

### 3.2 Dashboard — `react-i18next`

**Files affected**: `frontend/src/`, `frontend/src/components/`, `frontend/src/pages/`

**Setup**:
- Install `i18next` + `react-i18next` + `i18next-browser-languagedetector`
- Create `frontend/src/i18n/` with `index.ts` (init), `locales/{lang}/translation.json`
- Wrap `<App>` with `I18nextProvider`
- Replace all hardcoded strings with `t('key')` calls
- Replace `toLocaleTimeString('de-DE', …)` with `intl`-based formatting from `i18next`

**Message structure**:
```json
// frontend/src/i18n/locales/de/translation.json
{
  "nav": {
    "dashboard": "Übersicht",
    "map": "Lärmkarte",
    "episodes": "Ereignisse",
    "cases": "Fälle"
  },
  "episode": {
    "inbox": "Ereignis-Eingang",
    "severity": "Schweregrad",
    "status": {
      "open": "Offen",
      "in_review": "In Prüfung",
      "closed": "Abgeschlossen"
    }
  },
  "map": {
    "heatmap": "Lärm-Heatmap",
    "legend": "Legende"
  }
}
```

### 3.3 Mobile App — `flutter_localizations` + `.arb`

**Files affected**: `mobile/lib/`, `mobile/lib/l10n/`

**Setup**:
- Uncomment `localizationsDelegates` + `supportedLocales` in `mobile/lib/main.dart`
- Add `flutter_localizations` to `pubspec.yaml` dependencies
- Create `mobile/lib/l10n/app_en.arb`, `app_de.arb`, etc.
- Run `flutter gen-l10n` to generate Dart localizations
- Replace all hardcoded strings with `AppLocalizations.of(context)!.key`

**`.arb` structure**:
```json
// mobile/lib/l10n/app_de.arb
{
  "@@locale": "de",
  "appTitle": "OpenNoiseNet",
  "deviceSetup": "Gerät einrichten",
  "startMonitoring": "Überwachung starten",
  "eventCount": "{count, plural, =1{1 Ereignis} other{{count} Ereignisse}}",
  "@eventCount": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

### 3.4 Backend API — `Accept-Language` + Translation Files

**Files affected**: `backend/app/`, `backend/app/core/`

**Setup**:
- Create `backend/app/core/i18n.py` with locale detection middleware
- Translation files: `backend/app/translations/{lang}.json`
- API responses: Error messages, success messages, and classification labels returned in requested locale
- All endpoints respect `Accept-Language` header; fallback to `en`

**API contract**:
```
GET /api/v1/events?locale=de
Accept-Language: de

Response:
{
  "events": [
    {
      "classification_label": "Baustelle",   // ← localized
      "classification_label_en": "Construction"
    }
  ]
}
```

**Implementation approach**:
```python
# backend/app/core/i18n.py
from fastapi import Request

LOCALES = {"en", "de", "fr", "nl", "es", "it", "pl"}
DEFAULT_LOCALE = "en"

def get_locale(request: Request) -> str:
    header = request.headers.get("Accept-Language", DEFAULT_LOCALE)
    # Parse quality-weighted header, return best match
    …
```

### 3.5 Database — Multi-Language Labels

**Migration required**: Add `label_i18n` JSONB column to `events` table.

```sql
ALTER TABLE events ADD COLUMN label_i18n JSONB DEFAULT '{}';

-- Migration: backfill existing labels
UPDATE events SET label_i18n = jsonb_build_object('en', classification_label)
WHERE classification_label IS NOT NULL;
```

**Schema change**:

| Column | Type | Purpose |
|---|---|---|
| `classification_label` | `String(100)` | **Deprecated**. Kept for backward compat during rollout. Remove after all clients use `label_i18n`. |
| `label_i18n` | `JSONB` | `{"en": "Construction", "de": "Baustelle", "fr": "Chantier", …}`. Source of truth post-migration. |

**API reads**: Return `classification_label` in requested locale (from `label_i18n`). Fallback to `en`, then to raw `classification_label`.

**Classifier writes**: When the episode classifier assigns a label, write the English key. Community translators backfill other languages via Weblate → DB update.

**Episode model**: Same pattern — `episodes.label_i18n` JSONB column. Episodes carry a primary label applied by the classification pipeline.

---

## 4. Translation Workflow

### 4.1 Source of Truth

- **English is the source locale**. All new strings are written in English first.
- Translation keys use **dot-notation namespacing** (e.g. `episode.status.open`) — no raw English strings as keys.
- Key naming convention: `<domain>.<component>.<field>` or `<domain>.<action>`.

### 4.2 Tooling

| Tool | Role | Rationale |
|---|---|---|
| **Weblate** (self-hosted or SaaS) | Community translation platform | Open-source. Tight Git integration (PRs with translated `.json`/`.arb` files). Translation memory across releases. Supports all our file formats (JSON, ARB, gettext `.po`). |
| **Crowdin** (alternative) | Community translation platform | Larger free tier for open-source. More polished UI. Slightly less FOSS-aligned. |
| **`i18n-ally`** (VS Code extension) | Developer workflow | Inline translation preview, key navigation, missing-key detection. |

### 4.3 Translation Pipeline

```
1. Developer adds English string → PR with only `en.json`/`en.arb` changes
2. CI detects new/missing keys → opens Weblate component update
3. Community translators pick up new strings in Weblate
4. Weblate commits translations back to repo (or opens PR)
5. CI validates: no missing keys, no broken ICU/plural syntax
6. Merge → deploy with new translations
```

### 4.4 Community Translation Guidelines

- **Style guide** (per language): Tone (formal/informal — German uses "Sie", French uses "vous"), capitalization rules, date/time formats.
- **Glossary**: Domain terms that must be translated consistently (e.g. "episode" → "Ereignis" DE, "épisode" FR; "SPL" → untranslated acronym in all languages).
- **Review process**: 2 approvals required per string. Language moderators assigned per locale.
- **Recognition**: Translator names in `CONTRIBUTORS.md`, "Translation Champion" badge on GitHub profile.

### 4.5 Quality Assurance

- **ICU MessageFormat validation** in CI: Plural rules, selectors, and placeholders must parse correctly for each locale.
- **Screenshot context**: Weblate supports screenshot annotations — provide per-key screenshots showing where the string appears in the UI.
- **Visual regression**: After translation updates, screenshot-diff the landing page, dashboard, and mobile app in each locale.

---

## 5. Date, Time, Number, and Unit Formatting

### 5.1 Universal Rules

| Data Type | Formatting Rule | Example (DE) |
|---|---|---|
| **Dates** | `Intl.DateTimeFormat` / `DateFormatter` with locale | `12. März 2027` |
| **Times** | Locale-aware, 24h for DE/NL/FR/ES/IT/PL | `14:30` (not `2:30 PM`) |
| **Numbers** | `Intl.NumberFormat` with locale | `1.234,56` (DE), `1,234.56` (EN) |
| **dB values** | Always `##.# dBA` — number format localized, unit unchanged | `66,5 dBA` (DE), `66.5 dBA` (EN) |
| **Percentages** | `Intl.NumberFormat` with `style: 'percent'` | `42 %` (DE, with space), `42%` (EN) |
| **Durations** | `Intl.DurationFormat` (Stage 3 TC39) or manual | `3 Std. 15 Min.` (DE) |

### 5.2 Implementation

- **Landing + Dashboard**: Use `Intl` API (built into browsers). No extra library.
- **Mobile**: `flutter_localizations` provides `NumberFormat`, `DateFormat` per locale.
- **Backend**: Python `babel` library for locale-aware formatting in export/report generation.

---

## 6. Content Localization (Beyond UI Strings)

| Content Type | Localization Strategy |
|---|---|
| **Documentation** (`docs/`) | Write in English. Translate README + setup guide to DE, FR, ES. Rest stays EN-only. |
| **Blog / data stories** | Write in English + German (author). Community translations for other languages. |
| **Device setup guide** | Full translation for DE, FR, NL, ES. Illustrated — minimal text, maximum universality. |
| **Calibration guide** | Full translation for all supported languages. Safety-critical — accuracy matters. |
| **BOM / hardware docs** | English-only with local supplier links per country (see EU Expansion Plan §5.2). |
| **Legal / privacy** | German + English (GDPR). Other EU languages as needed for market entry. |

---

## 7. Backward Compatibility & Migration

### 7.1 Existing Data

- `classification_label` column retains its current value. During migration, `label_i18n` is populated with `{"en": <current label>}`.
- API continues to return `classification_label` in responses for 2 release cycles. New `classification_label_localized` field added alongside it. Clients migrate at their pace.

### 7.2 Client Migration

| Client | Migration |
|---|---|
| **Mobile app** | v1.5: reads `classification_label_localized`, falls back to `classification_label`. v2.0: only reads new field. |
| **Dashboard** | Immediate — same deploy. Single codebase. |
| **Landing** | N/A — landing page has no API-dynamic classification labels. |
| **Firmware** | Unaffected — firmware sends numeric data only, no classification labels. |

---

## 8. Timeline

| Phase | Quarter | Deliverables |
|---|---|---|
| **Phase 1** | Q3 2026 | `next-intl` on landing (EN+DE). `react-i18next` on dashboard (EN+DE). `flutter_localizations` on mobile (EN+DE). Backend `Accept-Language` + translation files. DB migration: `label_i18n` JSONB column. Weblate instance configured. |
| **Phase 2** | Q1 2027 | FR + NL translations added to all surfaces. Community translation pipeline live. First community translators onboarded. French + Dutch city launch playbooks translated. |
| **Phase 3** | Q3 2027 | ES + IT + PL translations added. 7-language coverage complete. Translation memory populated across 2+ release cycles. Glossaries stable. |

---

## 9. Risks & Mitigation

| Risk | Impact | Mitigation |
|---|---|---|
| **Translation quality varies (community)** | Poor UX in some languages | Review gate: 2 approvals per string. Language moderators. Screenshot context in Weblate. |
| **String explosion across 3 codebases** | Maintenance burden, inconsistent translations | Shared translation memory across projects. Consistent key naming. Reuse common strings (e.g. "Save", "Cancel"). |
| **ICU syntax errors in translations** | Broken UI at runtime | CI validation: every `.json`/`.arb` file checked for valid ICU syntax. Pre-commit hook. |
| **RTL languages needed later (Arabic, Hebrew)** | Layout breakage | Design system must use logical properties (`start`/`end` not `left`/`right`). Flutter and MUI support RTL natively. Audited during Phase 3. |
| **DB migration rollback** | `label_i18n` column causes issues | `classification_label` kept as fallback for 2 releases. Migration is additive (new column), not destructive. |
