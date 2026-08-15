-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Microinsurance Claims Analytics & Fraud Detection
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- POLICIES: 2,400,000 rows — Active microinsurance policies (life, health, accident, property)
-- CLAIMS: 185,000 rows — 12 months of claims submitted
-- CLAIM_DOCUMENTS: 520,000 rows — Scanned supporting documents (medical certs, receipts, IDs)
-- PAYOUTS: 142,000 rows — Claims paid with amount and method
-- FRAUD_HISTORY: 3,800 rows — Confirmed fraudulent claims for model training
-- PRODUCTS: 24 rows — Microinsurance product catalog
-- IC_REGULATIONS: 65 rows — Insurance Commission regulatory requirements
