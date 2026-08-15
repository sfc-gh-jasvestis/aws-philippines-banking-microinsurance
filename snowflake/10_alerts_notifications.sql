-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Microinsurance Claims Analytics & Fraud Detection
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_banking_microinsurance_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: FRAUD_FLAG_ALERT
CREATE OR REPLACE ALERT APP.FRAUD_FLAG_ALERT
  WAREHOUSE = CLAIMS_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'High-value claim flagged for potential fraud'
IF (EXISTS (
  SELECT 1 FROM CURATED.CLAIMS_ENRICHED
  WHERE 1=1 -- Condition: FRAUD_PROBABILITY > 0.85 AND CLAIM_AMOUNT > 50000
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_banking_microinsurance_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Microinsurance Claims Analytics & Fraud Detection: High-value claim flagged for potential fraud',
    'High-value claim flagged for potential fraud'
  );

ALTER ALERT APP.FRAUD_FLAG_ALERT RESUME;

-- Alert: SLA_BREACH_ALERT
CREATE OR REPLACE ALERT APP.SLA_BREACH_ALERT
  WAREHOUSE = CLAIMS_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Claims backlog exceeding 24-hour SLA capacity'
IF (EXISTS (
  SELECT 1 FROM CURATED.CLAIMS_ENRICHED
  WHERE 1=1 -- Condition: CLAIMS_PENDING_24H > 500
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_banking_microinsurance_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Microinsurance Claims Analytics & Fraud Detection: Claims backlog exceeding 24-hour SLA capacity',
    'Claims backlog exceeding 24-hour SLA capacity'
  );

ALTER ALERT APP.SLA_BREACH_ALERT RESUME;

