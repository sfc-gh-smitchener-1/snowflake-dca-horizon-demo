-- ============================================================================
-- CURATED LAYER - Dynamic Tables for Education Data
-- ============================================================================
-- This script creates Dynamic Tables that:
--   1. Transform raw data into business-ready dimensions and facts
--   2. Automatically refresh based on upstream changes
--   3. Apply business rules and derived attributes
--   4. Create pseudonymized columns for AI-safe consumption
--   5. Maintain FERPA compliance through the pipeline
--
-- Run order: After 04_generate_synthetic_data.sql
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE CURATED_DEV;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA SETUP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_DIMENSIONS
    COMMENT = 'Dimension tables for education analytics';

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_FACTS
    COMMENT = 'Fact tables for education analytics';

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_REFERENCE
    COMMENT = 'Reference and lookup tables';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: District
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT
    TARGET_LAG = '24 hours'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated district dimension with enriched attributes'
AS
SELECT
    -- Keys
    d.DISTRICT_ID AS DISTRICT_KEY,
    d.DISTRICT_ID,
    
    -- Attributes
    d.DISTRICT_NAME,
    d.COUNTY,
    d.CITY,
    d.STATE,
    d.SUPERINTENDENT_NAME,
    d.PHONE_MAIN,
    d.WEBSITE,
    d.CURRENT_SCHOOL_YEAR,
    
    -- Derived: District Size Category (based on schools - will be computed)
    'MEDIUM' AS SIZE_CATEGORY,
    
    -- Metadata
    d._LOADED_AT AS _SOURCE_LOADED_AT,
    d._IS_CURRENT
    
FROM RAW_DEV.RAW_SIS.DISTRICT_RAW d
WHERE d._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_district_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: School
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL
    TARGET_LAG = '24 hours'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated school dimension with performance metrics'
AS
SELECT
    -- Keys
    s.SCHOOL_ID AS SCHOOL_KEY,
    s.SCHOOL_ID,
    s.DISTRICT_ID,
    
    -- School Attributes
    s.SCHOOL_NAME,
    s.SCHOOL_NAME_SHORT,
    s.SCHOOL_TYPE,
    s.GRADE_LEVELS_SERVED,
    
    -- Classification Flags
    s.IS_TITLE_I,
    s.IS_MAGNET,
    s.IS_CHARTER,
    
    -- Location
    s.ADDRESS,
    s.CITY,
    s.STATE,
    s.ZIP_CODE,
    s.COUNTY,
    s.LATITUDE,
    s.LONGITUDE,
    
    -- Contact
    s.PHONE_MAIN,
    s.EMAIL_MAIN,
    s.WEBSITE,
    
    -- Leadership
    s.PRINCIPAL_STAFF_ID,
    s.PRINCIPAL_NAME,
    
    -- Capacity & Enrollment
    s.BUILDING_CAPACITY,
    s.CURRENT_ENROLLMENT,
    s.STAFF_COUNT,
    s.TEACHER_COUNT,
    
    -- Derived: Capacity Utilization
    ROUND(100.0 * s.CURRENT_ENROLLMENT / NULLIF(s.BUILDING_CAPACITY, 0), 1) AS CAPACITY_UTILIZATION_PCT,
    
    -- Derived: Capacity Status
    CASE 
        WHEN s.CURRENT_ENROLLMENT >= s.BUILDING_CAPACITY * 1.1 THEN 'OVER_CAPACITY'
        WHEN s.CURRENT_ENROLLMENT >= s.BUILDING_CAPACITY * 0.9 THEN 'NEAR_CAPACITY'
        WHEN s.CURRENT_ENROLLMENT >= s.BUILDING_CAPACITY * 0.7 THEN 'OPTIMAL'
        ELSE 'UNDER_UTILIZED'
    END AS CAPACITY_STATUS,
    
    -- Derived: Student-Teacher Ratio
    ROUND(s.CURRENT_ENROLLMENT / NULLIF(s.TEACHER_COUNT, 0), 1) AS STUDENT_TEACHER_RATIO,
    
    -- Performance Metrics
    s.ACCOUNTABILITY_RATING,
    s.GRADUATION_RATE,
    s.ATTENDANCE_RATE,
    
    -- Academic Calendar
    s.SCHOOL_YEAR,
    s.FIRST_DAY_OF_SCHOOL,
    s.LAST_DAY_OF_SCHOOL,
    
    -- Metadata
    s._LOADED_AT AS _SOURCE_LOADED_AT,
    s._IS_CURRENT
    
