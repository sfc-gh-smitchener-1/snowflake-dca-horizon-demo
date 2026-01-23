-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT HORIZON DEMO - INITIAL SETUP
-- ============================================================================
-- 
-- This is the FIRST script to run. It creates ALL foundational objects:
--   1. Roles and role hierarchy (education-specific)
--   2. Warehouses  
--   3. Databases and schemas
--   4. Governance tags (including FERPA)
--   5. Future grants for access control
--
-- OWNERSHIP: DATA_ADMIN owns all objects
-- RUN AS: ACCOUNTADMIN (only this script needs ACCOUNTADMIN)
--
-- ============================================================================
-- DEMO OVERVIEW
-- ============================================================================
-- 
-- 1. Three-layer architecture (RAW → CURATED → SEMANTIC)
-- 2. 100K synthetic students across 250 schools in Greater Boston
-- 3. FERPA-compliant governance with Object Tagging
-- 4. Tag-based masking policies for PII protection
-- 5. Row access policies for education hierarchy
-- 6. Cortex Analyst integration for natural language queries
-- 7. Complete observability dashboard
--
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- PRE-FLIGHT CHECK
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;

SELECT 'Massachusetts School District Horizon Demo Setup' AS DEMO_NAME,
       CURRENT_TIMESTAMP() AS SETUP_TIME,
       CURRENT_ACCOUNT() AS ACCOUNT;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: ROLES AND HIERARCHY
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- EDUCATION ROLE HIERARCHY
-- ─────────────────────────────────────────────────────────────────────────────
-- 
--                           ACCOUNTADMIN
--                                │
--                           DATA_ADMIN  ◄── Owns all demo objects
--                                │
--         ┌──────────────────────┼──────────────────────┐
--         │                      │                      │
--    DATA_ENGINEER          DATA_STEWARD           PII_VIEWER
--         │                      │                      │
--         │         ┌────────────┼────────────┐         │
--         │         │            │            │         │
--         │   DISTRICT_ADMIN  PRINCIPAL   REGISTRAR     │
--         │         │            │            │         │
--         │         └──────┬─────┴─────┬──────┘         │
--         │                │           │                │
--         └────────►    TEACHER    COUNSELOR    ◄───────┘
--                          │           │
--                          └─────┬─────┘
--                                │
--                          PARENT_PORTAL
--                                │
--                           AI_AGENT
--
-- ─────────────────────────────────────────────────────────────────────────────

-- Administrative Roles
CREATE ROLE IF NOT EXISTS DATA_ADMIN
    COMMENT = 'Full administrative access to all data layers and governance. Owns all demo objects.';

CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Manages data pipelines, RAW and CURATED layers.';

CREATE ROLE IF NOT EXISTS DATA_STEWARD
    COMMENT = 'Manages data contracts, governance tags, quality rules, and monitors SLA compliance.';

CREATE ROLE IF NOT EXISTS PII_VIEWER
    COMMENT = 'Privileged role that can view unmasked PII data. Requires special FERPA authorization.';

-- Education Hierarchy Roles
CREATE ROLE IF NOT EXISTS DISTRICT_ADMIN
    COMMENT = 'District-level access: Superintendent, Assistant Superintendent, District Directors.';

CREATE ROLE IF NOT EXISTS PRINCIPAL
    COMMENT = 'School-level access: Principal, Assistant Principal. Sees own school data.';

CREATE ROLE IF NOT EXISTS REGISTRAR
    COMMENT = 'School registrar: Enrollment and student records management.';

CREATE ROLE IF NOT EXISTS TEACHER
    COMMENT = 'Teacher: Sees only assigned classroom students. PII masked.';

CREATE ROLE IF NOT EXISTS COUNSELOR
    COMMENT = 'Guidance Counselor: Sees assigned students including sensitive data (504, IEP).';

CREATE ROLE IF NOT EXISTS PARENT_PORTAL
    COMMENT = 'Parent/Guardian: Self-service access to own children only.';

-- AI/Machine Roles
CREATE ROLE IF NOT EXISTS AI_AGENT
    COMMENT = 'AI/ML workloads: Only pseudonymized and aggregated data. No direct PII access.';

CREATE ROLE IF NOT EXISTS BI_VIEWER
    COMMENT = 'Read-only access to dashboards and aggregate reports.';

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLE HIERARCHY GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

