# FERPA Compliance Implementation

## Overview

This demo implements comprehensive **FERPA (Family Educational Rights and Privacy Act)** compliance using Snowflake Horizon governance capabilities.

## FERPA Data Categories

### 1. Directory Information
**Definition**: Information that would not generally be considered harmful if disclosed.

**Examples in This Demo**:
- Student name
- Grade level
- School enrollment
- Participation in activities

**Snowflake Implementation**:
```yaml
tags:
  FERPA_CATEGORY: DIRECTORY
  PII_TYPE: LOW
  AI_ALLOWED: PSEUDONYMIZED_ONLY
```

**Note**: Parents have the right to opt-out of directory information disclosure.

### 2. Educational Records
**Definition**: Records directly related to a student maintained by the school.

**Examples in This Demo**:
- Grades and transcripts
- Enrollment history
- Course registrations
- Attendance records

**Snowflake Implementation**:
```yaml
tags:
  FERPA_CATEGORY: EDUCATIONAL_RECORD
  PII_TYPE: MODERATE
  AI_ALLOWED: AGGREGATED_ONLY
```

### 3. Sensitive Records
**Definition**: Highly protected information requiring explicit consent.

**Examples in This Demo**:
- Social Security Number
- Disciplinary records
- Special education status (IEP)
- Homeless status
- Free/reduced lunch eligibility

**Snowflake Implementation**:
```yaml
tags:
  FERPA_CATEGORY: SENSITIVE
  PII_TYPE: HIGH
  AI_ALLOWED: "FALSE"
  DATA_CLASSIFICATION: RESTRICTED
```

### 4. Health Information
**Definition**: Medical and health-related records (HIPAA overlap).

**Examples in This Demo**:
- Section 504 plans
- Medical conditions
- Medication records
- Nurse visit logs

**Snowflake Implementation**:
```yaml
tags:
  FERPA_CATEGORY: HEALTH
  PII_TYPE: HIGH
  AI_ALLOWED: "FALSE"
  DATA_CLASSIFICATION: RESTRICTED
```

## Access Control Matrix

| Role | Directory | Educational | Sensitive | Health |
|------|-----------|-------------|-----------|--------|
| DATA_ADMIN | ✓ Full | ✓ Full | ✓ Full | ✓ Full |
| PII_VIEWER | ✓ Full | ✓ Full | ✓ Full | ✓ Full |
| DISTRICT_ADMIN | ✓ Full | ✓ Full | Partial | ✗ No |
| PRINCIPAL | ✓ Full | ✓ Full | Summary | Summary |
| REGISTRAR | ✓ Full | ✓ Full | Limited | ✗ No |
| TEACHER | ✓ Full | Own Class | ✗ No | ✗ No |
| COUNSELOR | ✓ Full | Assigned | ✓ Full | ✓ Full |
| PARENT_PORTAL | Own Child | Own Child | Own Child | Own Child |
| AI_AGENT | Aggregate | Aggregate | ✗ No | ✗ No |

## Masking Policy Examples

### SSN Masking
```sql
CREATE MASKING POLICY MASK_SSN AS (val STRING)
RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN') THEN 'XXX-XX-' || RIGHT(val, 4)
        ELSE '***-**-****'
    END;
```

### Date of Birth Masking
```sql
CREATE MASKING POLICY MASK_DOB AS (val DATE)
RETURNS DATE ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'COUNSELOR') THEN val
        WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN', 'PRINCIPAL') THEN DATE_TRUNC('MONTH', val)
        WHEN CURRENT_ROLE() IN ('TEACHER') THEN DATE_TRUNC('YEAR', val)
        ELSE NULL
    END;
```

### Sensitive Flag Masking (IEP, 504)
```sql
CREATE MASKING POLICY MASK_SENSITIVE_FLAG AS (val BOOLEAN)
RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'COUNSELOR', 'REGISTRAR') THEN val
        ELSE NULL
    END;
```

## Row Access Policies

### Teacher Access to Students
Teachers only see students enrolled in their classes:

