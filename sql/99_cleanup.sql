-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT HORIZON DEMO - CLEANUP
-- ============================================================================
-- 
-- This script removes ALL demo objects from the Snowflake account.
-- 
-- WARNING: This will delete all data and cannot be undone!
--
-- RUN AS: ACCOUNTADMIN
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIRMATION PROMPT
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 
    '⚠️ WARNING: This will delete all demo objects!' AS WARNING,
    'Uncomment the DROP statements below to proceed.' AS INSTRUCTIONS;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: DROP DATABASES
-- ═══════════════════════════════════════════════════════════════════════════

-- Uncomment to execute:
-- DROP DATABASE IF EXISTS SEM_DEV;
-- DROP DATABASE IF EXISTS CURATED_DEV;
-- DROP DATABASE IF EXISTS RAW_DEV;
-- DROP DATABASE IF EXISTS GOVERNANCE;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: DROP WAREHOUSES
-- ═══════════════════════════════════════════════════════════════════════════

-- Uncomment to execute:
-- DROP WAREHOUSE IF EXISTS ANALYTICS_WH;
-- DROP WAREHOUSE IF EXISTS TRANSFORM_WH;
-- DROP WAREHOUSE IF EXISTS INGEST_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 3: DROP ROLES (in reverse hierarchy order)
-- ═══════════════════════════════════════════════════════════════════════════

-- Uncomment to execute:

-- Education roles
-- DROP ROLE IF EXISTS PARENT_PORTAL;
-- DROP ROLE IF EXISTS TEACHER;
-- DROP ROLE IF EXISTS COUNSELOR;
-- DROP ROLE IF EXISTS REGISTRAR;
-- DROP ROLE IF EXISTS PRINCIPAL;
-- DROP ROLE IF EXISTS DISTRICT_ADMIN;

-- Technical roles
-- DROP ROLE IF EXISTS AI_AGENT;
-- DROP ROLE IF EXISTS BI_VIEWER;
-- DROP ROLE IF EXISTS PII_VIEWER;
-- DROP ROLE IF EXISTS DATA_STEWARD;
-- DROP ROLE IF EXISTS DATA_ENGINEER;
-- DROP ROLE IF EXISTS DATA_ADMIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 4: DROP DEMO USERS (if created)
-- ═══════════════════════════════════════════════════════════════════════════

-- Uncomment to execute:
-- DROP USER IF EXISTS DEMO_DATA_ADMIN;
-- DROP USER IF EXISTS DEMO_PRINCIPAL;
-- DROP USER IF EXISTS DEMO_TEACHER;
-- DROP USER IF EXISTS DEMO_PARENT;
-- DROP USER IF EXISTS DEMO_AI_AGENT;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Check what remains
SHOW DATABASES LIKE '%DEV';
SHOW DATABASES LIKE 'GOVERNANCE';
SHOW WAREHOUSES LIKE '%_WH';
SHOW ROLES LIKE 'DATA_%';
SHOW ROLES LIKE 'DISTRICT_%';
SHOW ROLES LIKE 'PRINCIPAL';
SHOW ROLES LIKE 'TEACHER';
SHOW ROLES LIKE 'COUNSELOR';
SHOW ROLES LIKE 'PARENT_%';
SHOW ROLES LIKE 'AI_%';

SELECT '✓ Cleanup complete (if statements were uncommented)' AS STATUS;
