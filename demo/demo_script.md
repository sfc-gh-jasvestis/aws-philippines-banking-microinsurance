# Demo Script: Microinsurance Claims Analytics & Fraud Detection
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake processes microinsurance claims from document parsing (Textract → AI_PARSE_DOCUMENT) through fraud classification (ML.CLASSIFICATION) to automated alerts — enabling 24-hour claims processing for underserved Filipino markets"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Teresa Remedios Osmena** | VP Claims & Operations | React App (SPCS) | Claims cycle time, fraud rates, loss ratios, regulatory compliance, payout accuracy |
| **Jose Carlos Roxas** | Claims Investigation Manager | Amazon QuickSight | Fraud patterns, document authenticity, claimant behavior, investigation queue |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 7 tables | POLICIES (2400000), CLAIMS (185000), CLAIM_DOCUMENTS (520000), PAYOUTS (142000), FRAUD_HISTORY (3800), PRODUCTS (24), IC_REGULATIONS (65) |
| **CURATED** | 4 Dynamic Tables | CLAIMS_ENRICHED, FRAUD_INDICATORS, LOSS_RATIO_ANALYSIS, PROCESSING_METRICS |
| **ML** | ML.CLASSIFICATION + ML.CLASSIFICATION | Forecasting + anomaly detection |
| **AI** | AI_PARSE_DOCUMENT, AI_CLASSIFY, COMPLETE | Classification + extraction |
| **Search** | Cortex Search | 65 documents indexed |
| **Agent** | CLAIMS_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

55 million Filipinos lack insurance coverage. Microinsurance — affordable policies under ₱500 annual premium — is the solution. But claims processing is the trust-breaker: if a farmer in Mindanao waits 2 weeks for a ₱10,000 payout after a typhoon, they'll never renew. The Insurance Commission mandates 24-hour processing. Snowflake automates document parsing, fraud detection, and adjudication to meet that mandate at scale.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "185,000 claims processed annually — average claim amount ₱12,400."

**Action**: Point at 185K claims KPI

### [0:45–1:30] CLAIMS AUTOMATION

**Show**: Claims Automation tab

> "AI_PARSE_DOCUMENT extracts data from 520K documents — medical certs, receipts, IDs."

**Action**: Show parsed document example with extracted fields

### [1:30–2:15] FRAUD DETECTION

**Show**: Fraud Detection tab

> "ML.CLASSIFICATION trained on 3,800 confirmed fraud cases — identifies 4.8% as suspicious."

**Action**: Show fraud score distribution

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Teresa asks: 'What's our loss ratio for the health microinsurance product?'"

**Action**: Type: 'Loss ratio for health microinsurance?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Textract → AI_PARSE_DOCUMENT → ML.CLASSIFICATION → auto-adjudicate or alert — full pipeline."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **AI_PARSE_DOCUMENT for claims documents** — Only demo parsing insurance claim documents (medical certs, receipts) natively
2. **ML.CLASSIFICATION for fraud + auto-adjudication** — Dual model approach — fraud detection AND straight-through processing
3. **24-hour claims SLA compliance** — Regulatory mandate met through automation — unique to Philippine insurance
4. **Microinsurance context** — Low-value, high-volume claims for underserved populations
5. **Insurance Commission regulatory search** — Cortex Search on IC circulars for compliance queries
6. **520K documents parsed** — Production-scale document intelligence for insurance


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM MICROINSURANCE.RAW.CLAIMS` → 185000
- [ ] `SELECT COUNT(*) FROM MICROINSURANCE.RAW.CLAIM_DOCUMENTS` → 520000
- [ ] `SELECT COUNT(*) FROM MICROINSURANCE.CURATED.CLAIMS_ENRICHED WHERE AUTO_ADJUDICATED = TRUE` → ~114700

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM MICROINSURANCE.ML.FRAUD_CLASSIFICATION_RESULTS WHERE FRAUD_PROBABILITY > 0.85` → >0
- [ ] `SELECT COUNT(*) FROM MICROINSURANCE.ML.AUTO_ADJUDICATION_RESULTS` → 185000

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM MICROINSURANCE.AI.PARSED_CLAIM_DOCUMENTS` → 520000

