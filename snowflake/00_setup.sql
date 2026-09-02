-- Generated from generator/demo_specs/aws-philippines-banking-microinsurance.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-banking-microinsurance
-- This is the schema that is actually deployed for PH_BANKING_MICROINSURANCE.

-- PH_BANKING_MICROINSURANCE  (Microinsurance Claims Analytics & Fraud Detection)
-- generated from generator/demo_specs/aws-philippines-banking-microinsurance.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_BANKING_MICROINSURANCE;
CREATE SCHEMA IF NOT EXISTS PH_BANKING_MICROINSURANCE.RAW;
CREATE SCHEMA IF NOT EXISTS PH_BANKING_MICROINSURANCE.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_BANKING_MICROINSURANCE.APP;
USE DATABASE PH_BANKING_MICROINSURANCE;

-- 5 real regions; entity names carry their region so the two always agree
