-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-claims alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_CLAIMS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic claims-handling knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.CLAIMS_DOCS AS
WITH types AS (
  SELECT DISTINCT r.CLAIM_CAUSE, a.CATEGORY
  FROM RAW.PLAN_DAILY r JOIN RAW.PLANS a ON a.ID = r.ENTITY_ID
  WHERE r.ESCALATED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, CLAIM_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  CLAIM_CAUSE,
  CATEGORY || ' - ' || CLAIM_CAUSE || ' claims handling' AS TITLE,
  'Synthetic demo SOP for a fictional microinsurer. It does not state any regulatory requirement. Microinsurance product: ' || CATEGORY
  || '. Claim cause: ' || CLAIM_CAUSE || '. '
  || 'Step 1: register the claim, acknowledge it to the insured member and assign a claims officer within one working day. '
  || 'Step 2: ' || CASE
       WHEN CLAIM_CAUSE = 'Hospital inpatient stay' THEN 'request the hospital discharge summary or certificate of confinement, confirm the confinement dates against the insured member''s cover period, and pay the daily hospital cash benefit for the confirmed days only.'
       WHEN CLAIM_CAUSE = 'Surgical benefit' THEN 'check the operative record against the plan''s schedule of surgical benefits and refer repeat claims from the same hospital within 30 days to the investigation desk.'
       WHEN CLAIM_CAUSE = 'Incomplete claim documents' THEN 'send the insured member a checklist of missing documents by text message and through the partner agent, log each attempt, and pause the settlement SLA clock only as the microinsurer''s claims manual allows.'
       WHEN CLAIM_CAUSE = 'Road accident injury' THEN 'obtain the police or barangay incident report and the attending physician''s medical certificate, and check the injury against the plan''s schedule of benefits.'
       WHEN CLAIM_CAUSE = 'Accidental death' THEN 'obtain the death certificate and the police or barangay incident report, confirm the accident date falls within the cover period, and refer the claim to the investigation desk before payment.'
       WHEN CLAIM_CAUSE = 'Death benefit' THEN 'verify the death certificate and the beneficiary nomination form, and confirm the beneficiary''s identity before payment.'
       WHEN CLAIM_CAUSE = 'Fire damage' THEN 'appoint a loss adjuster, obtain the fire bureau report, and record the damaged items against the declared sum covered.'
       WHEN CLAIM_CAUSE = 'Storm damage' THEN 'request dated photographs and a contractor quotation, and compare the event date with public weather reports for the area.'
       WHEN CLAIM_CAUSE = 'Business interruption' THEN 'request the latest management accounts and compare the claimed loss of income with the plan''s indemnity period.'
       WHEN CLAIM_CAUSE = 'Stock damage' THEN 'request the stock records and purchase invoices, and appoint a loss adjuster for claims above the plan''s adjuster threshold.'
       ELSE 'review the claim against the plan profile and refer it to investigation if unexplained.'
     END
  || ' Step 3: if the claim document rejection rate on the plan exceeds 5% or the average days to settle exceeds 10 after triage, keep the claim open and request a plan review. '
  || 'Step 4: record the outcome; if the claim was referred to investigation or missed its settlement SLA, log it for the claims report.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.CLAIMS_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, CLAIM_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, CLAIM_CAUSE, CONTENT FROM SEARCH.CLAIMS_DOCS);

-- ---------- Claim document rejection rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.DOC_REJECT_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, DOC_REJECT_PCT::FLOAT AS DOC_REJECT
FROM RAW.PLAN_DAILY;
CREATE OR REPLACE VIEW ML.DOC_REJECT_TRAIN AS
SELECT * FROM ML.DOC_REJECT_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.DOC_REJECT_SERIES);
CREATE OR REPLACE VIEW ML.DOC_REJECT_DETECT AS
SELECT * FROM ML.DOC_REJECT_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.DOC_REJECT_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.DOC_REJECT_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.DOC_REJECT_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'DOC_REJECT',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.DOC_REJECT_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS DOC_REJECT, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.DOC_REJECT_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.DOC_REJECT_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'DOC_REJECT'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.MICROINSURANCE_ANALYTICS
  TABLES (
    plans AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per microinsurance plan (one product in one city), 90-day totals',
    risk AS ML.ESCALATION_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day claims escalation probability per plan',
    claims AS CURATED.CLAIMS_SUMMARY PRIMARY KEY (CLAIM_CAUSE)
      COMMENT = 'Claims, escalations and settlement SLA breaches by claim cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Portfolio-wide totals per day'
  )
  RELATIONSHIPS (risk_plan AS risk (ENTITY_ID) REFERENCES plans)
  FACTS (
    plans.claims_f AS CLAIM_COUNT,
    plans.escalated_f AS ESCALATED_COUNT,
    plans.breaches_f AS SLA_BREACH_COUNT,
    plans.premiums_f AS PREMIUM_COUNT,
    plans.value_f AS VALUE_PHP,
    plans.review_due_f AS REVIEW_DUE,
    plans.review_done_f AS REVIEW_COMPLETED,
    risk.escalation_prob_f AS ESCALATION_PROB_7D,
    claims.cause_claims_f AS CLAIM_COUNT,
    claims.reason_escalated_f AS ESCALATED_COUNT,
    claims.reason_breaches_f AS SLA_BREACH_COUNT,
    claims.reason_value_f AS EXPOSED_VALUE_PHP,
    daily.day_claims_f AS CLAIM_COUNT,
    daily.day_escalated_f AS ESCALATED_COUNT,
    daily.day_value_f AS VALUE_PHP
  )
  DIMENSIONS (
    plans.plan_id AS ENTITY_ID WITH SYNONYMS = ('plan', 'microinsurance plan', 'entity'),
    plans.plan_name AS ENTITY_NAME,
    plans.city AS REGION WITH SYNONYMS = ('city', 'region', 'market')
      COMMENT = 'Philippine city where the plan is written',
    plans.product AS CATEGORY WITH SYNONYMS = ('product', 'microinsurance product', 'product line')
      COMMENT = 'Hospital cash, Personal accident, Microlife, Home and property or Livelihood',
    plans.risk_tier AS RISK_TIER COMMENT = 'Insured member risk grade 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    claims.claim_cause AS CLAIM_CAUSE WITH SYNONYMS = ('claim cause', 'reason', 'cause'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    plans.plan_count AS COUNT(plans.plan_id)
      WITH SYNONYMS = ('number of plans', 'entities', 'number of entities'),
    plans.claims_per_1k AS 1000 * SUM(plans.claims_f) / NULLIF(SUM(plans.premiums_f), 0)
      WITH SYNONYMS = ('claims per 1,000 premium payments', 'claims frequency')
      COMMENT = 'Claims notified per 1,000 premium payments received',
    plans.escalation_rate_pct AS 100 * SUM(plans.escalated_f) / NULLIF(SUM(plans.claims_f), 0)
      COMMENT = 'Claims escalated to claims investigation / claims',
    plans.claim_cases AS SUM(plans.claims_f) WITH SYNONYMS = ('claims', 'claims notified'),
    plans.escalated_cases AS SUM(plans.escalated_f) WITH SYNONYMS = ('escalations', 'investigation referrals'),
    plans.sla_breaches AS SUM(plans.breaches_f) WITH SYNONYMS = ('settlement SLA misses'),
    plans.premiums_due AS SUM(plans.premiums_f),
    plans.total_value_php AS SUM(plans.value_f) WITH SYNONYMS = ('premium value', 'value in PHP'),
    plans.review_compliance_pct AS 100 * SUM(plans.review_done_f) / NULLIF(SUM(plans.review_due_f), 0)
      COMMENT = 'Claims file audits completed / audits due',
    risk.avg_escalation_prob AS AVG(risk.escalation_prob_f),
    claims.cause_claims AS SUM(claims.cause_claims_f),
    claims.reason_escalated AS SUM(claims.reason_escalated_f),
    claims.reason_breaches AS SUM(claims.reason_breaches_f),
    claims.reason_escalation_rate_pct AS 100 * SUM(claims.reason_escalated_f) / NULLIF(SUM(claims.cause_claims_f), 0),
    daily.daily_claims AS SUM(daily.day_claims_f),
    daily.daily_escalated AS SUM(daily.day_escalated_f),
    daily.daily_value_php AS SUM(daily.day_value_f)
  )
  COMMENT = 'Synthetic Philippines microinsurance claims operations analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.MICROINSURANCE_AGENT
  COMMENT = 'Claims assistant over a synthetic Philippine microinsurer'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give plan IDs and numbers with units (PHP, %). Do not give legal or regulatory advice."
  orchestration: "Use microinsurance_analyst for premiums, claims, escalations, settlement SLA breaches, claims per 1,000 premium payments, claims file audit compliance, plans, cities, microinsurance products, claim causes and escalation risk. Use sop_search for claims-handling procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: microinsurance_analyst
      description: "Premiums received, premium value in PHP, claims, escalations to claims investigation, settlement SLA breaches, claims per 1,000 premium payments, claims file audit compliance, claim causes and escalation risk scores by plan, city and microinsurance product"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic claims-handling SOPs by microinsurance product and claim cause"
