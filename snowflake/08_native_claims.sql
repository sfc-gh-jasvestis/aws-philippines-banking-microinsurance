-- ============================================================================
-- 08_native_claims.sql - Snowflake-only build: live claim feed without AWS.
-- Creates RAW.LIVE_CLAIMS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_CLAIMS(N), which inserts synthetic
-- claim events with the same value ranges and ~10% REFERRED rate as
-- aws/publish_claims.py. Rows are inserted directly; this simulates an
-- claim feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_CLAIMS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_CLAIMS (
  PLAN_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, AMOUNT_PHP FLOAT, DAYS_OPEN FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_CLAIMS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_CLAIMS (PLAN_ID, EVENT_TS, AMOUNT_PHP, DAYS_OPEN, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'PLN-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS PLAN_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_REFERRED,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs constant arguments, so the referred offset is applied outside it.
    SELECT PLAN_ID, TS,
           ROUND(IFF(IS_REFERRED, 18000, 6000) * EXP(NORMAL(0, 0.5, RANDOM())), 0),
           ROUND(IFF(IS_REFERRED, 6, 0.3) * EXP(NORMAL(0, 0.4, RANDOM())), 0),
           IFF(IS_REFERRED, 'REFERRED', 'ACCEPTED'), TS, 'APP.SIMULATE_CLAIMS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_CLAIMS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_CLAIMS(5);
