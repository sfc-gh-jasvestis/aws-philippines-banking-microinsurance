# Philippines Microinsurance Claims Operations - Investigation Referral and Settlement Monitoring

Claims operations for **40 small-ticket microinsurance plans at a fictional Philippine microinsurer in 5 cities** (Quezon City, Cebu City, Davao City, Iloilo City and Tacloban City) using Snowflake, optionally with AWS: from a live claim notification to a 7-day risk score for referral to claims investigation (the step where suspected fraud or incomplete files are examined), an alert email and an AI action memo for the claims team. Amounts are in Philippine pesos (PHP).

## Architecture

A claims pipeline built on **Snowflake** (Dynamic Tables, Snowflake ML, Cortex Search, Cortex Agent, Cortex AI_COMPLETE, SPCS) and, in the full build, **AWS** (Amazon Data Firehose, S3, Bedrock Claude, QuickSight + Amazon Q). Claim events land in `RAW.LIVE_CLAIMS`. Dynamic tables curate 90 days of plan-day history: premium payments received, claims notified, referrals to claims investigation, settlement SLA breaches, claims per 1,000 premium payments and claims file audit compliance. Snowflake ML scores the 7-day risk that a plan's claims are referred to investigation, forecasts portfolio-wide claims volume and flags claim document rejection rate anomalies. A Cortex Agent answers questions with SOP citations, and an LLM drafts the claims action memo.

Microinsurance premiums are small and paid often, so the claims team sees thousands of premium payments for every claim and has to settle simple claims fast. The plans cover five product lines: hospital cash, personal accident, microlife, home and property, and livelihood cover for small businesses. Two city-wide typhoon events (Tacloban City and Iloilo City) produce claims that settle without investigation. The demo models claims operations only. It makes no legal or regulatory statements, and its SOPs are synthetic.

Interactive diagrams (hover for object names): [Snowflake only](docs/architecture-snowflake.html) | [AWS + Snowflake](docs/architecture-aws.html). The app shows both on its Architecture & Data tab, the current build first. Regenerate them with `python3 docs/build_architecture.py`.

```mermaid
flowchart LR
    subgraph AWS
      SIM[publish_claims.py] --> FH[Amazon Data Firehose<br/>stream ph-banking-microinsurance-claims]
      FH -->|batched JSON| S3[(Amazon S3<br/>claims/ landing)]
      BR[Amazon Bedrock<br/>Claude Sonnet 4.5]
      QS[Amazon QuickSight<br/>dashboard + Q topic]
    end
    subgraph Snowflake
      S3 -->|SQS event| PIPE[Snowpipe AUTO_INGEST] --> LIVE[RAW.LIVE_CLAIMS]
      GEN[02_raw_tables.sql<br/>seeded generator] --> RAW[RAW.PLANS / PLAN_DAILY / CLAIM_DOCUMENTS]
      RAW --> DT[CURATED dynamic tables]
      RAW --> ML[Snowflake ML<br/>CLASSIFICATION risk, FORECAST,<br/>ANOMALY_DETECTION]
      DT --> SV[Semantic view<br/>APP.MICROINSURANCE_ANALYTICS]
      RAW --> CS[Cortex Search<br/>claims SOPs]
      SV --> AG[Cortex Agent<br/>APP.MICROINSURANCE_AGENT]
      CS --> AG
      LIVE --> AL[Alert APP.LIVE_CLAIMS_ALERT<br/>+ email]
      UDF[APP.BEDROCK_GENERATE<br/>external access UDF]
      TK[Task graph: refresh, then rescore]
      APP[Next.js app on SPCS]
    end
    BR <--> UDF
    DT --> APP
    ML --> APP
    LIVE --> APP
    AG --> APP
    UDF --> APP
    DT --> QS
    ML --> QS
    LIVE --> QS
```

The Snowflake-only build drops the AWS subgraph: `APP.SIMULATE_CLAIMS` writes to `RAW.LIVE_CLAIMS`, and the app calls Cortex `AI_COMPLETE` instead of the Bedrock UDF.

