# OpenNoiseNet — EU Expansion Plan

**Status:** Planning · **Last updated:** 2026-06-02
**Phase:** 3 (after German rollout proven at 1,000+ devices, 50 cities)
**Timeline:** Q3 2027 – Q4 2028

This document operationalizes the EU expansion phase from the Business Strategy (§5.3). It assumes the German rollout has validated the multi-city playbook, the self-serve Pro beta is live, and at least one EU-level grant application is in progress by mid-2027.

---

## 1. Target Cities (ordered by deployment feasibility)

| # | City | Rationale | Local Partner | Unique Angle |
|---|------|-----------|---------------|-------------|
| 1 | **Amsterdam** | Strong citizen-science culture (Waag Society). Active noise policy — Schiphol flight paths, nightlife districts. Netherlands is a proven early-adopter market for civic tech. | Waag Society, AMS Institute | Schiphol noise monitoring — highly politicized, data-hungry community. Perfect alignment. |
| 2 | **Paris** | Bruitparif already operates a professional noise network — OpenNoiseNet as complementary citizen layer. Dense urban core, strong mayoral interest in environmental data. | Bruitparif (complementary, not competitive), La Fabrique de la Cité | Existing noise-awareness infrastructure = faster adoption. Fill the temporal-resolution gap (citizen layer between 5-year professional surveys). |
| 3 | **Barcelona** | Smart city pioneer (Sentilo platform). Noise is a top citizen complaint — tourism, nightlife, construction. Existing digital participation platforms (Decidim). | Barcelona Digital City, EIT Urban Mobility (Barcelona office) | Smart-city API integration. Map layer as open-data feed into Sentilo. |
| 4 | **Vienna** | Strong open-data policy (OGD Wien). MA 22 (Umweltschutz) already publishes noise maps. Citizen layer adds temporal resolution to existing professional surveys. | MA 22, TU Wien (Akustik) | Open-data mandate = guaranteed government cooperation. Model for other EU capitals. |
| 5 | **Copenhagen** | Global leader in urban livability. Noise mapped in Copenhagen City Plan 2024. Strong cycling + quiet-area culture. | Copenhagen Solutions Lab, DTU (Akustik) | Reference city for "quiet city" narrative. High visibility for EU policy impact. |

**Expansion logic**: Each city runs the proven 90-day pilot playbook (50–100 devices, local Umweltamt equivalent, Bürgerveranstaltung). Amsterdam + Vienna first (high cooperation likelihood), then Paris + Barcelona, Copenhagen as capstone.

---

## 2. EU Funding

| Programme | Fit | Typical Grant | Timeline / Call Pattern | Action |
|---|---|---|---|---|
| **Horizon Europe** (Cluster 5: Climate, Energy, Mobility) | "Urban environment monitoring," "citizen science for policy," "smart cities." Requires 8–15 partner consortium. | €3–8M | 2025–2027 calls. Monitor Work Programme updates. | Form consortium by Q1 2027: OpenNoiseNet + 3–4 city partners + 2 universities + 1 acoustics SME + 1 health institute. Target 2027 call. |
| **EU LIFE** (Zero Pollution → Noise sub-programme) | Explicit noise priority in 2021–2027 programme. Two-city pilot with END action-plan integration. | €2–10M (60% co-funding) | Annual calls. Standard Action Projects (SAP). | Submit concept note Q3 2027 with Amsterdam + Paris as pilot cities. Frame as "citizen-science layer for END compliance." |
| **European Innovation Council (EIC) Accelerator** | Open-source civic tech with commercial SaaS model. EIC funds deep-tech SMEs scaling in the EU. | €0.5–2.5M grant + €0.5–15M equity | Rolling open calls. Short application → full proposal if invited. | Apply once Pro SaaS has 50+ paying customers and month-over-month growth. Evidence of product-market fit required. |
| **EIT Urban Mobility** | Real-life city pilots improving livability. Requires city partner. | €200k–1M | Annual calls (Q3/Q4 windows). | Pair with Barcelona or Copenhagen as city partner. Co-fund device deployment + map integration. |
| **EIT Climate-KIC** | Climate adaptation, urban resilience. Stage-gated accelerator. | €50k–500k | Rolling. Accelerator programme + grant. | Apply with noise-as-climate-stressor framing. Urban heat + noise as compound stressor. |

