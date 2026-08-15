-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Microinsurance Claims Analytics & Fraud Detection
-- ============================================================================
USE DATABASE MICROINSURANCE;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.CLAIMS_INTELLIGENCE_AGENT
  COMMENT = 'Microinsurance Claims Analytics & Fraud Detection AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'MICROINSURANCE.APP.CLAIMS_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'MICROINSURANCE.SEARCH.IC_REGULATION_SEARCH', TOOL_DESCRIPTION => 'Search documents for Banking & Insurance information')
  )
  SYSTEM_PROMPT = 'You are the Claims Intelligence Agent for a Philippine microinsurance company with 2.4M policies, processing 185K claims annually with a 24-hour SLA target.';
