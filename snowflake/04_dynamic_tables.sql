-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Microinsurance Claims Analytics & Fraud Detection
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA CURATED;

-- CLAIMS_ENRICHED: Claims enriched with parsed documents and risk scores
-- Source: CLAIMS, CLAIM_DOCUMENTS, POLICIES
CREATE OR REPLACE DYNAMIC TABLE CURATED.CLAIMS_ENRICHED
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CLAIMS_WH
AS
SELECT * FROM RAW.CLAIMS;
-- TODO: Replace with actual join/aggregation logic per demo

-- FRAUD_INDICATORS: Red flag signals per claim (multiple claims, document inconsistencies)
-- Source: CLAIMS, CLAIM_DOCUMENTS, FRAUD_HISTORY
CREATE OR REPLACE DYNAMIC TABLE CURATED.FRAUD_INDICATORS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CLAIMS_WH
AS
SELECT * FROM RAW.CLAIMS;
-- TODO: Replace with actual join/aggregation logic per demo

-- LOSS_RATIO_ANALYSIS: Loss ratios by product, region, and distribution channel
-- Source: POLICIES, CLAIMS, PAYOUTS, PRODUCTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.LOSS_RATIO_ANALYSIS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CLAIMS_WH
AS
SELECT * FROM RAW.POLICIES;
-- TODO: Replace with actual join/aggregation logic per demo

-- PROCESSING_METRICS: Claims cycle time and SLA compliance tracking
-- Source: CLAIMS, PAYOUTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.PROCESSING_METRICS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = CLAIMS_WH
AS
SELECT * FROM RAW.CLAIMS;
-- TODO: Replace with actual join/aggregation logic per demo