**Funding sequencing**:
1. **Q3 2027**: EIT Urban Mobility (fast, city-paired, funds first pilots outside Germany)
2. **Q4 2027**: EU LIFE concept note (larger, needs consortium)
3. **Q1 2028**: Horizon Europe consortium formalized, proposal submitted
4. **Q3 2028**: EIC Accelerator (once SaaS metrics are compelling, 100+ Pro customers)

---

## 3. Localization

### 3.1 Language Support Plan

| Language | Phase | Scope | Deliverables |
|---|---|---|---|
| **English (EN)** | Now | Default language. All code, docs, API, landing page, mobile app, dashboard. | Already in place. |
| **German (DE)** | Now | Landing page, mobile app UI, public map labels, device setup guide, calibration manual. | In progress — see `i18n-roadmap.md`. |
| **French (FR)** | Q1 2027 | Landing, mobile app, dashboard, setup guide. | Ready before Paris pilot (Q3 2027). |
| **Dutch (NL)** | Q1 2027 | Landing, mobile app, setup guide. | Ready before Amsterdam pilot (Q3 2027). |
| **Spanish (ES)** | Q3 2027 | Landing, mobile app, setup guide. | Ready before Barcelona pilot (Q4 2027). |
| **Italian (IT)** | Q3 2027 | Landing, mobile app, setup guide. | Community-driven. Italian citizen-science network active. |
| **Polish (PL)** | Q3 2027 | Landing, mobile app, setup guide. | Community-driven. Large Polish contributor base in open-source. |

### 3.2 Technical Localization Strategy

See `docs/i18n-roadmap.md` for full technical plan. Key EU-specific considerations:

- **next-intl** for landing page (Next.js), **react-i18next** for dashboard (React/Vite), **flutter_localizations** for mobile app
- **DB schema**: `events` table gets `label_i18n` JSONB column for multi-language classification labels (`{"de": "Baustelle", "en": "Construction", "fr": "Chantier"}`)
- **API**: `Accept-Language` header support. Error messages and event labels returned in requested locale.
- **Community translations**: Crowdin or Weblate instance for volunteer translators. Translation memory to avoid re-translating common strings across releases.

---

## 4. EU Policy & Compliance

### 4.1 Environmental Noise Directive (END, 2002/49/EC)

**What it requires**: Member states produce strategic noise maps + action plans every 5 years for agglomerations >100,000 inhabitants, major roads, railways, and airports.

**OpenNoiseNet's role**:
- **Ground-truth validation**: Most cities use modeled (computed) noise maps. OpenNoiseNet provides real SPL measurements to validate or challenge models.
- **Temporal resolution**: END maps are produced every 5 years. OpenNoiseNet fills the gap with continuous citizen-sourced data — detects changes between cycles.
- **Action plan input**: Each city pilot produces a formatted END action-plan input report. Standardized template per city.
- **Data sharing with EEA** (European Environment Agency): Anonymized, aggregated noise data submitted via EEA's Reportnet 3.0 platform. OpenNoiseNet as a registered data provider.

### 4.2 GDPR/DSGVO Alignment (already built-in)

- `derived_only` as default evidence mode — no raw audio on server
- Device anonymization: `device_id` is a random token, not tied to personal identity
- Data retention: 7 days audio (if opt-in snippets), 5 years statistics, documented deletion policies
- Consent: Device hosts opt in. Public map shows aggregated (≥5 devices per grid cell), never per-device

### 4.3 Data Standards

- **INSPIRE Directive** (2007/2/EC): Spatial data interoperability. GeoJSON map feeds INSPIRE-compatible.
- **Open Data Directive** (2019/1024): Public data licensed under ODC-ODbL. Machine-readable, API-accessible.
- **Data Act** (2023/2854): IoT data sharing provisions. OpenNoiseNet's open-data model is compliant by default.

---

## 5. Operations & Scaling

### 5.1 Infrastructure Scaling (1,000 → 10,000 devices)

| Component | Current (Pilot ~100) | German Rollout (~1,000) | EU Expansion (~10,000) |
|---|---|---|---|
| **API servers** | 1× Docker container | 3× behind load balancer | 10×, auto-scaling (K8s) |
| **Database** | Single Postgres + TimescaleDB | Read replica + hypertable chunking | Multi-region replicas (EU-West, EU-Central) |
| **Event throughput** | ~100/min | ~1,000/min | ~10,000/min |
| **Map tiles** | Single server | CDN (Cloudflare) | CDN + regional edge caching |
| **Object storage** | MinIO (local) | S3-compatible (Hetzner) | Multi-region S3 |
| **Monitoring** | Prometheus + Grafana (1 node) | 2-node Prometheus HA | Thanos/Cortex for long-term metrics |

