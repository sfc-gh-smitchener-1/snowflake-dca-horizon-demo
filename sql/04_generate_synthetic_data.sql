-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT - SYNTHETIC DATA GENERATION & SCD LOADING
-- ============================================================================
-- 
-- This script:
--   1. Creates staging tables with synthetic data
--   2. Loads data into RAW tables using proper SCD Type 2 patterns
--   3. Generates realistic Massachusetts school district data:
--      - 25 Districts in Greater Boston area
--      - 250 Schools (Elementary, Middle, High)
--      - 100,000 Students (K-12)
--      - 12,000 Staff members
--      - 150,000 Guardians/Parents
--
-- SCD Type 2 Pattern:
--   - MERGE checks for changes using _ROW_HASH
--   - Changed records: set _IS_CURRENT=FALSE, _VALID_TO=CURRENT_TIMESTAMP
--   - Insert new/changed records with _IS_CURRENT=TRUE
--
-- Run order: After 03_raw_layer_tables.sql
-- RUN AS: DATA_ADMIN
-- ============================================================================

USE ROLE DATA_ADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE RAW_DEV;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: CREATE STAGING SCHEMA AND REFERENCE DATA
-- ═══════════════════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS RAW_DEV.STAGING
    COMMENT = 'Staging area for synthetic data before SCD load';

USE SCHEMA STAGING;

-- Massachusetts Districts reference data
CREATE OR REPLACE TABLE STG_DISTRICTS AS
SELECT * FROM (VALUES
    ('D001', 'Boston Public Schools', 'Suffolk', 'Boston'),
    ('D002', 'Cambridge Public Schools', 'Middlesex', 'Cambridge'),
    ('D003', 'Newton Public Schools', 'Middlesex', 'Newton'),
    ('D004', 'Brookline Public Schools', 'Norfolk', 'Brookline'),
    ('D005', 'Somerville Public Schools', 'Middlesex', 'Somerville'),
    ('D006', 'Quincy Public Schools', 'Norfolk', 'Quincy'),
    ('D007', 'Lexington Public Schools', 'Middlesex', 'Lexington'),
    ('D008', 'Arlington Public Schools', 'Middlesex', 'Arlington'),
    ('D009', 'Wellesley Public Schools', 'Norfolk', 'Wellesley'),
    ('D010', 'Needham Public Schools', 'Norfolk', 'Needham'),
    ('D011', 'Waltham Public Schools', 'Middlesex', 'Waltham'),
    ('D012', 'Malden Public Schools', 'Middlesex', 'Malden'),
    ('D013', 'Medford Public Schools', 'Middlesex', 'Medford'),
    ('D014', 'Revere Public Schools', 'Suffolk', 'Revere'),
    ('D015', 'Chelsea Public Schools', 'Suffolk', 'Chelsea'),
    ('D016', 'Everett Public Schools', 'Middlesex', 'Everett'),
    ('D017', 'Lynn Public Schools', 'Essex', 'Lynn'),
    ('D018', 'Salem Public Schools', 'Essex', 'Salem'),
    ('D019', 'Peabody Public Schools', 'Essex', 'Peabody'),
    ('D020', 'Beverly Public Schools', 'Essex', 'Beverly'),
    ('D021', 'Milton Public Schools', 'Norfolk', 'Milton'),
    ('D022', 'Dedham Public Schools', 'Norfolk', 'Dedham'),
    ('D023', 'Natick Public Schools', 'Middlesex', 'Natick'),
    ('D024', 'Framingham Public Schools', 'Middlesex', 'Framingham'),
    ('D025', 'Watertown Public Schools', 'Middlesex', 'Watertown')
) AS t(district_id, district_name, county, city);

-- School name components for generation
CREATE OR REPLACE TABLE STG_SCHOOL_NAMES AS
SELECT * FROM (VALUES
    ('Lincoln', 'Elementary'), ('Washington', 'Elementary'), ('Jefferson', 'Elementary'),
    ('Kennedy', 'Elementary'), ('Roosevelt', 'Elementary'), ('Adams', 'Elementary'),
    ('Franklin', 'Elementary'), ('Hamilton', 'Elementary'), ('Madison', 'Elementary'),
    ('Monroe', 'Elementary'), ('Oak Hill', 'Elementary'), ('Maple Grove', 'Elementary'),
    ('Riverside', 'Elementary'), ('Highland', 'Elementary'), ('Lakeside', 'Elementary'),
    ('Martin Luther King Jr.', 'Middle'), ('Central', 'Middle'), ('North', 'Middle'),
    ('South', 'Middle'), ('East', 'Middle'), ('West', 'Middle'), ('Heritage', 'Middle'),
    ('Innovation', 'Middle'), ('Discovery', 'Middle'), ('Unity', 'Middle'),
    ('Regional', 'High'), ('Memorial', 'High'), ('Technical', 'High'),
    ('Academy', 'High'), ('Preparatory', 'High')
) AS t(name_part, school_type);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: GENERATE STAGING DATA - DISTRICTS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE STAGING.STG_DISTRICT_RAW AS
SELECT
    district_id AS DISTRICT_ID,
    district_name AS DISTRICT_NAME,
    county AS COUNTY,
    city AS CITY,
    'MA' AS STATE,
    CONCAT('Dr. ', 
           CASE MOD(HASH(district_id), 10)
               WHEN 0 THEN 'Sarah Johnson' WHEN 1 THEN 'Michael Chen'
               WHEN 2 THEN 'Patricia Williams' WHEN 3 THEN 'Robert Garcia'
               WHEN 4 THEN 'Jennifer Martinez' WHEN 5 THEN 'David Brown'
               WHEN 6 THEN 'Elizabeth Taylor' WHEN 7 THEN 'James Wilson'
               WHEN 8 THEN 'Maria Rodriguez' ELSE 'Thomas Anderson'
           END) AS SUPERINTENDENT_NAME,
    CONCAT('617-', LPAD(MOD(HASH(district_id), 900) + 100, 3, '0'), '-', 
           LPAD(MOD(HASH(district_id || 'phone'), 9000) + 1000, 4, '0')) AS PHONE_MAIN,
    CONCAT(LOWER(REPLACE(district_name, ' ', '')), '.org') AS WEBSITE,
    '2025-2026' AS CURRENT_SCHOOL_YEAR,
    -- Row hash for SCD detection
    SHA2(CONCAT_WS('|', district_id, district_name, county, city), 256) AS _ROW_HASH
