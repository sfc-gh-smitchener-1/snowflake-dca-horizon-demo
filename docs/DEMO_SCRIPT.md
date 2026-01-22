# Massachusetts School District Horizon Demo Script

> **Duration**: 10-15 minutes  
> **Audience**: Technical decision makers, data leaders, compliance officers  
> **Goal**: Demonstrate Snowflake Horizon's governance, privacy, and observability capabilities

---

## Pre-Demo Setup

### Environment Check
```sql
-- Verify demo is ready
USE ROLE DATA_ADMIN;
USE WAREHOUSE ANALYTICS_WH;

-- Check data counts
SELECT 'Students' AS entity, COUNT(*) AS count FROM RAW_DEV.RAW_SIS.STUDENT_RAW
UNION ALL
SELECT 'Schools', COUNT(*) FROM RAW_DEV.RAW_SIS.SCHOOL_RAW
UNION ALL
SELECT 'Staff', COUNT(*) FROM RAW_DEV.RAW_HR.STAFF_RAW;
```

### Browser Tabs to Have Open
1. Snowsight - SQL Worksheet (for live queries)
2. Snowsight - Streamlit App (SCHOOL_DISTRICT_DEMO)
3. Snowsight - Data → Governance → Tags (show tag definitions)

---

## Act 1: The Data Foundation (3 minutes)

### Scene 1.1: Introduce the Dataset

**Talk Track:**
> "Today I'll show you how Snowflake Horizon enables education organizations to implement enterprise-grade data governance while maintaining FERPA compliance. We've created a synthetic Massachusetts school district with 100,000 students across 250 schools in the Greater Boston area."

```sql
-- Show the scale of our demo data
SELECT 
    'Massachusetts School District Demo' AS demo,
    (SELECT COUNT(*) FROM RAW_DEV.RAW_SIS.STUDENT_RAW) AS students,
    (SELECT COUNT(*) FROM RAW_DEV.RAW_SIS.SCHOOL_RAW) AS schools,
    (SELECT COUNT(DISTINCT DISTRICT_ID) FROM RAW_DEV.RAW_SIS.SCHOOL_RAW) AS districts,
    (SELECT COUNT(*) FROM RAW_DEV.RAW_HR.STAFF_RAW) AS staff_members;
```

### Scene 1.2: Three-Layer Architecture

**Talk Track:**
> "We follow a contract-first architecture with three layers: RAW for ingestion, CURATED for business transformations using Dynamic Tables, and SEMANTIC for AI-ready Semantic Views. Each layer has explicit data contracts that define schema, quality rules, and governance."

```sql
-- Show databases
SHOW DATABASES LIKE '%DEV';
SHOW DATABASES LIKE 'GOVERNANCE';

-- Show the Dynamic Tables in CURATED layer
SHOW DYNAMIC TABLES IN DATABASE CURATED_DEV;

-- Show the Semantic Views in SEMANTIC layer
SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV;

-- Show a sample contract
SELECT CONTRACT_ID, VERSION, STATUS, PRODUCER_TEAM, GOVERNANCE_CLASSIFICATION
FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
WHERE CONTRACT_ID LIKE 'student%'
LIMIT 5;
```

### Scene 1.3: Data Contracts in Action

**Talk Track:**
> "Data contracts aren't just documentation—they're executable specifications. Let's see the contract for our student data."

```sql
-- Show quality rules for student data
SELECT 
    CONTRACT_ID,
    RULE_ID,
    RULE_NAME,
    SEVERITY,
    LAST_RUN_STATUS
FROM GOVERNANCE.OBSERVABILITY.VW_QUALITY_RULES
WHERE CONTRACT_ID = 'student_v1'
ORDER BY SEVERITY;
```

---

## Act 2: Horizon Governance in Action (5 minutes)

### Scene 2.1: Object Tagging

**Talk Track:**
> "Snowflake Horizon's object tagging lets us classify every column with governance metadata. For education data, we tag FERPA categories, PII sensitivity, and AI eligibility."

```sql
-- Show tags on student table
SELECT 
    COLUMN_NAME,
    TAG_NAME,
    TAG_VALUE
FROM TABLE(
    INFORMATION_SCHEMA.TAG_REFERENCES(
        'RAW_DEV.RAW_SIS.STUDENT_RAW', 
        'TABLE'
    )
)
WHERE TAG_NAME IN ('FERPA_CATEGORY', 'PII_TYPE', 'AI_ALLOWED')
ORDER BY COLUMN_NAME, TAG_NAME;
```

**Talk Track:**
> "Notice how SSN is tagged as SENSITIVE with HIGH PII, while grade level is DIRECTORY information that's AI-eligible. These tags drive our masking policies automatically."

### Scene 2.2: Tag-Based Masking Policies

**Talk Track:**
> "Let's see masking in action. I'll query the same data as different roles. Watch how PII is automatically protected."

