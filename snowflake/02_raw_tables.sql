-- Synthetic plan-day observations for a fictional Philippine microinsurer.
-- A plan is one microinsurance product written in one city.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-plan claim propensity, drift between
-- claims file audits, missed audits, product-weighted claim causes, claims
-- settled without investigation, and two city-wide typhoon events.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.PLANS AS
WITH plans AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS PLAN_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT PLAN_INDEX,
         MOD(ABS(HASH(PLAN_INDEX, 'phmi-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(PLAN_INDEX, 'phmi-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(PLAN_INDEX, 'phmi-review')), 1000000) / 1e6 AS U_REVIEW,
         MOD(ABS(HASH(PLAN_INDEX, 'phmi-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(PLAN_INDEX, 'phmi-tier')), 1000000) / 1e6 AS U_TIER
  FROM plans
)
SELECT 'PLN-' || LPAD(PLAN_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic plan ' || LPAD(PLAN_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every city and product
       -- is present. All plans are written in the Philippines (PHP).
       CASE MOD(PLAN_INDEX, 5) WHEN 0 THEN 'Quezon City' WHEN 1 THEN 'Cebu City'
            WHEN 2 THEN 'Davao City' WHEN 3 THEN 'Iloilo City' ELSE 'Tacloban City' END AS REGION,
       CASE MOD(PLAN_INDEX, 8) WHEN 0 THEN 'Hospital cash' WHEN 1 THEN 'Hospital cash'
            WHEN 2 THEN 'Hospital cash' WHEN 3 THEN 'Personal accident' WHEN 4 THEN 'Personal accident'
            WHEN 5 THEN 'Microlife' WHEN 6 THEN 'Home and property'
            ELSE 'Livelihood' END AS CATEGORY,
       PLAN_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.2 + U_AGE * 5.8, 1) AS PLAN_AGE_YEARS,
       -- Base daily probability of a claim referred to investigation 0.4%-3%; ~15% of
       -- plans are chronically weak (x3).
       (0.004 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_ESCALATION_RATE,
       7 * (1 + FLOOR(U_REVIEW * 3)) AS REVIEW_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS REVIEW_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.PLAN_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide typhoon events; every plan in the city
  -- notifies a claim that settles without investigation.
  SELECT * FROM VALUES (24, 'Tacloban City'), (61, 'Iloilo City') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT r.ID AS ENTITY_ID, r.PLAN_INDEX, r.CATEGORY, r.REGION, r.PLAN_AGE_YEARS,
         r.BASE_ESCALATION_RATE, r.REVIEW_INTERVAL_DAYS, r.REVIEW_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + r.PLAN_INDEX * 5, r.REVIEW_INTERVAL_DAYS) AS DAYS_SINCE_REVIEW,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-fail')), 1000000) / 1e6 AS U_FAIL,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-clear')), 1000000) / 1e6 AS U_CLEAR,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-type')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(r.ID, d.DAY_INDEX, 'phmi-sla')), 1000000) / 1e6 AS U_SLA,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.PLANS r CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = r.REGION
), review AS (
  SELECT *,
         IFF(DAYS_SINCE_REVIEW = 0, 1, 0) AS REVIEW_DUE,
         IFF(DAYS_SINCE_REVIEW = 0 AND U_DONE < REVIEW_COMPLETION_PROB, 1, 0) AS REVIEW_COMPLETED,
         -- Early-warning drift rises between claims file audits; weak
         -- review discipline carries it over.
         DAYS_SINCE_REVIEW / REVIEW_INTERVAL_DAYS + (1 - REVIEW_COMPLETION_PROB) AS DRIFT
  FROM base
), stress AS (
  SELECT *,
         CASE WHEN U_FAIL < LEAST(0.5, BASE_ESCALATION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PLAN_AGE_YEARS))) / 4 THEN 2
              WHEN U_FAIL < LEAST(0.5, BASE_ESCALATION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + PLAN_AGE_YEARS))) THEN 1
              ELSE 0 END AS STRESS_COUNT
  FROM review
), cases AS (
  SELECT *,
         -- About 85% of stressed plan-days produce claims that are
         -- escalated to claims investigation; the rest close without a claim.
         IFF(CITY_EVENT, 0, IFF(U_DETECT < 0.85, STRESS_COUNT, 0)) AS ESCALATED_COUNT,
         -- Claims settled by the claims team without investigation.
         IFF(CITY_EVENT, 1, IFF(U_CLEAR < CASE CATEGORY WHEN 'Microlife' THEN 0.20
                                                      WHEN 'Home and property' THEN 0.12
                                                      WHEN 'Livelihood' THEN 0.14 ELSE 0.08 END, 1, 0)) AS RESOLVED_COUNT
  FROM stress
), measured AS (
  SELECT *,
         ESCALATED_COUNT + RESOLVED_COUNT AS CLAIM_COUNT,
         ROUND(CASE CATEGORY WHEN 'Hospital cash' THEN 880 WHEN 'Personal accident' THEN 310
                             WHEN 'Microlife' THEN 640 WHEN 'Home and property' THEN 160 ELSE 115 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.8 * STRESS_COUNT)) AS PREMIUM_COUNT,
         CASE CATEGORY WHEN 'Hospital cash' THEN 115 WHEN 'Personal accident' THEN 55
                       WHEN 'Microlife' THEN 85 WHEN 'Home and property' THEN 210
                       ELSE 340 END
           * (0.8 + 0.4 * U_NOISE) AS AVG_PREMIUM_PHP
  FROM cases
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       PREMIUM_COUNT,
       ROUND(PREMIUM_COUNT * AVG_PREMIUM_PHP, 0) AS VALUE_PHP,
       CLAIM_COUNT, ESCALATED_COUNT,
       IFF(ESCALATED_COUNT > 0 AND U_SLA < 0.6, 1, 0) AS SLA_BREACHED,
       CASE WHEN CLAIM_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Typhoon event'
            WHEN CATEGORY = 'Hospital cash' THEN IFF(U_TYPE < 0.5, 'Hospital inpatient stay', IFF(U_TYPE < 0.8, 'Surgical benefit', 'Incomplete claim documents'))
            WHEN CATEGORY = 'Personal accident' THEN IFF(U_TYPE < 0.45, 'Road accident injury', IFF(U_TYPE < 0.8, 'Accidental death', 'Incomplete claim documents'))
            WHEN CATEGORY = 'Microlife' THEN IFF(U_TYPE < 0.55, 'Hospital inpatient stay', 'Death benefit')
            WHEN CATEGORY = 'Home and property' THEN IFF(U_TYPE < 0.45, 'Fire damage', IFF(U_TYPE < 0.8, 'Storm damage', 'Incomplete claim documents'))
            ELSE IFF(U_TYPE < 0.5, 'Business interruption', IFF(U_TYPE < 0.75, 'Stock damage', 'Incomplete claim documents')) END AS CLAIM_CAUSE,
       REVIEW_DUE, REVIEW_COMPLETED,
       ROUND(0.5 + 2.0 * DRIFT + 3.0 * STRESS_COUNT + U_NOISE * 0.8, 2) AS DOC_REJECT_PCT,
       ROUND(2.5 + 3 * DRIFT + 4 * STRESS_COUNT + U_NOISE * 1.5, 1) AS AVG_DAYS_TO_SETTLE,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Claim file document coverage per plan (snapshot).
CREATE TABLE RAW.CLAIM_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Hospital cash' THEN 'Hospital discharge summary'
                     WHEN 'Personal accident' THEN 'Police and medical report'
                     WHEN 'Microlife' THEN 'Beneficiary nomination form'
                     WHEN 'Home and property' THEN 'Loss adjuster report'
                     ELSE 'Business loss statement' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'phmi-req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'phmi-file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'phmi-file')), 5) < 1 + MOD(ABS(HASH(ID, 'phmi-req')), 4),
           MOD(ABS(HASH(ID, 'phmi-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.PLANS;
