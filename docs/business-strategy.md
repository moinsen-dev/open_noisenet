# OpenNoiseNet — Monetization & Growth Strategy

**Status:** Strategy document · **Last updated:** 2026-06-02  
**Product stage:** Pre-commercial (software stabilization gate closing; Pro slices hardening in progress)  
**Target reader:** Founder, early team, grant reviewers, potential partners  

This document lays out the commercial path for OpenNoiseNet while preserving its open-source, privacy-first, citizen-science mission. It builds on the product reality documented in the Pro Roadmap and the FUNDING playbook already in this repo — not on speculative features.

---

## 1. Use Cases Beyond Core Noise Monitoring

The same sensor → event → episode pipeline that detects construction noise or traffic peaks can be repurposed with minimal changes. Each use case below maps to the existing tech stack: ESP32/Pi + MEMS mic → SPL logging → threshold exceedance → server episode engine.

### 1.1 Adjacent Acoustic Monitoring (same hardware, different classification)

| Use Case | Trigger Pattern | Classification Target | Commercial Buyer |
|---|---|---|---|
| **Home surveillance** | Sharp transient peaks at unusual hours, glass-break signatures | Break-in, vandalism, door/window force | Homeowners, security integrators |
| **Baby/child monitoring** | Sustained broadband crying, silence anomalies | Crying duration, sleep interruption count | Parents, Kita facilities |
| **Pet monitoring** | Repetitive bark bursts, whining patterns | Separation anxiety score, bark frequency over time | Pet owners, vet practices |
| **Elderly care** | Activity sound density, sudden impact spikes | Activity level, potential fall event | Pflegedienste, assisted-living operators |
| **Construction compliance** | Continuous heavy machinery signatures | Exceedance of TA Lärm limits, duration logging | Bauherren, Bauämter, Anwohnerinitiativen |
| **Event venue management** | Music/PA system threshold breaches | Curfew violations, dB over license limits | Venue operators, Ordnungsamt |
| **Smart city traffic mapping** | Persistent road-noise bands, peak-hour clustering | Traffic density proxy, hotspot identification | Verkehrsplanung, Umweltämter |
| **Insurance claims** | Timestamped dB logs around reported incidents | Evidence for/against noise-related damage claims | Versicherer, Gutachter |
| **Real estate** | Long-term ambient noise profiles | Neighborhood quietness rating, noise trend over 30/90 days | Makler, Käufer, Mieter |

### 1.2 Differentiation: Why OpenNoiseNet for These

- **Privacy-first by default**: No raw audio leaves the device. Derived-only evidence (dB levels, event types, durations) avoids GDPR pitfalls that kill competing solutions.
- **Open-source classifier pipeline**: New sound classes are community-extendable. A Pflegedienst can train a fall-detection model on their own data without vendor lock-in.
- **Episode intelligence**: Already implemented server-side episode merging, scoring, and review makes multi-event patterns (e.g. "dog barks every weekday 9-17h") actionable, not just raw SPL graphs.

---

## 2. Revenue Model

The commercial model is anchored in the **Pro Roadmap's three-tier structure** and builds on the existing `organization → site → zone → policy → device` domain model.

### 2.1 SaaS Tiers

| Tier | Scope | Price | Key Features |
|---|---|---|---|
| **Free / Public** | 1 device, public data only | €0 | Map visibility, basic dashboard, open-data export |
| **Pro Site** | 1 site, up to 5 devices | €9.99/mo | Episodes, review, case creation, PDF/CSV export, quiet-hours scoring |
| **Portfolio** | Unlimited sites, unlimited devices | €49.99/mo | Multi-site governance, cross-site analytics, recurring-disturbance workflows, priority support |
| **Enterprise / API** | Custom | After beta | API access, webhooks, consultant/municipal report packs, white-label |

**Pricing rationale**: Benchmarked against property management software (€5–50/unit/mo) and environmental monitoring SaaS (€50–500/mo). The Pro Site tier is priced for adoption — a Hausverwaltung with 5 devices across a building pays less than one hour of a technician's time per month.

### 2.2 Data Licensing

