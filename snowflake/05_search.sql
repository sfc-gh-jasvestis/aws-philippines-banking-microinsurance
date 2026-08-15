-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Microinsurance Claims Analytics & Fraud Detection
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.IC_REGULATION_SEARCH
  ON REGULATION_TEXT
  ATTRIBUTES CIRCULAR_NUMBER, PRODUCT_TYPE, REQUIREMENT_TYPE
  WAREHOUSE = CLAIMS_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.IC_REGULATIONS
);