## Snowflake Capabilities

| Capability | Implementation |
|-----------|---------------|
| Dynamic Tables | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `CLAIMS_SUMMARY`, `TREND_ANALYSIS` from the RAW tables |
| Snowflake ML | CLASSIFICATION 7-day investigation-referral risk (`ML.ESCALATION_RISK_SCORES`), 14-day claims-volume FORECAST, claim document rejection rate ANOMALY_DETECTION |
| Cortex Search | 14 synthetic claims-handling SOPs (one per microinsurance product and claim cause) in `SEARCH.CLAIMS_SOP_SEARCH` |
| Semantic View | `APP.MICROINSURANCE_ANALYTICS` over plans, claim causes, daily totals and risk |
| Cortex Agent | `APP.MICROINSURANCE_AGENT`: Cortex Analyst over the semantic view plus Cortex Search for SOP citations |
| Cortex AI | `AI_COMPLETE('claude-sonnet-4-5')` for grounded answers, and for the action memo in the Snowflake-only build |
| Alerts + Tasks | `APP.LIVE_CLAIMS_ALERT` logs REFERRED claims and sends email; task graph `TASK_REFRESH_CURATED`, then `TASK_RESCORE_RISK` |
| Snowpark Container Services | Next.js app `APP.PH_BANKING_MICROINSURANCE_APP` with 6 tabs: Executive Cockpit, Predictive, Controls, Live Claims, Ask AI, Architecture & Data |
| Snowpipe | `RAW.LIVE_CLAIMS_PIPE` AUTO_INGEST from S3 (AWS build only) |

## AWS Services

Used only in the AWS + Snowflake build.

| Service | Role in Demo |
|---------|-------------|
| Amazon Data Firehose | Direct PUT stream `ph-banking-microinsurance-claims` receives simulated claim events and writes batches to S3 |
| Amazon S3 | Landing bucket (`claims/`). An event notification goes to the Snowpipe SQS queue |
| Amazon Bedrock | Claude Sonnet 4.5 writes the action memo, called from Snowflake through an external-access UDF |
| Amazon QuickSight | DIRECT_QUERY executive dashboard over Snowflake (daily claims, referrals by plan, referral risk) |
| Amazon Q | Natural-language questions over the QuickSight topic `ph-banking-microinsurance-topic` |
| AWS IAM | Least-privilege roles for S3, Firehose and Bedrock |

## Personas

These personas are fictional.

| Persona | Role | Key Questions |
|---------|------|---------------|
| **Maria Teresa Villanueva** | Head of Claims | "How many claims are we notified per 1,000 premium payments?" "Which claim causes are referred to claims investigation?" |
| **Paolo Reyes Santos** | Claims Analyst | "Which plans are high risk this week, and which SOP applies?" |

## Data

All data is synthetic and seeded, so every rebuild reproduces it. The microinsurer, plans and names are fictional; the cities are real Philippine cities used only as regions. Premium amounts are synthetic peso values, not market rates.

| Table | Rows | Description |
|-------|------|-------------|
| RAW.PLANS | 40 | Microinsurance plans across 5 cities and 5 products (Hospital cash, Personal accident, Microlife, Home and property, and Livelihood), with insured member risk grade |
| RAW.PLAN_DAILY | 3,600 | Daily plan observations over 90 days: premium payments received, premium value (PHP), claims notified, referrals to investigation, settlement SLA breaches, claim cause, claims file audits, claim document rejection rate and average days to settle |
| RAW.CLAIM_DOCUMENTS | 40 | Required, on-file and pending claim file documents per plan |
| SEARCH.CLAIMS_DOCS | 14 | Synthetic claims-handling SOPs indexed for Cortex Search |
| RAW.LIVE_CLAIMS | Grows during the demo | Live claim events from Firehose (AWS build) or `APP.SIMULATE_CLAIMS` (Snowflake-only build) |
| ML.ESCALATION_RISK_SCORES | 40 | 7-day investigation-referral probability and risk band per plan |