FROM RAW_DEV.RAW_SIS.SCHOOL_RAW s
WHERE s._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_school_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Student
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated student dimension with derived attributes and pseudonymization'
AS
SELECT
    -- Keys
    s.STUDENT_ID AS STUDENT_KEY,
    s.STUDENT_ID,
    
    -- Pseudonymized Keys (for AI workloads)
    SHA2(s.STUDENT_ID, 256) AS STUDENT_ID_HASH,
    SHA2(s.FIRST_NAME || ' ' || s.LAST_NAME, 256) AS STUDENT_NAME_HASH,
    
    -- PII Fields (will be masked in semantic layer)
    s.FIRST_NAME,
    s.MIDDLE_NAME,
    s.LAST_NAME,
    s.PREFERRED_NAME,
    s.SSN,
    s.STATE_ID,
    s.DATE_OF_BIRTH,
    
    -- Derived: Display Name (for general use)
    COALESCE(s.PREFERRED_NAME, s.FIRST_NAME) || ' ' || LEFT(s.LAST_NAME, 1) || '.' AS DISPLAY_NAME,
    
    -- Derived: Age
    DATEDIFF('year', s.DATE_OF_BIRTH, CURRENT_DATE()) AS AGE,
    
    -- Demographics
    s.GENDER,
    s.ETHNICITY,
    s.RACE,
    s.PRIMARY_LANGUAGE,
    s.ELL_STATUS,
    
    -- Address (PII)
    s.HOME_ADDRESS_LINE1,
    s.HOME_ADDRESS_LINE2,
    s.CITY,
    s.STATE,
    s.ZIP_CODE,
    s.COUNTY,
    
    -- School Assignment
    s.CURRENT_SCHOOL_ID,
    s.CURRENT_DISTRICT_ID,
    s.GRADE_LEVEL,
    s.HOMEROOM,
    
    -- Derived: Grade Level Category
    CASE 
        WHEN s.GRADE_LEVEL IN ('PK', 'K', '01', '02', '03', '04', '05') THEN 'ELEMENTARY'
        WHEN s.GRADE_LEVEL IN ('06', '07', '08') THEN 'MIDDLE'
        WHEN s.GRADE_LEVEL IN ('09', '10', '11', '12') THEN 'HIGH'
        ELSE 'OTHER'
    END AS GRADE_LEVEL_CATEGORY,
    
    -- Derived: Numeric Grade for sorting
    CASE s.GRADE_LEVEL
        WHEN 'PK' THEN -1
        WHEN 'K' THEN 0
        ELSE TRY_TO_NUMBER(s.GRADE_LEVEL)
    END AS GRADE_LEVEL_NUM,
    
    -- Enrollment
    s.ENROLLMENT_STATUS,
    s.ENROLLMENT_DATE,
    s.EXPECTED_GRADUATION_YEAR,
    
    -- Derived: Cohort Year
    s.EXPECTED_GRADUATION_YEAR AS COHORT_YEAR,
    
    -- Special Programs (Sensitive)
    s.SPECIAL_EDUCATION,
    s.SECTION_504,
    s.GIFTED_TALENTED,
    s.FREE_REDUCED_LUNCH,
    s.HOMELESS_STATUS,
    
    -- Derived: At-Risk Flag (placeholder - would be calculated from grades/attendance)
    CASE 
        WHEN s.HOMELESS_STATUS = TRUE THEN TRUE
        WHEN s.FREE_REDUCED_LUNCH = 'Free' AND s.ELL_STATUS = TRUE THEN TRUE
        ELSE FALSE
    END AS AT_RISK_FLAG,
    
    -- Derived: Program Count
    (CASE WHEN s.SPECIAL_EDUCATION THEN 1 ELSE 0 END +
     CASE WHEN s.SECTION_504 THEN 1 ELSE 0 END +
     CASE WHEN s.GIFTED_TALENTED THEN 1 ELSE 0 END +
     CASE WHEN s.ELL_STATUS THEN 1 ELSE 0 END) AS PROGRAM_COUNT,
    
    -- Metadata
    s._LOADED_AT AS _SOURCE_LOADED_AT,
    s._SOURCE_SYSTEM,
    s._ROW_HASH AS _SOURCE_HASH,
    s._IS_CURRENT
    