FROM STAGING.STG_DISTRICTS;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: GENERATE STAGING DATA - SCHOOLS (250)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE STAGING.STG_SCHOOL_RAW AS
WITH school_assignments AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY d.district_id, s.school_type, s.name_part) AS rn,
        d.district_id, d.district_name, d.county, d.city,
        s.name_part, s.school_type
    FROM STAGING.STG_DISTRICTS d
    CROSS JOIN STAGING.STG_SCHOOL_NAMES s
    ORDER BY HASH(d.district_id || s.name_part)
    LIMIT 250
)
SELECT
    CONCAT('SCH-', LPAD(rn, 4, '0')) AS SCHOOL_ID,
    CONCAT(name_part, ' ', school_type, ' School') AS SCHOOL_NAME,
    CONCAT(UPPER(LEFT(name_part, 3)), '-', school_type) AS SCHOOL_NAME_SHORT,
    school_type AS SCHOOL_TYPE,
    CASE school_type WHEN 'Elementary' THEN 'K-5' WHEN 'Middle' THEN '6-8' ELSE '9-12' END AS GRADE_LEVELS_SERVED,
    MOD(rn, 3) = 0 AS IS_TITLE_I,
    MOD(rn, 20) = 0 AS IS_MAGNET,
    MOD(rn, 25) = 0 AS IS_CHARTER,
    district_id AS DISTRICT_ID,
    district_name AS DISTRICT_NAME,
    CONCAT(MOD(rn * 17, 900) + 100, ' Main Street') AS ADDRESS,
    city AS CITY,
    'MA' AS STATE,
    CONCAT('02', LPAD(MOD(rn, 200) + 100, 3, '0')) AS ZIP_CODE,
    county AS COUNTY,
    42.35 + (MOD(rn, 100) * 0.005) AS LATITUDE,
    -71.05 - (MOD(rn, 100) * 0.005) AS LONGITUDE,
    CONCAT('617-', LPAD(MOD(HASH(rn), 900) + 100, 3, '0'), '-', 
           LPAD(MOD(HASH(rn || 'school'), 9000) + 1000, 4, '0')) AS PHONE_MAIN,
    NULL AS PHONE_FAX,
    CONCAT('https://', LOWER(REPLACE(name_part, ' ', '')), '.', 
           LOWER(REPLACE(district_name, ' Public Schools', '')), '.k12.ma.us') AS WEBSITE,
    CONCAT(LOWER(REPLACE(name_part, ' ', '')), '@', 
           LOWER(REPLACE(district_name, ' ', '')), '.org') AS EMAIL_MAIN,
    CONCAT('S-', LPAD(MOD(rn, 500) + 1, 4, '0')) AS PRINCIPAL_STAFF_ID,
    CONCAT('Principal ', 
           CASE MOD(rn, 10)
               WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams'
               WHEN 3 THEN 'Brown' WHEN 4 THEN 'Jones' WHEN 5 THEN 'Garcia'
               WHEN 6 THEN 'Miller' WHEN 7 THEN 'Davis' WHEN 8 THEN 'Rodriguez'
               ELSE 'Martinez'
           END) AS PRINCIPAL_NAME,
    CASE school_type WHEN 'Elementary' THEN 400 + MOD(rn, 200) 
                     WHEN 'Middle' THEN 600 + MOD(rn, 300) 
                     ELSE 1000 + MOD(rn, 500) END AS BUILDING_CAPACITY,
    CASE school_type WHEN 'Elementary' THEN 350 + MOD(rn, 150)
                     WHEN 'Middle' THEN 500 + MOD(rn, 200)
                     ELSE 800 + MOD(rn, 400) END AS CURRENT_ENROLLMENT,
    CASE school_type WHEN 'Elementary' THEN 30 + MOD(rn, 20)
                     WHEN 'Middle' THEN 50 + MOD(rn, 30)
                     ELSE 80 + MOD(rn, 40) END AS STAFF_COUNT,
    CASE school_type WHEN 'Elementary' THEN 20 + MOD(rn, 15)
                     WHEN 'Middle' THEN 35 + MOD(rn, 20)
                     ELSE 55 + MOD(rn, 30) END AS TEACHER_COUNT,
    '2025-2026' AS SCHOOL_YEAR,
    '2025-09-03'::DATE AS FIRST_DAY_OF_SCHOOL,
    '2026-06-18'::DATE AS LAST_DAY_OF_SCHOOL,
    CASE MOD(rn, 5) WHEN 0 THEN 'Exemplary' WHEN 1 THEN 'Commendable'
                    WHEN 2 THEN 'Acceptable' ELSE 'Commendable' END AS ACCOUNTABILITY_RATING,
    CASE WHEN school_type = 'High' THEN 85 + MOD(rn, 14) ELSE NULL END AS GRADUATION_RATE,
    92 + (MOD(rn, 7) * 0.5) AS ATTENDANCE_RATE,
    -- Row hash for SCD detection
    SHA2(CONCAT_WS('|', 
        CONCAT('SCH-', LPAD(rn, 4, '0')), 
        CONCAT(name_part, ' ', school_type, ' School'),
        district_id, city
    ), 256) AS _ROW_HASH
