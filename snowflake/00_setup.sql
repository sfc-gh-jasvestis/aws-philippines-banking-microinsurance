-- ============================================================================
-- Microinsurance Claims Analytics & Fraud Detection
-- 55M uninsured Filipinos — microinsurance claims must be processed in 24 hours or customers lose trust. Snowflake parses claim documents with AI, classifies fraud with ML, and alerts adjusters before payouts — all in native SQL.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS MICROINSURANCE;
CREATE WAREHOUSE IF NOT EXISTS CLAIMS_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE MICROINSURANCE;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE CLAIMS_WH;
