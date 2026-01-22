# Architecture Documentation

## Overview

This document details the technical architecture of the Massachusetts School District Horizon Demo, implementing the Enterprise Architecture Guide for the Snowflake Data Cloud principles.

## Snowflake Horizon Capabilities

| Horizon Feature | Purpose in This Demo |
|----------------|---------------------|
| **Object Tagging** | FERPA categories, PII levels, AI eligibility |
| **Tag-Based Masking** | Dynamic PII protection based on role |
| **Row Access Policies** | Classroom, school, district-level filtering |
| **Data Classification** | Automatic sensitivity detection |
| **Access History** | FERPA compliance audit trail |
| **Dynamic Tables** | Automated refresh with SLA targets |
| **Semantic Views** | Cortex Analyst integration |

## Core Principle: The Dependency Chain

```
People → Data → Governance → Automation
```

| Layer | Responsibility | Demo Implementation |
|-------|---------------|---------------------|
| **People** | Define intent and ownership | Role hierarchy, contract ownership |
| **Data** | Encode meaning and rules | Schema definitions, quality rules |
| **Governance** | Enforce constraints at runtime | Tags, masking, row access |
| **Automation** | Execute at scale | Dynamic Tables, validation tasks |

---

## Data Model

### Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SCHOOL DISTRICT DATA MODEL                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐            │
│  │  DISTRICT   │────────▶│   SCHOOL    │────────▶│   STUDENT   │            │
│  │             │  1:N    │             │  1:N    │             │            │
│  │ district_id │         │ school_id   │         │ student_id  │            │
│  │ name        │         │ name        │         │ first_name  │            │
│  │ county      │         │ type        │         │ last_name   │            │
│  │ superintendent│       │ principal_id│         │ ssn ⚠️      │            │
│  └─────────────┘         │ address     │         │ dob ⚠️      │            │
│                          └─────────────┘         │ address ⚠️  │            │
│                                │                 │ grade_level │            │
│                                │                 └─────────────┘            │
│                                │                        │                   │
│  ┌─────────────┐               │                        │                   │
│  │    STAFF    │◀──────────────┘                        │                   │
│  │             │                                        │                   │
│  │ staff_id    │         ┌─────────────┐               │                    │
│  │ first_name  │         │  GUARDIAN   │◀──────────────┘                    │
│  │ last_name   │         │             │  N:M (via STUDENT_GUARDIAN)        │
│  │ role        │         │ guardian_id │                                    │
│  │ school_id   │         │ first_name  │                                    │
│  │ ssn ⚠️      │         │ last_name   │                                    │
│  └─────────────┘         │ phone ⚠️    │                                    │
│         │                │ email ⚠️    │                                    │
│         │                │ address ⚠️  │                                    │
│         ▼                └─────────────┘                                    │
│  ┌─────────────┐                                                            │
│  │ CLASS_SECTION│        ┌─────────────┐                                    │
│  │             │────────▶│ ENROLLMENT  │◀── Links student to section        │
│  │ section_id  │  1:N    │             │                                    │
│  │ course_id   │         │ enrollment_id│                                   │
│  │ teacher_id  │         │ student_id  │                                    │
│  │ period      │         │ section_id  │                                    │
│  │ room        │         │ start_date  │                                    │
│  └─────────────┘         │ end_date    │                                    │
│         │                └─────────────┘                                    │
│         │                       │                                           │
│         ▼                       ▼                                           │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐            │
│  │   COURSE    │         │    GRADE    │         │ ATTENDANCE  │            │
│  │             │         │             │         │             │            │
│  │ course_id   │         │ grade_id    │         │ record_id   │            │
│  │ name        │         │ student_id  │         │ student_id  │            │
│  │ subject     │         │ section_id  │         │ date        │            │
│  │ grade_level │         │ assignment  │         │ status      │            │
│  │ credits     │         │ score ⚠️    │         │ minutes_absent│          │
│  └─────────────┘         │ letter_grade│         └─────────────┘            │
│                          └─────────────┘                                    │
│                                                                             │
│  ⚠️ = PII/Sensitive Data (tagged and masked)                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Entity Descriptions