FROM school_assignments;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: GENERATE STAGING DATA - STUDENTS (100,000)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE STAGING.STG_STUDENT_RAW AS
WITH student_base AS (
    SELECT 
        SEQ4() + 1 AS student_num,
        CONCAT('STU-', LPAD(SEQ4() + 1, 6, '0')) AS student_id
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),
schools AS (
    SELECT SCHOOL_ID, SCHOOL_TYPE, DISTRICT_ID, CITY, COUNTY, ZIP_CODE,
           ROW_NUMBER() OVER (ORDER BY SCHOOL_ID) AS school_rn
    FROM STAGING.STG_SCHOOL_RAW
)
SELECT
    s.student_id AS STUDENT_ID,
    -- First name (diverse population)
    CASE MOD(HASH(s.student_id || 'fn'), 64)
        WHEN 0 THEN 'Emma' WHEN 1 THEN 'Liam' WHEN 2 THEN 'Olivia' WHEN 3 THEN 'Noah'
        WHEN 4 THEN 'Ava' WHEN 5 THEN 'Ethan' WHEN 6 THEN 'Sophia' WHEN 7 THEN 'Mason'
        WHEN 8 THEN 'Isabella' WHEN 9 THEN 'William' WHEN 10 THEN 'Mia' WHEN 11 THEN 'James'
        WHEN 12 THEN 'Charlotte' WHEN 13 THEN 'Benjamin' WHEN 14 THEN 'Amelia' WHEN 15 THEN 'Lucas'
        WHEN 16 THEN 'Harper' WHEN 17 THEN 'Henry' WHEN 18 THEN 'Evelyn' WHEN 19 THEN 'Alexander'
        WHEN 20 THEN 'Wei' WHEN 21 THEN 'Ming' WHEN 22 THEN 'Yuki' WHEN 23 THEN 'Hiroshi'
        WHEN 24 THEN 'Priya' WHEN 25 THEN 'Raj' WHEN 26 THEN 'Fatima' WHEN 27 THEN 'Ahmed'
        WHEN 28 THEN 'Jose' WHEN 29 THEN 'Maria' WHEN 30 THEN 'Carlos' WHEN 31 THEN 'Ana'
        ELSE 'Alex'
    END AS FIRST_NAME,
    CASE WHEN MOD(s.student_num, 3) = 0 THEN 'Marie' ELSE NULL END AS MIDDLE_NAME,
    -- Last name (diverse population)
    CASE MOD(HASH(s.student_id || 'ln'), 56)
        WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams' WHEN 3 THEN 'Brown'
        WHEN 4 THEN 'Jones' WHEN 5 THEN 'Garcia' WHEN 6 THEN 'Miller' WHEN 7 THEN 'Davis'
        WHEN 8 THEN 'Rodriguez' WHEN 9 THEN 'Martinez' WHEN 10 THEN 'Chen' WHEN 11 THEN 'Patel'
        WHEN 12 THEN 'Kim' WHEN 13 THEN 'Nguyen' WHEN 14 THEN 'Singh' WHEN 15 THEN 'Kumar'
        WHEN 16 THEN 'Lee' WHEN 17 THEN 'Wang' WHEN 18 THEN 'Zhang' WHEN 19 THEN 'Lopez'
        ELSE 'Adams'
    END AS LAST_NAME,
    NULL AS PREFERRED_NAME,
    NULL AS SUFFIX,
    -- SSN (sensitive)
    CONCAT(LPAD(MOD(HASH(s.student_id || 'ssn1'), 900) + 100, 3, '0'), '-',
           LPAD(MOD(HASH(s.student_id || 'ssn2'), 100), 2, '0'), '-',
           LPAD(MOD(HASH(s.student_id || 'ssn3'), 10000), 4, '0')) AS SSN,
    CONCAT('MA-', LPAD(s.student_num, 8, '0')) AS STATE_ID,
    -- Date of birth (ages 5-18)
    DATEADD('year', -(5 + MOD(s.student_num, 14)), 
            DATEADD('day', -MOD(s.student_num, 365), '2026-01-01'::DATE)) AS DATE_OF_BIRTH,
    CASE MOD(s.student_num, 2) WHEN 0 THEN 'Male' ELSE 'Female' END AS GENDER,
    -- Ethnicity (MA demographics)
    CASE MOD(s.student_num, 10)
        WHEN 0 THEN 'Asian' WHEN 1 THEN 'Asian'
        WHEN 2 THEN 'Hispanic/Latino' WHEN 3 THEN 'Hispanic/Latino'
        WHEN 4 THEN 'Black/African American'
        ELSE 'White'
    END AS ETHNICITY,
    CASE MOD(s.student_num, 10)
        WHEN 0 THEN 'Asian' WHEN 1 THEN 'Asian'
        WHEN 2 THEN 'Hispanic or Latino' WHEN 3 THEN 'Hispanic or Latino'
        WHEN 4 THEN 'Black or African American'
        ELSE 'White'
    END AS RACE,
    CASE MOD(s.student_num, 20)
        WHEN 0 THEN 'Spanish' WHEN 1 THEN 'Portuguese' WHEN 2 THEN 'Chinese'
        WHEN 3 THEN 'Vietnamese' WHEN 4 THEN 'Haitian Creole'
        ELSE 'English'
    END AS PRIMARY_LANGUAGE,
    MOD(s.student_num, 10) = 0 AS ELL_STATUS,
    -- Address
    CONCAT(MOD(HASH(s.student_id), 9999) + 1, ' ', 
           CASE MOD(s.student_num, 8)
               WHEN 0 THEN 'Oak Street' WHEN 1 THEN 'Maple Avenue' WHEN 2 THEN 'Pine Road'
               WHEN 3 THEN 'Cedar Lane' WHEN 4 THEN 'Elm Drive' WHEN 5 THEN 'Washington Street'
               WHEN 6 THEN 'Main Street' ELSE 'Park Avenue'
           END) AS HOME_ADDRESS_LINE1,
    CASE WHEN MOD(s.student_num, 5) = 0 THEN CONCAT('Apt ', MOD(s.student_num, 500) + 1) ELSE NULL END AS HOME_ADDRESS_LINE2,
    sch.CITY AS CITY,
    'MA' AS STATE,
    sch.ZIP_CODE AS ZIP_CODE,
    sch.COUNTY AS COUNTY,
    sch.SCHOOL_ID AS CURRENT_SCHOOL_ID,
    sch.DISTRICT_ID AS CURRENT_DISTRICT_ID,
    -- Grade level based on school type
    CASE 
        WHEN sch.SCHOOL_TYPE = 'Elementary' THEN 
            CASE MOD(s.student_num, 6) WHEN 0 THEN 'K' ELSE LPAD(MOD(s.student_num, 5) + 1, 2, '0') END
        WHEN sch.SCHOOL_TYPE = 'Middle' THEN LPAD(MOD(s.student_num, 3) + 6, 2, '0')
        ELSE LPAD(MOD(s.student_num, 4) + 9, 2, '0')
    END AS GRADE_LEVEL,
    CONCAT(sch.SCHOOL_ID, '-HR-', LPAD(MOD(s.student_num, 30) + 1, 2, '0')) AS HOMEROOM,
    'Active' AS ENROLLMENT_STATUS,
    DATEADD('year', -MOD(s.student_num, 5), '2025-09-03'::DATE) AS ENROLLMENT_DATE,
    CASE sch.SCHOOL_TYPE
        WHEN 'High' THEN 2026 + (4 - MOD(s.student_num, 4))
        WHEN 'Middle' THEN 2030 + MOD(s.student_num, 3)
        ELSE 2035 - MOD(s.student_num, 6)
    END AS EXPECTED_GRADUATION_YEAR,
    -- Special programs (realistic percentages)
    MOD(s.student_num, 7) = 0 AS SPECIAL_EDUCATION,   -- ~14%
    MOD(s.student_num, 20) = 0 AS SECTION_504,        -- ~5%
    MOD(s.student_num, 15) = 0 AS GIFTED_TALENTED,    -- ~7%
    CASE MOD(s.student_num, 4) WHEN 0 THEN 'Free' WHEN 1 THEN 'Reduced' ELSE 'Full' END AS FREE_REDUCED_LUNCH,
    MOD(s.student_num, 50) = 0 AS HOMELESS_STATUS,    -- ~2%
    -- Row hash for SCD detection
    SHA2(CONCAT_WS('|', s.student_id, FIRST_NAME, LAST_NAME, sch.SCHOOL_ID, GRADE_LEVEL), 256) AS _ROW_HASH