Anonymized, aggregated noise maps and trend data sold to:
- **Cities & Verkehrsplanung**: €500–2,000/yr per district for noise heatmaps, peak-hour analysis, and END compliance reporting inputs.
- **Researchers**: Free for academic use; €100–500/dataset for commercial research.
- **Insurance / Real estate**: Per-query or subscription access to historical noise profiles for specific addresses or neighborhoods.

Data is always aggregated (≥5 devices per grid cell), never per-device, and never includes audio.

### 2.3 Hardware Referral & Kits

- **Affiliate links**: Curated BOM with affiliate links to Mouser, Adafruit, BerryBase for ESP32 kits, INMP441 mics, enclosures. Estimated €2–5 per referred build.
- **Pre-assembled kits (later track)**: After self-serve beta validation, sell calibrated, flashed, weatherproofed devices at €59 (ESP32) / €99 (Pi Zero 2 W) with 30% margin. Not before — hardware is Phase 5+ in the roadmap.

### 2.4 White-Label & Custom Deployments

- Municipalities and NGOs can license a self-hosted or managed instance with their branding.
- Pricing: €1,500–5,000 setup + €99–299/mo hosting, depending on device count and SLA.
- Target: Umweltämter running their own citizen-science programs.

### 2.5 API Access

- Public API: Free for non-commercial use, rate-limited.
- Commercial API: €29–199/mo based on request volume, includes higher rate limits, SLA, and dedicated endpoints for episode/case export.
- Enterprise API: Custom pricing for integrations with city dashboards, traffic management systems, or insurance platforms.

---

## 3. Funding Opportunities

This section builds on the detailed playbook in `FUNDING.md`. The table below prioritizes by near-term viability (2025–2026 calls).

### 3.1 EU-Level

| Programme | Fit | Typical Grant | Near-Term Action |
|---|---|---|---|
| **EU LIFE** (Zero Pollution → Noise) | Explicit noise priority. Two-city pilot with END action-plan integration. | €2–10M (60% co-funding) | Concept note + partner recruitment (city + university + acoustics SME). Deadline ~Sept 2025. |
| **Horizon Europe** (Cluster 5: Climate, Energy, Mobility) | Urban mobility, smart cities, citizen engagement. | €3–8M (consortium of 8–15 partners) | Monitor 2025–2026 calls for "urban environment monitoring" or "citizen science for policy" topics. |
| **EIT Urban Mobility** | Real-life city pilots improving liveability. | €200k–1M | Requires city partner. Annual calls; check Q3/Q4 2025 windows. |
| **EIT Climate-KIC** | Climate adaptation, urban resilience. | €50k–500k (stage-gated) | Accelerator application emphasizing noise as health/climate stressor. |

### 3.2 Germany

| Programme | Fit | Typical Grant | Near-Term Action |
|---|---|---|---|
| **DBU (Deutsche Bundesstiftung Umwelt)** | Model environmental solutions, citizen participation. | Project-dependent, non-repayable | Submit 2-page Projektskizze for a Land-level pilot. Rolling deadline. |
| **mFUND (BMDV)** | Data-driven mobility innovation. Open-source required. | Line 1: ≤€200k; Line 2: ≤€3M | Frame as traffic-noise intelligence + open API. Regular calls. |
| **Prototype Fund (BMBF via OKF DE)** | FOSS prototypes for societal needs. | €47.5k / 6 months | Fund mobile app MVP hardening + on-device AI pipeline. Multiple rounds/year. |
| **BMBF Citizen-Science** | Currently under evaluation (2021–2024 programme ended). Watch for refreshed call in 2025–2026. | €100k–500k | Prepare positioning paper; join citizen-science networks (Bürger schaffen Wissen). |

### 3.3 Foundations & Accelerators

| Organisation | Angle | Amount |
|---|---|---|
| **NLnet Foundation** | Open-source, privacy-respecting internet tech. | €5k–50k per project |
| **Stiftung Mercator** | Climate, participation, urban transformation. | €50k–200k |
| **Volkswagen Stiftung** | "Pioniervorhaben" for citizen science + tech. | €100k–500k |
| **Carbon13** | Climate tech accelerator (Hamburg hub). | €80k investment + 6-month programme |

### 3.4 Smart City Tenders