| Entity | Record Count | Description |
|--------|-------------|-------------|
| **DISTRICT** | 25 | School districts in Greater Boston |
| **SCHOOL** | 250 | Elementary, Middle, High schools |
| **STUDENT** | 100,000 | K-12 students with demographics |
| **STAFF** | 12,000 | Teachers, admins, support |
| **GUARDIAN** | 150,000 | Parents/guardians |
| **COURSE** | 500 | Curriculum offerings |
| **CLASS_SECTION** | 5,000 | Scheduled course instances |
| **ENROLLMENT** | 500,000 | Student-section assignments |
| **GRADE** | 2,000,000 | Assignment/course grades |
| **ATTENDANCE** | 18,000,000 | Daily attendance records |

---

## Three-Layer Architecture

### RAW Layer (RAW_DEV)

**Purpose**: Capture data with minimal transformation, maintain history using SCD Type 2

**Schemas**:
- `RAW_SIS` - Student Information System data
- `RAW_HR` - Human Resources/Staff data
- `STAGING` - Staging tables for data loading

**SCD Type 2 System Columns**:
| Column | Description |
|--------|-------------|
| `_LOADED_AT` | Timestamp when record was loaded |
| `_SOURCE_SYSTEM` | Origin system identifier |
| `_ROW_HASH` | SHA2 hash for change detection |
| `_IS_CURRENT` | TRUE for current version, FALSE for historical |
| `_VALID_FROM` | When this version became effective |
| `_VALID_TO` | When this version was superseded (9999-12-31 for current) |

**SCD Loading Pattern**:
```sql
-- MERGE to detect changes
MERGE INTO RAW_TABLE AS tgt
USING STAGING_TABLE AS src
ON tgt.BUSINESS_KEY = src.BUSINESS_KEY AND tgt._IS_CURRENT = TRUE
WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
    UPDATE SET _IS_CURRENT = FALSE, _VALID_TO = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (...) VALUES (..., TRUE, CURRENT_TIMESTAMP(), '9999-12-31');
```

**Features**:
- SCD Type 2 history tracking
- Full governance tags applied at column level
- Row hash for efficient change detection
- Source system tracking for lineage

### CURATED Layer (CURATED_DEV)

**Purpose**: Business logic, derived attributes, dimensional model

**Schemas**:
- `CURATED_DIMENSIONS` - Dimension tables (DIM_*)
- `CURATED_FACTS` - Fact tables (FACT_*)
- `CURATED_REFERENCE` - Reference/lookup tables

**Dynamic Tables Created**:
| Table | Type | TARGET_LAG | Description |
|-------|------|------------|-------------|
| `DIM_DISTRICT` | Dimension | 24 hours | District attributes |
| `DIM_SCHOOL` | Dimension | 24 hours | School with capacity metrics |
| `DIM_STUDENT` | Dimension | 1 hour | Students with pseudonymization |
| `DIM_STAFF` | Dimension | 1 hour | Staff with HR metrics |
| `DIM_GUARDIAN` | Dimension | 1 hour | Parent/guardian contacts |
| `BRIDGE_STUDENT_GUARDIAN` | Bridge | 1 hour | Student-guardian relationships |
| `FACT_ENROLLMENT_SUMMARY` | Fact | 1 hour | Enrollment by school/grade |
| `FACT_SCHOOL_METRICS` | Fact | 24 hours | School-level aggregations |
| `FACT_STAFF_SUMMARY` | Fact | 24 hours | Staff metrics by school |

**Features**:
- Dynamic Tables with TARGET_LAG SLAs
- Derived attributes (student risk scores, tenure, at-risk flags)
- Pseudonymization for AI workloads (STUDENT_ID_HASH, STUDENT_NAME_HASH)
- Business rule enforcement
- Capacity utilization and student-teacher ratio calculations

