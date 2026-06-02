# OpenNoiseNet — German Rollout Plan

**Status:** Planning · **Last updated:** 2026-06-02
**Phase:** 2 (after Berlin pilot proven, stabilization gate closed)
**Timeline:** Q4 2026 – Q2 2027

This document operationalizes the German rollout phase from the Business Strategy (§5.2) and Pro Roadmap. It assumes the Berlin pilot (Phase 1) has validated the full stack with 100 devices and at least one Bezirksamt partnership.

---

## 1. Target Cities (ordered by noise complaint density)

| # | City | Rationale | Key Contact |
|---|------|-----------|-------------|
| 1 | **Hamburg** | Port noise, airport (HAM), dense urban core. "MySMARTLife" programme receptive to citizen-science monitoring. City Science Lab @ HCU as academic partner. | HCU City Science Lab, Behörde für Umwelt |
| 2 | **Munich** | Strong noise complaints in inner districts (Altstadt-Lehel, Ludwigsvorstadt). "Smarter Together" follow-up projects. Well-funded Umweltreferat. | Referat für Klima- und Umweltschutz |
| 3 | **Cologne** | Rhine corridor traffic noise, event noise (Karneval, concerts). Strong Bürgerinitiative culture. | Umwelt- und Verbraucherschutzamt |
| 4 | **Frankfurt** | Airport (FRA) — Europe's 4th busiest, persistent community complaints. Financial hub = potential Pro customers. | Umweltamt Frankfurt, Fluglärmkommission |

**Expansion logic**: Each city gets the same playbook as Berlin — pitch the Umweltamt, recruit 50–100 volunteer device hosts, run a 90-day pilot, publish a city-specific noise report, hold a Bürgerveranstaltung.

---

## 2. Partner Network

### 2.1 Environmental NGOs (recruitment + credibility)

| Organisation | Role | Starting Point |
|---|---|---|
| **BUND** (Bund für Umwelt und Naturschutz) | Local chapters recruit device hosts, co-brand public reports. Already runs citizen-science air quality monitoring — noise is a natural extension. | Pitch as complementary monitoring layer. Offer free Portfolio tier for organized groups. |
| **NABU** (Naturschutzbund) | Urban nature + noise impact angle. Strong local chapter network. Bird/nature reserves near traffic corridors as monitoring targets. | Frame noise as habitat stressor. Co-brand field guides for citizen deployment. |
| **VCD** (Verkehrsclub Deutschland) | Traffic noise advocacy. Perfect alignment: VCD campaigns for quieter cities; OpenNoiseNet provides the data. | Offer co-branded "Verkehrslärm messen" campaign kit. Device hosts from VCD membership base. |
| **Deutsche Umwelthilfe (DUH)** | Legal advocacy + policy. DUH has sued cities over NO2 limits; noise is next. Data from OpenNoiseNet supports their litigation and policy work. | Provide export-ready END-compliance reports. Offer free data access for their campaigns. |

### 2.2 Municipal Partners

- Target **Lärmschutzbeauftragte** in each city's Umweltamt — they are legally required, under-resourced, and hungry for data.
- Each city pilot produces a **Lärmaktionsplan input report** — directly feeds the 5-year END update cycle.
- Offer cities the **Bezirksamt playbook** proven in Berlin: 50–100 devices, 90-day run, public report, Bürgerveranstaltung.

### 2.3 Academic Partners

- **TU Berlin** (Akustik): Calibration methodology validation, peer-reviewed publication.
- **HCU Hamburg** (City Science Lab): Urban data integration, map layer interoperability.
- **Uni Stuttgart** (Lärmwirkung): Health impact correlation studies.

---

## 3. Media Strategy

| Outlet | Type | Angle | Timing |
|---|---|---|---|
| **Tagesspiegel** (Berlin → national) | Print/online | Local angle: "Wie laut ist Ihre Stadt wirklich?" Data-driven comparisons between cities. | City launch + report publication |
| **ZEIT / ZEIT Online** | National weekly | Feature: "Die Lärm-Revolution von unten" — long-form citizen-science narrative. | Mid-rollout, after 2+ cities live |
| **Spiegel Online** | National news | Data story: noise maps across German cities, interactive comparisons. | Early 2027, when map has 4-city coverage |
| **Deutschlandfunk** | National radio | Feature + interview: live device demo, noise-affected resident interview. Audio-friendly topic. | Q1 2027 |
| **Golem / heise online** | Tech | Hardware deep-dive: ESP32 build, firmware OTA, server architecture. Attracts contributors. | Q4 2026 (tech angle first) |
| **taz** | National left/eco | Civic tech + environmental justice: "Open Source gegen Lärm." taz audience overlaps heavily with potential contributors. | Ongoing |

**Press kit deliverables** (prepare before first city launch):
- 2-page fact sheet: mission, tech, privacy, metrics
- Press-quality photos: device build, deployment, map screenshot
- Data story template: customizable per city with live map embed