- **Hamburg**: Senate Department for Urban Mobility, Transport, Climate (SenMVKU) regularly tenders pilot projects for smart city tech. The "Gemeinsam Digital: Hamburg" strategy explicitly funds citizen-science monitoring.
- **Hamburg**: "MySMARTLife" programme and the City Science Lab at HCU are open to environmental monitoring partnerships.
- **Munich**: "Smarter Together" follow-up projects; noise is a documented concern in several Bezirksausschüsse.

---

## 4. Political Advocacy

OpenNoiseNet's value proposition is inherently political: it gives citizens, NGOs, and municipalities **independent, verifiable evidence** to replace anecdotal noise complaints. This section outlines who to reach and how to position.

### 4.1 Who to Approach

| Target | Why They Care | Starting Point |
|---|---|---|
| **Umweltausschuss** (Hamburg Abgeordnetenhaus, Bezirksverordnetenversammlungen) | Noise is a top-3 citizen complaint category in every Hamburg district. An open monitoring network gives them data-driven arguments for policy change. | Request a 15-min presentation slot. Bring a live map showing real device data from the pilot district. |
| **Lärmschutzbeauftragte** (noise protection officers) | Legally required in many municipalities. Currently rely on sparse, expensive professional measurements. OpenNoiseNet fills the gap between complaint logs and professional surveys. | Approach directly with a pilot proposal for their district. |
| **Bürgerinitiativen** (citizen action groups) | Already organized, already angry about specific noise sources (Tegel follow-up, A100 extension, club noise in Friedrichshain). They need data, not just anecdotes. | Offer free Pro Site tier for organized groups; provide export-ready reports for their petitions. |
| **Umweltverbände** (BUND, NABU, DUH) | Noise is an environmental health issue. BUND already runs citizen-science air quality monitoring; noise is a natural extension. | Pitch as a complementary monitoring layer to their existing programmes. |

### 4.2 Policy Angles

- **EU Environmental Noise Directive (END, 2002/49/EC)**: Requires member states to produce strategic noise maps and action plans every 5 years. Most cities rely on modeled data — OpenNoiseNet provides ground-truth validation and fills the gap between 5-year cycles.
- **TA Lärm**: Germany's technical noise protection regulation. The Pro episode engine can be configured to flag TA Lärm exceedances automatically, producing legally structured evidence packages.
- **DIN 45645**: Standard for assessing noise annoyance. Episode scoring (nuisance score, quiet-hours weighting) maps directly to the DIN's noise-rating levels.
- **Hamburger Lärmaktionsplan**: Updated every 5 years. The 2024–2029 plan explicitly mentions citizen participation in noise monitoring. A 2025/2026 pilot would feed directly into the next update cycle.

### 4.3 Pilot Strategy: Bezirksamt Partnership

**Proposal**: Partner with one Hamburg Bezirksamt (recommended: Friedrichshain-Kreuzberg or Neukölln — both have active noise complaints and engaged Bezirksverordnete) for a 3-month, 100-device trial.

**Structure**:
1. Recruit 80–100 volunteer households and businesses across 3–5 noise hotspots.
2. Deploy OpenNoiseNet devices (ESP32 kits provided; volunteers supply Wi-Fi and power).
3. Run for 90 days, generating a public noise map and a Bezirksamt-specific report.
4. Wrap with a Bürgerveranstaltung presenting findings + policy recommendations.

**Cost to the Bezirksamt**: ~€5,000–8,000 (100 devices @ €30 BOM + logistics + report). Fundable via Bezirkskasse or sponsor.

**Win for OpenNoiseNet**: Real-world validation, press coverage, a replicable template for other districts and cities, and a reference deployment for grant applications.

### 4.4 Media Strategy

| Outlet | Angle | Pitch |
|---|---|---|
| **Tagesspiegel** (Hamburg) | Local angle: "Wie laut ist Ihre Straße wirklich? Bürger messen selbst." | Offer exclusive access to the pilot map + interviews with participating households. |
| **taz** | Civic tech + environmental justice: "Open Source gegen Lärm — eine Community nimmt es selbst in die Hand." | Pitch the citizen-science + open-source narrative. taz audience overlaps heavily with potential contributors. |
| **Spiegel Online** | National: "Lärmkarten aus der Nachbarschaft — wie eine App Wohnqualität messbar macht." | Data-driven story with comparisons between districts. |
| **Golem / heise online** | Tech: "ESP32 als Lärmsensor — OpenNoiseNet baut ein offenes Monitoring-Netz." | Hardware + software deep-dive. Attracts contributors. |
| **Deutschlandfunk / Radioeins** | Radio feature: live demo of a device, interview with a noise-affected resident. | Audio-friendly topic; radio audiences are older homeowners — potential device hosts. |