### SEMANTIC Layer (SEM_DEV)

**Purpose**: Consumer-facing Semantic Views built on CURATED layer for Cortex Analyst

**Schemas**:
- `SEM_STUDENT` - Student enrollment and demographics analytics
- `SEM_SCHOOL` - School performance analytics
- `SEM_STAFF` - Staff workforce analytics
- `SEM_GOVERNANCE` - Governance and compliance observability

**Semantic Views Created**:
| Schema | View | Base Tables (CURATED) |
|--------|------|----------------------|
| `SEM_STUDENT` | `STUDENT_ENROLLMENT_ANALYTICS` | DIM_STUDENT, DIM_SCHOOL, DIM_DISTRICT |
| `SEM_STUDENT` | `STUDENT_DEMOGRAPHICS_ANALYTICS` | DIM_STUDENT, DIM_SCHOOL |
| `SEM_STUDENT` | `ENROLLMENT_SUMMARY_ANALYTICS` | FACT_ENROLLMENT_SUMMARY, DIM_SCHOOL |
| `SEM_SCHOOL` | `SCHOOL_PERFORMANCE_ANALYTICS` | DIM_SCHOOL, DIM_DISTRICT, FACT_SCHOOL_METRICS |
| `SEM_STAFF` | `STAFF_WORKFORCE_ANALYTICS` | DIM_STAFF, DIM_SCHOOL, FACT_STAFF_SUMMARY |
| `SEM_GOVERNANCE` | `GOVERNANCE_ANALYTICS` | CONTRACTS, CONSUMERS, QUALITY_RULES, ALERTS |
| `SEM_GOVERNANCE` | `DATA_QUALITY_ANALYTICS` | CONTRACTS, QUALITY_RULES, QUALITY_RULE_RESULTS |
| `SEM_GOVERNANCE` | `FERPA_COMPLIANCE_ANALYTICS` | CONTRACTS, CONSUMERS |

**Features**:
- Native Snowflake Semantic Views (not YAML models)
- Pre-defined dimensions and metrics for Cortex Analyst
- Governance policies inherited from base tables
- AI-safe with role-based access control

---

## Role Hierarchy

```
                          ACCOUNTADMIN
                               │
                          SYSADMIN
                               │
                          DATA_ADMIN ◄── Owns all demo objects
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   DATA_ENGINEER          DATA_STEWARD           PII_VIEWER
        │                      │                      │
        │         ┌────────────┼────────────┐         │
        │         │            │            │         │
        │   DISTRICT_ADMIN  PRINCIPAL   REGISTRAR     │
        │         │            │            │         │
        │         └──────┬─────┴─────┬──────┘         │
        │                │           │                │
        └────────►    TEACHER    COUNSELOR    ◄───────┘
                         │           │
                         └─────┬─────┘
                               │
                         PARENT_PORTAL
                               │
                          AI_AGENT
```

### Role Definitions

| Role | Layer Access | Row Scope | PII Access |
|------|-------------|-----------|------------|
| DATA_ADMIN | All | All | Full |
| DATA_ENGINEER | RAW, CURATED | All | Masked |
| DATA_STEWARD | GOVERNANCE, SEM | All | Masked |
| PII_VIEWER | SEM | All | Full (audited) |
| DISTRICT_ADMIN | SEM | District | Partial |
| PRINCIPAL | SEM | School | Partial |
| REGISTRAR | SEM | School | Enrollment data |
| TEACHER | SEM | Classroom | Masked |
| COUNSELOR | SEM | Assigned students | Health/sensitive |
| PARENT_PORTAL | SEM | Own children | Own only |
| AI_AGENT | SEM (AI views) | Aggregated | Pseudonymized |

---

## Governance Tags

### FERPA Categories

