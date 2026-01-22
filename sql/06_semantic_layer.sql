-- ============================================================================
-- SEMANTIC LAYER - Snowflake Semantic Views for Education
-- ============================================================================
-- This script creates native Snowflake Semantic Views on top of the CURATED
-- layer Dynamic Tables. Semantic Views provide:
--   - Logical table definitions with relationships
--   - Dimensions and metrics for Cortex Analyst
--   - Business-friendly names and descriptions
--   - Natural language query capabilities
--
-- Architecture: RAW → CURATED (Dynamic Tables) → SEMANTIC (Semantic Views)
--
-- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view
-- Run order: After 05_curated_layer_dynamic_tables.sql
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE SEM_DEV;
USE WAREHOUSE ANALYTICS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA SETUP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_STUDENT
    COMMENT = 'Semantic layer for student analytics - enrollment, performance, demographics';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_SCHOOL
    COMMENT = 'Semantic layer for school analytics - capacity, performance, staffing';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_STAFF
    COMMENT = 'Semantic layer for staff analytics - HR metrics and workforce';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_GOVERNANCE
    COMMENT = 'Semantic layer for governance analytics - contracts and data quality';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Student Enrollment Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Primary semantic view for student-related analytics
-- Built on: DIM_STUDENT, DIM_SCHOOL, DIM_DISTRICT (CURATED layer)
-- Used by: District Leadership, Principals, Registrars, BI Teams

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS
  TABLES (
    students AS CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT PRIMARY KEY (STUDENT_KEY),
    schools AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL PRIMARY KEY (SCHOOL_ID),
    districts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT PRIMARY KEY (DISTRICT_ID)
  )
  RELATIONSHIPS (
    students(CURRENT_SCHOOL_ID) REFERENCES schools(SCHOOL_ID),
    students(CURRENT_DISTRICT_ID) REFERENCES districts(DISTRICT_ID),
    schools(DISTRICT_ID) REFERENCES districts(DISTRICT_ID)
  )
  DIMENSIONS (
    -- Student dimensions
    students.STUDENT_ID AS STUDENT_ID,
    students.DISPLAY_NAME AS DISPLAY_NAME,
    students.GRADE_LEVEL AS GRADE_LEVEL,
    students.GRADE_LEVEL_CATEGORY AS GRADE_LEVEL_CATEGORY,
    students.ENROLLMENT_STATUS AS ENROLLMENT_STATUS,
    students.COHORT_YEAR AS COHORT_YEAR,
    students.AGE AS AGE,
    students.GENDER AS GENDER,
    students.ETHNICITY AS ETHNICITY,
    students.PRIMARY_LANGUAGE AS PRIMARY_LANGUAGE,
    students.ELL_STATUS AS ELL_STATUS,
    students.SPECIAL_EDUCATION AS SPECIAL_EDUCATION,
    students.SECTION_504 AS SECTION_504,
    students.GIFTED_TALENTED AS GIFTED_TALENTED,
    students.FREE_REDUCED_LUNCH AS FREE_REDUCED_LUNCH,
    students.HOMELESS_STATUS AS HOMELESS_STATUS,
    students.AT_RISK_FLAG AS AT_RISK_FLAG,
    students.PROGRAM_COUNT AS PROGRAM_COUNT,
    
    -- School dimensions
    schools.SCHOOL_ID AS SCHOOL_ID,
    schools.SCHOOL_NAME AS SCHOOL_NAME,
    schools.SCHOOL_TYPE AS SCHOOL_TYPE,
    schools.IS_TITLE_I AS IS_TITLE_I,
    schools.IS_MAGNET AS IS_MAGNET,
    schools.IS_CHARTER AS IS_CHARTER,
    schools.CITY AS CITY,
    schools.COUNTY AS COUNTY,
    schools.ACCOUNTABILITY_RATING AS ACCOUNTABILITY_RATING,
    schools.CAPACITY_STATUS AS CAPACITY_STATUS,
    
    -- District dimensions
    districts.DISTRICT_ID AS DISTRICT_ID,
    districts.DISTRICT_NAME AS DISTRICT_NAME,
    districts.SUPERINTENDENT_NAME AS SUPERINTENDENT_NAME
  )
  METRICS (
    -- Student counts
    students.student_count AS COUNT(students.STUDENT_KEY),
    students.active_students AS SUM(CASE WHEN students.ENROLLMENT_STATUS = 'Active' THEN 1 ELSE 0 END),
    students.at_risk_count AS SUM(CASE WHEN students.AT_RISK_FLAG THEN 1 ELSE 0 END),
    
    -- Program participation counts
    students.ell_count AS SUM(CASE WHEN students.ELL_STATUS THEN 1 ELSE 0 END),
    students.sped_count AS SUM(CASE WHEN students.SPECIAL_EDUCATION THEN 1 ELSE 0 END),
    students.section504_count AS SUM(CASE WHEN students.SECTION_504 THEN 1 ELSE 0 END),
    students.gifted_count AS SUM(CASE WHEN students.GIFTED_TALENTED THEN 1 ELSE 0 END),
    students.frl_count AS SUM(CASE WHEN students.FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 ELSE 0 END),
    students.homeless_count AS SUM(CASE WHEN students.HOMELESS_STATUS THEN 1 ELSE 0 END),
    
    -- School counts
    schools.school_count AS COUNT(DISTINCT schools.SCHOOL_KEY),
    schools.title_i_count AS SUM(CASE WHEN schools.IS_TITLE_I THEN 1 ELSE 0 END),
    
    -- Capacity metrics from schools
    schools.total_capacity AS SUM(schools.BUILDING_CAPACITY),
    schools.total_enrollment AS SUM(schools.CURRENT_ENROLLMENT),
    
    -- Derived rates
    ell_rate AS students.ell_count / NULLIF(students.student_count, 0) * 100,
    sped_rate AS students.sped_count / NULLIF(students.student_count, 0) * 100,
    frl_rate AS students.frl_count / NULLIF(students.student_count, 0) * 100,
    at_risk_rate AS students.at_risk_count / NULLIF(students.student_count, 0) * 100,
    capacity_utilization AS schools.total_enrollment / NULLIF(schools.total_capacity, 0) * 100
  )
  COMMENT = 'Student enrollment analytics for district leadership and school administrators';

