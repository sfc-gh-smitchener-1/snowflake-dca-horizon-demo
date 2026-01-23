-- ============================================================================
-- MASSACHUSETTS SCHOOL DISTRICT - STREAMLIT APP DEPLOYMENT
-- ============================================================================
-- 
-- Deploys the Streamlit application to Snowflake
-- The app provides:
-- - Cortex Analyst natural language queries
-- - Horizon governance dashboard
-- - Role-based data visualization
-- - FERPA compliance monitoring
--
-- RUN AS: DATA_ADMIN (or ACCOUNTADMIN if needed for stage creation)
-- ============================================================================

USE ROLE DATA_ADMIN;
USE WAREHOUSE ANALYTICS_WH;
USE DATABASE SEM_DEV;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: CREATE SCHEMA FOR STREAMLIT APPS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE SCHEMA IF NOT EXISTS SEM_DEV.STREAMLIT_APPS
    COMMENT = 'Schema for Streamlit applications';

USE SCHEMA STREAMLIT_APPS;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: CREATE INTERNAL STAGE FOR APP FILES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Streamlit application files';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: UPLOAD THE STREAMLIT APP
-- ═══════════════════════════════════════════════════════════════════════════

-- NOTE: Run this PUT command from SnowSQL or Snowflake CLI, not from worksheet
-- The file path should be adjusted to your local path

-- From SnowSQL:
-- PUT file:///path/to/streamlit/school_district_app.py @SEM_DEV.STREAMLIT_APPS.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: CREATE THE STREAMLIT APP
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO
    ROOT_LOCATION = '@SEM_DEV.STREAMLIT_APPS.STREAMLIT_STAGE'
    MAIN_FILE = 'school_district_app.py'
    QUERY_WAREHOUSE = 'ANALYTICS_WH'
    COMMENT = 'Massachusetts School District Horizon Demo - Cortex Analyst & Governance Dashboard';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: GRANT ACCESS TO ROLES
-- ═══════════════════════════════════════════════════════════════════════════

-- Grant usage on the schema
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE DISTRICT_ADMIN;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE PRINCIPAL;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE TEACHER;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE COUNSELOR;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE REGISTRAR;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE PARENT_PORTAL;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.STREAMLIT_APPS TO ROLE BI_VIEWER;

-- Grant usage on the Streamlit app
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE DISTRICT_ADMIN;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE PRINCIPAL;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE TEACHER;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE COUNSELOR;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE REGISTRAR;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE PARENT_PORTAL;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE AI_AGENT;
GRANT USAGE ON STREAMLIT SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Streamlit App Deployment Complete' AS STATUS;

-- Show the created Streamlit app
SHOW STREAMLITS IN SCHEMA SEM_DEV.STREAMLIT_APPS;

-- Get the URL for the Streamlit app
SELECT SYSTEM$GET_STREAMLIT_URL('SEM_DEV.STREAMLIT_APPS.SCHOOL_DISTRICT_DEMO') AS APP_URL;

-- ═══════════════════════════════════════════════════════════════════════════
-- DEPLOYMENT INSTRUCTIONS
-- ═══════════════════════════════════════════════════════════════════════════
/*
To deploy the Streamlit app:

1. First, upload the Python file to the stage using SnowSQL or Snowflake CLI:

   # Using SnowSQL
   snowsql -a <account> -u <user>
   USE ROLE DATA_ADMIN;
   USE DATABASE SEM_DEV;
   USE SCHEMA STREAMLIT_APPS;
   PUT file://streamlit/school_district_app.py @STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

   # Or using Snowflake CLI (snow)
   snow stage copy streamlit/school_district_app.py @SEM_DEV.STREAMLIT_APPS.STREAMLIT_STAGE --overwrite

2. Then run this SQL script to create the Streamlit app object

3. Access the app via:
   - Snowsight: Projects > Streamlit > SCHOOL_DISTRICT_DEMO
   - Or use the URL returned by SYSTEM$GET_STREAMLIT_URL()

Alternative: Create via Snowsight UI
1. Navigate to Projects > Streamlit
2. Click "+ Streamlit App"
3. Name: SCHOOL_DISTRICT_DEMO
4. Warehouse: ANALYTICS_WH
5. Database: SEM_DEV, Schema: STREAMLIT_APPS
6. Paste the contents of school_district_app.py into the editor
*/