---

## 4. Funding

| Programme | Amount | Fit | Action |
|---|---|---|---|
| **Umweltbundesamt (UBA)** | €50k–300k | Environmental monitoring, citizen science, END implementation support. | Submit project proposal framing German rollout as END action-plan input. Research UBA's "Umweltforschung" calls. |
| **DBU (Deutsche Bundesstiftung Umwelt)** | Project-dependent, non-repayable | Model environmental solutions with citizen participation. | Submit 2-page Projektskizze for multi-city pilot. Rolling deadline — earliest win. |
| **mFUND (BMDV)** | Line 1: ≤€200k / Line 2: ≤€3M | Data-driven mobility innovation. Open-source required. Frame as traffic-noise intelligence + open API. | Monitor call windows. Prepare consortium with city partner + university. |
| **Prototype Fund (BMBF via OKF DE)** | €47.5k / 6 months | FOSS for societal needs. Fund mobile app + on-device AI hardening pre-rollout. | Apply next round. Quickest money on the table. |
| **Bundesländer-specific** | Varies | Each Land has environmental monitoring / smart-city pots. Hamburg's "MySMARTLife", Munich's "Smarter Together" follow-up, NRW's "Digitale Modellregionen." | Identify per-city before pitching the Umweltamt. |

**Funding sequencing**: DBU Projektskizze first (fastest, rolling deadline) → Prototype Fund for mobile hardening → UBA for rollout scale → mFUND for traffic-noise depth.

---

## 5. Operations & Logistics

### 5.1 Device Supply

- **Target**: 200 devices per city (800 total for first 4 cities)
- **Build model**: Community build events + pre-assembled kits
- **Cost**: ~€30/device BOM × 800 = €24,000 (fundable via single DBU grant)
- **Calibration**: Standardized procedure documented. Community calibration events per city.

### 5.2 Server Scaling

- Current Docker stack handles pilot scale (100 devices). Before rollout:
  - TimescaleDB hypertable for events (already in schema)
  - Load-test at 1,000-device scale
  - CDN for map tiles (Cloudflare)
  - Regional DB read replicas if latency demands

### 5.3 Community Management

- **City captains**: 1–2 volunteer leads per city for device host coordination, local press, event organization
- **Monthly community call**: City captains + core team, 30 min, public agenda
- **GitHub**: "good first issue" tags, contribution guide maintained, city-specific deployment issues tracked
- **Content**: City-launch blog posts, data stories, calibration tutorials (German + English)

---

## 6. Timeline

| Quarter | Key Milestones | Success Metrics |
|---|---|---|
| **Q4 2026** | DBU Projektskizze submitted; Hamburg pilot launched (50 devices); press kit published; Golem/heise tech coverage | 50 devices in Hamburg reporting; 1 academic partner confirmed |
| **Q1 2027** | Munich + Cologne pilots launched; Deutschlandfunk feature aired; community build events in 3 cities; Prototype Fund application submitted | 200 devices total across 3 cities; 5+ media pieces; 20+ GitHub contributors |
| **Q2 2027** | Frankfurt pilot launched; multi-city noise comparison report published; first 2 city-specific Lärmaktionsplan inputs delivered; UBA proposal submitted | 500 devices across 4 cities; 50 cities covered (incl. suburbs); 100k monthly events; 10+ paying Pro organizations |

---

## 7. Success Metrics (Phase Exit)

| Metric | Target |
|---|---|
| Active devices deployed | 1,000 |
| Cities covered (≥5 devices each) | 50 |
| Monthly events ingested | 100,000 |
| Paying Pro organizations | 20+ |
| Media features (national) | 10+ |
| Grant funding secured | €200k+ |
| GitHub contributors | 50+ |
| Academic publications (peer-reviewed) | 1+ |

---

## 8. Risks & Mitigation

| Risk | Impact | Mitigation |
|---|---|---|
| **City bureaucracy stalls permit/partnership** | Delayed launch | Start Umweltamt conversations 3 months before planned launch. Have the Berlin Bezirksamt reference case ready. |
| **Device supply bottleneck** | Can't meet host demand | Pre-order ESP32+INMP441 kits in batches of 200. Partner with German electronics distributor (BerryBase, Reichelt) for bulk pricing. |
| **Community fatigue after pilot hype** | Device attrition, data gaps | City captain model. Monthly engagement (events, blog posts, data stories). Gamification: "Quietest street in Hamburg" leaderboard. |
| **Server scaling under load** | Degraded uptime, data loss | Load-test at 1,000-device scale during Q3 2026 (pre-rollout). TimescaleDB proven at this scale. CDN for map tiles. |
| **Grant rejection(s)** | Funding gap | Apply to 4+ programmes in parallel. DBU (fastest), Prototype Fund (small but quick), UBA (larger), mFUND (traffic angle). Private sponsors as fallback (Stiftung Mercator). |