-- Top of hierarchy
GRANT ROLE DATA_ADMIN TO ROLE ACCOUNTADMIN;

-- Admin roles under DATA_ADMIN
GRANT ROLE DATA_ENGINEER TO ROLE DATA_ADMIN;
GRANT ROLE DATA_STEWARD TO ROLE DATA_ADMIN;
GRANT ROLE PII_VIEWER TO ROLE DATA_ADMIN;

-- Education roles under DATA_STEWARD
GRANT ROLE DISTRICT_ADMIN TO ROLE DATA_STEWARD;
GRANT ROLE PRINCIPAL TO ROLE DATA_STEWARD;
GRANT ROLE REGISTRAR TO ROLE DATA_STEWARD;

-- Classroom roles under education leadership
GRANT ROLE TEACHER TO ROLE DISTRICT_ADMIN;
GRANT ROLE TEACHER TO ROLE PRINCIPAL;
GRANT ROLE COUNSELOR TO ROLE DISTRICT_ADMIN;
GRANT ROLE COUNSELOR TO ROLE PRINCIPAL;

-- Parent portal access
GRANT ROLE PARENT_PORTAL TO ROLE TEACHER;
GRANT ROLE PARENT_PORTAL TO ROLE COUNSELOR;

-- AI/BI roles
GRANT ROLE AI_AGENT TO ROLE DATA_STEWARD;
GRANT ROLE BI_VIEWER TO ROLE DISTRICT_ADMIN;
GRANT ROLE BI_VIEWER TO ROLE PRINCIPAL;

-- ─────────────────────────────────────────────────────────────────────────────
-- DEMO ACCESS: Grant all roles to DATA_ADMIN and ACCOUNTADMIN
-- This allows switching between roles in the Streamlit app to demonstrate RBAC
-- ─────────────────────────────────────────────────────────────────────────────

-- Grant ALL demo roles directly to DATA_ADMIN for role-switching demos
GRANT ROLE DISTRICT_ADMIN TO ROLE DATA_ADMIN;
GRANT ROLE PRINCIPAL TO ROLE DATA_ADMIN;
GRANT ROLE REGISTRAR TO ROLE DATA_ADMIN;
GRANT ROLE TEACHER TO ROLE DATA_ADMIN;
GRANT ROLE COUNSELOR TO ROLE DATA_ADMIN;
GRANT ROLE PARENT_PORTAL TO ROLE DATA_ADMIN;
GRANT ROLE AI_AGENT TO ROLE DATA_ADMIN;
GRANT ROLE BI_VIEWER TO ROLE DATA_ADMIN;

-- Grant ALL demo roles directly to ACCOUNTADMIN for role-switching demos
GRANT ROLE DATA_ENGINEER TO ROLE ACCOUNTADMIN;
GRANT ROLE DATA_STEWARD TO ROLE ACCOUNTADMIN;
GRANT ROLE PII_VIEWER TO ROLE ACCOUNTADMIN;
GRANT ROLE DISTRICT_ADMIN TO ROLE ACCOUNTADMIN;
GRANT ROLE PRINCIPAL TO ROLE ACCOUNTADMIN;
GRANT ROLE REGISTRAR TO ROLE ACCOUNTADMIN;
GRANT ROLE TEACHER TO ROLE ACCOUNTADMIN;
GRANT ROLE COUNSELOR TO ROLE ACCOUNTADMIN;
GRANT ROLE PARENT_PORTAL TO ROLE ACCOUNTADMIN;
GRANT ROLE AI_AGENT TO ROLE ACCOUNTADMIN;
GRANT ROLE BI_VIEWER TO ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- CORTEX ANALYST ACCESS
-- Enable Cortex AI features for demo roles
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable Cortex cross-region if needed (allows using Cortex in any region)
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Grant Cortex access to all demo roles
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_ADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_ENGINEER;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DATA_STEWARD;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PII_VIEWER;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE DISTRICT_ADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PRINCIPAL;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE REGISTRAR;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE TEACHER;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE COUNSELOR;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PARENT_PORTAL;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE AI_AGENT;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE BI_VIEWER;

-- Grant CREATE privileges to DATA_ADMIN
GRANT CREATE DATABASE ON ACCOUNT TO ROLE DATA_ADMIN;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE DATA_ADMIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: WAREHOUSES
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE DATA_ADMIN;

CREATE WAREHOUSE IF NOT EXISTS INGEST_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for data ingestion workloads';

CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for transformation and Dynamic Tables';

CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for analytics queries and Cortex Analyst';

-- Grant warehouse access by role tier
GRANT USAGE ON WAREHOUSE INGEST_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE TRANSFORM_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_STEWARD;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE PII_VIEWER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DISTRICT_ADMIN;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE PRINCIPAL;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE REGISTRAR;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE TEACHER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE COUNSELOR;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE PARENT_PORTAL;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE AI_AGENT;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE BI_VIEWER;

USE WAREHOUSE TRANSFORM_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: DATABASES
-- ═══════════════════════════════════════════════════════════════════════════

-- GOVERNANCE database - contracts, observability, tags
CREATE DATABASE IF NOT EXISTS GOVERNANCE
    COMMENT = 'Data governance: contracts, observability, and policy definitions';

-- RAW layer - ingestion
CREATE DATABASE IF NOT EXISTS RAW_DEV
    COMMENT = 'Raw data layer - ingestion from source systems';

-- CURATED layer - transformed data
CREATE DATABASE IF NOT EXISTS CURATED_DEV
    COMMENT = 'Curated layer - transformed and business-ready data using Dynamic Tables';

-- SEMANTIC layer - consumer-facing
CREATE DATABASE IF NOT EXISTS SEM_DEV
    COMMENT = 'Semantic layer - consumer-facing views with governance policies applied';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: SCHEMAS
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- GOVERNANCE SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.CONTRACT_REGISTRY
    COMMENT = 'Contract definitions, versions, and metadata';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.OBSERVABILITY
    COMMENT = 'Monitoring views and dashboards for contract health';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.TAGS
    COMMENT = 'Governance tag definitions';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.POLICIES
    COMMENT = 'Masking and row access policy definitions';

-- ─────────────────────────────────────────────────────────────────────────────
-- RAW LAYER SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_SIS
    COMMENT = 'Student Information System raw data';

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_HR
    COMMENT = 'Human Resources raw data';

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_ASSESSMENT
    COMMENT = 'Assessment and testing raw data';

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_OPERATIONS
    COMMENT = 'Facilities and operations raw data';

-- ─────────────────────────────────────────────────────────────────────────────
-- CURATED LAYER SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_DIMENSIONS
    COMMENT = 'Curated dimension tables (DIM_*)';

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_FACTS
    COMMENT = 'Curated fact tables (FACT_*)';

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_REFERENCE
    COMMENT = 'Reference and lookup tables';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC LAYER SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_DISTRICT
    COMMENT = 'District-level analytics views';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_SCHOOL
    COMMENT = 'School-level analytics views';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_STUDENT
    COMMENT = 'Student analytics views';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_CLASSROOM
    COMMENT = 'Classroom/teacher views';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_PARENT
    COMMENT = 'Parent portal views';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_GOVERNANCE
    COMMENT = 'Governance observability semantic views';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: GOVERNANCE TAGS
-- ═══════════════════════════════════════════════════════════════════════════

USE SCHEMA GOVERNANCE.TAGS;

-- Standard Data Classification
CREATE TAG IF NOT EXISTS DATA_CLASSIFICATION
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Data classification level for sensitivity';

-- PII Type - Personal information level
CREATE TAG IF NOT EXISTS PII_TYPE
    ALLOWED_VALUES 'NONE', 'LOW', 'MODERATE', 'HIGH'
    COMMENT = 'Level of personally identifiable information';

-- AI Allowed - AI/ML eligibility
CREATE TAG IF NOT EXISTS AI_ALLOWED
    ALLOWED_VALUES 'TRUE', 'FALSE', 'PSEUDONYMIZED_ONLY', 'AGGREGATED_ONLY'
    COMMENT = 'Whether data can be used for AI/ML workloads';

-- Residency Region - Data residency requirements
CREATE TAG IF NOT EXISTS RESIDENCY_REGION
    ALLOWED_VALUES 'GLOBAL', 'ORIGIN', 'EU_ONLY', 'US_ONLY'
    COMMENT = 'Data residency requirements';

-- FERPA Category - Education-specific
CREATE TAG IF NOT EXISTS FERPA_CATEGORY
    ALLOWED_VALUES 'DIRECTORY', 'EDUCATIONAL_RECORD', 'SENSITIVE', 'HEALTH'
    COMMENT = 'FERPA data category for education compliance';

