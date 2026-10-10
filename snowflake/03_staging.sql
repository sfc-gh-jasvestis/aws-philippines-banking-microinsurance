-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.PLAN_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.PLAN_DAILY observation
    LEFT JOIN RAW.PLANS plan ON plan.ID = observation.ENTITY_ID
    WHERE plan.ID IS NULL OR observation.PREMIUM_COUNT < 0
       OR observation.VALUE_PHP < 0
       OR observation.ESCALATED_COUNT < 0 OR observation.ESCALATED_COUNT > observation.CLAIM_COUNT
       OR observation.CLAIM_COUNT > observation.PREMIUM_COUNT
       OR observation.SLA_BREACHED > observation.ESCALATED_COUNT
       OR observation.REVIEW_COMPLETED > observation.REVIEW_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