FROM student_base s
JOIN schools sch ON MOD(s.student_num, 250) + 1 = sch.school_rn;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: GENERATE STAGING DATA - STAFF (12,000)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE STAGING.STG_STAFF_RAW AS
WITH staff_base AS (
    SELECT 
        SEQ4() + 1 AS staff_num,
        CONCAT('S-', LPAD(SEQ4() + 1, 5, '0')) AS staff_id
    FROM TABLE(GENERATOR(ROWCOUNT => 12000))
),
schools AS (
    SELECT SCHOOL_ID, DISTRICT_ID, ROW_NUMBER() OVER (ORDER BY SCHOOL_ID) AS school_rn
    FROM STAGING.STG_SCHOOL_RAW
)
SELECT
    s.staff_id AS STAFF_ID,
    CASE MOD(s.staff_num, 40)
        WHEN 0 THEN 'John' WHEN 1 THEN 'Mary' WHEN 2 THEN 'Robert' WHEN 3 THEN 'Patricia'
        WHEN 4 THEN 'Michael' WHEN 5 THEN 'Jennifer' WHEN 6 THEN 'William' WHEN 7 THEN 'Linda'
        WHEN 8 THEN 'Wei' WHEN 9 THEN 'Mei' WHEN 10 THEN 'Juan' WHEN 11 THEN 'Maria'
        ELSE 'Alex'
    END AS FIRST_NAME,
    NULL AS MIDDLE_NAME,
    CASE MOD(s.staff_num, 30)
        WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams' WHEN 3 THEN 'Brown'
        WHEN 4 THEN 'Chen' WHEN 5 THEN 'Patel' WHEN 6 THEN 'Kim' WHEN 7 THEN 'Nguyen'
        WHEN 8 THEN 'Garcia' WHEN 9 THEN 'Martinez'
        ELSE 'Adams'
    END AS LAST_NAME,
    NULL AS PREFERRED_NAME,
    CONCAT(LOWER(FIRST_NAME), '.', LOWER(LAST_NAME), '@district.edu') AS EMAIL,
    CONCAT(LOWER(FIRST_NAME), '.', LOWER(LAST_NAME), '@gmail.com') AS PERSONAL_EMAIL,
    CONCAT('617-', LPAD(MOD(HASH(s.staff_id), 900) + 100, 3, '0'), '-', 
           LPAD(MOD(HASH(s.staff_id || 'work'), 9000) + 1000, 4, '0')) AS PHONE_WORK,
    CONCAT('617-', LPAD(MOD(HASH(s.staff_id || 'mob'), 900) + 100, 3, '0'), '-', 
           LPAD(MOD(HASH(s.staff_id || 'mobile'), 9000) + 1000, 4, '0')) AS PHONE_MOBILE,
    CONCAT(LPAD(MOD(HASH(s.staff_id || 'ssn1'), 900) + 100, 3, '0'), '-',
           LPAD(MOD(HASH(s.staff_id || 'ssn2'), 100), 2, '0'), '-',
           LPAD(MOD(HASH(s.staff_id || 'ssn3'), 10000), 4, '0')) AS SSN,
    DATEADD('year', -(25 + MOD(s.staff_num, 40)), CURRENT_DATE()) AS DATE_OF_BIRTH,
    CONCAT(MOD(HASH(s.staff_id), 9999) + 1, ' Main Street') AS HOME_ADDRESS,
    'Boston' AS CITY,
    'MA' AS STATE,
    CONCAT('02', LPAD(MOD(s.staff_num, 200) + 100, 3, '0')) AS ZIP_CODE,
    CASE WHEN MOD(s.staff_num, 20) = 0 THEN 'Part-Time' ELSE 'Full-Time' END AS EMPLOYEE_TYPE,
    CASE 
        WHEN MOD(s.staff_num, 50) = 0 THEN 'Principal'
        WHEN MOD(s.staff_num, 50) = 1 THEN 'Assistant Principal'
        WHEN MOD(s.staff_num, 20) < 2 THEN 'Counselor'
        WHEN MOD(s.staff_num, 10) < 7 THEN 'Teacher'
        WHEN MOD(s.staff_num, 10) = 7 THEN 'Special Education Teacher'
        ELSE 'Support Staff'
    END AS POSITION_TITLE,
    CASE 
        WHEN MOD(s.staff_num, 50) IN (0, 1) THEN 'Administrator'
        WHEN MOD(s.staff_num, 20) < 2 THEN 'Counselor'
        WHEN MOD(s.staff_num, 10) < 8 THEN 'Teacher'
        ELSE 'Support'
    END AS ROLE_CATEGORY,
    CASE MOD(s.staff_num, 8)
        WHEN 0 THEN 'Mathematics' WHEN 1 THEN 'English Language Arts'
        WHEN 2 THEN 'Science' WHEN 3 THEN 'Social Studies'
        WHEN 4 THEN 'Special Education' WHEN 5 THEN 'Physical Education'
        WHEN 6 THEN 'Arts' ELSE 'General'
    END AS DEPARTMENT,
    sch.SCHOOL_ID AS PRIMARY_SCHOOL_ID,
    sch.DISTRICT_ID AS DISTRICT_ID,
    DATEADD('year', -MOD(s.staff_num, 25), '2025-08-15'::DATE) AS HIRE_DATE,
    DATEADD('year', -MOD(s.staff_num, 5), '2025-08-15'::DATE) AS START_DATE_CURRENT_POSITION,
    NULL AS TERMINATION_DATE,
    'Active' AS EMPLOYMENT_STATUS,
    CASE MOD(s.staff_num, 4) WHEN 0 THEN 'Doctorate' WHEN 1 THEN 'Master' ELSE 'Bachelor' END AS HIGHEST_DEGREE,
    CASE WHEN MOD(s.staff_num, 10) < 8 THEN 'MA Professional License' ELSE NULL END AS TEACHING_LICENSE,
    CASE WHEN MOD(s.staff_num, 10) < 8 THEN DATEADD('year', MOD(s.staff_num, 5), CURRENT_DATE()) ELSE NULL END AS LICENSE_EXPIRATION,
    MOD(s.staff_num, 30) + 1 AS YEARS_EXPERIENCE,
    MOD(s.staff_num, 10) < 8 AS HIGHLY_QUALIFIED,
    45000 + (MOD(s.staff_num, 60) * 1000) AS SALARY,
    CONCAT('G', MOD(s.staff_num, 10) + 1) AS PAY_GRADE,
    CASE WHEN MOD(s.staff_num, 10) < 8 THEN 'Massachusetts Teachers Association' ELSE NULL END AS UNION_MEMBERSHIP,
    SHA2(CONCAT_WS('|', s.staff_id, FIRST_NAME, LAST_NAME, sch.SCHOOL_ID), 256) AS _ROW_HASH