## Build Instructions

### Prerequisites
- Snowflake account with ACCOUNTADMIN access, and Cortex AI enabled (AI_COMPLETE, Search, Agent).
- An X-Small warehouse with auto-suspend at or below 120 s, and an existing SPCS compute pool.
- Python 3.11+, `snowflake-connector-python`, Node.js 22+, Docker and the `snow` CLI.
- App image: run `snow spcs image-registry login`, then build and push `ph-banking-microinsurance-app:v1` to the database's `APP.IMAGES` repository (see the header of `snowflake/07_deploy_app.sql`).
- AWS build only: `boto3`, AWS credentials for the target account (us-west-2) with Bedrock access, and QuickSight Enterprise.

### SPCS App
```
<DATABASE>.APP.PH_BANKING_MICROINSURANCE_APP
```

### Tests
```bash
python -m pytest aws snowflake quicksight
```

For a local run, put `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_DATABASE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_AUTHENTICATOR=PROGRAMMATIC_ACCESS_TOKEN`, `SNOWFLAKE_TOKEN` and `DEMO_PLATFORM` in the environment, then run `npm --prefix app run build && npm --prefix app start`.

## Build Modes

Both modes share the same core. They differ in three places, and the app's `DEMO_PLATFORM` setting (in its SPCS spec) switches the memo provider and the Live Claims tab.

| Layer | Snowflake Only | Full AWS + Snowflake |
|---|---|---|
| Live claims | `CALL APP.SIMULATE_CLAIMS(n)` inserts simulated claim events into `RAW.LIVE_CLAIMS`. This simulates a claim feed; it is not Snowpipe Streaming | `aws/publish_claims.py` to Amazon Data Firehose, then S3, SQS and Snowpipe AUTO_INGEST |
| Action memo | Cortex `AI_COMPLETE('claude-sonnet-4-5')` | Amazon Bedrock Claude Sonnet 4.5 through `APP.BEDROCK_GENERATE` |
| BI and natural-language questions | The SPCS app is the dashboard; questions go to the Cortex Agent | Also a QuickSight dashboard and an Amazon Q topic |
| App setting | `DEMO_PLATFORM: snowflake` | `DEMO_PLATFORM: aws` |

### Snowflake Only

```bash
# 1. Core data and dynamic tables (guarded: new isolated database only)
python snowflake/run_core.py --database PHILIPPINES_BANKING_MICROINSURANCE_SNOWFLAKE --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --apply
# 2. Native claim feed, ML, search, semantic view, agent, alert and task graph
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_MICROINSURANCE_SNOWFLAKE --platform snowflake --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com
# 3. App on SPCS with DEMO_PLATFORM=snowflake (push the image first)
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_MICROINSURANCE_SNOWFLAKE --platform snowflake --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com --files 07_deploy_app.sql --compute-pool <COMPUTE_POOL>
```

During the demo:
- Run `CALL APP.SIMULATE_CLAIMS(20)` to add live claim events. For a continuous feed, run `ALTER TASK APP.TASK_SIMULATE_CLAIMS RESUME`, and `SUSPEND` it afterwards.
- Run `EXECUTE ALERT APP.LIVE_CLAIMS_ALERT` to raise the alert email.
- Run `EXECUTE TASK APP.TASK_REFRESH_CURATED` to refresh the curated tables and rescore escalation risk.

Afterwards, drop the database or run `ALTER SERVICE APP.PH_BANKING_MICROINSURANCE_APP SUSPEND`.

### Full AWS + Snowflake