-- Grant access to education roles
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS TO ROLE DISTRICT_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS TO ROLE PRINCIPAL;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS TO ROLE REGISTRAR;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS TO ROLE BI_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Student Demographics Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Focused view for demographic analysis and equity reporting

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS
  TABLES (
    students AS CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT PRIMARY KEY (STUDENT_KEY),
    schools AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL PRIMARY KEY (SCHOOL_ID)
  )
  RELATIONSHIPS (
    students(CURRENT_SCHOOL_ID) REFERENCES schools(SCHOOL_ID)
  )
  DIMENSIONS (
    students.GRADE_LEVEL AS GRADE_LEVEL,
    students.GRADE_LEVEL_CATEGORY AS GRADE_LEVEL_CATEGORY,
    students.GENDER AS GENDER,
    students.ETHNICITY AS ETHNICITY,
    students.RACE AS RACE,
    students.PRIMARY_LANGUAGE AS PRIMARY_LANGUAGE,
    students.ELL_STATUS AS ELL_STATUS,
    students.FREE_REDUCED_LUNCH AS FREE_REDUCED_LUNCH,
    students.COUNTY AS COUNTY,
    schools.SCHOOL_NAME AS SCHOOL_NAME,
    schools.SCHOOL_TYPE AS SCHOOL_TYPE
  )
  METRICS (
    students.student_count AS COUNT(students.STUDENT_KEY),
    students.ell_count AS SUM(CASE WHEN students.ELL_STATUS THEN 1 ELSE 0 END),
    students.frl_count AS SUM(CASE WHEN students.FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 ELSE 0 END),
    
    ell_rate AS students.ell_count / NULLIF(students.student_count, 0) * 100,
    frl_rate AS students.frl_count / NULLIF(students.student_count, 0) * 100
  )
  COMMENT = 'Student demographics analytics for equity reporting and compliance';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS TO ROLE DISTRICT_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS TO ROLE PRINCIPAL;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: School Performance Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- School-level metrics for capacity, performance, and resource planning

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS
  TABLES (
    schools AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL PRIMARY KEY (SCHOOL_ID),
    districts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT PRIMARY KEY (DISTRICT_ID),
    metrics AS CURATED_DEV.CURATED_FACTS.FACT_SCHOOL_METRICS PRIMARY KEY (SCHOOL_ID)
  )
  RELATIONSHIPS (
    schools(DISTRICT_ID) REFERENCES districts(DISTRICT_ID),
    metrics(SCHOOL_ID) REFERENCES schools(SCHOOL_ID)
  )
  DIMENSIONS (
    schools.SCHOOL_ID AS SCHOOL_ID,
    schools.SCHOOL_NAME AS SCHOOL_NAME,
    schools.SCHOOL_TYPE AS SCHOOL_TYPE,
    schools.GRADE_LEVELS_SERVED AS GRADE_LEVELS_SERVED,
    schools.IS_TITLE_I AS IS_TITLE_I,
    schools.IS_MAGNET AS IS_MAGNET,
    schools.IS_CHARTER AS IS_CHARTER,
    schools.CITY AS CITY,
    schools.COUNTY AS COUNTY,
    schools.ACCOUNTABILITY_RATING AS ACCOUNTABILITY_RATING,
    schools.CAPACITY_STATUS AS CAPACITY_STATUS,
    schools.PRINCIPAL_NAME AS PRINCIPAL_NAME,
    districts.DISTRICT_NAME AS DISTRICT_NAME,
    districts.SUPERINTENDENT_NAME AS SUPERINTENDENT_NAME
  )
  METRICS (
    schools.school_count AS COUNT(DISTINCT schools.SCHOOL_KEY),
    schools.total_capacity AS SUM(schools.BUILDING_CAPACITY),
    schools.total_enrollment AS SUM(schools.CURRENT_ENROLLMENT),
    schools.total_staff AS SUM(schools.STAFF_COUNT),
    schools.total_teachers AS SUM(schools.TEACHER_COUNT),
    schools.avg_graduation_rate AS AVG(schools.GRADUATION_RATE),
    schools.avg_attendance_rate AS AVG(schools.ATTENDANCE_RATE),
    metrics.total_students AS SUM(metrics.TOTAL_STUDENTS),
    metrics.ell_students AS SUM(metrics.ELL_STUDENTS),
    metrics.sped_students AS SUM(metrics.SPED_STUDENTS),
    metrics.frl_students AS SUM(metrics.FRL_STUDENTS),
    capacity_utilization AS schools.total_enrollment / NULLIF(schools.total_capacity, 0) * 100,
    student_teacher_ratio AS schools.total_enrollment / NULLIF(schools.total_teachers, 0),
    avg_capacity_utilization AS AVG(schools.CAPACITY_UTILIZATION_PCT)
  )
  COMMENT = 'School performance analytics for capacity planning and accountability';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS TO ROLE DISTRICT_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS TO ROLE PRINCIPAL;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS TO ROLE BI_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Staff Workforce Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- HR and workforce analytics for staff management

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS
  TABLES (
    staff AS CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF PRIMARY KEY (STAFF_KEY),
    schools AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL PRIMARY KEY (SCHOOL_ID),
    summary AS CURATED_DEV.CURATED_FACTS.FACT_STAFF_SUMMARY PRIMARY KEY (SCHOOL_ID, ROLE_CATEGORY, DEPARTMENT)
  )
  RELATIONSHIPS (
    staff(PRIMARY_SCHOOL_ID) REFERENCES schools(SCHOOL_ID),
    summary(SCHOOL_ID) REFERENCES schools(SCHOOL_ID)
  )
  DIMENSIONS (
    staff.STAFF_ID AS STAFF_ID,
    staff.DISPLAY_NAME AS DISPLAY_NAME,
    staff.EMPLOYEE_TYPE AS EMPLOYEE_TYPE,
    staff.POSITION_TITLE AS POSITION_TITLE,
    staff.ROLE_CATEGORY AS ROLE_CATEGORY,
    staff.DEPARTMENT AS DEPARTMENT,
    staff.EMPLOYMENT_STATUS AS EMPLOYMENT_STATUS,
    staff.HIGHEST_DEGREE AS HIGHEST_DEGREE,
    staff.HIGHLY_QUALIFIED AS HIGHLY_QUALIFIED,
    staff.LICENSE_STATUS AS LICENSE_STATUS,
    staff.SALARY_BAND AS SALARY_BAND,
    staff.IS_TEACHER AS IS_TEACHER,
    staff.IS_ADMINISTRATOR AS IS_ADMINISTRATOR,
    schools.SCHOOL_NAME AS SCHOOL_NAME,
    schools.SCHOOL_TYPE AS SCHOOL_TYPE,
    schools.COUNTY AS COUNTY
  )
  METRICS (
    staff.staff_count AS COUNT(staff.STAFF_KEY),
    staff.active_staff AS SUM(CASE WHEN staff.EMPLOYMENT_STATUS = 'Active' THEN 1 ELSE 0 END),
    staff.teacher_count AS SUM(CASE WHEN staff.IS_TEACHER THEN 1 ELSE 0 END),
    staff.admin_count AS SUM(CASE WHEN staff.IS_ADMINISTRATOR THEN 1 ELSE 0 END),
    staff.total_experience_years AS SUM(staff.YEARS_EXPERIENCE),
    staff.avg_experience AS AVG(staff.YEARS_EXPERIENCE),
    staff.avg_tenure AS AVG(staff.TENURE_YEARS),
    staff.highly_qualified_count AS SUM(CASE WHEN staff.HIGHLY_QUALIFIED THEN 1 ELSE 0 END),
    summary.avg_summary_experience AS AVG(summary.AVG_YEARS_EXPERIENCE),
    summary.total_hq_rate AS AVG(summary.HIGHLY_QUALIFIED_RATE),
    highly_qualified_rate AS staff.highly_qualified_count / NULLIF(staff.teacher_count, 0) * 100
  )
  COMMENT = 'Staff workforce analytics for HR management and staffing decisions';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS TO ROLE DISTRICT_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS TO ROLE DATA_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Enrollment Summary Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Aggregate enrollment metrics by school and grade

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS
  TABLES (
    enrollment AS CURATED_DEV.CURATED_FACTS.FACT_ENROLLMENT_SUMMARY PRIMARY KEY (SCHOOL_ID, GRADE_LEVEL),
    schools AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL PRIMARY KEY (SCHOOL_ID),
    districts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT PRIMARY KEY (DISTRICT_ID)
  )
  RELATIONSHIPS (
    enrollment(SCHOOL_ID) REFERENCES schools(SCHOOL_ID),
    enrollment(DISTRICT_ID) REFERENCES districts(DISTRICT_ID)
  )
  DIMENSIONS (
    enrollment.GRADE_LEVEL AS GRADE_LEVEL,
    schools.SCHOOL_ID AS SCHOOL_ID,
    schools.SCHOOL_NAME AS SCHOOL_NAME,
    schools.SCHOOL_TYPE AS SCHOOL_TYPE,
    schools.COUNTY AS COUNTY,
    districts.DISTRICT_ID AS DISTRICT_ID,
    districts.DISTRICT_NAME AS DISTRICT_NAME
  )
  METRICS (
    enrollment.student_count AS SUM(enrollment.STUDENT_COUNT),
    enrollment.active_count AS SUM(enrollment.ACTIVE_COUNT),
    enrollment.ell_count AS SUM(enrollment.ELL_COUNT),
    enrollment.sped_count AS SUM(enrollment.SPED_COUNT),
    enrollment.frl_count AS SUM(enrollment.FRL_COUNT),
    enrollment.homeless_count AS SUM(enrollment.HOMELESS_COUNT),
    ell_rate AS enrollment.ell_count / NULLIF(enrollment.student_count, 0) * 100,
    sped_rate AS enrollment.sped_count / NULLIF(enrollment.student_count, 0) * 100,
    frl_rate AS enrollment.frl_count / NULLIF(enrollment.student_count, 0) * 100
  )
  COMMENT = 'Enrollment summary analytics for aggregate reporting';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS TO ROLE DISTRICT_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS TO ROLE PRINCIPAL;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS TO ROLE TEACHER;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Governance Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Contract health and data quality monitoring

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS
  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS PRIMARY KEY (CONTRACT_ID),
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONSUMERS PRIMARY KEY (CONSUMER_ID),
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES PRIMARY KEY (RULE_ID),
    alerts AS GOVERNANCE.CONTRACT_REGISTRY.ALERTS PRIMARY KEY (ALERT_ID)
  )
  RELATIONSHIPS (
    consumers(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID),
    quality_rules(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID),
    alerts(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID)
  )
  DIMENSIONS (
    contracts.CONTRACT_ID AS CONTRACT_ID,
    contracts.VERSION AS CONTRACT_VERSION,
    contracts.STATUS AS CONTRACT_STATUS,
    contracts.CONTRACT_TYPE AS CONTRACT_TYPE,
    contracts.PRODUCER_SYSTEM AS PRODUCER_SYSTEM,
    contracts.PRODUCER_TEAM AS PRODUCER_TEAM,
    contracts.GOVERNANCE_CLASSIFICATION AS CLASSIFICATION,
    contracts.HEALTH_STATUS AS HEALTH_STATUS,
    quality_rules.RULE_NAME AS RULE_NAME,
    quality_rules.RULE_TYPE AS RULE_TYPE,
    quality_rules.SEVERITY AS RULE_SEVERITY,
    alerts.ALERT_TYPE AS ALERT_TYPE,
    alerts.SEVERITY AS ALERT_SEVERITY,
    alerts.STATUS AS ALERT_STATUS
  )
  METRICS (
    contracts.contract_count AS COUNT(contracts.CONTRACT_ID),
    contracts.active_contracts AS SUM(CASE WHEN contracts.STATUS = 'active' THEN 1 ELSE 0 END),
    contracts.healthy_contracts AS SUM(CASE WHEN contracts.HEALTH_STATUS = 'GREEN' THEN 1 ELSE 0 END),
    contracts.warning_contracts AS SUM(CASE WHEN contracts.HEALTH_STATUS = 'YELLOW' THEN 1 ELSE 0 END),
    contracts.critical_contracts AS SUM(CASE WHEN contracts.HEALTH_STATUS = 'RED' THEN 1 ELSE 0 END),
    consumers.consumer_count AS COUNT(consumers.CONSUMER_ID),
    consumers.active_consumers AS SUM(CASE WHEN consumers.IS_ACTIVE THEN 1 ELSE 0 END),
    quality_rules.rule_count AS COUNT(quality_rules.RULE_ID),
    quality_rules.active_rules AS SUM(CASE WHEN quality_rules.IS_ACTIVE THEN 1 ELSE 0 END),
    alerts.alert_count AS COUNT(alerts.ALERT_ID),
    alerts.open_alerts AS SUM(CASE WHEN alerts.STATUS = 'OPEN' THEN 1 ELSE 0 END),
    alerts.critical_alerts AS SUM(CASE WHEN alerts.SEVERITY = 'error' AND alerts.STATUS = 'OPEN' THEN 1 ELSE 0 END),
    avg_consumers_per_contract AS consumers.consumer_count / NULLIF(contracts.contract_count, 0),
    avg_rules_per_contract AS quality_rules.rule_count / NULLIF(contracts.contract_count, 0),
    health_score AS contracts.healthy_contracts / NULLIF(contracts.active_contracts, 0) * 100
  )
  COMMENT = 'Governance analytics for monitoring contract health and data quality';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS TO ROLE DATA_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS TO ROLE DATA_STEWARD;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS TO ROLE DATA_ENGINEER;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Data Quality Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Focused view for data quality rule monitoring

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.DATA_QUALITY_ANALYTICS
  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS PRIMARY KEY (CONTRACT_ID),
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES PRIMARY KEY (RULE_ID),
    results AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS PRIMARY KEY (RESULT_ID)
  )
  RELATIONSHIPS (
    quality_rules(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID),
    results(RULE_ID) REFERENCES quality_rules(RULE_ID)
  )
  DIMENSIONS (
    contracts.CONTRACT_ID AS CONTRACT_ID,
    contracts.PRODUCER_SYSTEM AS PRODUCER_SYSTEM,
    contracts.PRODUCER_TEAM AS PRODUCER_TEAM,
    quality_rules.RULE_ID AS RULE_ID,
    quality_rules.RULE_NAME AS RULE_NAME,
    quality_rules.RULE_TYPE AS RULE_TYPE,
    quality_rules.TARGET_COLUMN AS TARGET_COLUMN,
    quality_rules.SEVERITY AS SEVERITY,
    results.STATUS AS CHECK_STATUS
  )
  METRICS (
    quality_rules.rule_count AS COUNT(quality_rules.RULE_ID),
    quality_rules.active_rules AS SUM(CASE WHEN quality_rules.IS_ACTIVE THEN 1 ELSE 0 END),
    results.check_count AS COUNT(results.RESULT_ID),
    results.passed_checks AS SUM(CASE WHEN results.STATUS = 'PASS' THEN 1 ELSE 0 END),
    results.failed_checks AS SUM(CASE WHEN results.STATUS = 'FAIL' THEN 1 ELSE 0 END),
    results.total_records_checked AS SUM(results.RECORDS_CHECKED),
    results.total_records_failed AS SUM(results.RECORDS_FAILED),
    pass_rate AS results.passed_checks / NULLIF(results.check_count, 0) * 100,
    record_pass_rate AS (results.total_records_checked - results.total_records_failed) / NULLIF(results.total_records_checked, 0) * 100
  )
  COMMENT = 'Data quality analytics for monitoring rule execution and pass rates';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.DATA_QUALITY_ANALYTICS TO ROLE DATA_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.DATA_QUALITY_ANALYTICS TO ROLE DATA_STEWARD;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.DATA_QUALITY_ANALYTICS TO ROLE DATA_ENGINEER;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: FERPA Compliance Analytics  