FROM staff_base s
JOIN schools sch ON MOD(s.staff_num, 250) + 1 = sch.school_rn;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: GENERATE STAGING DATA - GUARDIANS (150,000)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE STAGING.STG_GUARDIAN_RAW AS
WITH guardian_base AS (
    SELECT 
        SEQ4() + 1 AS guardian_num,
        CONCAT('G-', LPAD(SEQ4() + 1, 6, '0')) AS guardian_id
    FROM TABLE(GENERATOR(ROWCOUNT => 150000))
)
SELECT
    g.guardian_id AS GUARDIAN_ID,
    CASE MOD(g.guardian_num, 40)
        WHEN 0 THEN 'James' WHEN 1 THEN 'Mary' WHEN 2 THEN 'Robert' WHEN 3 THEN 'Patricia'
        WHEN 4 THEN 'Wei' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Juan' WHEN 7 THEN 'Maria'
        ELSE 'Alex'
    END AS FIRST_NAME,
    CASE MOD(g.guardian_num, 30)
        WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Chen' WHEN 3 THEN 'Patel'
        WHEN 4 THEN 'Garcia' WHEN 5 THEN 'Kim'
        ELSE 'Adams'
    END AS LAST_NAME,
    CASE MOD(g.guardian_num, 10)
        WHEN 0 THEN 'Mother' WHEN 1 THEN 'Father' WHEN 2 THEN 'Mother' WHEN 3 THEN 'Father'
        WHEN 6 THEN 'Grandmother' WHEN 7 THEN 'Grandfather'
        WHEN 8 THEN 'Legal Guardian' ELSE 'Foster Parent'
    END AS RELATIONSHIP_TYPE,
    CONCAT(LOWER(FIRST_NAME), '.', LOWER(LAST_NAME), MOD(g.guardian_num, 100), '@gmail.com') AS EMAIL_PRIMARY,
    NULL AS EMAIL_SECONDARY,
    CONCAT('617-', LPAD(MOD(HASH(g.guardian_id || 'home'), 900) + 100, 3, '0'), '-', 
           LPAD(MOD(HASH(g.guardian_id || 'h'), 9000) + 1000, 4, '0')) AS PHONE_HOME,
    CONCAT('617-', LPAD(MOD(HASH(g.guardian_id || 'mob'), 900) + 100, 3, '0'), '-', 
           LPAD(MOD(HASH(g.guardian_id || 'm'), 9000) + 1000, 4, '0')) AS PHONE_MOBILE,
    NULL AS PHONE_WORK,
    CONCAT(MOD(HASH(g.guardian_id), 9999) + 1, ' Main Street') AS ADDRESS_LINE1,
    NULL AS ADDRESS_LINE2,
    CASE MOD(g.guardian_num, 10)
        WHEN 0 THEN 'Boston' WHEN 1 THEN 'Cambridge' WHEN 2 THEN 'Somerville'
        WHEN 3 THEN 'Newton' ELSE 'Brookline'
    END AS CITY,
    'MA' AS STATE,
    CONCAT('02', LPAD(MOD(g.guardian_num, 200) + 100, 3, '0')) AS ZIP_CODE,
    NULL AS EMPLOYER,
    CASE MOD(g.guardian_num, 10) WHEN 0 THEN 'Spanish' WHEN 1 THEN 'Chinese' ELSE 'English' END AS PREFERRED_LANGUAGE,
    MOD(g.guardian_num, 10) < 8 AS PORTAL_ACCOUNT_ACTIVE,
    CASE WHEN MOD(g.guardian_num, 10) < 8 THEN CONCAT('parent', g.guardian_num) ELSE NULL END AS PORTAL_USERNAME,
    MOD(g.guardian_num, 5) < 4 AS RECEIVES_DISTRICT_COMMUNICATIONS,
    SHA2(CONCAT_WS('|', g.guardian_id, FIRST_NAME, LAST_NAME), 256) AS _ROW_HASH