```sql
-- As DATA_ADMIN - see everything
USE ROLE DATA_ADMIN;
SELECT STUDENT_ID, FIRST_NAME, LAST_NAME, SSN, DATE_OF_BIRTH, HOME_ADDRESS
FROM SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE
LIMIT 5;
```

```sql
-- As TEACHER - PII is masked
USE ROLE TEACHER;
SELECT STUDENT_ID, FIRST_NAME, LAST_NAME, SSN, DATE_OF_BIRTH, HOME_ADDRESS
FROM SEM_DEV.SEM_STUDENT.VW_STUDENT_PROFILE
LIMIT 5;
```

**Talk Track:**
> "As a teacher, I see student names because I need them for my job, but SSN is fully masked, date of birth shows only the year, and the full address is hidden. This is tag-based masking—no code changes needed when we add new columns."

```sql
-- As AI_AGENT - see only pseudonymized/aggregate data
USE ROLE AI_AGENT;
SELECT STUDENT_ID_HASH, GRADE_LEVEL, DISTRICT_NAME, GPA_RANGE
FROM SEM_DEV.SEM_STUDENT.VW_STUDENT_AI_SAFE
LIMIT 5;
```

**Talk Track:**
> "For AI workloads, we provide a completely different view with pseudonymized identifiers and aggregated metrics. The AI can analyze patterns without ever seeing individual student PII."

### Scene 2.3: Row Access Policies

**Talk Track:**
> "Beyond column masking, we also control which ROWS each user can see. Teachers should only see their assigned students."

```sql
-- As a specific teacher, see only their students
USE ROLE TEACHER;
-- Simulating teacher Jane Smith
SET CURRENT_TEACHER_ID = 'T-5001';

SELECT 
    STUDENT_ID, 
    FIRST_NAME, 
    LAST_NAME, 
    CURRENT_GRADE_LEVEL,
    COURSE_NAME
FROM SEM_DEV.SEM_STUDENT.VW_MY_STUDENTS
ORDER BY LAST_NAME;

-- Count shows only their students
SELECT COUNT(*) AS my_student_count FROM SEM_DEV.SEM_STUDENT.VW_MY_STUDENTS;
```

**Talk Track:**
> "This teacher sees only their 28 assigned students. The row access policy automatically filters based on the class roster without any application code."

### Scene 2.4: Access History for Compliance

**Talk Track:**
> "For FERPA compliance, we need to know who accessed what student data. Snowflake Access History provides a complete audit trail."

```sql
USE ROLE DATA_ADMIN;

-- Show recent access to student data
SELECT 
    QUERY_START_TIME,
    USER_NAME,
    ROLE_NAME,
    QUERY_TEXT,
    DIRECT_OBJECTS_ACCESSED
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE ARRAY_CONTAINS('RAW_DEV.RAW_SIS.STUDENT_RAW'::VARIANT, BASE_OBJECTS_ACCESSED)
  AND QUERY_START_TIME > DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY QUERY_START_TIME DESC
LIMIT 10;
```

**Talk Track:**
> "Every query is logged with the user, role, time, and exactly which tables were accessed. This is your FERPA audit trail, built into the platform."

---

## Act 3: Role-Based Experience (4 minutes)

### Scene 3.1: Superintendent View (District Admin)

**Talk Track:**
> "Let's see how different education personas experience the data. First, as a superintendent, I see district-wide analytics."

```sql
USE ROLE DISTRICT_ADMIN;

SELECT 
    DISTRICT_NAME,
    COUNT(DISTINCT SCHOOL_ID) AS schools,
    COUNT(DISTINCT STUDENT_ID) AS students,
    ROUND(AVG(GRADUATION_RATE), 1) AS avg_graduation_rate,
    ROUND(AVG(ATTENDANCE_RATE), 1) AS avg_attendance_rate
FROM SEM_DEV.SEM_DISTRICT.VW_DISTRICT_DASHBOARD
GROUP BY DISTRICT_NAME
ORDER BY students DESC
LIMIT 10;
```

### Scene 3.2: Principal View (School Level)

**Talk Track:**
> "As a principal, I see only my school but with more detail."

```sql
USE ROLE PRINCIPAL;
-- Simulating Lincoln Elementary principal
SET CURRENT_SCHOOL_ID = 'SCH-0042';

-- My school's performance
SELECT 
    GRADE_LEVEL,
    COUNT(*) AS students,
    ROUND(AVG(GPA), 2) AS avg_gpa,
    ROUND(AVG(ATTENDANCE_RATE), 1) AS attendance_pct,
    SUM(CASE WHEN AT_RISK_FLAG THEN 1 ELSE 0 END) AS at_risk_count
FROM SEM_DEV.SEM_SCHOOL.VW_MY_SCHOOL_STUDENTS
GROUP BY GRADE_LEVEL
ORDER BY GRADE_LEVEL;
```

### Scene 3.3: Teacher View (Classroom Level)

**Talk Track:**
> "As a teacher, I see only my assigned students with the information I need for instruction."

