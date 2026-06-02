# Pilot Scaling Checklist — Hamburg 100-Device Deployment

**Status: Planning | Last updated: June 2026**

---

## 1. Technical Readiness

### 1.1 Server Load Estimate

| Metric | Per Device | 100 Devices |
|---|---|---|
| Event ingest rate | 1 event/min | 100 events/min (~1.7/s) |
| Daily events | 1,440 | 144,000 |
| Monthly events | ~43,000 | ~4.3 M |
| Avg payload size | ~200 bytes | ~20 KB/min ingress |
| Peak concurrent connections | 1 WS + periodic REST | ~100 WS + burst HTTP |

**Action items:**
- [ ] Load-test API at 200 events/s (2× projected peak) with `wrk` or `locust`
- [ ] Verify Redis can handle 100 concurrent WS pub/sub subscribers
- [ ] Confirm FastAPI worker count: 4 uvicorn workers on 4 vCPU is adequate for 100 devices
- [ ] Set up Prometheus + Grafana dashboard for: request latency (p50/p95/p99), error rate, DB pool usage, Redis memory

### 1.2 Database Sizing

**Event table growth:**
- 4.3 M rows/month × 3 months = ~13 M rows
- At ~200 bytes/row: ~2.6 GB raw data
- With indexes (event_type, device_id, timestamp, location): ~5 GB total

**Other tables (estimates):**
- Devices: 100 rows (negligible)
- Users: ~500 rows (participants + operators)
- Cases/Episodes (Pro tier): <10,000 rows

**Action items:**
- [ ] Provision PostgreSQL with ≥20 GB storage for pilot period + buffer
- [ ] Enable `pg_stat_statements` for query performance monitoring
- [ ] Create BRIN indexes on `events.timestamp` (time-series optimization)
- [ ] Set up partitioned tables by month if event volume exceeds 5 M/month
- [ ] Schedule `VACUUM ANALYZE` cron nightly at 03:00 UTC

### 1.3 Monitoring & Alerting

**Action items:**
- [ ] Uptime monitoring: health endpoint polled every 60 s (use Hetzner status or external)
- [ ] Alert rules:
  - API error rate >1% over 5 min
  - P95 latency >500 ms over 5 min
  - DB connection pool exhausted (>80% utilized)
  - Disk usage >80%
  - Redis memory >80%
- [ ] Device health: track last event timestamp per device; alert if no data for >15 min
- [ ] Set up daily digest email to operator with: event count, unique devices active, error summary

### 1.4 Backup & Recovery

**Action items:**
- [ ] Automated `pg_dump` daily at 02:00 UTC, retained 30 days
- [ ] WAL archiving enabled for point-in-time recovery
- [ ] Test restore from backup before pilot launch

---

## 2. Operational Readiness

### 2.1 Device Distribution

**Action items:**
- [ ] Finalize device BOM (ESP32 board, MEMS mic, enclosure, power supply)
- [ ] Order 110 units (100 + 10 spares)
- [ ] Flash firmware on all devices, label with unique device ID + QR code
- [ ] Print quick-start guide (1-page German, laminated) per device
- [ ] Prepare distribution event logistics:
  - [ ] Venue booking (community center or co-working space)
  - [ ] 2 distribution dates (weekday evening + Saturday morning)
  - [ ] Sign-up sheet with device ID ↔ participant mapping

### 2.2 Onboarding Flow

**Action items:**
- [ ] App store listings: Google Play + App Store (TestFlight for pilot)
- [ ] Onboarding wizard in app:
  - [ ] Device pairing (scan QR → WiFi config → verify data flow)
  - [ ] Window placement guide (visual guide with photos)
  - [ ] Privacy consent (DSGVO-compliant checkbox flow)
  - [ ] Quick tour: Dashboard, Map, Alerts
- [ ] Welcome email automation:
  - [ ] Day 0: "Dein Gerät ist unterwegs" with tracking
  - [ ] Day 1: Onboarding checklist + video link
  - [ ] Day 7: "Deine erste Woche" with stats summary
- [ ] Printed quick-start card in box (German, A6)

### 2.3 Support Channels

**Action items:**
- [ ] Email support: pilot@opennoienet.org, response SLA: <24 h business days
- [ ] Signal/WhatsApp group for participants (opt-in, peer support)
- [ ] FAQ page on website (see pilot landing page)
- [ ] Known-issues page updated weekly from support tickets
- [ ] Device replacement process: mail-in swap for DOA units (<48 h turnaround)

### 2.4 Community Engagement

**Action items:**
- [ ] Monthly community call (Zoom/Jitsi, 30 min) — first call Week 1
- [ ] Newsletter: bi-weekly during pilot, with map highlights and participant stories
- [ ] Mid-pilot survey (Week 6): satisfaction, UX friction, feature requests
- [ ] Closing event (Week 12): results presentation, community feedback, next steps

