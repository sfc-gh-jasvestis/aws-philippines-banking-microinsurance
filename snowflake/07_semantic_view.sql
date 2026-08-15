-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Microinsurance Claims Analytics & Fraud Detection
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.CLAIMS_ANALYTICS
  COMMENT = 'Microinsurance claims processing, fraud detection, and loss ratio analytics'
AS
  TABLES (
    CURATED.CLAIMS_ENRICHED AS claims_enriched,CURATED.FRAUD_INDICATORS AS fraud_indicators,CURATED.LOSS_RATIO_ANALYSIS AS loss_ratio_analysis,CURATED.PROCESSING_METRICS AS processing_metrics
  );