```sql
USE ROLE TEACHER;
SET CURRENT_TEACHER_ID = 'T-5001';

-- My gradebook
SELECT 
    STUDENT_NAME,
    ASSIGNMENT_NAME,
    GRADE,
    SUBMITTED_DATE,
    FEEDBACK
FROM SEM_DEV.SEM_CLASSROOM.VW_MY_GRADEBOOK
WHERE COURSE_ID = 'ALG-101-P3'
ORDER BY STUDENT_NAME, SUBMITTED_DATE;
```

### Scene 3.4: Parent Portal View

**Talk Track:**
> "Finally, parents in the portal see only their own children's information."

```sql
USE ROLE PARENT_PORTAL;
-- Simulating parent ID
SET CURRENT_PARENT_ID = 'P-12345';

-- My children's information
SELECT 
    STUDENT_NAME,
    SCHOOL_NAME,
    GRADE_LEVEL,
    CURRENT_GPA,
    ATTENDANCE_RATE,
    TEACHER_NAME,
    NEXT_CONFERENCE_DATE
FROM SEM_DEV.SEM_PARENT.VW_MY_CHILDREN
ORDER BY GRADE_LEVEL;
```

---

## Act 4: AI & Observability (3 minutes)

### Scene 4.1: Cortex Analyst Demo

**Talk Track:**
> "Cortex Analyst enables natural language queries while respecting all our governance policies. Let me ask some questions about our school district."

*Switch to Streamlit App → Cortex Analyst Tab*

**Sample Questions to Demo:**
1. "What is the average GPA by district?"
2. "Which schools have the highest chronic absenteeism rates?"
3. "Show me enrollment trends over the past 5 years"
4. "Which grade levels have the most at-risk students?"

**Talk Track:**
> "Notice the SQL generated uses our semantic views, which already have masking and row access applied. The AI never sees raw PII."

### Scene 4.2: Governance Dashboard

**Talk Track:**
> "Our observability layer provides real-time visibility into governance health."

*Switch to Streamlit App → Horizon Dashboard Tab*

**Key Metrics to Highlight:**
- **Contract Health**: Show stoplights for each contract
- **Tag Coverage**: Percentage of columns properly tagged
- **SLA Compliance**: Freshness and quality metrics
- **Access Patterns**: Who's accessing what data

```sql
USE ROLE DATA_ADMIN;

-- Dashboard KPIs
SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_DASHBOARD_KPIS;

-- Tag coverage
SELECT 
    TAG_NAME,
    TAGGED_COLUMNS,
    TOTAL_COLUMNS,
    ROUND(100.0 * TAGGED_COLUMNS / TOTAL_COLUMNS, 1) AS coverage_pct
FROM GOVERNANCE.OBSERVABILITY.VW_TAG_COVERAGE
ORDER BY coverage_pct;
```

### Scene 4.3: Active Alerts

**Talk Track:**
> "When governance issues occur, we have automated alerts."

```sql
-- Show any active alerts
SELECT 
    ALERT_ID,
    SEVERITY,
    ALERT_TYPE,
    MESSAGE,
    CREATED_AT
FROM GOVERNANCE.OBSERVABILITY.VW_ACTIVE_ALERTS
WHERE STATUS = 'OPEN'
ORDER BY SEVERITY, CREATED_AT DESC;
```

---

## Closing (1 minute)

**Talk Track:**
> "To summarize what we've seen:
> 
> 1. **Object Tagging** classifies every column with FERPA and PII metadata
> 2. **Tag-Based Masking** automatically protects sensitive data based on role
> 3. **Row Access Policies** ensure users see only data they're authorized for
> 4. **Access History** provides complete audit trails for compliance
> 5. **Cortex Analyst** enables AI-powered analytics while respecting governance
> 6. **Observability** gives real-time visibility into data health
> 
> All of this is built into the Snowflake platform—no external tools required. This is Snowflake Horizon."

---

## Q&A Preparation

### Common Questions

**Q: How does this scale to millions of students?**
> A: Snowflake's architecture scales automatically. The same policies work whether you have 100K or 10M students.

**Q: Can we customize the masking for different states' privacy laws?**
> A: Absolutely. Tags are customizable, and masking policies can be as simple or complex as needed.

**Q: What about real-time data from student information systems?**
> A: We support CDC (Change Data Capture) patterns with Dynamic Tables that refresh automatically.

**Q: How do parents get access to the portal?**
> A: This integrates with your identity provider. Row access policies use the authenticated user context.

**Q: Is the audit trail immutable?**
> A: Yes, Access History is a system view that cannot be modified or deleted by users.

---

## Demo Reset

If you need to reset the demo between presentations:

```sql
-- Reset session variables
USE ROLE DATA_ADMIN;
UNSET CURRENT_TEACHER_ID;
UNSET CURRENT_SCHOOL_ID;
UNSET CURRENT_PARENT_ID;

-- Verify clean state
SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE();
```