FROM RAW_DEV.RAW_SIS.STUDENT_RAW s
WHERE s._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_student_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'RESTRICTED',
            GOVERNANCE.TAGS.FERPA_CATEGORY = 'EDUCATIONAL_RECORD';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Staff
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated staff dimension with HR metrics'
AS
SELECT
    -- Keys
    st.STAFF_ID AS STAFF_KEY,
    st.STAFF_ID,
    
    -- Pseudonymized
    SHA2(st.STAFF_ID, 256) AS STAFF_ID_HASH,
    SHA2(st.FIRST_NAME || ' ' || st.LAST_NAME, 256) AS STAFF_NAME_HASH,
    
    -- PII Fields
    st.FIRST_NAME,
    st.MIDDLE_NAME,
    st.LAST_NAME,
    st.PREFERRED_NAME,
    st.SSN,
    st.DATE_OF_BIRTH,
    
    -- Derived: Display Name
    COALESCE(st.PREFERRED_NAME, st.FIRST_NAME) || ' ' || st.LAST_NAME AS DISPLAY_NAME,
    
    -- Contact
    st.EMAIL,
    st.PERSONAL_EMAIL,
    st.PHONE_WORK,
    st.PHONE_MOBILE,
    
    -- Address
    st.HOME_ADDRESS,
    st.CITY,
    st.STATE,
    st.ZIP_CODE,
    
    -- Employment
    st.EMPLOYEE_TYPE,
    st.POSITION_TITLE,
    st.ROLE_CATEGORY,
    st.DEPARTMENT,
    st.PRIMARY_SCHOOL_ID,
    st.DISTRICT_ID,
    
    -- Derived: Is Teacher Flag
    CASE WHEN st.ROLE_CATEGORY = 'Teacher' THEN TRUE ELSE FALSE END AS IS_TEACHER,
    
    -- Derived: Is Administrator Flag
    CASE WHEN st.ROLE_CATEGORY = 'Administrator' THEN TRUE ELSE FALSE END AS IS_ADMINISTRATOR,
    
    -- Dates
    st.HIRE_DATE,
    st.START_DATE_CURRENT_POSITION,
    st.TERMINATION_DATE,
    st.EMPLOYMENT_STATUS,
    
    -- Derived: Tenure (Years at District)
    ROUND(DATEDIFF('day', st.HIRE_DATE, CURRENT_DATE()) / 365.25, 1) AS TENURE_YEARS,
    
    -- Derived: Time in Current Position
    ROUND(DATEDIFF('day', st.START_DATE_CURRENT_POSITION, CURRENT_DATE()) / 365.25, 1) AS YEARS_IN_POSITION,
    
    -- Credentials
    st.HIGHEST_DEGREE,
    st.TEACHING_LICENSE,
    st.LICENSE_EXPIRATION,
    st.YEARS_EXPERIENCE,
    st.HIGHLY_QUALIFIED,
    
    -- Derived: License Status
    CASE 
        WHEN st.LICENSE_EXPIRATION IS NULL THEN 'NO_LICENSE'
        WHEN st.LICENSE_EXPIRATION < CURRENT_DATE() THEN 'EXPIRED'
        WHEN st.LICENSE_EXPIRATION < DATEADD('month', 6, CURRENT_DATE()) THEN 'EXPIRING_SOON'
        ELSE 'VALID'
    END AS LICENSE_STATUS,
    
    -- Compensation (Sensitive)
    st.SALARY,
    st.PAY_GRADE,
    st.UNION_MEMBERSHIP,
    
    -- Derived: Salary Band
    CASE 
        WHEN st.SALARY >= 100000 THEN 'EXECUTIVE'
        WHEN st.SALARY >= 75000 THEN 'SENIOR'
        WHEN st.SALARY >= 50000 THEN 'MID'
        ELSE 'ENTRY'
    END AS SALARY_BAND,
    
    -- Metadata
    st._LOADED_AT AS _SOURCE_LOADED_AT,
    st._IS_CURRENT
    