| Tag Value | Description | Example Columns |
|-----------|-------------|-----------------|
| DIRECTORY | Opt-out available public info | name, grade_level, school |
| EDUCATIONAL_RECORD | Protected educational records | grades, transcripts, disciplinary |
| SENSITIVE | Highly protected | SSN, special education, IEP |
| HEALTH | Medical information | 504 plans, medications |

### PII Types

| Tag Value | Description | Example Columns |
|-----------|-------------|-----------------|
| NONE | No personal information | school_id, course_name |
| LOW | Indirect identifiers | grade_level, enrollment_date |
| MODERATE | Direct identifiers | name, address, phone |
| HIGH | Sensitive identifiers | SSN, date_of_birth |

### AI Eligibility

| Tag Value | Description | Usage |
|-----------|-------------|-------|
| TRUE | Safe for AI workloads | Aggregate metrics, non-PII |
| FALSE | Never expose to AI | SSN, health records |
| PSEUDONYMIZED_ONLY | Hash/tokenize first | Names, student IDs |
| AGGREGATED_ONLY | Only in aggregate | Individual grades |

---

## Masking Policies

### Policy: MASK_SSN

```sql
CREATE MASKING POLICY MASK_SSN AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN') THEN 'XXX-XX-' || RIGHT(val, 4)
        ELSE '***-**-****'
    END;
```

### Policy: MASK_DOB

```sql
CREATE MASKING POLICY MASK_DOB AS (val DATE)
RETURNS DATE ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'COUNSELOR') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN', 'PRINCIPAL') THEN DATE_TRUNC('MONTH', val)
        ELSE DATE_TRUNC('YEAR', val)
    END;
```

### Policy: MASK_ADDRESS

```sql
CREATE MASKING POLICY MASK_ADDRESS AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN', 'PRINCIPAL') THEN val
        ELSE REGEXP_REPLACE(val, '^[0-9]+', '***') || ' [MASKED]'
    END;
```

---

## Row Access Policies

### Policy: TEACHER_STUDENT_ACCESS

Teachers see only students in their assigned class sections.

```sql
CREATE ROW ACCESS POLICY TEACHER_STUDENT_ACCESS AS (student_id STRING)
RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'DISTRICT_ADMIN')
    OR (
        CURRENT_ROLE() = 'PRINCIPAL' 
        AND student_id IN (
            SELECT student_id FROM enrollment 
            WHERE school_id = CURRENT_SETTING('CURRENT_SCHOOL_ID')
        )
    )
    OR (
        CURRENT_ROLE() = 'TEACHER'
        AND student_id IN (
            SELECT e.student_id 
            FROM enrollment e
            JOIN class_section cs ON e.section_id = cs.section_id
            WHERE cs.teacher_id = CURRENT_SETTING('CURRENT_TEACHER_ID')
        )
    );
```

### Policy: PARENT_CHILD_ACCESS

Parents see only their own children.

```sql
CREATE ROW ACCESS POLICY PARENT_CHILD_ACCESS AS (student_id STRING)
RETURNS BOOLEAN ->
    CURRENT_ROLE() != 'PARENT_PORTAL'
    OR student_id IN (
        SELECT student_id 
        FROM student_guardian 
        WHERE guardian_id = CURRENT_SETTING('CURRENT_PARENT_ID')
    );
```

---

## Dynamic Tables

### Refresh Schedule

| Dynamic Table | TARGET_LAG | Purpose |
|--------------|------------|---------|
| DIM_DISTRICT | 24 hours | District reference data |
| DIM_SCHOOL | 24 hours | School with capacity/performance metrics |
| DIM_STUDENT | 1 hour | Current student attributes with pseudonymization |
| DIM_STAFF | 1 hour | Staff with HR metrics and tenure |
| DIM_GUARDIAN | 1 hour | Parent/guardian contacts |
| BRIDGE_STUDENT_GUARDIAN | 1 hour | Student-guardian relationships |
| FACT_ENROLLMENT_SUMMARY | 1 hour | Enrollment aggregated by school/grade |
| FACT_SCHOOL_METRICS | 24 hours | School-level aggregated metrics |
| FACT_STAFF_SUMMARY | 24 hours | Staff metrics by school/department |