FROM guardian_base g;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 7: LOAD DATA USING SCD TYPE 2 MERGE PATTERN
-- ═══════════════════════════════════════════════════════════════════════════

-- Load Districts with SCD Type 2
MERGE INTO RAW_DEV.RAW_SIS.DISTRICT_RAW AS tgt
USING STAGING.STG_DISTRICT_RAW AS src
ON tgt.DISTRICT_ID = src.DISTRICT_ID AND tgt._IS_CURRENT = TRUE
WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
    UPDATE SET 
        _IS_CURRENT = FALSE,
        _VALID_TO = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (DISTRICT_ID, DISTRICT_NAME, COUNTY, CITY, STATE, SUPERINTENDENT_NAME, 
            PHONE_MAIN, WEBSITE, CURRENT_SCHOOL_YEAR, 
            _LOADED_AT, _SOURCE_SYSTEM, _ROW_HASH, _IS_CURRENT, _VALID_FROM, _VALID_TO)
    VALUES (src.DISTRICT_ID, src.DISTRICT_NAME, src.COUNTY, src.CITY, src.STATE, src.SUPERINTENDENT_NAME,
            src.PHONE_MAIN, src.WEBSITE, src.CURRENT_SCHOOL_YEAR,
            CURRENT_TIMESTAMP(), 'DISTRICT_MANAGEMENT_SYSTEM', src._ROW_HASH, TRUE, CURRENT_TIMESTAMP(), '9999-12-31'::TIMESTAMP_NTZ);

-- Insert new versions for changed records
INSERT INTO RAW_DEV.RAW_SIS.DISTRICT_RAW 
    (DISTRICT_ID, DISTRICT_NAME, COUNTY, CITY, STATE, SUPERINTENDENT_NAME,
     PHONE_MAIN, WEBSITE, CURRENT_SCHOOL_YEAR,
     _LOADED_AT, _SOURCE_SYSTEM, _ROW_HASH, _IS_CURRENT, _VALID_FROM, _VALID_TO)
SELECT 
    src.DISTRICT_ID, src.DISTRICT_NAME, src.COUNTY, src.CITY, src.STATE, src.SUPERINTENDENT_NAME,
    src.PHONE_MAIN, src.WEBSITE, src.CURRENT_SCHOOL_YEAR,
    CURRENT_TIMESTAMP(), 'DISTRICT_MANAGEMENT_SYSTEM', src._ROW_HASH, TRUE, CURRENT_TIMESTAMP(), '9999-12-31'::TIMESTAMP_NTZ
FROM STAGING.STG_DISTRICT_RAW src
JOIN RAW_DEV.RAW_SIS.DISTRICT_RAW tgt 
    ON src.DISTRICT_ID = tgt.DISTRICT_ID 
    AND tgt._IS_CURRENT = FALSE 
    AND tgt._VALID_TO > DATEADD('minute', -1, CURRENT_TIMESTAMP())
WHERE NOT EXISTS (
    SELECT 1 FROM RAW_DEV.RAW_SIS.DISTRICT_RAW curr
    WHERE curr.DISTRICT_ID = src.DISTRICT_ID AND curr._IS_CURRENT = TRUE
);

-- Load Schools with SCD Type 2
MERGE INTO RAW_DEV.RAW_SIS.SCHOOL_RAW AS tgt
USING STAGING.STG_SCHOOL_RAW AS src
ON tgt.SCHOOL_ID = src.SCHOOL_ID AND tgt._IS_CURRENT = TRUE
WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
    UPDATE SET _IS_CURRENT = FALSE, _VALID_TO = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (SCHOOL_ID, SCHOOL_NAME, SCHOOL_NAME_SHORT, SCHOOL_TYPE, GRADE_LEVELS_SERVED,
            IS_TITLE_I, IS_MAGNET, IS_CHARTER, DISTRICT_ID, DISTRICT_NAME,
            ADDRESS, CITY, STATE, ZIP_CODE, COUNTY, LATITUDE, LONGITUDE,
            PHONE_MAIN, PHONE_FAX, WEBSITE, EMAIL_MAIN,
            PRINCIPAL_STAFF_ID, PRINCIPAL_NAME, BUILDING_CAPACITY, CURRENT_ENROLLMENT,
            STAFF_COUNT, TEACHER_COUNT, SCHOOL_YEAR, FIRST_DAY_OF_SCHOOL, LAST_DAY_OF_SCHOOL,
            ACCOUNTABILITY_RATING, GRADUATION_RATE, ATTENDANCE_RATE,
            _LOADED_AT, _SOURCE_SYSTEM, _ROW_HASH, _IS_CURRENT, _VALID_FROM, _VALID_TO)
    VALUES (src.SCHOOL_ID, src.SCHOOL_NAME, src.SCHOOL_NAME_SHORT, src.SCHOOL_TYPE, src.GRADE_LEVELS_SERVED,
            src.IS_TITLE_I, src.IS_MAGNET, src.IS_CHARTER, src.DISTRICT_ID, src.DISTRICT_NAME,
            src.ADDRESS, src.CITY, src.STATE, src.ZIP_CODE, src.COUNTY, src.LATITUDE, src.LONGITUDE,
            src.PHONE_MAIN, src.PHONE_FAX, src.WEBSITE, src.EMAIL_MAIN,
            src.PRINCIPAL_STAFF_ID, src.PRINCIPAL_NAME, src.BUILDING_CAPACITY, src.CURRENT_ENROLLMENT,
            src.STAFF_COUNT, src.TEACHER_COUNT, src.SCHOOL_YEAR, src.FIRST_DAY_OF_SCHOOL, src.LAST_DAY_OF_SCHOOL,
            src.ACCOUNTABILITY_RATING, src.GRADUATION_RATE, src.ATTENDANCE_RATE,
            CURRENT_TIMESTAMP(), 'DISTRICT_MANAGEMENT_SYSTEM', src._ROW_HASH, TRUE, CURRENT_TIMESTAMP(), '9999-12-31'::TIMESTAMP_NTZ);