FROM RAW_DEV.RAW_HR.STAFF_RAW st
WHERE st._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_staff_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Guardian
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_GUARDIAN
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated guardian/parent dimension'
AS
SELECT
    -- Keys
    g.GUARDIAN_ID AS GUARDIAN_KEY,
    g.GUARDIAN_ID,
    
    -- Pseudonymized
    SHA2(g.GUARDIAN_ID, 256) AS GUARDIAN_ID_HASH,
    
    -- PII
    g.FIRST_NAME,
    g.LAST_NAME,
    g.FIRST_NAME || ' ' || g.LAST_NAME AS FULL_NAME,
    g.RELATIONSHIP_TYPE,
    
    -- Contact
    g.EMAIL_PRIMARY,
    g.EMAIL_SECONDARY,
    g.PHONE_HOME,
    g.PHONE_MOBILE,
    g.PHONE_WORK,
    
    -- Derived: Primary Phone
    COALESCE(g.PHONE_MOBILE, g.PHONE_HOME, g.PHONE_WORK) AS PRIMARY_PHONE,
    
    -- Address
    g.ADDRESS_LINE1,
    g.ADDRESS_LINE2,
    g.CITY,
    g.STATE,
    g.ZIP_CODE,
    
    -- Preferences
    g.EMPLOYER,
    g.PREFERRED_LANGUAGE,
    g.PORTAL_ACCOUNT_ACTIVE,
    g.PORTAL_USERNAME,
    g.RECEIVES_DISTRICT_COMMUNICATIONS,
    
    -- Metadata
    g._LOADED_AT AS _SOURCE_LOADED_AT,
    g._IS_CURRENT
    
FROM RAW_DEV.RAW_SIS.GUARDIAN_RAW g
WHERE g._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_GUARDIAN
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_guardian_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
            GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Date (Generated - not dynamic table)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE AS
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2015-01-01')::DATE AS DATE_KEY
    FROM TABLE(GENERATOR(ROWCOUNT => 5000))
)
SELECT
    DATE_KEY,
    DATE_KEY AS FULL_DATE,
    YEAR(DATE_KEY) AS YEAR,
    QUARTER(DATE_KEY) AS QUARTER,
    MONTH(DATE_KEY) AS MONTH,
    MONTHNAME(DATE_KEY) AS MONTH_NAME,
    WEEK(DATE_KEY) AS WEEK_OF_YEAR,
    DAYOFWEEK(DATE_KEY) AS DAY_OF_WEEK,
    DAYNAME(DATE_KEY) AS DAY_NAME,
    DAYOFMONTH(DATE_KEY) AS DAY_OF_MONTH,
    DAYOFYEAR(DATE_KEY) AS DAY_OF_YEAR,
    
    -- Academic Year (Aug-July)
    CASE 
        WHEN MONTH(DATE_KEY) >= 8 THEN YEAR(DATE_KEY)
        ELSE YEAR(DATE_KEY) - 1
    END AS ACADEMIC_YEAR_START,
    
    CASE 
        WHEN MONTH(DATE_KEY) >= 8 THEN CONCAT(YEAR(DATE_KEY), '-', YEAR(DATE_KEY) + 1)
        ELSE CONCAT(YEAR(DATE_KEY) - 1, '-', YEAR(DATE_KEY))
    END AS ACADEMIC_YEAR,
    
    -- Academic Quarter
    CASE 
        WHEN MONTH(DATE_KEY) IN (8, 9, 10) THEN 1
        WHEN MONTH(DATE_KEY) IN (11, 12, 1) THEN 2
        WHEN MONTH(DATE_KEY) IN (2, 3, 4) THEN 3
        ELSE 4
    END AS ACADEMIC_QUARTER,
    
    -- Semester
    CASE 
        WHEN MONTH(DATE_KEY) IN (8, 9, 10, 11, 12, 1) THEN 'FALL'
        ELSE 'SPRING'
    END AS SEMESTER,
    
    -- School Day Flags
    CASE WHEN DAYOFWEEK(DATE_KEY) IN (0, 6) THEN FALSE ELSE TRUE END AS IS_WEEKDAY,
    CASE WHEN DAYOFWEEK(DATE_KEY) IN (0, 6) THEN TRUE ELSE FALSE END AS IS_WEEKEND,
    
    -- Massachusetts Holidays (simplified)
    CASE 
        WHEN MONTH(DATE_KEY) = 1 AND DAYOFMONTH(DATE_KEY) = 1 THEN TRUE  -- New Year
        WHEN MONTH(DATE_KEY) = 7 AND DAYOFMONTH(DATE_KEY) = 4 THEN TRUE  -- July 4
        WHEN MONTH(DATE_KEY) = 12 AND DAYOFMONTH(DATE_KEY) = 25 THEN TRUE -- Christmas
        WHEN MONTH(DATE_KEY) = 11 AND DAYOFWEEK(DATE_KEY) = 4 
             AND DAYOFMONTH(DATE_KEY) BETWEEN 22 AND 28 THEN TRUE -- Thanksgiving
        ELSE FALSE
    END AS IS_HOLIDAY,
    
    -- Period Keys for aggregation
    TO_CHAR(DATE_KEY, 'YYYYMM')::INT AS YEAR_MONTH_KEY,
    TO_CHAR(DATE_KEY, 'YYYYQ')::VARCHAR AS YEAR_QUARTER_KEY
