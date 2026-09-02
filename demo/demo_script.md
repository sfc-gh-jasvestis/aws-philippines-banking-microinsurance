# Microinsurance Claims Analytics & Fraud Detection

**Philippines - Banking & Insurance**
Use case: Microinsurance Claims

> 55M uninsured Filipinos — microinsurance claims must be processed in 24 hours or customers lose trust. Snowflake parses claim documents with AI, classifies fraud with ML, and alerts adjusters before payouts — all in native SQL.

## Why Snowflake

Snowflake processes microinsurance claims from document parsing (Textract → AI_PARSE_DOCUMENT) through fraud classification (ML.CLASSIFICATION) to automated alerts — enabling 24-hour claims processing for underserved Filipino markets

- **AI_PARSE_DOCUMENT for claims documents** - Only demo parsing insurance claim documents (medical certs, receipts) natively
- **ML.CLASSIFICATION for fraud + auto-adjudication** - Dual model approach — fraud detection AND straight-through processing
- **24-hour claims SLA compliance** - Regulatory mandate met through automation — unique to Philippine insurance
- **Microinsurance context** - Low-value, high-volume claims for underserved populations
- **Insurance Commission regulatory search** - Cortex Search on IC circulars for compliance queries
- **520K documents parsed** - Production-scale document intelligence for insurance

## What is deployed

| | |
|---|---|
| Database | `PH_BANKING_MICROINSURANCE` |
| Service | `PH_BANKING_MICROINSURANCE_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.PRODUCTS` (20 rows) |
| Fact table | `RAW.POLICIES` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: Life Micro, Health Micro, Calamity, Personal Accident

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_BANKING_MICROINSURANCE
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Policies Active | `8.4M` | total across Products |
| Claims Ratio | `42%` | average per event |
| Premium Income | `PHP 2.1B` | average per event |
| Inclusion Reach | `+1.2M` | total across Products |
| Agent Network | `42K` | total across Products |
| Digital Enrollment | `34%` | average per event |
| Renewal Rate | `78%` | average per event |


## Demo flow

1. Executive Cockpit
2. Claims Automation
3. Fraud Detection
4. Ask AI
5. Architecture & Data

## Talking points

- **185,000 claims** - processed annually (₱2.3B in payouts)
- **18 hours** - average processing time (within 24-hour mandate)
- **62%** - of claims auto-adjudicated by ML
- **4.8%** - of claims flagged as suspicious (₱108M exposure)
- **520K documents** - parsed by AI_PARSE_DOCUMENT
- **2.4M policies** - active microinsurance coverage

## Business impact

- 55 million Filipinos lack any form of insurance coverage (Insurance Commission Philippines)
- Philippine microinsurance market grew 28% in 2023 to ₱12B in premiums (IC Philippines)
- AI-powered claims processing reduces cycle time by 60-80% (McKinsey Insurance)
- Automated fraud detection saves insurers 15-30% in claims leakage (Deloitte Insurance)

---
Generated from `generator/demo_specs/aws-philippines-banking-microinsurance.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-banking-microinsurance` instead.