tool_resources:
  microinsurance_analyst:
    semantic_view: __DEMO_DB__.APP.MICROINSURANCE_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.CLAIMS_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-claims alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), PLAN_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_PHP FLOAT, DAYS_OPEN FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_BANKING_MICROINSURANCE_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (PLAN_ID, EVENT_TS, AMOUNT_PHP, DAYS_OPEN, SOP_HINT)
    SELECT p.PLAN_ID, p.EVENT_TS, p.AMOUNT_PHP, p.DAYS_OPEN,
           'Check ' || r.CATEGORY || ' claims SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_CLAIMS p
    JOIN RAW.PLANS r ON r.ID = p.PLAN_ID
    LEFT JOIN ML.ESCALATION_RISK_SCORES s ON s.ENTITY_ID = p.PLAN_ID
    WHERE p.STATUS = 'REFERRED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PLAN_ID = p.PLAN_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_BANKING_MICROINSURANCE_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Referred claim alert',
      'New referred claims logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_CLAIMS_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_CLAIMS p
    WHERE p.STATUS = 'REFERRED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.PLAN_ID = p.PLAN_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();
-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.CLAIMS_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.ESCALATION_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.ESCALATION_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.ESCALATION_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'PLAN_AGE_YEARS', PLAN_AGE_YEARS,
             'DOC_REJECT_PCT', DOC_REJECT_PCT, 'AVG_DAYS_TO_SETTLE', AVG_DAYS_TO_SETTLE,
             'DOC_REJECT_7D', DOC_REJECT_7D, 'ESCALATED_30D', ESCALATED_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:ESCALATED::FLOAT, 4) AS ESCALATION_PROB_7D,
         CASE WHEN PRED:probability:ESCALATED::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:ESCALATED::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