### Example: DIM_STUDENT

```sql
CREATE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
AS
SELECT
    -- Keys
    s.STUDENT_ID AS STUDENT_KEY,
    s.STUDENT_ID,
    
    -- Pseudonymized Keys (for AI workloads)
    SHA2(s.STUDENT_ID, 256) AS STUDENT_ID_HASH,
    SHA2(s.FIRST_NAME || ' ' || s.LAST_NAME, 256) AS STUDENT_NAME_HASH,
    
    -- PII Fields (masked in semantic layer)
    s.FIRST_NAME,
    s.LAST_NAME,
    s.SSN,
    s.DATE_OF_BIRTH,
    
    -- Derived: Display Name
    COALESCE(s.PREFERRED_NAME, s.FIRST_NAME) || ' ' || LEFT(s.LAST_NAME, 1) || '.' AS DISPLAY_NAME,
    
    -- Derived: Age
    DATEDIFF('year', s.DATE_OF_BIRTH, CURRENT_DATE()) AS AGE,
    
    -- School Assignment
    s.CURRENT_SCHOOL_ID,
    s.CURRENT_DISTRICT_ID,
    s.GRADE_LEVEL,
    
    -- Derived: Grade Level Category
    CASE 
        WHEN s.GRADE_LEVEL IN ('PK', 'K', '01', '02', '03', '04', '05') THEN 'ELEMENTARY'
        WHEN s.GRADE_LEVEL IN ('06', '07', '08') THEN 'MIDDLE'
        WHEN s.GRADE_LEVEL IN ('09', '10', '11', '12') THEN 'HIGH'
        ELSE 'OTHER'
    END AS GRADE_LEVEL_CATEGORY,
    
    -- Special Programs
    s.SPECIAL_EDUCATION,
    s.SECTION_504,
    s.ELL_STATUS,
    s.FREE_REDUCED_LUNCH,
    
    -- Derived: At-Risk Flag
    CASE 
        WHEN s.HOMELESS_STATUS = TRUE THEN TRUE
        WHEN s.FREE_REDUCED_LUNCH = 'Free' AND s.ELL_STATUS = TRUE THEN TRUE
        ELSE FALSE
    END AS AT_RISK_FLAG,
    
    s._IS_CURRENT
FROM RAW_DEV.RAW_SIS.STUDENT_RAW s
WHERE s._IS_CURRENT = TRUE;
```

---

## Native Snowflake Semantic Views

This demo uses native **Snowflake Semantic Views** (not YAML models) for Cortex Analyst integration.

### Available Semantic Views

| Schema | View | Purpose |
|--------|------|---------|
| `SEM_STUDENT` | `STUDENT_ENROLLMENT_ANALYTICS` | Primary student view with enrollment, demographics, program participation |
| `SEM_STUDENT` | `STUDENT_DEMOGRAPHICS_ANALYTICS` | Demographics and equity reporting |
| `SEM_STUDENT` | `ATTENDANCE_ANALYTICS` | Attendance tracking and truancy monitoring |
| `SEM_SCHOOL` | `SCHOOL_PERFORMANCE_ANALYTICS` | Capacity, performance, staffing metrics |
| `SEM_STAFF` | `STAFF_WORKFORCE_ANALYTICS` | HR and workforce analytics |
| `SEM_GOVERNANCE` | `GOVERNANCE_ANALYTICS` | Contract health and quality monitoring |
| `SEM_GOVERNANCE` | `DATA_QUALITY_ANALYTICS` | Quality rule execution and pass rates |
| `SEM_GOVERNANCE` | `FERPA_COMPLIANCE_ANALYTICS` | FERPA compliance monitoring |

### Example: Student Enrollment Analytics