---

## 5. Go-to-Market

### 5.1 Phase 1: Hamburg Pilot (Q3 2025 — Q1 2026)

**Objective**: Validate the full stack with 100 real devices in the field, generate a public noise map, secure first Bezirksamt partnership.

| Action | Owner | Success Metric |
|---|---|---|
| Close stabilization gate (24h field runs on iOS + Android) | Engineering | 2 devices running 72h without manual intervention |
| Harden Pro domain slice (tenant isolation, case lifecycle) | Engineering | All Pro API tests passing; cross-tenant regression suite green |
| Recruit pilot households in 1–2 Bezirke | Community | 80+ devices registered and reporting |
| Partner with 1 Bezirksamt | Founder | Letter of support or co-funding commitment |
| Launch public noise map for pilot area | Product | Map live, events visible, media pickup |
| Publish findings + policy recommendations | Product + Partner | Report delivered, Bürgerveranstaltung held |

**Budget**: ~€5,000–10,000 (devices, logistics, event). Covered by Prototype Fund or DBU Projektskizze.

### 5.2 Phase 2: German Rollout (Q2 2026 — Q4 2026)

**Objective**: Expand to 500+ devices across 5–10 German cities; launch self-serve Pro beta; secure first paying Pro customers.

| Action | Success Metric |
|---|---|
| Partner with Umweltverbände (BUND, NABU) for recruitment | 5+ local chapters running device pools |
| Open self-serve Pro beta (Pro Site tier) | 20+ paying organizations |
| Secure DBU or mFUND grant for expansion | €200k+ grant signed |
| Media coverage in national outlets | 5+ articles/features |
| Community: 50+ GitHub contributors, 10+ active device firmware contributors | Measured via GitHub insights |

### 5.3 Phase 3: EU Expansion (2027)

**Objective**: First non-German pilots; EU-level visibility; portfolio revenue covering operating costs.

| City | Rationale |
|---|---|
| **Amsterdam** | Strong citizen-science culture, active noise policy (Schiphol, nightlife), Waag Society as potential partner. |
| **Paris** | Bruitparif already operates a professional network — OpenNoiseNet as complementary citizen layer. |
| **Barcelona** | Smart city pioneer; noise is a top complaint (tourism, nightlife); existing digital participation platforms. |
| **Vienna** | Strong open-data policy; MA 22 (Umweltschutz) already publishes noise maps; citizen layer adds temporal resolution. |

### 5.4 Community Building

- **GitHub-first**: All development public. Good first issues tagged, contribution guide maintained. Monthly community calls.
- **Citizen-scientist onboarding**: Step-by-step setup video, calibration walkthrough, data interpretation guide. Make it possible for a non-technical person to deploy a device in 30 minutes.
- **University partnerships**: Offer free Portfolio tier to research groups. They supply devices, publish papers citing OpenNoiseNet — mutual credibility.
- **Content marketing**: Blog series: "What we learned from 100 Hamburg noise sensors", "How to read your neighborhood's noise profile", "The 10 loudest streets in [city] — and what the data says".

---

## 6. Competitive Landscape

### 6.1 Existing Solutions

| Solution | Type | Strengths | Weaknesses vs. OpenNoiseNet |
|---|---|---|---|
| **NoiseTube** (BE) | Research project, app-based | Early mover, academic credibility | Phone-mic only (poor calibration), no dedicated hardware, project appears inactive since ~2018 |
| **NoiseCapture** (FR) | Open-source Android app (Ifsttar/CNRS) | Strong academic backing, open-source | Phone-only, no dedicated device, no episode classification, no commercial model, limited backend |
| **Hush City** (IT/DE) | Research app for quiet areas | UX-focused, participatory mapping | Subjective ratings, not quantitative SPL monitoring, no hardware, no Pro tier |
| **Ambiciti** (FR) | Research project (INRIA) | Multi-pollutant (noise + air), academic | App-based, appears inactive, no hardware, no commercial path |
| **Bruitparif** (FR) | Public agency, professional network | High-quality calibrated sensors, regulatory standing | Closed, expensive, Paris-only, no citizen participation layer |
| **Brüel & Kjær / Svantek** | Commercial instruments | Lab-grade accuracy, regulatory accepted | €2,000–10,000 per unit, not accessible to citizens/NGOs, closed ecosystem |