FROM date_spine
WHERE DATE_KEY <= '2030-12-31';

-- Apply tags
ALTER TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE
    SET TAG GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

-- ─────────────────────────────────────────────────────────────────────────────
-- FACT: Student Enrollment Summary
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_ENROLLMENT_SUMMARY
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Student enrollment fact aggregated by school and grade'
AS
SELECT
    -- Keys
    s.CURRENT_SCHOOL_ID AS SCHOOL_ID,
    s.CURRENT_DISTRICT_ID AS DISTRICT_ID,
    s.GRADE_LEVEL,
    
    -- Counts
    COUNT(*) AS STUDENT_COUNT,
    COUNT(CASE WHEN s.ENROLLMENT_STATUS = 'Active' THEN 1 END) AS ACTIVE_COUNT,
    COUNT(CASE WHEN s.ENROLLMENT_STATUS = 'Withdrawn' THEN 1 END) AS WITHDRAWN_COUNT,
    
    -- Demographics
    COUNT(CASE WHEN s.GENDER = 'Male' THEN 1 END) AS MALE_COUNT,
    COUNT(CASE WHEN s.GENDER = 'Female' THEN 1 END) AS FEMALE_COUNT,
    
    -- Program Participation
    COUNT(CASE WHEN s.ELL_STATUS = TRUE THEN 1 END) AS ELL_COUNT,
    COUNT(CASE WHEN s.SPECIAL_EDUCATION = TRUE THEN 1 END) AS SPED_COUNT,
    COUNT(CASE WHEN s.SECTION_504 = TRUE THEN 1 END) AS SECTION_504_COUNT,
    COUNT(CASE WHEN s.GIFTED_TALENTED = TRUE THEN 1 END) AS GIFTED_COUNT,
    COUNT(CASE WHEN s.FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 END) AS FRL_COUNT,
    COUNT(CASE WHEN s.FREE_REDUCED_LUNCH = 'Free' THEN 1 END) AS FREE_LUNCH_COUNT,
    COUNT(CASE WHEN s.FREE_REDUCED_LUNCH = 'Reduced' THEN 1 END) AS REDUCED_LUNCH_COUNT,
    COUNT(CASE WHEN s.HOMELESS_STATUS = TRUE THEN 1 END) AS HOMELESS_COUNT,
    
    -- Rates
    ROUND(100.0 * COUNT(CASE WHEN s.ELL_STATUS = TRUE THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS ELL_RATE,
    ROUND(100.0 * COUNT(CASE WHEN s.SPECIAL_EDUCATION = TRUE THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS SPED_RATE,
    ROUND(100.0 * COUNT(CASE WHEN s.FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS FRL_RATE,
    
    -- Snapshot Date
    CURRENT_DATE() AS SNAPSHOT_DATE
    
FROM RAW_DEV.RAW_SIS.STUDENT_RAW s
WHERE s._IS_CURRENT = TRUE
GROUP BY s.CURRENT_SCHOOL_ID, s.CURRENT_DISTRICT_ID, s.GRADE_LEVEL;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_ENROLLMENT_SUMMARY
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_enrollment_fact_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- FACT: School Metrics Summary
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_SCHOOL_METRICS
    TARGET_LAG = '24 hours'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'School-level aggregated metrics'
AS
SELECT
    -- Keys
    sch.SCHOOL_ID,
    sch.DISTRICT_ID,
    sch.SCHOOL_TYPE,
    
    -- School Info
    sch.SCHOOL_NAME,
    sch.COUNTY,
    sch.IS_TITLE_I,
    
    -- Capacity Metrics
    sch.BUILDING_CAPACITY,
    sch.CURRENT_ENROLLMENT,
    ROUND(100.0 * sch.CURRENT_ENROLLMENT / NULLIF(sch.BUILDING_CAPACITY, 0), 1) AS CAPACITY_UTILIZATION,
    
    -- Staff Metrics
    sch.STAFF_COUNT,
    sch.TEACHER_COUNT,
    ROUND(sch.CURRENT_ENROLLMENT / NULLIF(sch.TEACHER_COUNT, 0), 1) AS STUDENT_TEACHER_RATIO,
    
    -- Student Metrics (from aggregation)
    COALESCE(enr.TOTAL_STUDENTS, 0) AS TOTAL_STUDENTS,
    COALESCE(enr.ACTIVE_STUDENTS, 0) AS ACTIVE_STUDENTS,
    COALESCE(enr.ELL_STUDENTS, 0) AS ELL_STUDENTS,
    COALESCE(enr.SPED_STUDENTS, 0) AS SPED_STUDENTS,
    COALESCE(enr.FRL_STUDENTS, 0) AS FRL_STUDENTS,
    
    -- Rates from student data
    COALESCE(enr.ELL_RATE, 0) AS ELL_RATE,
    COALESCE(enr.SPED_RATE, 0) AS SPED_RATE,
    COALESCE(enr.FRL_RATE, 0) AS FRL_RATE,
    
    -- Performance (from school)
    sch.ACCOUNTABILITY_RATING,
    sch.GRADUATION_RATE,
    sch.ATTENDANCE_RATE,
    
    -- Snapshot
    CURRENT_DATE() AS SNAPSHOT_DATE
    
FROM RAW_DEV.RAW_SIS.SCHOOL_RAW sch
LEFT JOIN (
    SELECT
        CURRENT_SCHOOL_ID,
        COUNT(*) AS TOTAL_STUDENTS,
        COUNT(CASE WHEN ENROLLMENT_STATUS = 'Active' THEN 1 END) AS ACTIVE_STUDENTS,
        COUNT(CASE WHEN ELL_STATUS = TRUE THEN 1 END) AS ELL_STUDENTS,
        COUNT(CASE WHEN SPECIAL_EDUCATION = TRUE THEN 1 END) AS SPED_STUDENTS,
        COUNT(CASE WHEN FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 END) AS FRL_STUDENTS,
        ROUND(100.0 * COUNT(CASE WHEN ELL_STATUS = TRUE THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS ELL_RATE,
        ROUND(100.0 * COUNT(CASE WHEN SPECIAL_EDUCATION = TRUE THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS SPED_RATE,
        ROUND(100.0 * COUNT(CASE WHEN FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS FRL_RATE
    FROM RAW_DEV.RAW_SIS.STUDENT_RAW
    WHERE _IS_CURRENT = TRUE
    GROUP BY CURRENT_SCHOOL_ID
) enr ON sch.SCHOOL_ID = enr.CURRENT_SCHOOL_ID
WHERE sch._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_SCHOOL_METRICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_school_metrics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

-- ─────────────────────────────────────────────────────────────────────────────
-- FACT: Staff Summary by School
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_STAFF_SUMMARY
    TARGET_LAG = '24 hours'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Staff metrics aggregated by school'
AS
SELECT
    -- Keys
    st.PRIMARY_SCHOOL_ID AS SCHOOL_ID,
    st.DISTRICT_ID,
    st.ROLE_CATEGORY,
    st.DEPARTMENT,
    
    -- Counts
    COUNT(*) AS STAFF_COUNT,
    COUNT(CASE WHEN st.EMPLOYMENT_STATUS = 'Active' THEN 1 END) AS ACTIVE_COUNT,
    COUNT(CASE WHEN st.ROLE_CATEGORY = 'Teacher' THEN 1 END) AS TEACHER_COUNT,
    COUNT(CASE WHEN st.ROLE_CATEGORY = 'Administrator' THEN 1 END) AS ADMIN_COUNT,
    COUNT(CASE WHEN st.ROLE_CATEGORY = 'Support' THEN 1 END) AS SUPPORT_COUNT,
    
    -- Experience
    ROUND(AVG(st.YEARS_EXPERIENCE), 1) AS AVG_YEARS_EXPERIENCE,
    MIN(st.YEARS_EXPERIENCE) AS MIN_YEARS_EXPERIENCE,
    MAX(st.YEARS_EXPERIENCE) AS MAX_YEARS_EXPERIENCE,
    
    -- Qualifications
    COUNT(CASE WHEN st.HIGHLY_QUALIFIED = TRUE THEN 1 END) AS HIGHLY_QUALIFIED_COUNT,
    ROUND(100.0 * COUNT(CASE WHEN st.HIGHLY_QUALIFIED = TRUE THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS HIGHLY_QUALIFIED_RATE,
    
    -- Tenure
    ROUND(AVG(DATEDIFF('day', st.HIRE_DATE, CURRENT_DATE()) / 365.25), 1) AS AVG_TENURE_YEARS,
    
    -- License Status
    COUNT(CASE WHEN st.LICENSE_EXPIRATION >= CURRENT_DATE() THEN 1 END) AS VALID_LICENSE_COUNT,
    COUNT(CASE WHEN st.LICENSE_EXPIRATION < CURRENT_DATE() THEN 1 END) AS EXPIRED_LICENSE_COUNT,
    
    -- Snapshot
    CURRENT_DATE() AS SNAPSHOT_DATE
    
FROM RAW_DEV.RAW_HR.STAFF_RAW st
WHERE st._IS_CURRENT = TRUE
GROUP BY st.PRIMARY_SCHOOL_ID, st.DISTRICT_ID, st.ROLE_CATEGORY, st.DEPARTMENT;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_STAFF_SUMMARY
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_staff_summary_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- BRIDGE: Student-Guardian Relationship
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.BRIDGE_STUDENT_GUARDIAN
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Bridge table linking students to guardians'
AS
SELECT
    sg.RELATIONSHIP_ID,
    sg.STUDENT_ID,
    sg.GUARDIAN_ID,
    sg.RELATIONSHIP_TYPE,
    sg.IS_PRIMARY_CONTACT,
    sg.AUTHORIZED_PICKUP,
    sg.EMERGENCY_CONTACT,
    sg._IS_CURRENT
FROM RAW_DEV.RAW_SIS.STUDENT_GUARDIAN_RAW sg
WHERE sg._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.BRIDGE_STUDENT_GUARDIAN
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_student_guardian_bridge_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL',
            GOVERNANCE.TAGS.FERPA_CATEGORY = 'DIRECTORY';

-- ─────────────────────────────────────────────────────────────────────────────
-- GRANT ACCESS TO ROLES
-- ─────────────────────────────────────────────────────────────────────────────

-- Grant usage on schemas
GRANT USAGE ON SCHEMA CURATED_DEV.CURATED_DIMENSIONS TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA CURATED_DEV.CURATED_FACTS TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA CURATED_DEV.CURATED_DIMENSIONS TO ROLE DATA_STEWARD;
GRANT USAGE ON SCHEMA CURATED_DEV.CURATED_FACTS TO ROLE DATA_STEWARD;

-- Grant select on all dynamic tables to data roles
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA CURATED_DEV.CURATED_DIMENSIONS TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA CURATED_DEV.CURATED_FACTS TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA CURATED_DEV.CURATED_DIMENSIONS TO ROLE DATA_ENGINEER;

-- Future grants
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA CURATED_DEV.CURATED_DIMENSIONS TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA CURATED_DEV.CURATED_FACTS TO ROLE DATA_ENGINEER;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Curated Layer Dynamic Tables Created Successfully' AS STATUS;

SHOW DYNAMIC TABLES IN DATABASE CURATED_DEV;

-- Check dynamic table status
-- SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.DYNAMIC_TABLES 
-- WHERE DATABASE_NAME = 'CURATED_DEV';
