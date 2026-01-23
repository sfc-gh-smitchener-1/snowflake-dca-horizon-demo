-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT - OBSERVABILITY VIEWS
-- ============================================================================
-- 
-- Creates observability views for monitoring:
-- - Contract health
-- - Data quality
-- - SLA compliance
-- - Tag coverage
-- - Access patterns
--
-- RUN AS: DATA_ADMIN
-- ============================================================================

USE ROLE DATA_ADMIN;
USE WAREHOUSE ANALYTICS_WH;
USE DATABASE GOVERNANCE;

-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS GOVERNANCE.OBSERVABILITY
    COMMENT = 'Observability views for monitoring contract health and data quality';

USE SCHEMA OBSERVABILITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: DASHBOARD KPIs
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_DASHBOARD_KPIS AS
SELECT
    -- Contract metrics
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS WHERE STATUS = 'active') AS ACTIVE_CONTRACTS,
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS WHERE HEALTH_STATUS = 'GREEN') AS HEALTHY_CONTRACTS,
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS WHERE HEALTH_STATUS = 'YELLOW') AS WARNING_CONTRACTS,
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS WHERE HEALTH_STATUS = 'RED') AS CRITICAL_CONTRACTS,
    
    -- Quality metrics
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.QUALITY_RULES WHERE IS_ACTIVE = TRUE) AS ACTIVE_QUALITY_RULES,
    (SELECT AVG(PASS_RATE) FROM CONTRACT_REGISTRY.QUALITY_RULE_RESULTS 
     WHERE RUN_AT > DATEADD('day', -1, CURRENT_TIMESTAMP())) AS QUALITY_PASS_RATE_24H,
    
    -- Consumer metrics
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONSUMERS WHERE IS_ACTIVE = TRUE) AS ACTIVE_CONSUMERS,
    
    -- Alert metrics
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.ALERTS WHERE STATUS = 'OPEN') AS OPEN_ALERTS,
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.ALERTS 
     WHERE STATUS = 'OPEN' AND SEVERITY = 'error') AS CRITICAL_ALERTS,
    
    -- Data metrics
    (SELECT COUNT(*) FROM RAW_DEV.RAW_SIS.STUDENT_RAW WHERE _IS_CURRENT) AS TOTAL_STUDENTS,
    (SELECT COUNT(*) FROM RAW_DEV.RAW_SIS.SCHOOL_RAW WHERE _IS_CURRENT) AS TOTAL_SCHOOLS,
    (SELECT COUNT(*) FROM RAW_DEV.RAW_HR.STAFF_RAW WHERE _IS_CURRENT) AS TOTAL_STAFF,
    
    CURRENT_TIMESTAMP() AS SNAPSHOT_TIME;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: CONTRACT HEALTH DASHBOARD
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_CONTRACT_HEALTH_DASHBOARD AS
SELECT
    c.CONTRACT_ID,
    c.VERSION,
    c.STATUS,
    c.PRODUCER_TEAM,
    c.TARGET_DATABASE || '.' || c.TARGET_SCHEMA || '.' || c.TARGET_TABLE AS FULL_TABLE_NAME,
    c.GOVERNANCE_CLASSIFICATION,
    c.HEALTH_STATUS,
    c.FRESHNESS_MAX_MINUTES,
    c.COMPLETENESS_THRESHOLD,
    
    -- Quality metrics
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.QUALITY_RULES qr 
     WHERE qr.CONTRACT_ID = c.CONTRACT_ID AND qr.IS_ACTIVE = TRUE) AS QUALITY_RULE_COUNT,
    (SELECT AVG(PASS_RATE) FROM CONTRACT_REGISTRY.QUALITY_RULE_RESULTS qrr
     JOIN CONTRACT_REGISTRY.QUALITY_RULES qr ON qrr.RULE_ID = qr.RULE_ID
     WHERE qr.CONTRACT_ID = c.CONTRACT_ID
     AND qrr.RUN_AT > DATEADD('day', -1, CURRENT_TIMESTAMP())) AS QUALITY_SCORE_24H,
    
    -- Consumer count
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONSUMERS cons 
     WHERE cons.CONTRACT_ID = c.CONTRACT_ID AND cons.IS_ACTIVE = TRUE) AS CONSUMER_COUNT,
    
    -- Alert count
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.ALERTS a 
     WHERE a.CONTRACT_ID = c.CONTRACT_ID AND a.STATUS = 'OPEN') AS OPEN_ALERT_COUNT,
    
    c.LAST_HEALTH_CHECK,
    c.UPDATED_AT
FROM CONTRACT_REGISTRY.CONTRACTS c
ORDER BY 
    CASE c.HEALTH_STATUS WHEN 'RED' THEN 1 WHEN 'YELLOW' THEN 2 ELSE 3 END,
    c.CONTRACT_ID;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: QUALITY RULES VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_QUALITY_RULES AS
SELECT
    qr.RULE_ID,
    qr.CONTRACT_ID,
    qr.RULE_NAME,
    qr.RULE_TYPE,
    qr.TARGET_COLUMN,
    qr.SEVERITY,
    qr.IS_ACTIVE,
    
    -- Latest result
    latest.STATUS AS LAST_RUN_STATUS,
    latest.PASS_RATE AS LAST_PASS_RATE,
    latest.RECORDS_CHECKED AS LAST_RECORDS_CHECKED,
    latest.RECORDS_FAILED AS LAST_RECORDS_FAILED,
    latest.RUN_AT AS LAST_RUN_AT