-- Load Students with SCD Type 2
MERGE INTO RAW_DEV.RAW_SIS.STUDENT_RAW AS tgt
USING STAGING.STG_STUDENT_RAW AS src
ON tgt.STUDENT_ID = src.STUDENT_ID AND tgt._IS_CURRENT = TRUE
WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
    UPDATE SET _IS_CURRENT = FALSE, _VALID_TO = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (STUDENT_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME, PREFERRED_NAME, SUFFIX,
            SSN, STATE_ID, DATE_OF_BIRTH, GENDER, ETHNICITY, RACE, PRIMARY_LANGUAGE, ELL_STATUS,
            HOME_ADDRESS_LINE1, HOME_ADDRESS_LINE2, CITY, STATE, ZIP_CODE, COUNTY,
            CURRENT_SCHOOL_ID, CURRENT_DISTRICT_ID, GRADE_LEVEL, HOMEROOM,
            ENROLLMENT_STATUS, ENROLLMENT_DATE, EXPECTED_GRADUATION_YEAR,
            SPECIAL_EDUCATION, SECTION_504, GIFTED_TALENTED, FREE_REDUCED_LUNCH, HOMELESS_STATUS,
            _LOADED_AT, _SOURCE_SYSTEM, _ROW_HASH, _IS_CURRENT, _VALID_FROM, _VALID_TO)
    VALUES (src.STUDENT_ID, src.FIRST_NAME, src.MIDDLE_NAME, src.LAST_NAME, src.PREFERRED_NAME, src.SUFFIX,
            src.SSN, src.STATE_ID, src.DATE_OF_BIRTH, src.GENDER, src.ETHNICITY, src.RACE, src.PRIMARY_LANGUAGE, src.ELL_STATUS,
            src.HOME_ADDRESS_LINE1, src.HOME_ADDRESS_LINE2, src.CITY, src.STATE, src.ZIP_CODE, src.COUNTY,
            src.CURRENT_SCHOOL_ID, src.CURRENT_DISTRICT_ID, src.GRADE_LEVEL, src.HOMEROOM,
            src.ENROLLMENT_STATUS, src.ENROLLMENT_DATE, src.EXPECTED_GRADUATION_YEAR,
            src.SPECIAL_EDUCATION, src.SECTION_504, src.GIFTED_TALENTED, src.FREE_REDUCED_LUNCH, src.HOMELESS_STATUS,
            CURRENT_TIMESTAMP(), 'STUDENT_INFORMATION_SYSTEM', src._ROW_HASH, TRUE, CURRENT_TIMESTAMP(), '9999-12-31'::TIMESTAMP_NTZ);

-- Load Staff with SCD Type 2
MERGE INTO RAW_DEV.RAW_HR.STAFF_RAW AS tgt
USING STAGING.STG_STAFF_RAW AS src
ON tgt.STAFF_ID = src.STAFF_ID AND tgt._IS_CURRENT = TRUE
WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
    UPDATE SET _IS_CURRENT = FALSE, _VALID_TO = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (STAFF_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME, PREFERRED_NAME,
            EMAIL, PERSONAL_EMAIL, PHONE_WORK, PHONE_MOBILE, SSN, DATE_OF_BIRTH,
            HOME_ADDRESS, CITY, STATE, ZIP_CODE,
            EMPLOYEE_TYPE, POSITION_TITLE, ROLE_CATEGORY, DEPARTMENT, PRIMARY_SCHOOL_ID, DISTRICT_ID,
            HIRE_DATE, START_DATE_CURRENT_POSITION, TERMINATION_DATE, EMPLOYMENT_STATUS,
            HIGHEST_DEGREE, TEACHING_LICENSE, LICENSE_EXPIRATION, YEARS_EXPERIENCE, HIGHLY_QUALIFIED,
            SALARY, PAY_GRADE, UNION_MEMBERSHIP,
            _LOADED_AT, _SOURCE_SYSTEM, _ROW_HASH, _IS_CURRENT, _VALID_FROM, _VALID_TO)
    VALUES (src.STAFF_ID, src.FIRST_NAME, src.MIDDLE_NAME, src.LAST_NAME, src.PREFERRED_NAME,
            src.EMAIL, src.PERSONAL_EMAIL, src.PHONE_WORK, src.PHONE_MOBILE, src.SSN, src.DATE_OF_BIRTH,
            src.HOME_ADDRESS, src.CITY, src.STATE, src.ZIP_CODE,
            src.EMPLOYEE_TYPE, src.POSITION_TITLE, src.ROLE_CATEGORY, src.DEPARTMENT, src.PRIMARY_SCHOOL_ID, src.DISTRICT_ID,
            src.HIRE_DATE, src.START_DATE_CURRENT_POSITION, src.TERMINATION_DATE, src.EMPLOYMENT_STATUS,
            src.HIGHEST_DEGREE, src.TEACHING_LICENSE, src.LICENSE_EXPIRATION, src.YEARS_EXPERIENCE, src.HIGHLY_QUALIFIED,
            src.SALARY, src.PAY_GRADE, src.UNION_MEMBERSHIP,
            CURRENT_TIMESTAMP(), 'HR_INFORMATION_SYSTEM', src._ROW_HASH, TRUE, CURRENT_TIMESTAMP(), '9999-12-31'::TIMESTAMP_NTZ);

