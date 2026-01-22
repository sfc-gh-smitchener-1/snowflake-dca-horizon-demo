-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT - CONTRACT REGISTRY
-- ============================================================================
-- 
-- Creates the contract registry tables and procedures for managing
-- data contracts, consumers, quality rules, and alerts.
--
-- RUN AS: DATA_ADMIN
-- ============================================================================

USE ROLE DATA_ADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: CONTRACTS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE CONTRACTS (
    CONTRACT_ID VARCHAR(100) PRIMARY KEY,
    VERSION VARCHAR(20) NOT NULL,
    STATUS VARCHAR(20) DEFAULT 'draft',
    CONTRACT_TYPE VARCHAR(30) DEFAULT 'data',
    
    -- Producer information
    PRODUCER_SYSTEM VARCHAR(100),
    PRODUCER_TEAM VARCHAR(100),
    PRODUCER_OWNER VARCHAR(100),
    PRODUCER_SLACK VARCHAR(50),
    
    -- Schema reference
    TARGET_DATABASE VARCHAR(100),
    TARGET_SCHEMA VARCHAR(100),
    TARGET_TABLE VARCHAR(100),
    
    -- Governance
    GOVERNANCE_CLASSIFICATION VARCHAR(20),
    AI_ELIGIBILITY VARCHAR(30),
    RETENTION_DAYS NUMBER,
    
    -- SLA
    FRESHNESS_MAX_MINUTES NUMBER,
    COMPLETENESS_THRESHOLD NUMBER(5,2),
    
    -- Metadata
    CONTRACT_YAML VARIANT,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY VARCHAR(100) DEFAULT CURRENT_USER(),
    
    -- Health tracking
    LAST_HEALTH_CHECK TIMESTAMP_NTZ,
    HEALTH_STATUS VARCHAR(20) DEFAULT 'UNKNOWN'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: CONSUMERS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE CONSUMERS (
    CONSUMER_ID VARCHAR(100) PRIMARY KEY,
    CONTRACT_ID VARCHAR(100) REFERENCES CONTRACTS(CONTRACT_ID),
    CONSUMER_TEAM VARCHAR(100) NOT NULL,
    CONSUMER_CONTACT VARCHAR(100),
    USE_CASE VARCHAR(500),
    ACCESS_LEVEL VARCHAR(30),
    REGISTERED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LAST_ACCESS TIMESTAMP_NTZ,
    IS_ACTIVE BOOLEAN DEFAULT TRUE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: QUALITY RULES TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE QUALITY_RULES (
    RULE_ID VARCHAR(100) PRIMARY KEY,
    CONTRACT_ID VARCHAR(100) REFERENCES CONTRACTS(CONTRACT_ID),
    RULE_NAME VARCHAR(200) NOT NULL,
    RULE_TYPE VARCHAR(30),
    TARGET_COLUMN VARCHAR(100),
    RULE_SQL VARCHAR(4000),
    SEVERITY VARCHAR(20),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: QUALITY RULE RESULTS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE QUALITY_RULE_RESULTS (
    RESULT_ID VARCHAR(100) DEFAULT UUID_STRING() PRIMARY KEY,
    RULE_ID VARCHAR(100) REFERENCES QUALITY_RULES(RULE_ID),
    CONTRACT_ID VARCHAR(100) REFERENCES CONTRACTS(CONTRACT_ID),
    RUN_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STATUS VARCHAR(20),
    RECORDS_CHECKED NUMBER,
    RECORDS_PASSED NUMBER,
    RECORDS_FAILED NUMBER,
    PASS_RATE NUMBER(5,2),
    ERROR_MESSAGE VARCHAR(4000),
    SAMPLE_FAILURES VARIANT
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: ALERTS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE ALERTS (
    ALERT_ID VARCHAR(100) DEFAULT UUID_STRING() PRIMARY KEY,
    CONTRACT_ID VARCHAR(100) REFERENCES CONTRACTS(CONTRACT_ID),
    ALERT_TYPE VARCHAR(50),
    SEVERITY VARCHAR(20),
    MESSAGE VARCHAR(4000),
    STATUS VARCHAR(20) DEFAULT 'OPEN',
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    ACKNOWLEDGED_AT TIMESTAMP_NTZ,
    ACKNOWLEDGED_BY VARCHAR(100),
    RESOLVED_AT TIMESTAMP_NTZ,
    RESOLVED_BY VARCHAR(100)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: CONTRACT HISTORY TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE CONTRACT_HISTORY (
    HISTORY_ID VARCHAR(100) DEFAULT UUID_STRING() PRIMARY KEY,
    CONTRACT_ID VARCHAR(100) REFERENCES CONTRACTS(CONTRACT_ID),
    VERSION VARCHAR(20),
    CHANGE_TYPE VARCHAR(50),
    CHANGE_DESCRIPTION VARCHAR(4000),
    CHANGED_BY VARCHAR(100) DEFAULT CURRENT_USER(),
    CHANGED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PREVIOUS_STATE VARIANT,
    NEW_STATE VARIANT
);

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 7: LOAD SAMPLE CONTRACTS
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO CONTRACTS (
    CONTRACT_ID, VERSION, STATUS, CONTRACT_TYPE,
    PRODUCER_SYSTEM, PRODUCER_TEAM, PRODUCER_OWNER,
    TARGET_DATABASE, TARGET_SCHEMA, TARGET_TABLE,
    GOVERNANCE_CLASSIFICATION, AI_ELIGIBILITY, RETENTION_DAYS,
    FRESHNESS_MAX_MINUTES, COMPLETENESS_THRESHOLD,
    HEALTH_STATUS
) VALUES
    ('student_v1', '1.0.0', 'active', 'data',
     'STUDENT_INFORMATION_SYSTEM', 'Student Data Services', 'sis-team@district.edu',
     'RAW_DEV', 'RAW_SIS', 'STUDENT_RAW',
     'RESTRICTED', 'PSEUDONYMIZED_ONLY', 2555,
     60, 99.9, 'GREEN'),
    
    ('staff_v1', '1.0.0', 'active', 'data',
     'HR_INFORMATION_SYSTEM', 'Human Resources', 'hr-data@district.edu',
     'RAW_DEV', 'RAW_HR', 'STAFF_RAW',
     'CONFIDENTIAL', 'PSEUDONYMIZED_ONLY', 2555,
     120, 99.5, 'GREEN'),
    
    ('school_v1', '1.0.0', 'active', 'data',
     'DISTRICT_MANAGEMENT_SYSTEM', 'District Operations', 'ops-data@district.edu',
     'RAW_DEV', 'RAW_SIS', 'SCHOOL_RAW',
     'PUBLIC', 'TRUE', 3650,
     1440, 100, 'GREEN'),
    
    ('guardian_v1', '1.0.0', 'active', 'data',
     'STUDENT_INFORMATION_SYSTEM', 'Student Data Services', 'sis-team@district.edu',
     'RAW_DEV', 'RAW_SIS', 'GUARDIAN_RAW',
     'CONFIDENTIAL', 'PSEUDONYMIZED_ONLY', 2555,
     120, 99.0, 'GREEN'),
    
    ('enrollment_v1', '1.0.0', 'active', 'data',
     'STUDENT_INFORMATION_SYSTEM', 'Student Data Services', 'sis-team@district.edu',
     'RAW_DEV', 'RAW_SIS', 'ENROLLMENT_RAW',
     'CONFIDENTIAL', 'AGGREGATED_ONLY', 2555,
     60, 99.9, 'GREEN'),
    
    ('attendance_v1', '1.0.0', 'active', 'data',
     'STUDENT_INFORMATION_SYSTEM', 'Student Data Services', 'sis-team@district.edu',
     'RAW_DEV', 'RAW_SIS', 'ATTENDANCE_RAW',
     'CONFIDENTIAL', 'AGGREGATED_ONLY', 2555,
     60, 99.9, 'GREEN');

-- Insert sample quality rules
INSERT INTO QUALITY_RULES (
    RULE_ID, CONTRACT_ID, RULE_NAME, RULE_TYPE, TARGET_COLUMN, RULE_SQL, SEVERITY
) VALUES
    ('student_qr_001', 'student_v1', 'valid_student_id', 'column_check', 'STUDENT_ID', 
     'STUDENT_ID IS NOT NULL AND LENGTH(STUDENT_ID) > 0', 'error'),
    ('student_qr_002', 'student_v1', 'valid_grade_level', 'column_check', 'GRADE_LEVEL',
     'GRADE_LEVEL IN (''PK'', ''K'', ''01'', ''02'', ''03'', ''04'', ''05'', ''06'', ''07'', ''08'', ''09'', ''10'', ''11'', ''12'')', 'error'),
    ('student_qr_003', 'student_v1', 'valid_ssn_format', 'column_check', 'SSN',
     'SSN IS NULL OR SSN REGEXP ''^[0-9]{3}-[0-9]{2}-[0-9]{4}$''', 'warning'),
    ('staff_qr_001', 'staff_v1', 'valid_staff_id', 'column_check', 'STAFF_ID',
     'STAFF_ID IS NOT NULL', 'error'),
    ('school_qr_001', 'school_v1', 'valid_school_id', 'column_check', 'SCHOOL_ID',
     'SCHOOL_ID IS NOT NULL', 'error');

-- Insert sample consumers
INSERT INTO CONSUMERS (
    CONSUMER_ID, CONTRACT_ID, CONSUMER_TEAM, CONSUMER_CONTACT, USE_CASE, ACCESS_LEVEL
) VALUES
    ('c001', 'student_v1', 'District Analytics', 'analytics@district.edu', 'District-wide enrollment reporting', 'read_masked'),
    ('c002', 'student_v1', 'School Leadership', 'principals@district.edu', 'School-level student management', 'read_masked'),
    ('c003', 'student_v1', 'Teachers', 'teachers@district.edu', 'Classroom student information', 'read_masked'),
    ('c004', 'staff_v1', 'Human Resources', 'hr@district.edu', 'Staff management and reporting', 'read_full'),
    ('c005', 'school_v1', 'Public Affairs', 'communications@district.edu', 'Public school directory', 'read_full');

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Contract Registry Setup Complete' AS STATUS;

SELECT 'Contracts' AS entity, COUNT(*) AS count FROM CONTRACTS
UNION ALL SELECT 'Quality Rules', COUNT(*) FROM QUALITY_RULES
UNION ALL SELECT 'Consumers', COUNT(*) FROM CONSUMERS;