```sql
CREATE ROW ACCESS POLICY ROW_ACCESS_MY_STUDENTS AS (student_id STRING)
RETURNS BOOLEAN ->
    CURRENT_ROLE() != 'TEACHER'
    OR EXISTS (
        SELECT 1 FROM enrollment e
        JOIN class_section cs ON e.section_id = cs.section_id
        WHERE e.student_id = student_id 
        AND cs.teacher_id = CURRENT_SETTING('CURRENT_TEACHER_ID')
    );
```

### Parent Access to Children
Parents only see their own children:

```sql
CREATE ROW ACCESS POLICY ROW_ACCESS_MY_CHILDREN AS (student_id STRING)
RETURNS BOOLEAN ->
    CURRENT_ROLE() != 'PARENT_PORTAL'
    OR EXISTS (
        SELECT 1 FROM student_guardian sg
        WHERE sg.student_id = student_id
        AND sg.guardian_id = CURRENT_SETTING('CURRENT_PARENT_ID')
    );
```

## Audit Trail with Access History

Snowflake Access History provides FERPA-compliant audit trails:

```sql
-- Who accessed student data in the last 24 hours?
SELECT 
    QUERY_START_TIME,
    USER_NAME,
    ROLE_NAME,
    QUERY_TEXT,
    DIRECT_OBJECTS_ACCESSED
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE ARRAY_CONTAINS('RAW_DEV.RAW_SIS.STUDENT_RAW'::VARIANT, BASE_OBJECTS_ACCESSED)
  AND QUERY_START_TIME > DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY QUERY_START_TIME DESC;
```

## Legitimate Educational Interest

FERPA allows disclosure to school officials with legitimate educational interest. This demo implements this through:

1. **Role-based access**: Only roles with educational need have access
2. **Row-level filtering**: Teachers see only their students
3. **Column masking**: Sensitive data masked unless needed
4. **Audit logging**: All access is logged for accountability

## Parent Rights Implementation

### Right to Inspect Records
- Parents use `PARENT_PORTAL` role
- See only their children's data
- Educational records visible

### Right to Amend Records
- Amendment requests tracked in `GOVERNANCE.CONTRACT_REGISTRY.AMENDMENT_REQUESTS`
- Workflow for review and approval

### Right to Consent to Disclosures
- Consent flags stored per student
- Third-party access requires explicit consent

### Right to Opt-Out of Directory Information
- `OPT_OUT_DIRECTORY` flag on student record
- Masked even for directory-level roles when set

## Compliance Monitoring

### Tag Coverage Dashboard
```sql
SELECT 
    TABLE_NAME,
    COUNT(*) AS total_columns,
    SUM(CASE WHEN FERPA_CATEGORY IS NOT NULL THEN 1 ELSE 0 END) AS ferpa_tagged,
    ROUND(100.0 * SUM(CASE WHEN FERPA_CATEGORY IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS coverage_pct
FROM GOVERNANCE.OBSERVABILITY.VW_COLUMN_TAGS
GROUP BY TABLE_NAME
ORDER BY coverage_pct;
```

### Access Anomaly Detection
```sql
-- Unusual access patterns
SELECT 
    USER_NAME,
    ROLE_NAME,
    COUNT(*) AS query_count,
    COUNT(DISTINCT DATE(QUERY_START_TIME)) AS active_days
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE ARRAY_SIZE(BASE_OBJECTS_ACCESSED) > 0
  AND QUERY_START_TIME > DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY USER_NAME, ROLE_NAME
HAVING query_count > 1000
ORDER BY query_count DESC;
```

## References

- [FERPA Overview (US Department of Education)](https://www2.ed.gov/policy/gen/guid/fpco/ferpa/index.html)
- [Student Privacy Compass](https://studentprivacycompass.org/)
- [Snowflake Horizon Governance](https://www.snowflake.com/en/data-cloud/horizon/)
- [Snowflake Access History](https://docs.snowflake.com/en/sql-reference/account-usage/access_history)