### 6.2 OpenNoiseNet's Differentiation

1. **Open-source, end-to-end**: Firmware, backend, frontend, ML pipeline — all public. No vendor lock-in. Community-extendable classifier.
2. **Privacy-first architecture**: `derived_only` as default evidence mode. No raw audio on the server. GDPR/DSGVO by design, not afterthought.
3. **Dedicated hardware at citizen prices**: €30 ESP32 build vs. €2,000+ professional meters. Calibration procedure documented. Accuracy sufficient for policy evidence, not just awareness.
4. **Episode intelligence, not just dB**: Server-side classification (7 noise types), quiet-hours scoring, nuisance ranking, case management. Competitors stop at SPL graphs.
5. **Hybrid Public/Pro model**: Free public map and open data + paid Pro SaaS for organizations. Survivable without perpetual grant dependency.
6. **Housing/property focus**: First commercial buyer is defined (Hausverwaltungen, Wohnungsbaugesellschaften), not abstract "municipalities" or "citizens." Concrete use case: "Prove to the Mieter that the construction noise next door exceeds TA Lärm."

### 6.3 Moats

| Moat | Depth |
|---|---|
| **Network effects**: More devices → richer map → more press/visibility → more volunteers deploying devices. Each new device increases the value of the public map. | Medium — requires active community management |
| **Data moat**: A year of continuous noise data across a city is not quickly replicable. Anonymized historical datasets become reference baselines. | High — once at scale |
| **Classifier quality**: Episode classification improves with more labeled data. Open-source contributions plus commercial data licensing create a flywheel. | High — compounding over time |
| **Switching costs (Pro)**: A Hausverwaltung that integrates episode → case → export into their workflow (tenant disputes, Bauüberwachung) faces friction to switch. | Medium — PDF/CSV exports reduce lock-in |

---

## 7. Financial Projections (Illustrative)

**Assumption**: Self-serve beta opens Q2 2026 with a working Pro Site tier. Numbers are for planning, not fundraising.

| Metric | Year 1 (2026) | Year 2 (2027) | Year 3 (2028) |
|---|---|---|---|
| **Free devices** | 500 | 2,000 | 5,000 |
| **Pro Site subscribers** | 50 | 300 | 1,000 |
| **Portfolio subscribers** | 5 | 40 | 150 |
| **SaaS ARR** | €7,200 | €43,200 | €178,800 |
| **Data licensing** | €0 | €5,000 | €25,000 |
| **Hardware kit margin** | €0 | €6,000 | €30,000 |
| **Grants secured** | €100,000 | €250,000 | €200,000 |
| **Total Revenue** | €107,200 | €304,200 | €433,800 |

**Path to self-sustainability**: At ~1,200 Pro subscribers (mix of Site and Portfolio) plus modest data licensing, the SaaS revenue covers a 2-person team at Hamburg rates. This is plausible by end of Year 3.

---

## 8. Immediate Next Steps

1. **Close the stabilization gate** (current priority — see `docs/current-status.md`). Android APK fix, 24h field runs on both platforms.
2. **Harden Pro tenant isolation** (Phase 4 in the production-readiness plan). Cross-tenant regression tests are the #1 commercial blocker.
3. **Submit Prototype Fund application** for the next round. €47.5k covers 6 months of mobile app hardening + on-device AI pipeline. Quickest money on the table.
4. **Draft 2-page DBU Projektskizze** for a Hamburg pilot. Use the Bezirksamt partnership structure from §4.3.
5. **Identify and approach 2–3 Bezirksämter** with a concrete pilot proposal. Start with Friedrichshain-Kreuzberg (active noise complaints, green-party Bezirksbürgermeister, precedent for citizen-science cooperation).
6. **Update landing page copy** to reflect Pro model once the stabilization gate closes. Current landing is intentionally minimal; add a "For Organizations" section with the SaaS tiers.