---

## 3. Legal & Compliance

### 3.1 Datenschutz-Folgeabschätzung (DPIA)

Per DSGVO Art. 35 erforderlich bei systematischer Überwachung öffentlicher Räume.

**Action items:**
- [ ] Document data flows: Device → API → DB → Public Map + Pro Dashboard
- [ ] Classify personal data: device location (street-level, not exact GPS for public map), email, device ID
- [ ] Risk assessment:
  - [ ] Re-identification risk from clustered device locations
  - [ ] Unauthorized access to Pro-tier case data
  - [ ] Data retention: define deletion policy for raw events
- [ ] Mitigations:
  - [ ] Public map: spatial fuzzing to ±50 m, temporal aggregation to 15-min buckets
  - [ ] Pro data: access control via JWT roles, audit logging
  - [ ] Retention: raw events 12 months, aggregates indefinite
- [ ] Appoint data protection contact (can be founder for pilot scale)
- [ ] Publish DPIA summary on website (transparency)
- [ ] Register processing activities with Hamburg DPA (Hamburger Beauftragte für Datenschutz)

### 3.2 Nutzungsbedingungen (Terms of Use)

**Action items:**
- [ ] Draft pilot-specific ToU (German), covering:
  - [ ] Device is loaned, not gifted (ownership remains with OpenNoiseNet)
  - [ ] Participant responsibilities: keep device powered + connected, reasonable care
  - [ ] Data rights: participant retains rights to their raw data; OpenNoiseNet gets license to publish anonymized aggregates
  - [ ] Termination: either party can exit with 2 weeks notice; device must be returned
  - [ ] Liability cap and warranty disclaimer
- [ ] Legal review by pro-bono counsel (reach out to IfD or similar)
- [ ] Acceptance flow: checkbox + timestamp on first app launch

### 3.3 Insurance

**Action items:**
- [ ] Check if existing liability insurance covers device loan program
- [ ] Evaluate device insurance for loss/damage (€30/unit × 100 = €3,000 max exposure)

---

## 4. Week-by-Week Timeline

### Preparation (June 2026)

| Week | Dates | Tasks |
|---|---|---|
| W-4 | 01–07 Jun | Finalize hardware BOM, order components; complete pilot landing page; draft press materials |
| W-3 | 08–14 Jun | Assemble + flash 110 devices; load-test API at 200 events/s; set up monitoring |
| W-2 | 15–21 Jun | Open participant registration; send outreach emails to Bezirksämter + Verbände; DB backup setup |
| W-1 | 22–28 Jun | Participant selection + notification; device packaging + labeling; dry-run distribution event |
| W-0 | 29–30 Jun | Final checklist review; on-call rotation set; press release sent |

### Pilot (July–September 2026)

| Week | Dates | Tasks |
|---|---|---|
| W1 | 01–05 Jul | **Distribution event 1** (Wed evening); onboarding support blitz; monitor device activation rate |
| W2 | 06–12 Jul | **Distribution event 2** (Sat morning); follow up non-activated devices; first community call |
| W3 | 13–19 Jul | Stabilization: address top support issues; firmware OTA update if needed |
| W4 | 20–26 Jul | First monthly report: device uptime, event volume, data quality |
| W5 | 27 Jul–02 Aug | Mid-pilot survey prep; begin case-study interviews with participants |
| W6 | 03–09 Aug | **Mid-pilot survey** (send Mon, close Fri); analyze results |
| W7 | 10–16 Aug | Address survey findings; second firmware update if needed |
| W8 | 17–23 Aug | Second monthly report; community call |
| W9 | 24–30 Aug | Begin data analysis for final report; draft findings |
| W10 | 31 Aug–06 Sep | Stakeholder preview of preliminary findings |
| W11 | 07–13 Sep | Prepare closing event: venue, presentation, data visualizations |
| W12 | 14–20 Sep | **Closing event**; final report published; participant exit survey |

### Post-Pilot (October 2026)

| Week | Tasks |
|---|---|
| W13–14 | Consolidate final report; publish open dataset; stakeholder debriefs |
| W15 | Decision gate: proceed to permanent Hamburg network? Expand to other cities? |
| W16 | Transition plan: participant devices transfer to permanent program or return |

---

## 5. Success Criteria

- [ ] ≥90 of 100 devices activated and reporting within Week 1
- [ ] ≥80 devices still active at Week 12 (end of pilot)
- [ ] ≥4 M valid events collected over 3 months
- [ ] <2% data loss (events ingested vs. events generated)
- [ ] API uptime ≥99.5% over pilot period
- [ ] ≤5 support tickets per week after Week 2
- [ ] ≥3 press articles published
- [ ] ≥2 formal partnerships with Bezirksämter or Verbände confirmed by Week 12
- [ ] DPIA completed and registered before launch
- [ ] Final report published within 2 weeks of pilot end