```bash
# 1. Core data and dynamic tables (guarded: new isolated database only)
python snowflake/run_core.py --database PHILIPPINES_BANKING_MICROINSURANCE_AWS --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --apply
# 2. AWS ingestion and Bedrock (dry run first, then --apply)
python aws/setup_aws.py --database PHILIPPINES_BANKING_MICROINSURANCE_AWS --account <AWS_ACCOUNT_ID> --connection <CONNECTION> --apply
# 3. ML, search, semantic view, agent, alert and task graph
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_MICROINSURANCE_AWS --platform aws --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com
# 4. App on SPCS with DEMO_PLATFORM=aws (push the image first)
python snowflake/run_intelligence.py --database PHILIPPINES_BANKING_MICROINSURANCE_AWS --platform aws --warehouse <XS_WAREHOUSE> --connection <CONNECTION> --alert-email you@example.com --files 07_deploy_app.sql --compute-pool <COMPUTE_POOL>
# 5. QuickSight dashboard and Q topic (needs an existing Snowflake data source)
python quicksight/build_dashboards.py --database PHILIPPINES_BANKING_MICROINSURANCE_AWS --account <AWS_ACCOUNT_ID> --principal-arn <QUICKSIGHT_USER_ARN> --data-source-arn <DATA_SOURCE_ARN> --prefix ph-banking-microinsurance --apply --update --with-topic
```

QuickSight objects must be shared with the QuickSight user who signs in (`--principal-arn`); otherwise the console shows nothing.

During the demo:
- Run `python aws/publish_claims.py --count 20` to send live claim events. Firehose buffers for up to 60 seconds before writing to S3.
- Run `EXECUTE ALERT APP.LIVE_CLAIMS_ALERT` to raise the alert email.
- Run `EXECUTE TASK APP.TASK_REFRESH_CURATED` to refresh the curated tables and rescore escalation risk.

Afterwards, `python aws/teardown_aws.py --database PHILIPPINES_BANKING_MICROINSURANCE_AWS --account <AWS_ACCOUNT_ID> --connection <CONNECTION> --apply` removes the AWS resources and the account-level Bedrock external-access and S3 storage integrations. It leaves the email integration `PH_BANKING_MICROINSURANCE_EMAIL_INT`, which the Snowflake-only build also uses.

## Business Impact

Industry research and Snowflake customer outcomes:
- **Claims experience drives retention**: "$170 billion in premium is at risk over the next 5 years as customers switch carriers due to not being fully satisfied by the claims process" -- [Accenture, Transforming claims and underwriting with AI](https://www.accenture.com/us-en/insights/insurance/ai-transforming-claims-underwriting)
- **Emirates Insurance** (Snowflake customer) reports "30-40% faster motor claims registration with AI" and "380 hours of work automated over 3 months" -- [Snowflake customer story: Emirates Insurance](https://www.snowflake.com/en/customers/all-customers/case-study/Emirates/)

## Key Demo Numbers

These figures are synthetic and come from the seeded demo data. Forecast and anomaly figures can shift slightly with the build day.

- **40 plans** across 5 Philippine cities and 5 microinsurance products, 3,600 plan-days over 90 days; **2,005,461 premium payments received** worth PHP 224.0 M
- **637 claims notified** (0.32 per 1,000 premium payments), of which **253** were referred to claims investigation (escalation rate 39.7%); **117 settlement SLA breaches**
- **Incomplete claim documents** produce the most referrals (59 of 121 claims), ahead of hospital inpatient stays (51 of 148); Quezon City has the most referrals (87); the 16 typhoon event claims (Tacloban City and Iloilo City) always settle without investigation
- **Referral risk model** out-of-time holdout: precision 0.58, recall 0.42 at a 0.5 threshold, against a 0.30 base rate. 11 plans are high risk; the top plan is PLN-0020, at 99.1%
- **14-day claims forecast** with prediction intervals; **32 of 640** plan-days flagged as claim document rejection rate anomalies
- **Claims file audit compliance 77.4%**, claim file coverage 51.5%, with 22 documents pending
- **14 SOPs** indexed for Cortex Search and cited by ID in agent answers

## License

Apache 2.0 — See [LICENSE](LICENSE) for details.

This is a personal demo project and is not an official Snowflake offering. It comes with no support or warranty. Industry metrics cited are from publicly available third-party sources and Snowflake customer stories; they represent reported outcomes and are not guarantees of results. The demo does not provide legal, regulatory or insurance advice.