-- Contract ID - Links objects to contracts
CREATE TAG IF NOT EXISTS CONTRACT_ID
    COMMENT = 'Data contract identifier associated with this object';

-- Contract Version
CREATE TAG IF NOT EXISTS CONTRACT_VERSION
    COMMENT = 'Data contract version';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: DATABASE-LEVEL GRANTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Grant database usage
GRANT USAGE ON DATABASE GOVERNANCE TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT USAGE ON DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE RAW_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE PII_VIEWER;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE DISTRICT_ADMIN;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE PRINCIPAL;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE REGISTRAR;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE TEACHER;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE COUNSELOR;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE PARENT_PORTAL;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE AI_AGENT;
GRANT USAGE ON DATABASE SEM_DEV TO ROLE BI_VIEWER;
GRANT USAGE ON DATABASE GOVERNANCE TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 7: SCHEMA-LEVEL GRANTS
-- ═══════════════════════════════════════════════════════════════════════════

-- DATA_ENGINEER grants
GRANT USAGE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE DYNAMIC TABLE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;

-- DATA_STEWARD grants
GRANT USAGE ON ALL SCHEMAS IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_STEWARD;

-- Education roles - semantic layer access
GRANT USAGE ON SCHEMA SEM_DEV.SEM_DISTRICT TO ROLE DISTRICT_ADMIN;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_SCHOOL TO ROLE DISTRICT_ADMIN;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_STUDENT TO ROLE DISTRICT_ADMIN;

GRANT USAGE ON SCHEMA SEM_DEV.SEM_SCHOOL TO ROLE PRINCIPAL;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_STUDENT TO ROLE PRINCIPAL;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_CLASSROOM TO ROLE PRINCIPAL;

GRANT USAGE ON SCHEMA SEM_DEV.SEM_STUDENT TO ROLE REGISTRAR;

GRANT USAGE ON SCHEMA SEM_DEV.SEM_CLASSROOM TO ROLE TEACHER;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_STUDENT TO ROLE TEACHER;

GRANT USAGE ON SCHEMA SEM_DEV.SEM_STUDENT TO ROLE COUNSELOR;

GRANT USAGE ON SCHEMA SEM_DEV.SEM_PARENT TO ROLE PARENT_PORTAL;

GRANT USAGE ON SCHEMA SEM_DEV.SEM_DISTRICT TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_SCHOOL TO ROLE AI_AGENT;

GRANT USAGE ON SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE BI_VIEWER;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_GOVERNANCE TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 8: FUTURE GRANTS
-- ═══════════════════════════════════════════════════════════════════════════

-- DATA_ENGINEER future grants
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;

-- DATA_STEWARD future grants
GRANT SELECT ON FUTURE TABLES IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY TO ROLE DATA_STEWARD;
GRANT SELECT ON FUTURE VIEWS IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;

-- Education roles - semantic views
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_DISTRICT TO ROLE DISTRICT_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_SCHOOL TO ROLE DISTRICT_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_STUDENT TO ROLE DISTRICT_ADMIN;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_SCHOOL TO ROLE PRINCIPAL;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_STUDENT TO ROLE PRINCIPAL;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_CLASSROOM TO ROLE PRINCIPAL;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_CLASSROOM TO ROLE TEACHER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_STUDENT TO ROLE TEACHER;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_STUDENT TO ROLE COUNSELOR;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_PARENT TO ROLE PARENT_PORTAL;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_DISTRICT TO ROLE AI_AGENT;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_SCHOOL TO ROLE AI_AGENT;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE DATA_ADMIN;

SELECT '✓ Massachusetts School District Setup Complete' AS STATUS;
SELECT '  All objects owned by DATA_ADMIN' AS NOTE;
SELECT '  Education role hierarchy configured' AS NOTE2;
SELECT '  FERPA tags created' AS NOTE3;

-- Show what was created
SHOW ROLES LIKE 'DATA_%';
SHOW ROLES LIKE 'DISTRICT_%';
SHOW ROLES LIKE 'PRINCIPAL';
SHOW ROLES LIKE 'TEACHER';
SHOW ROLES LIKE 'COUNSELOR';
SHOW ROLES LIKE 'PARENT_%';
SHOW ROLES LIKE 'AI_%';
SHOW WAREHOUSES;
SHOW DATABASES LIKE '%DEV';
SHOW DATABASES LIKE 'GOVERNANCE';
SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;