-- ─────────────────────────────────────────────────────────────────────────────
-- Education-specific compliance monitoring

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.FERPA_COMPLIANCE_ANALYTICS
  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS PRIMARY KEY (CONTRACT_ID),
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONSUMERS PRIMARY KEY (CONSUMER_ID)
  )
  RELATIONSHIPS (
    consumers(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID)
  )
  DIMENSIONS (
    contracts.CONTRACT_ID AS CONTRACT_ID,
    contracts.PRODUCER_SYSTEM AS PRODUCER_SYSTEM,
    contracts.GOVERNANCE_CLASSIFICATION AS DATA_CLASSIFICATION,
    contracts.AI_ELIGIBILITY AS AI_ELIGIBILITY,
    consumers.CONSUMER_TEAM AS CONSUMER_TEAM,
    consumers.ACCESS_LEVEL AS ACCESS_LEVEL,
    consumers.USE_CASE AS USE_CASE
  )
  METRICS (
    contracts.total_contracts AS COUNT(contracts.CONTRACT_ID),
    contracts.restricted_contracts AS SUM(CASE WHEN contracts.GOVERNANCE_CLASSIFICATION = 'RESTRICTED' THEN 1 ELSE 0 END),
    contracts.confidential_contracts AS SUM(CASE WHEN contracts.GOVERNANCE_CLASSIFICATION = 'CONFIDENTIAL' THEN 1 ELSE 0 END),
    contracts.public_contracts AS SUM(CASE WHEN contracts.GOVERNANCE_CLASSIFICATION = 'PUBLIC' THEN 1 ELSE 0 END),
    contracts.ai_allowed AS SUM(CASE WHEN contracts.AI_ELIGIBILITY = 'TRUE' THEN 1 ELSE 0 END),
    contracts.ai_aggregated_only AS SUM(CASE WHEN contracts.AI_ELIGIBILITY = 'AGGREGATED_ONLY' THEN 1 ELSE 0 END),
    contracts.ai_pseudonymized AS SUM(CASE WHEN contracts.AI_ELIGIBILITY = 'PSEUDONYMIZED_ONLY' THEN 1 ELSE 0 END),
    consumers.consumer_count AS COUNT(consumers.CONSUMER_ID),
    consumers.full_access AS SUM(CASE WHEN consumers.ACCESS_LEVEL = 'read_full' THEN 1 ELSE 0 END),
    consumers.masked_access AS SUM(CASE WHEN consumers.ACCESS_LEVEL = 'read_masked' THEN 1 ELSE 0 END)
  )
  COMMENT = 'FERPA compliance analytics for education data governance monitoring';

GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.FERPA_COMPLIANCE_ANALYTICS TO ROLE DATA_ADMIN;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.FERPA_COMPLIANCE_ANALYTICS TO ROLE DATA_STEWARD;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_GOVERNANCE.FERPA_COMPLIANCE_ANALYTICS TO ROLE DISTRICT_ADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Semantic Views Created Successfully' AS STATUS;

SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV;

/*
Sample Cortex Analyst Questions:
- "How many students are enrolled in high schools?"
- "What is the ELL rate by district?"
- "Which schools have the highest capacity utilization?"
- "Show me student demographics by school type"
- "What is the average student-teacher ratio?"
- "How many contracts are in healthy status?"
- "What is the data quality pass rate?"
*/
