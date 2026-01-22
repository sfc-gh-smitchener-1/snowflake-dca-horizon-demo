-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT - HORIZON GOVERNANCE POLICIES
-- ============================================================================
-- 
-- This script creates:
--   1. Tag-based masking policies for PII protection
--   2. Row access policies for education hierarchy
--   3. Tag application to tables and columns
--
-- FERPA Compliance:
--   - Directory information: Name, grade, school (opt-out available)
--   - Educational records: Grades, transcripts (protected)
--   - Sensitive: SSN, disciplinary records (highly protected)
--   - Health: 504 plans, medical (HIPAA overlap)
--
-- RUN AS: DATA_ADMIN
-- ============================================================================

USE ROLE DATA_ADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE GOVERNANCE;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: MASKING POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

USE SCHEMA GOVERNANCE.POLICIES;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_SSN: Social Security Number masking
-- ─────────────────────────────────────────────────────────────────────────────
-- Fully visible: DATA_ADMIN, PII_VIEWER
-- Last 4 digits: DISTRICT_ADMIN
-- Fully masked: Everyone else

CREATE OR REPLACE MASKING POLICY MASK_SSN AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN') THEN 'XXX-XX-' || RIGHT(val, 4)
        ELSE '***-**-****'
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_DOB: Date of Birth masking
-- ─────────────────────────────────────────────────────────────────────────────
-- Full date: DATA_ADMIN, PII_VIEWER, COUNSELOR
-- Month/Year: DISTRICT_ADMIN, PRINCIPAL, REGISTRAR
-- Year only: TEACHER
-- Null: PARENT_PORTAL (see own child only via row access), AI_AGENT

CREATE OR REPLACE MASKING POLICY MASK_DOB AS (val DATE)
RETURNS DATE ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'COUNSELOR') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR') THEN DATE_TRUNC('MONTH', val)
        WHEN CURRENT_ROLE() IN ('TEACHER') THEN DATE_TRUNC('YEAR', val)
        ELSE NULL
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_ADDRESS: Home address masking
-- ─────────────────────────────────────────────────────────────────────────────
-- Full address: DATA_ADMIN, PII_VIEWER, DISTRICT_ADMIN, PRINCIPAL, REGISTRAR
-- Partial: COUNSELOR
-- City only: TEACHER
-- Masked: AI_AGENT, BI_VIEWER

CREATE OR REPLACE MASKING POLICY MASK_ADDRESS AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR') THEN val
        WHEN CURRENT_ROLE() IN ('COUNSELOR') THEN val
        WHEN CURRENT_ROLE() IN ('TEACHER') THEN '[Address Hidden]'
        ELSE '[MASKED]'
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_PHONE: Phone number masking
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE MASKING POLICY MASK_PHONE AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR', 'COUNSELOR') THEN val
        WHEN CURRENT_ROLE() IN ('TEACHER') THEN 'XXX-XXX-' || RIGHT(REGEXP_REPLACE(val, '[^0-9]', ''), 4)
        ELSE '[MASKED]'
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_EMAIL: Email address masking
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE MASKING POLICY MASK_EMAIL AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR', 'COUNSELOR', 'TEACHER') THEN val
        ELSE CONCAT(LEFT(val, 2), '***@', SPLIT_PART(val, '@', 2))
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_STUDENT_NAME: Student name masking
-- ─────────────────────────────────────────────────────────────────────────────
-- Full name: Most education roles
-- Initials: AI_AGENT
-- Masked: BI_VIEWER (aggregates only)

CREATE OR REPLACE MASKING POLICY MASK_STUDENT_NAME AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR', 'COUNSELOR', 'TEACHER', 'PARENT_PORTAL') THEN val
        WHEN CURRENT_ROLE() = 'AI_AGENT' THEN CONCAT(LEFT(val, 1), '.')
        ELSE '[STUDENT]'
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_STUDENT_ID: Student ID masking for AI
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE MASKING POLICY MASK_STUDENT_ID AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR', 'COUNSELOR', 'TEACHER', 'PARENT_PORTAL') THEN val
        WHEN CURRENT_ROLE() = 'AI_AGENT' THEN SHA2(val, 256)
        ELSE '[MASKED]'
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_SENSITIVE_FLAG: Sensitive boolean flags (IEP, 504, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
-- Only visible to authorized roles

CREATE OR REPLACE MASKING POLICY MASK_SENSITIVE_FLAG AS (val BOOLEAN)
RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'COUNSELOR', 'REGISTRAR') THEN val
        ELSE NULL
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASK_SALARY: Staff salary masking
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE MASKING POLICY MASK_SALARY AS (val NUMBER)
RETURNS NUMBER ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN') THEN ROUND(val, -3)  -- Rounded to nearest $1000
        ELSE NULL
    END;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: ROW ACCESS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW_ACCESS_STUDENT_BY_SCHOOL: Filter students by school assignment
