-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Microinsurance Claims Analytics & Fraud Detection
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_PARSE_DOCUMENTS
  WAREHOUSE = CLAIMS_WH
  SCHEDULE = 'USING CRON 0 */2 * * * UTC'
  COMMENT = 'Parse new claim documents with AI_PARSE_DOCUMENT'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_SCORE_CLAIMS
  WAREHOUSE = CLAIMS_WH
  AFTER APP.TASK_PARSE_DOCUMENTS
  COMMENT = 'Score claims for fraud risk and auto-adjudication'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_ALERT_INVESTIGATORS
  WAREHOUSE = CLAIMS_WH
  AFTER APP.TASK_SCORE_CLAIMS
  COMMENT = 'Alert investigation team for high-risk claims'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_ALERT_INVESTIGATORS RESUME;
ALTER TASK APP.TASK_SCORE_CLAIMS RESUME;
ALTER TASK APP.TASK_PARSE_DOCUMENTS RESUME;