```sql
CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS
  TABLES (
    students AS RAW_DEV.RAW_SIS.STUDENT_RAW PRIMARY KEY (STUDENT_ID),
    schools AS RAW_DEV.RAW_SIS.SCHOOL_RAW PRIMARY KEY (SCHOOL_ID),
    districts AS RAW_DEV.RAW_SIS.DISTRICT_RAW PRIMARY KEY (DISTRICT_ID)
  )
  RELATIONSHIPS (
    students(CURRENT_SCHOOL_ID) REFERENCES schools(SCHOOL_ID),
    students(CURRENT_DISTRICT_ID) REFERENCES districts(DISTRICT_ID),
    schools(DISTRICT_ID) REFERENCES districts(DISTRICT_ID)
  )
  DIMENSIONS (
    students.GRADE_LEVEL AS GRADE_LEVEL COMMENT 'Current grade level (PK-12)',
    students.ENROLLMENT_STATUS AS ENROLLMENT_STATUS,
    students.ELL_STATUS AS ELL_STATUS COMMENT 'English Language Learner status',
    students.SPECIAL_EDUCATION AS SPECIAL_EDUCATION COMMENT 'Has IEP',
    schools.SCHOOL_NAME AS SCHOOL_NAME,
    schools.SCHOOL_TYPE AS SCHOOL_TYPE,
    districts.DISTRICT_NAME AS DISTRICT_NAME
  )
  METRICS (
    students.student_count AS COUNT(students.STUDENT_ID) COMMENT 'Total students',
    students.ell_count AS SUM(CASE WHEN students.ELL_STATUS THEN 1 ELSE 0 END),
    ell_rate AS students.ell_count / NULLIF(students.student_count, 0) * 100
  )
  COMMENT = 'Student enrollment analytics for district leadership';
```

### Key Benefits of Native Semantic Views

| Feature | Benefit |
|---------|---------|
| **Snowflake-Native** | No external files to manage, version control in-database |
| **Governance Inheritance** | Masking and row access policies apply automatically |
| **Dimensions & Metrics** | Pre-defined aggregations for Cortex Analyst |
| **Column Comments** | Business descriptions for AI understanding |
| **Relationships** | Join paths defined for automatic query generation |

---

## Observability

### Key Views

| View | Purpose |
|------|---------|
| VW_DASHBOARD_KPIS | High-level health metrics |
| VW_CONTRACT_HEALTH | Per-contract status |
| VW_TAG_COVERAGE | Governance tag completeness |
| VW_SLA_COMPLIANCE | Freshness and quality |
| VW_ACTIVE_ALERTS | Current violations |
| VW_ACCESS_AUDIT | Recent data access |
| VW_FERPA_COMPLIANCE | FERPA-specific metrics |

### Sample KPIs

```sql
SELECT 
    'Contracts' AS category,
    COUNT(*) AS total,
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active,
    ROUND(100.0 * SUM(CASE WHEN health = 'GREEN' THEN 1 ELSE 0 END) / COUNT(*), 1) AS green_pct
FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS

UNION ALL

SELECT 
    'Tag Coverage',
    SUM(total_columns),
    SUM(tagged_columns),
    ROUND(100.0 * SUM(tagged_columns) / SUM(total_columns), 1)
FROM GOVERNANCE.OBSERVABILITY.VW_TAG_COVERAGE

UNION ALL

SELECT
    'Quality Rules',
    COUNT(*),
    SUM(CASE WHEN last_run_status = 'PASS' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN last_run_status = 'PASS' THEN 1 ELSE 0 END) / COUNT(*), 1)
FROM GOVERNANCE.OBSERVABILITY.VW_QUALITY_RULES;
```

---

## References

- [Snowflake Horizon](https://www.snowflake.com/en/data-cloud/horizon/)
- [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
- [Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [FERPA Overview](https://www2.ed.gov/policy/gen/guid/fpco/ferpa/index.html)