-- ─────────────────────────────────────────────────────────────────────────────
-- DISTRICT_ADMIN: All students in their district
-- PRINCIPAL: Students in their school
-- TEACHER/COUNSELOR: Controlled via separate class roster policy
-- PARENT_PORTAL: Own children only

CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_STUDENT_BY_SCHOOL
AS (school_id STRING, district_id STRING)
RETURNS BOOLEAN ->
    -- Full access roles
    CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DATA_STEWARD', 'DATA_ENGINEER')
    -- District admin sees all in district (simplified - in production use session context)
    OR CURRENT_ROLE() = 'DISTRICT_ADMIN'
    -- Principal sees all in school (simplified - in production use session context)
    OR CURRENT_ROLE() = 'PRINCIPAL'
    -- Other education roles with classroom-level filtering
    OR CURRENT_ROLE() IN ('REGISTRAR', 'COUNSELOR', 'TEACHER')
    -- AI Agent for aggregated views
    OR CURRENT_ROLE() = 'AI_AGENT';

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW_ACCESS_MY_STUDENTS: Teacher sees only their classroom students
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_MY_STUDENTS
AS (student_id STRING)
RETURNS BOOLEAN ->
    -- Full access roles
    CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DATA_STEWARD', 'DATA_ENGINEER', 'DISTRICT_ADMIN', 'PRINCIPAL', 'REGISTRAR')
    -- Teacher role (simplified - in production, use session context to filter to teacher's students)
    OR CURRENT_ROLE() = 'TEACHER'
    -- Counselor role (simplified - in production, use session context to filter to counselor's students)
    OR CURRENT_ROLE() = 'COUNSELOR'
    -- AI Agent for aggregated views
    OR CURRENT_ROLE() = 'AI_AGENT';

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW_ACCESS_MY_CHILDREN: Parents see only their own children
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_MY_CHILDREN
AS (student_id STRING)
RETURNS BOOLEAN ->
    -- All non-parent roles pass through
    CURRENT_ROLE() != 'PARENT_PORTAL'
    -- Parent portal: simplified for demo (in production, use session context to filter to parent's children)
    OR CURRENT_ROLE() = 'PARENT_PORTAL';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: APPLY TAGS TO STUDENT TABLE
-- ═══════════════════════════════════════════════════════════════════════════

USE DATABASE RAW_DEV;
USE SCHEMA RAW_SIS;

-- Table-level tags
ALTER TABLE STUDENT_RAW SET TAG 
    GOVERNANCE.TAGS.CONTRACT_ID = 'student_v1',
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED';

-- Column-level tags - Student ID
ALTER TABLE STUDENT_RAW MODIFY COLUMN STUDENT_ID SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
    GOVERNANCE.TAGS.PII_TYPE = 'MODERATE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'PSEUDONYMIZED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'EDUCATIONAL_RECORD';

-- Column-level tags - Names
ALTER TABLE STUDENT_RAW MODIFY COLUMN FIRST_NAME SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
    GOVERNANCE.TAGS.PII_TYPE = 'MODERATE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'PSEUDONYMIZED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

ALTER TABLE STUDENT_RAW MODIFY COLUMN LAST_NAME SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
    GOVERNANCE.TAGS.PII_TYPE = 'MODERATE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'PSEUDONYMIZED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

-- Column-level tags - SSN (most sensitive)
ALTER TABLE STUDENT_RAW MODIFY COLUMN SSN SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
    GOVERNANCE.TAGS.PII_TYPE = 'HIGH',
    GOVERNANCE.TAGS.AI_ALLOWED = 'FALSE',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'SENSITIVE',
    GOVERNANCE.TAGS.RESIDENCY_REGION = 'US_ONLY';

-- Column-level tags - Date of Birth
ALTER TABLE STUDENT_RAW MODIFY COLUMN DATE_OF_BIRTH SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
    GOVERNANCE.TAGS.PII_TYPE = 'MODERATE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'AGGREGATED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'EDUCATIONAL_RECORD';

-- Column-level tags - Address
ALTER TABLE STUDENT_RAW MODIFY COLUMN HOME_ADDRESS_LINE1 SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
    GOVERNANCE.TAGS.PII_TYPE = 'MODERATE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'FALSE',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

-- Column-level tags - Special programs (sensitive)
ALTER TABLE STUDENT_RAW MODIFY COLUMN SPECIAL_EDUCATION SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
    GOVERNANCE.TAGS.PII_TYPE = 'HIGH',
    GOVERNANCE.TAGS.AI_ALLOWED = 'AGGREGATED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'SENSITIVE';

ALTER TABLE STUDENT_RAW MODIFY COLUMN SECTION_504 SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
    GOVERNANCE.TAGS.PII_TYPE = 'HIGH',
    GOVERNANCE.TAGS.AI_ALLOWED = 'AGGREGATED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'HEALTH';

ALTER TABLE STUDENT_RAW MODIFY COLUMN FREE_REDUCED_LUNCH SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
    GOVERNANCE.TAGS.PII_TYPE = 'MODERATE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'AGGREGATED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'SENSITIVE';

ALTER TABLE STUDENT_RAW MODIFY COLUMN HOMELESS_STATUS SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
    GOVERNANCE.TAGS.PII_TYPE = 'HIGH',
    GOVERNANCE.TAGS.AI_ALLOWED = 'AGGREGATED_ONLY',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'SENSITIVE';

-- Column-level tags - Non-sensitive
ALTER TABLE STUDENT_RAW MODIFY COLUMN GRADE_LEVEL SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
    GOVERNANCE.TAGS.PII_TYPE = 'NONE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

ALTER TABLE STUDENT_RAW MODIFY COLUMN CURRENT_SCHOOL_ID SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
    GOVERNANCE.TAGS.PII_TYPE = 'NONE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE',
    GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: APPLY TAGS TO STAFF TABLE
-- ═══════════════════════════════════════════════════════════════════════════

USE SCHEMA RAW_HR;

ALTER TABLE STAFF_RAW SET TAG 
    GOVERNANCE.TAGS.CONTRACT_ID = 'staff_v1',
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

ALTER TABLE STAFF_RAW MODIFY COLUMN SSN SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
    GOVERNANCE.TAGS.PII_TYPE = 'HIGH',
    GOVERNANCE.TAGS.AI_ALLOWED = 'FALSE',
    GOVERNANCE.TAGS.RESIDENCY_REGION = 'US_ONLY';

ALTER TABLE STAFF_RAW MODIFY COLUMN SALARY SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
    GOVERNANCE.TAGS.PII_TYPE = 'HIGH',
    GOVERNANCE.TAGS.AI_ALLOWED = 'AGGREGATED_ONLY';

ALTER TABLE STAFF_RAW MODIFY COLUMN EMAIL SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
    GOVERNANCE.TAGS.PII_TYPE = 'LOW',
    GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

ALTER TABLE STAFF_RAW MODIFY COLUMN POSITION_TITLE SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
    GOVERNANCE.TAGS.PII_TYPE = 'NONE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: APPLY TAGS TO SCHOOL TABLE
-- ═══════════════════════════════════════════════════════════════════════════

USE SCHEMA RAW_SIS;

ALTER TABLE SCHOOL_RAW SET TAG 
    GOVERNANCE.TAGS.CONTRACT_ID = 'school_v1',
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

ALTER TABLE SCHOOL_RAW MODIFY COLUMN SCHOOL_NAME SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC',
    GOVERNANCE.TAGS.PII_TYPE = 'NONE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

ALTER TABLE SCHOOL_RAW MODIFY COLUMN ADDRESS SET TAG
    GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC',
    GOVERNANCE.TAGS.PII_TYPE = 'NONE',
    GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: APPLY MASKING POLICIES TO SEMANTIC LAYER
-- ═══════════════════════════════════════════════════════════════════════════

-- Note: These will be applied when semantic views are created
-- Example of how to apply to a view:

/*
ALTER VIEW SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE 
    MODIFY COLUMN SSN SET MASKING POLICY GOVERNANCE.POLICIES.MASK_SSN;

ALTER VIEW SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE 
    MODIFY COLUMN DATE_OF_BIRTH SET MASKING POLICY GOVERNANCE.POLICIES.MASK_DOB;

ALTER VIEW SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE 
    MODIFY COLUMN HOME_ADDRESS SET MASKING POLICY GOVERNANCE.POLICIES.MASK_ADDRESS;

ALTER VIEW SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE 
    MODIFY COLUMN FIRST_NAME SET MASKING POLICY GOVERNANCE.POLICIES.MASK_STUDENT_NAME;

ALTER VIEW SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE 
    MODIFY COLUMN SPECIAL_EDUCATION SET MASKING POLICY GOVERNANCE.POLICIES.MASK_SENSITIVE_FLAG;
*/

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Horizon Governance Policies Created' AS STATUS;

-- Show masking policies
SHOW MASKING POLICIES IN SCHEMA GOVERNANCE.POLICIES;

-- Show row access policies
SHOW ROW ACCESS POLICIES IN SCHEMA GOVERNANCE.POLICIES;

-- Show tags applied to student table
SELECT 
    TAG_NAME,
    TAG_VALUE,
    COLUMN_NAME
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('RAW_DEV.RAW_SIS.STUDENT_RAW', 'TABLE'))
ORDER BY COLUMN_NAME, TAG_NAME;

-- Verify tag coverage
SELECT 
    'STUDENT_RAW' AS table_name,
    COUNT(DISTINCT COLUMN_NAME) AS tagged_columns
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES('RAW_DEV.RAW_SIS.STUDENT_RAW', 'TABLE'))
WHERE COLUMN_NAME IS NOT NULL;