### 5.2 Device Supply Chain (EU-wide)

- **German distribution**: BerryBase, Reichelt (established in German rollout)
- **EU-wide**: Partner with EU distributors — Kiwi Electronics (NL), Gotronic (FR), Mouser EU
- **BOM localization**: Per-country BOM with local supplier links, prices in local currency
- **Community build events**: 1 per city launch, partner with local makerspaces / FabLabs

### 5.3 City Launch Playbook (reusable template)

```
Month 1: Partner recruitment — Umweltamt + university + local NGO chapter
Month 2: Device production — community build event, 50–100 devices assembled
Month 3: Host recruitment — press launch + social media + NGO mailing lists
Month 4–6: 90-day data collection run
Month 7: Data analysis + city noise report + END action-plan input
Month 8: Bürgerveranstaltung / public presentation + policy recommendations
```

---

## 6. Timeline

| Quarter | Key Milestones | Success Metrics |
|---|---|---|
| **Q3 2027** | EU LIFE concept note submitted; EIT Urban Mobility application; Amsterdam pilot launched (50 devices); NL + FR translations live | 1 non-German city live; 2 EU grants applied |
| **Q4 2027** | Paris pilot launched; localization: ES, IT, PL added; EEA data-sharing pipeline tested | 3 cities live (DE+NL+FR); 2,000 total devices; 5 languages supported |
| **Q1 2028** | Barcelona pilot launched; Horizon Europe consortium formalized; first END action-plan input delivered (non-German city) | 4 cities live; 5,000 total devices; 250k monthly events |
| **Q2 2028** | Vienna pilot launched; EU LIFE proposal submitted; EIC Accelerator short application | 5 cities live; 7,500 total devices; 500k monthly events |
| **Q3 2028** | Copenhagen pilot launched; first EU-wide noise comparison report published; all 7 languages live | 7 cities live; 10,000 total devices; 750k monthly events |
| **Q4 2028** | 200-city milestone; 1M monthly events; Horizon Europe or LIFE grant secured; SaaS ARR covering EU ops | Phase exit criteria met. Post-EU expansion begins (see §8). |

---

## 7. Success Metrics (Phase Exit)

| Metric | Target |
|---|---|
| Active devices deployed | 10,000 |
| Cities covered (≥5 devices each) | 200 |
| Monthly events ingested | 1,000,000 |
| Languages supported | 7 (EN, DE, FR, NL, ES, IT, PL) |
| EU countries with active deployments | 10+ |
| EU grant funding secured | €2M+ committed |
| END action-plan inputs delivered | 5+ city reports |
| EEA data partnership | Active |
| Pro SaaS customers (EU) | 100+ |
| GitHub contributors (international) | 100+ |

---

## 8. Post-EU Expansion (2029+)

- **Non-EU Europe**: Zurich, Oslo, London — adapt playbook for non-EU regulatory context
- **Global cities**: Tokyo, Seoul, São Paulo — partner with local civic-tech organizations
- **Federation**: Regional server nodes for data sovereignty. EU node, Americas node, Asia-Pacific node
- **Hardware productization**: Calibrated, pre-assembled OpenNoiseNet devices at scale (Phase 5+ in Pro Roadmap)

---

## 9. Risks & Mitigation

| Risk | Impact | Mitigation |
|---|---|---|
| **Language/cultural barriers in new markets** | Slow adoption, low device density | City captain must be local, native speaker. Partner with local NGO chapter before launch. All materials localized before city announcement. |
| **EU grant competition** | Funding gap | Apply to 5+ programmes in parallel across 2027–2028. EIT Urban Mobility is fastest, EIC Accelerator rewards commercial traction. Diversify. |
| **END compliance data not accepted by authorities** | Credibility loss | Partner with accredited acoustics lab (e.g., Müller-BBM, TÜV) for calibration certification. Publish open calibration methodology. Position as complementary, not replacement, for professional surveys. |
| **Server scaling at 10k devices** | Downtime, data loss, user churn | Incremental scaling (see §5.1). Load-test at 2× target before each expansion step. Run chaos engineering before EU launch. |
| **City partner backs out mid-pilot** | Lost deployment, wasted devices | Signed MoU with each city before devices ship. Fallback: redirect devices to neighboring city or community group. |
| **Regulatory divergence post-Brexit** | UK data handling differs | UK as separate legal entity later. Focus on EU27 first. |
