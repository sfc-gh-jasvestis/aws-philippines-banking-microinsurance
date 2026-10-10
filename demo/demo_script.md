# Philippines Microinsurance Claims Operations

**Philippines - Microinsurance Claims Operations**
Use case: claim notification, referral to claims investigation and claims file controls for small-ticket cover

> Claims monitoring for 40 microinsurance plans at a fictional Philippine microinsurer across 5 cities: dynamic tables, a holdout-evaluated referral-risk classifier, a claims-volume forecast, claim document rejection anomalies and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile premium payments received, claims, referrals to investigation, settlement SLA breaches and claims file audit compliance from RAW plan data, with checks in `run_core.py`
- **Referral classification** gives a holdout-evaluated probability per plan that a claim is referred to investigation in the next 7 days
- **Claims forecast** projects 14 days of portfolio-wide claims per day with prediction intervals, for claims staffing after events such as typhoons
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live claims**: a native simulator (Snowflake only) or Amazon Data Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.PLANS` (40 rows) |
| Fact table | `RAW.PLAN_DAILY` (3,600 plan-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `CLAIMS_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.ESCALATION_RISK_SCORES`, `ML.ESCALATION_RISK_HOLDOUT_METRICS`, `ML.CLAIMS_FORECAST`, `ML.DOC_REJECT_ANOMALIES` |

Cities: Quezon City, Cebu City, Davao City, Iloilo City, Tacloban City (PHP).
Microinsurance products: Hospital cash, Personal accident, Microlife, Home and property, Livelihood.

Presenter note: microinsurance premiums are small and paid often, so a plan sees thousands of premium payments for every claim. The demo models claims operations only. The microinsurer, plans and people are fictional, it makes no legal or regulatory statements, and its SOPs are synthetic.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Claims per 1,000 Premium Payments | 0.32 |
| Claims Notified | 637 |
| Escalated to Claims Investigation | 253 |
| Escalation Rate | 39.7% |
| Settlement SLA Breaches | 117 |
| Premium Value (PHP M) | 224 |
| Premium Payments Received | 2,005,461 |
| Claims File Audit Compliance | 77.4% |
| Plans Monitored | 40 |
| Claim File Coverage | 51.5% |
| Claim Documents Pending | 22 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily claims against referrals, claims and referrals by cause, plan table
2. Predictive: holdout metrics, risk bands, 14-day claims forecast, claim document rejection rate anomalies
3. Controls: claims file audit compliance, claim file coverage and pending documents, audit compliance against referred claims, then generate the action memo
4. Live Claims: run `CALL APP.SIMULATE_CLAIMS(20)` (Snowflake only) or `python aws/publish_claims.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_CLAIMS_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 637 claims were notified against 2,005,461 premium payments (0.32 per 1,000); 39.7% of claims were referred to claims investigation.
- Incomplete claim documents produce the most referrals (59 of 121 claims), ahead of hospital inpatient stays (51 of 148). Chasing missing documents early is the cheapest lever.
- Quezon City has the most referrals (87 of 148 claims). The 16 typhoon event claims (Tacloban City and Iloilo City) hit every plan in a city on one day and always settle without investigation.
- The risk model is evaluated on a time-based holdout: precision 0.58 and recall 0.42 at 0.5, against a 0.30 base rate. Present it as triage, not a verdict.
- Typhoon events are excluded from model training, because they are not plan-driven.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