-- Load Guardians with SCD Type 2
MERGE INTO RAW_DEV.RAW_SIS.GUARDIAN_RAW AS tgt
USING STAGING.STG_GUARDIAN_RAW AS src
ON tgt.GUARDIAN_ID = src.GUARDIAN_ID AND tgt._IS_CURRENT = TRUE
WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
    UPDATE SET _IS_CURRENT = FALSE, _VALID_TO = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (GUARDIAN_ID, FIRST_NAME, LAST_NAME, RELATIONSHIP_TYPE,
            EMAIL_PRIMARY, EMAIL_SECONDARY, PHONE_HOME, PHONE_MOBILE, PHONE_WORK,
            ADDRESS_LINE1, ADDRESS_LINE2, CITY, STATE, ZIP_CODE,
            EMPLOYER, PREFERRED_LANGUAGE, PORTAL_ACCOUNT_ACTIVE, PORTAL_USERNAME, RECEIVES_DISTRICT_COMMUNICATIONS,
            _LOADED_AT, _SOURCE_SYSTEM, _ROW_HASH, _IS_CURRENT, _VALID_FROM, _VALID_TO)
    VALUES (src.GUARDIAN_ID, src.FIRST_NAME, src.LAST_NAME, src.RELATIONSHIP_TYPE,
            src.EMAIL_PRIMARY, src.EMAIL_SECONDARY, src.PHONE_HOME, src.PHONE_MOBILE, src.PHONE_WORK,
            src.ADDRESS_LINE1, src.ADDRESS_LINE2, src.CITY, src.STATE, src.ZIP_CODE,
            src.EMPLOYER, src.PREFERRED_LANGUAGE, src.PORTAL_ACCOUNT_ACTIVE, src.PORTAL_USERNAME, src.RECEIVES_DISTRICT_COMMUNICATIONS,
            CURRENT_TIMESTAMP(), 'STUDENT_INFORMATION_SYSTEM', src._ROW_HASH, TRUE, CURRENT_TIMESTAMP(), '9999-12-31'::TIMESTAMP_NTZ);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 8: CREATE STUDENT-GUARDIAN RELATIONSHIPS
-- ═══════════════════════════════════════════════════════════════════════════

-- Load Student-Guardian relationships (simple insert, no SCD needed for bridge table)
INSERT INTO RAW_DEV.RAW_SIS.STUDENT_GUARDIAN_RAW 
    (RELATIONSHIP_ID, STUDENT_ID, GUARDIAN_ID, RELATIONSHIP_TYPE, 
     IS_PRIMARY_CONTACT, AUTHORIZED_PICKUP, EMERGENCY_CONTACT, 
     _LOADED_AT, _SOURCE_SYSTEM, _IS_CURRENT)
SELECT
    CONCAT(s.STUDENT_ID, '-', g.GUARDIAN_ID) AS RELATIONSHIP_ID,
    s.STUDENT_ID,
    g.GUARDIAN_ID,
    g.RELATIONSHIP_TYPE,
    MOD(HASH(s.STUDENT_ID || g.GUARDIAN_ID), 2) = 0 AS IS_PRIMARY_CONTACT,
    MOD(HASH(s.STUDENT_ID || g.GUARDIAN_ID || 'pickup'), 3) < 2 AS AUTHORIZED_PICKUP,
    MOD(HASH(s.STUDENT_ID || g.GUARDIAN_ID || 'emergency'), 2) = 0 AS EMERGENCY_CONTACT,
    CURRENT_TIMESTAMP(),
    'STUDENT_INFORMATION_SYSTEM',
    TRUE
FROM RAW_DEV.RAW_SIS.STUDENT_RAW s
CROSS JOIN LATERAL (
    SELECT GUARDIAN_ID, RELATIONSHIP_TYPE FROM RAW_DEV.RAW_SIS.GUARDIAN_RAW 
    WHERE _IS_CURRENT = TRUE
      AND MOD(HASH(s.STUDENT_ID || GUARDIAN_ID), 100) < 2  -- 1-2 guardians per student
    ORDER BY HASH(s.STUDENT_ID || GUARDIAN_ID)
    LIMIT 2
) g
WHERE s._IS_CURRENT = TRUE
  AND NOT EXISTS (
      SELECT 1 FROM RAW_DEV.RAW_SIS.STUDENT_GUARDIAN_RAW sg
      WHERE sg.STUDENT_ID = s.STUDENT_ID AND sg.GUARDIAN_ID = g.GUARDIAN_ID
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Synthetic Data Loaded with SCD Type 2 Pattern' AS STATUS;

SELECT 
    'Districts' AS entity, 
    COUNT(*) AS total_records,
    SUM(CASE WHEN _IS_CURRENT THEN 1 ELSE 0 END) AS current_records,
    SUM(CASE WHEN NOT _IS_CURRENT THEN 1 ELSE 0 END) AS historical_records
FROM RAW_DEV.RAW_SIS.DISTRICT_RAW
UNION ALL
SELECT 'Schools', COUNT(*), SUM(CASE WHEN _IS_CURRENT THEN 1 ELSE 0 END), SUM(CASE WHEN NOT _IS_CURRENT THEN 1 ELSE 0 END)
FROM RAW_DEV.RAW_SIS.SCHOOL_RAW
UNION ALL
SELECT 'Students', COUNT(*), SUM(CASE WHEN _IS_CURRENT THEN 1 ELSE 0 END), SUM(CASE WHEN NOT _IS_CURRENT THEN 1 ELSE 0 END)
FROM RAW_DEV.RAW_SIS.STUDENT_RAW
UNION ALL
SELECT 'Staff', COUNT(*), SUM(CASE WHEN _IS_CURRENT THEN 1 ELSE 0 END), SUM(CASE WHEN NOT _IS_CURRENT THEN 1 ELSE 0 END)
FROM RAW_DEV.RAW_HR.STAFF_RAW
UNION ALL
SELECT 'Guardians', COUNT(*), SUM(CASE WHEN _IS_CURRENT THEN 1 ELSE 0 END), SUM(CASE WHEN NOT _IS_CURRENT THEN 1 ELSE 0 END)
FROM RAW_DEV.RAW_SIS.GUARDIAN_RAW
UNION ALL
SELECT 'Student-Guardian Links', COUNT(*), SUM(CASE WHEN _IS_CURRENT THEN 1 ELSE 0 END), 0
FROM RAW_DEV.RAW_SIS.STUDENT_GUARDIAN_RAW;

-- Sample data verification
SELECT 'Sample Students:' AS info;
SELECT STUDENT_ID, FIRST_NAME, LAST_NAME, GRADE_LEVEL, CURRENT_SCHOOL_ID, _IS_CURRENT, _VALID_FROM 
FROM RAW_DEV.RAW_SIS.STUDENT_RAW WHERE _IS_CURRENT LIMIT 5;

SELECT 'Sample Schools:' AS info;
SELECT SCHOOL_ID, SCHOOL_NAME, SCHOOL_TYPE, CURRENT_ENROLLMENT, _IS_CURRENT 
FROM RAW_DEV.RAW_SIS.SCHOOL_RAW WHERE _IS_CURRENT LIMIT 5;