FROM CONTRACT_REGISTRY.QUALITY_RULES qr
LEFT JOIN LATERAL (
    SELECT *
    FROM CONTRACT_REGISTRY.QUALITY_RULE_RESULTS qrr
    WHERE qrr.RULE_ID = qr.RULE_ID
    ORDER BY qrr.RUN_AT DESC
    LIMIT 1
) latest ON TRUE
ORDER BY qr.CONTRACT_ID, qr.RULE_ID;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: ACTIVE ALERTS VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_ACTIVE_ALERTS AS
SELECT
    a.ALERT_ID,
    a.CONTRACT_ID,
    c.PRODUCER_TEAM,
    a.ALERT_TYPE,
    a.SEVERITY,
    a.MESSAGE,
    a.STATUS,
    a.CREATED_AT,
    DATEDIFF('hour', a.CREATED_AT, CURRENT_TIMESTAMP()) AS HOURS_OPEN,
    a.ACKNOWLEDGED_AT,
    a.ACKNOWLEDGED_BY
FROM CONTRACT_REGISTRY.ALERTS a
JOIN CONTRACT_REGISTRY.CONTRACTS c ON a.CONTRACT_ID = c.CONTRACT_ID
WHERE a.STATUS = 'OPEN'
ORDER BY 
    CASE a.SEVERITY WHEN 'error' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END,
    a.CREATED_AT;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: TAG COVERAGE VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_TAG_COVERAGE AS
WITH table_info AS (
    SELECT 
        TABLE_CATALOG || '.' || TABLE_SCHEMA || '.' || TABLE_NAME AS FULL_TABLE_NAME,
        TABLE_SCHEMA,
        TABLE_NAME,
        COUNT(*) AS TOTAL_COLUMNS
    FROM RAW_DEV.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA IN ('RAW_SIS', 'RAW_HR')
    GROUP BY TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME
)
SELECT
    FULL_TABLE_NAME,
    TABLE_SCHEMA,
    TABLE_NAME,
    TOTAL_COLUMNS,
    -- Placeholder for tag coverage (would require TAG_REFERENCES function)
    0 AS TAGGED_COLUMN_COUNT,
    0.0 AS COVERAGE_PCT
FROM table_info
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: SLA COMPLIANCE VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_SLA_COMPLIANCE AS
SELECT
    c.CONTRACT_ID,
    c.TARGET_TABLE,
    c.FRESHNESS_MAX_MINUTES,
    c.COMPLETENESS_THRESHOLD,
    
    -- Calculate actual freshness (would need actual table stats)
    c.FRESHNESS_MAX_MINUTES AS MAX_FRESHNESS_MINUTES,
    30 AS ACTUAL_FRESHNESS_MINUTES,  -- Placeholder
    CASE WHEN 30 <= c.FRESHNESS_MAX_MINUTES THEN 'PASS' ELSE 'FAIL' END AS FRESHNESS_STATUS,
    
    -- Calculate completeness (would need actual null checks)
    c.COMPLETENESS_THRESHOLD AS COMPLETENESS_TARGET,
    99.9 AS ACTUAL_COMPLETENESS,  -- Placeholder
    CASE WHEN 99.9 >= c.COMPLETENESS_THRESHOLD THEN 'PASS' ELSE 'FAIL' END AS COMPLETENESS_STATUS,
    
    -- Overall SLA status
    CASE 
        WHEN 30 <= c.FRESHNESS_MAX_MINUTES AND 99.9 >= c.COMPLETENESS_THRESHOLD THEN 'COMPLIANT'
        ELSE 'NON-COMPLIANT'
    END AS OVERALL_SLA_STATUS,
    
    CURRENT_TIMESTAMP() AS CHECKED_AT
FROM CONTRACT_REGISTRY.CONTRACTS c
WHERE c.STATUS = 'active';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 7: CONSUMER USAGE VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_CONSUMER_USAGE AS
SELECT
    cons.CONSUMER_ID,
    cons.CONTRACT_ID,
    c.TARGET_TABLE,
    cons.CONSUMER_TEAM,
    cons.USE_CASE,
    cons.ACCESS_LEVEL,
    cons.REGISTERED_AT,
    cons.LAST_ACCESS,
    DATEDIFF('day', cons.LAST_ACCESS, CURRENT_TIMESTAMP()) AS DAYS_SINCE_LAST_ACCESS,
    cons.IS_ACTIVE
FROM CONTRACT_REGISTRY.CONSUMERS cons
JOIN CONTRACT_REGISTRY.CONTRACTS c ON cons.CONTRACT_ID = c.CONTRACT_ID
ORDER BY cons.CONSUMER_TEAM, cons.CONTRACT_ID;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 8: FERPA COMPLIANCE SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW VW_FERPA_COMPLIANCE AS
SELECT
    'FERPA Compliance Summary' AS REPORT_NAME,
    
    -- Contracts with FERPA data
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS 
     WHERE GOVERNANCE_CLASSIFICATION IN ('CONFIDENTIAL', 'RESTRICTED')) AS PROTECTED_CONTRACTS,
    
    -- Active contracts
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS 
     WHERE STATUS = 'active') AS ACTIVE_CONTRACTS,
    
    -- Restricted data contracts (highest FERPA sensitivity)
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS 
     WHERE GOVERNANCE_CLASSIFICATION = 'RESTRICTED') AS RESTRICTED_CONTRACTS,
    
    -- AI-allowed contracts
    (SELECT COUNT(*) FROM CONTRACT_REGISTRY.CONTRACTS 
     WHERE AI_ELIGIBILITY IN ('TRUE', 'AGGREGATED_ONLY', 'PSEUDONYMIZED_ONLY')) AS AI_ELIGIBLE_CONTRACTS,
    
    CURRENT_TIMESTAMP() AS REPORT_TIME;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Observability Views Created' AS STATUS;

-- Test KPIs view
SELECT * FROM VW_DASHBOARD_KPIS;

-- Test contract health
SELECT * FROM VW_CONTRACT_HEALTH_DASHBOARD LIMIT 5;
