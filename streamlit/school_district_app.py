# ============================================================================
# MASSACHUSETTS SCHOOL DISTRICT - Streamlit in Snowflake Application
# ============================================================================
# A comprehensive dashboard for:
#   1. Snowflake Cortex Analyst - Natural language queries on semantic views
#   2. Snowflake Horizon - FERPA governance & compliance dashboard
#
# Uses the Cortex Analyst API for native semantic view querying
# ============================================================================

import streamlit as st
import pandas as pd
import requests
import json
from snowflake.snowpark.context import get_active_session

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================

st.set_page_config(
    page_title="MA School District - Horizon Demo",
    page_icon="🎓",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# SNOWFLAKE EDUCATION THEME STYLING
# ============================================================================

SNOWFLAKE_BLUE = "#29B5E8"
EDUCATION_PURPLE = "#6E56CF"
SUCCESS_GREEN = "#18794E"
WARNING_AMBER = "#AD5700"
ERROR_RED = "#CD2B31"

st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
    
    .stApp {
        background: linear-gradient(180deg, #FFFFFF 0%, #F0F9FF 100%);
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    }
    
    [data-testid="stSidebar"] {
        background: linear-gradient(180deg, #11567F 0%, #0D3D5C 100%);
    }
    
    [data-testid="stSidebar"] * {
        color: white !important;
    }
    
    .main-header {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(41, 181, 232, 0.3);
    }
    
    .main-header h1 { margin: 0; font-size: 1.75rem; font-weight: 700; }
    .main-header p { margin: 0.5rem 0 0 0; opacity: 0.9; font-size: 0.95rem; }
    
    .ferpa-header {
        background: linear-gradient(135deg, #6E56CF 0%, #29B5E8 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        color: white;
        box-shadow: 0 4px 20px rgba(110, 86, 207, 0.3);
    }
    
    .ferpa-header h1 { margin: 0; font-size: 1.75rem; font-weight: 700; }
    .ferpa-header p { margin: 0.5rem 0 0 0; opacity: 0.9; }
    
    .metric-card {
        background: white;
        border-radius: 12px;
        padding: 1.25rem;
        border-left: 4px solid #29B5E8;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
        margin-bottom: 0.5rem;
    }
    
    .metric-card.success { border-left-color: #18794E; }
    .metric-card.warning { border-left-color: #AD5700; }
    .metric-card.error { border-left-color: #CD2B31; }
    
    .metric-card strong {
        color: #64748B;
        font-size: 0.8rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }
    
    .metric-card h2 {
        color: #0F172A !important;
        margin: 0.5rem 0 0 0;
        font-size: 1.75rem;
        font-weight: 700;
    }
    
    .stoplight {
        display: inline-block;
        width: 14px;
        height: 14px;
        border-radius: 50%;
        margin-right: 8px;
        vertical-align: middle;
    }
    
    .stoplight.green { background: #18794E; box-shadow: 0 0 8px rgba(24,121,78,0.5); }
    .stoplight.yellow { background: #AD5700; box-shadow: 0 0 8px rgba(173,87,0,0.5); }
    .stoplight.red { background: #CD2B31; box-shadow: 0 0 8px rgba(205,43,49,0.5); }
    
    .chat-bubble {
        padding: 15px;
        border-radius: 12px;
        margin-bottom: 10px;
    }
    
    .user-bubble {
        background: #E3F5FC;
        border-left: 5px solid #29B5E8;
    }
    
    .assistant-bubble {
        background: #F1F5F9;
        border-left: 5px solid #6E56CF;
    }
    
    .stButton > button {
        background: linear-gradient(135deg, #29B5E8 0%, #11567F 100%);
        color: white;
        border: none;
        border-radius: 8px;
        font-weight: 500;
    }
    
    .role-badge {
        display: inline-block;
        padding: 5px 15px;
        border-radius: 20px;
        font-size: 0.8rem;
        font-weight: bold;
    }
    
    .role-admin { background: #fee2e2; color: #dc2626; }
    .role-principal { background: #fef3c7; color: #d97706; }
    .role-teacher { background: #dbeafe; color: #2563eb; }
    
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

# ============================================================================
# SESSION & CORTEX ANALYST API
# ============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session"""
    return get_active_session()

def call_cortex_analyst(prompt: str, semantic_view: str):
    """Calls the Cortex Analyst API using the Snowflake session."""
    session = get_session()
    
    try:
        rest = session._conn._rest
        endpoint = "/api/v2/cortex/analyst/message"
        
        request_body = {
            "messages": [
                {"role": "user", "content": [{"type": "text", "text": prompt}]}
            ],
            "semantic_view": semantic_view
        }
        
        response = rest.request(
            url=endpoint,
            method="POST",
            body=request_body,
            headers={"Content-Type": "application/json"}
        )
        
        if response and 'message' in response:
            return response, None
        else:
            return call_cortex_complete_fallback(prompt, semantic_view)
            
    except AttributeError:
        return call_cortex_analyst_external(prompt, semantic_view)
    except Exception as e:
        return call_cortex_complete_fallback(prompt, semantic_view)

def call_cortex_analyst_external(prompt: str, semantic_view: str):
    """Calls Cortex Analyst using external REST API with token."""
    session = get_session()
    
    try:
        host = session.connection.host if hasattr(session, 'connection') else None
        token = None
        try:
            token = session._conn._rest._token
        except:
            pass
        
        if not host or not token:
            return call_cortex_complete_fallback(prompt, semantic_view)
        
        url = f"https://{host}/api/v2/cortex/analyst/message"
        
        request_body = {
            "messages": [
                {"role": "user", "content": [{"type": "text", "text": prompt}]}
            ],
            "semantic_view": semantic_view
        }
        
        headers = {
            "Authorization": f'Snowflake Token="{token}"',
            "Content-Type": "application/json",
            "Accept": "application/json"
        }

        response = requests.post(url, json=request_body, headers=headers)
        
        if response.status_code == 200:
            return response.json(), None
        else:
            return call_cortex_complete_fallback(prompt, semantic_view)
            
    except Exception as e:
        return call_cortex_complete_fallback(prompt, semantic_view)

def call_cortex_complete_fallback(prompt: str, semantic_view: str):
    """Fallback using CORTEX.COMPLETE to generate SQL for semantic views."""
    session = get_session()
    
    try:
        view_info = get_semantic_view_info(semantic_view)
        
        escaped_prompt = prompt.replace("'", "''")
        escaped_view = semantic_view.replace("'", "''")
        escaped_info = view_info.replace("'", "''")
        
        result = session.sql(f"""
            SELECT SNOWFLAKE.CORTEX.COMPLETE(
                'llama3.1-70b',
                'Generate a SQL query using the SEMANTIC_VIEW() function.

SEMANTIC VIEW: {escaped_view}

{escaped_info}

USE THIS EXACT PATTERN - the SEMANTIC_VIEW() function:
SELECT * FROM SEMANTIC_VIEW(
  {escaped_view}
  DIMENSIONS dimension1, dimension2
  METRICS metric1, metric2
)

RULES:
1. Always use SEMANTIC_VIEW() function - this is the ONLY correct way
2. List dimensions after DIMENSIONS keyword (comma separated)
3. List metrics after METRICS keyword (comma separated)
4. Use exact names from the lists above
5. Return ONLY the SQL query

Question: {escaped_prompt}

SQL:'
            ) AS response
        """).to_pandas()
        
        if not result.empty:
            sql = result['RESPONSE'].iloc[0].strip()
            
            if '```' in sql:
                parts = sql.split('```')
                for part in parts:
                    if 'SELECT' in part.upper():
                        sql = part.strip()
                        if sql.lower().startswith('sql'):
                            sql = sql[3:].strip()
                        break
            
            if ';' in sql:
                sql = sql.split(';')[0] + ';'
            
            return {
                "message": {
                    "content": [
                        {"type": "text", "text": "Here's the query for your question:"},
                        {"type": "sql", "statement": sql}
                    ]
                }
            }, None
        else:
            return None, "No response generated"
            
    except Exception as e:
        return None, f"Error: {str(e)}"

def get_semantic_view_info(semantic_view: str) -> str:
    """Get metadata about a semantic view for LLM context."""
    session = get_session()
    
    info_parts = []
    
    try:
        dims = session.sql(f"SHOW SEMANTIC DIMENSIONS IN SEMANTIC VIEW {semantic_view}").to_pandas()
        if not dims.empty and 'name' in dims.columns:
            dim_names = dims['name'].tolist()
            info_parts.append(f"DIMENSIONS: {', '.join(dim_names)}")
    except:
        pass
    
    try:
        metrics = session.sql(f"SHOW SEMANTIC METRICS IN SEMANTIC VIEW {semantic_view}").to_pandas()
        if not metrics.empty and 'name' in metrics.columns:
            metric_names = metrics['name'].tolist()
            info_parts.append(f"METRICS: {', '.join(metric_names)}")
    except:
        pass
    
    if info_parts:
        return "\n".join(info_parts)
    
    # Fallback hardcoded info for education semantic views
    view_contexts = {
        'STUDENT_ENROLLMENT_ANALYTICS': """DIMENSIONS: STUDENT_ID, DISPLAY_NAME, GRADE_LEVEL, GRADE_LEVEL_CATEGORY, ENROLLMENT_STATUS, COHORT_YEAR, AGE, GENDER, ETHNICITY, PRIMARY_LANGUAGE, ELL_STATUS, SPECIAL_EDUCATION, SECTION_504, GIFTED_TALENTED, FREE_REDUCED_LUNCH, HOMELESS_STATUS, AT_RISK_FLAG, PROGRAM_COUNT, SCHOOL_ID, SCHOOL_NAME, SCHOOL_TYPE, IS_TITLE_I, IS_MAGNET, IS_CHARTER, CITY, COUNTY, ACCOUNTABILITY_RATING, CAPACITY_STATUS, DISTRICT_ID, DISTRICT_NAME, SUPERINTENDENT_NAME
METRICS: student_count, active_students, at_risk_count, ell_count, sped_count, section504_count, gifted_count, frl_count, homeless_count, school_count, title_i_count, total_capacity, total_enrollment, ell_rate, sped_rate, frl_rate, at_risk_rate, capacity_utilization""",
        'STUDENT_DEMOGRAPHICS_ANALYTICS': """DIMENSIONS: GRADE_LEVEL, GRADE_LEVEL_CATEGORY, GENDER, ETHNICITY, RACE, PRIMARY_LANGUAGE, ELL_STATUS, FREE_REDUCED_LUNCH, COUNTY, SCHOOL_NAME, SCHOOL_TYPE
METRICS: student_count, ell_count, frl_count, ell_rate, frl_rate""",
        'SCHOOL_PERFORMANCE_ANALYTICS': """DIMENSIONS: SCHOOL_ID, SCHOOL_NAME, SCHOOL_TYPE, GRADE_LEVELS_SERVED, IS_TITLE_I, IS_MAGNET, IS_CHARTER, CITY, COUNTY, ACCOUNTABILITY_RATING, CAPACITY_STATUS, PRINCIPAL_NAME, DISTRICT_NAME, SUPERINTENDENT_NAME
METRICS: school_count, total_capacity, total_enrollment, total_staff, total_teachers, avg_graduation_rate, avg_attendance_rate, total_students, ell_students, sped_students, frl_students, capacity_utilization, student_teacher_ratio, avg_capacity_utilization""",
        'STAFF_WORKFORCE_ANALYTICS': """DIMENSIONS: STAFF_ID, DISPLAY_NAME, EMPLOYEE_TYPE, POSITION_TITLE, ROLE_CATEGORY, DEPARTMENT, EMPLOYMENT_STATUS, HIGHEST_DEGREE, HIGHLY_QUALIFIED, LICENSE_STATUS, SALARY_BAND, IS_TEACHER, IS_ADMINISTRATOR, SCHOOL_NAME, SCHOOL_TYPE, COUNTY
METRICS: staff_count, active_staff, teacher_count, admin_count, total_experience_years, avg_experience, avg_tenure, highly_qualified_count, avg_summary_experience, total_hq_rate, highly_qualified_rate""",
        'ENROLLMENT_SUMMARY_ANALYTICS': """DIMENSIONS: GRADE_LEVEL, SCHOOL_ID, SCHOOL_NAME, SCHOOL_TYPE, COUNTY, DISTRICT_ID, DISTRICT_NAME
METRICS: student_count, active_count, ell_count, sped_count, frl_count, homeless_count, ell_rate, sped_rate, frl_rate""",
        'GOVERNANCE_ANALYTICS': """DIMENSIONS: CONTRACT_ID, VERSION, STATUS, CONTRACT_TYPE, PRODUCER_SYSTEM, PRODUCER_TEAM, GOVERNANCE_CLASSIFICATION, HEALTH_STATUS, RULE_NAME, RULE_TYPE, SEVERITY, ALERT_TYPE
METRICS: contract_count, active_contracts, healthy_contracts, warning_contracts, critical_contracts, consumer_count, active_consumers, rule_count, active_rules, alert_count, open_alerts, critical_alerts, avg_consumers_per_contract, avg_rules_per_contract, health_score"""
    }
    
    for key, ctx in view_contexts.items():
        if key in semantic_view.upper():
            return ctx
    
    return "Query this semantic view to analyze education data."

def execute_sql(sql: str):
    """Execute SQL and return DataFrame"""
    session = get_session()
    try:
        return session.sql(sql).to_pandas(), None
    except Exception as e:
        return None, str(e)

# ============================================================================
# DATA FETCHING FOR DASHBOARD
# ============================================================================

@st.cache_data(ttl=60)
def get_dashboard_kpis():
    """Fetch dashboard KPIs"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                (SELECT COUNT(*) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT WHERE ENROLLMENT_STATUS = 'Active') AS TOTAL_STUDENTS,
                (SELECT COUNT(*) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL) AS TOTAL_SCHOOLS,
                (SELECT COUNT(*) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF WHERE EMPLOYMENT_STATUS = 'Active') AS TOTAL_STAFF,
                (SELECT COUNT(DISTINCT DISTRICT_ID) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT) AS TOTAL_DISTRICTS,
                (SELECT COUNT(*) FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS WHERE STATUS = 'active') AS ACTIVE_CONTRACTS,
                (SELECT COUNT(*) FROM GOVERNANCE.CONTRACT_REGISTRY.ALERTS WHERE STATUS = 'OPEN') AS OPEN_ALERTS
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_enrollment_by_school_type():
    """Get enrollment breakdown by school type"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                s.SCHOOL_TYPE,
                COUNT(DISTINCT st.STUDENT_KEY) AS STUDENT_COUNT
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT st
            JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL s ON st.CURRENT_SCHOOL_ID = s.SCHOOL_ID
            WHERE st.ENROLLMENT_STATUS = 'Active'
            GROUP BY s.SCHOOL_TYPE
            ORDER BY STUDENT_COUNT DESC
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

@st.cache_data(ttl=60)
def get_program_participation():
    """Get special program participation rates"""
    session = get_session()
    try:
        df = session.sql("""
            SELECT 
                SUM(CASE WHEN ELL_STATUS THEN 1 ELSE 0 END) AS ELL_COUNT,
                SUM(CASE WHEN SPECIAL_EDUCATION THEN 1 ELSE 0 END) AS SPED_COUNT,
                SUM(CASE WHEN SECTION_504 THEN 1 ELSE 0 END) AS SECTION_504_COUNT,
                SUM(CASE WHEN GIFTED_TALENTED THEN 1 ELSE 0 END) AS GIFTED_COUNT,
                SUM(CASE WHEN FREE_REDUCED_LUNCH IN ('Free', 'Reduced') THEN 1 ELSE 0 END) AS FRL_COUNT,
                COUNT(*) AS TOTAL
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
            WHERE ENROLLMENT_STATUS = 'Active'
        """).to_pandas()
        return df
    except:
        return pd.DataFrame()

@st.cache_data(ttl=300)
def get_semantic_views():
    """List available semantic views"""
    session = get_session()
    try:
        df = session.sql("SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV").to_pandas()
        if not df.empty and 'name' in df.columns:
            views = []
            for _, row in df.iterrows():
                schema = row.get('schema_name', '')
                name = row.get('name', '')
                if schema and name:
                    views.append(f"SEM_DEV.{schema}.{name}")
            return views if views else get_default_semantic_views()
        return get_default_semantic_views()
    except:
        return get_default_semantic_views()

def get_default_semantic_views():
    """Return default list of semantic views"""
    return [
        # Student Analytics
        'SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS',
        'SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS',
        'SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS',
        # School Analytics
        'SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS',
        # Staff Analytics
        'SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS',
        # Governance Analytics
        'SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS',
        'SEM_DEV.SEM_GOVERNANCE.DATA_QUALITY_ANALYTICS',
        'SEM_DEV.SEM_GOVERNANCE.FERPA_COMPLIANCE_ANALYTICS'
    ]

# ============================================================================
# SIDEBAR
# ============================================================================

def render_sidebar():
    """Render the sidebar navigation"""
    with st.sidebar:
        st.markdown("""
        <div style="text-align: center; padding: 1rem 0 1.5rem 0;">
            <div style="font-size: 3rem; margin-bottom: 0.5rem;">🎓</div>
            <h2 style="color: white; font-size: 1.2rem; margin: 0; font-weight: 700;">MA School District</h2>
            <p style="color: #29B5E8; font-size: 0.85rem; margin: 0.25rem 0 0 0;">Horizon Demo</p>
        </div>
        """, unsafe_allow_html=True)
        
        st.divider()
        
        page = st.radio(
            "Navigation",
            ["🤖 Cortex Analyst", "🔮 FERPA Dashboard", "📊 School Analytics", "👥 Student Data", "ℹ️ About"],
            label_visibility="collapsed"
        )
        
        st.divider()
        
        # Quick stats
        st.markdown("### 📈 Quick Stats")
        kpis = get_dashboard_kpis()
        if not kpis.empty:
            col1, col2 = st.columns(2)
            with col1:
                if 'TOTAL_STUDENTS' in kpis.columns:
                    val = kpis['TOTAL_STUDENTS'].iloc[0]
                    st.metric("Students", f"{int(val):,}" if pd.notna(val) else 0)
                if 'TOTAL_SCHOOLS' in kpis.columns:
                    val = kpis['TOTAL_SCHOOLS'].iloc[0]
                    st.metric("Schools", int(val) if pd.notna(val) else 0)
            with col2:
                if 'TOTAL_STAFF' in kpis.columns:
                    val = kpis['TOTAL_STAFF'].iloc[0]
                    st.metric("Staff", f"{int(val):,}" if pd.notna(val) else 0)
                if 'TOTAL_DISTRICTS' in kpis.columns:
                    val = kpis['TOTAL_DISTRICTS'].iloc[0]
                    st.metric("Districts", int(val) if pd.notna(val) else 0)
        else:
            st.info("Loading stats...")
        
        st.divider()
        
        # Current role display
        session = get_session()
        try:
            role_df = session.sql("SELECT CURRENT_ROLE() AS ROLE").to_pandas()
            current_role = role_df['ROLE'].iloc[0] if not role_df.empty else "Unknown"
            st.markdown(f"**Current Role:** `{current_role}`")
        except:
            pass
        
        st.markdown("""
        <div style="text-align: center; padding-top: 1rem;">
            <p style="color: rgba(255,255,255,0.6); font-size: 0.75rem; margin: 0;">Powered by</p>
            <p style="color: #29B5E8; font-size: 0.85rem; margin: 0.25rem 0 0 0; font-weight: 500;">Snowflake Horizon + Cortex</p>
        </div>
        """, unsafe_allow_html=True)
        
        return page

# ============================================================================
# CORTEX ANALYST PAGE
# ============================================================================

def render_cortex_page():
    """Render the Cortex Analyst chat interface"""
    
    st.markdown("""
    <div class="main-header">
        <h1>🤖 Snowflake Cortex Analyst</h1>
        <p>Ask questions about student, school, and staff data using natural language</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Semantic View selector
    col1, col2 = st.columns([3, 1])
    with col1:
        views = get_semantic_views()
        selected_view = st.selectbox(
            "Select Semantic View",
            views,
            help="Choose which semantic view to query"
        )
    with col2:
        st.write("")
        if st.button("🔄 Refresh", use_container_width=True):
            st.cache_data.clear()
            st.experimental_rerun()
    
    st.divider()
    
    # Initialize chat history
    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []
    
    # Display chat history
    for i, chat in enumerate(st.session_state.chat_history):
        if chat["role"] == "user":
            st.markdown(f"""
            <div class="chat-bubble user-bubble">
                <strong>👤 You</strong><br>{chat["content"]}
            </div>
            """, unsafe_allow_html=True)
        else:
            st.markdown(f"""
            <div class="chat-bubble assistant-bubble">
                <strong>🤖 Cortex Analyst</strong><br>{chat["content"]}
            </div>
            """, unsafe_allow_html=True)
            if "sql" in chat and chat["sql"]:
                with st.expander("View Generated SQL", expanded=False):
                    st.code(chat["sql"], language="sql")
            if "df" in chat and chat["df"] is not None and not chat["df"].empty:
                st.dataframe(chat["df"], use_container_width=True)
    
    # Sample questions
    if not st.session_state.chat_history:
        st.markdown("### 💡 Sample Questions")
        
        sample_questions = {
            "SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS": [
                "How many students are enrolled by school type?",
                "What is the ELL rate by district?",
                "Show me at-risk student counts by grade level",
                "Which schools have the highest enrollment?"
            ],
            "SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS": [
                "What is the student count by ethnicity?",
                "Show demographics by school type",
                "What languages do students speak?",
                "What is the gender breakdown by grade?"
            ],
            "SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS": [
                "Which schools have the highest capacity utilization?",
                "What is the student-teacher ratio by school type?",
                "Show graduation rates by district",
                "How many Title I schools are there?"
            ],
            "SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS": [
                "How many teachers are highly qualified?",
                "What is the average experience by department?",
                "Show staff counts by role category",
                "What is the tenure distribution?"
            ],
            "SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS": [
                "How many data contracts are active?",
                "Show contract health status",
                "What is the alert breakdown by type?",
                "Which contracts have quality rules?"
            ]
        }
        
        questions = sample_questions.get(selected_view, [
            "Show me a summary of the data",
            "What are the key metrics?",
            "What are the totals by category?",
            "Show me the top 10 items"
        ])
        
        cols = st.columns(2)
        for i, q in enumerate(questions):
            with cols[i % 2]:
                if st.button(f"💬 {q}", key=f"sample_{i}", use_container_width=True):
                    process_question(q, selected_view)
                    st.experimental_rerun()
    
    st.divider()
    
    # Text input for questions
    col1, col2 = st.columns([5, 1])
    with col1:
        user_question = st.text_input(
            "Ask a question",
            placeholder="Ask a question about education data...",
            label_visibility="collapsed",
            key="question_input"
        )
    with col2:
        ask_clicked = st.button("🚀 Ask", use_container_width=True)
    
    if ask_clicked and user_question:
        process_question(user_question, selected_view)
        st.experimental_rerun()
    
    # Clear chat button
    if st.session_state.chat_history:
        if st.button("🗑️ Clear Chat", key="clear_chat"):
            st.session_state.chat_history = []
            st.experimental_rerun()

def process_question(prompt: str, semantic_view: str):
    """Process a user question via Cortex Analyst API"""
    
    st.session_state.chat_history.append({
        "role": "user",
        "content": prompt
    })
    
    api_response, error = call_cortex_analyst(prompt, semantic_view)
    
    if error:
        st.session_state.chat_history.append({
            "role": "assistant",
            "content": f"❌ {error}"
        })
        return
    
    if api_response:
        msg_content = api_response.get("message", {}).get("content", [])
        sql_query = None
        explanation = ""
        
        for part in msg_content:
            if part.get("type") == "text":
                explanation += part.get("text", "")
            elif part.get("type") == "sql":
                sql_query = part.get("statement", "")
        
        result_df = None
        if sql_query:
            result_df, sql_error = execute_sql(sql_query)
            if sql_error:
                explanation += f"\n\n⚠️ SQL Error: {sql_error}"
        
        st.session_state.chat_history.append({
            "role": "assistant",
            "content": explanation if explanation else "✅ Query executed successfully",
            "sql": sql_query,
            "df": result_df
        })

# ============================================================================
# FERPA DASHBOARD PAGE
# ============================================================================

def render_ferpa_dashboard():
    """Render the FERPA governance dashboard"""
    
    st.markdown("""
    <div class="ferpa-header">
        <h1>🔮 FERPA Compliance Dashboard</h1>
        <p>Snowflake Horizon - Education Data Governance</p>
    </div>
    """, unsafe_allow_html=True)
    
    kpis = get_dashboard_kpis()
    
    # KPI Row
    st.markdown("### 📊 District Overview")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        val = kpis['TOTAL_STUDENTS'].iloc[0] if not kpis.empty and 'TOTAL_STUDENTS' in kpis.columns else 0
        st.markdown(f"""
        <div class="metric-card success">
            <strong>Total Students</strong>
            <h2>{int(val):,}</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        val = kpis['TOTAL_SCHOOLS'].iloc[0] if not kpis.empty and 'TOTAL_SCHOOLS' in kpis.columns else 0
        st.markdown(f"""
        <div class="metric-card">
            <strong>Schools</strong>
            <h2>{int(val)}</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        val = kpis['ACTIVE_CONTRACTS'].iloc[0] if not kpis.empty and 'ACTIVE_CONTRACTS' in kpis.columns else 0
        st.markdown(f"""
        <div class="metric-card">
            <strong>Data Contracts</strong>
            <h2>{int(val)}</h2>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        val = kpis['OPEN_ALERTS'].iloc[0] if not kpis.empty and 'OPEN_ALERTS' in kpis.columns else 0
        stoplight = "green" if val == 0 else ("yellow" if val <= 3 else "red")
        card_class = "success" if stoplight == "green" else ("warning" if stoplight == "yellow" else "error")
        st.markdown(f"""
        <div class="metric-card {card_class}">
            <span class="stoplight {stoplight}"></span>
            <strong>Open Alerts</strong>
            <h2>{int(val)}</h2>
        </div>
        """, unsafe_allow_html=True)
    
    st.divider()
    
    # Charts Row
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 🏫 Enrollment by School Type")
        enrollment = get_enrollment_by_school_type()
        if not enrollment.empty:
            st.bar_chart(enrollment.set_index('SCHOOL_TYPE'))
        else:
            st.info("Loading enrollment data...")
    
    with col2:
        st.markdown("### 📋 Special Program Participation")
        programs = get_program_participation()
        if not programs.empty:
            program_data = pd.DataFrame({
                'Program': ['ELL', 'SPED', '504', 'Gifted', 'FRL'],
                'Count': [
                    programs['ELL_COUNT'].iloc[0],
                    programs['SPED_COUNT'].iloc[0],
                    programs['SECTION_504_COUNT'].iloc[0],
                    programs['GIFTED_COUNT'].iloc[0],
                    programs['FRL_COUNT'].iloc[0]
                ]
            })
            st.bar_chart(program_data.set_index('Program'))
        else:
            st.info("Loading program data...")
    
    st.divider()
    
    # Governance Info
    st.markdown("### 🛡️ FERPA Governance Tags Applied")
    
    st.markdown("""
    | Tag | Purpose | Coverage |
    |-----|---------|----------|
    | `FERPA_CATEGORY` | Classifies data as DIRECTORY, EDUCATIONAL_RECORD, or SENSITIVE | Student & Staff tables |
    | `PII_TYPE` | Identifies SSN, DOB, ADDRESS, NAME, CONTACT | All PII columns |
    | `DATA_CLASSIFICATION` | PUBLIC, CONFIDENTIAL, RESTRICTED levels | All tables |
    | `AI_ALLOWED` | Controls Cortex AI access to sensitive data | PII columns |
    """)
    
    st.divider()
    
    st.markdown("### 🔒 Role-Based Access Control")
    
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("""
        **Administrative Roles:**
        - `DISTRICT_ADMIN` - Full district access
        - `PRINCIPAL` - School-level access
        - `DATA_ADMIN` - System administration
        """)
    with col2:
        st.markdown("""
        **Operational Roles:**
        - `TEACHER` - Classroom students only
        - `COUNSELOR` - Assigned students
        - `PARENT_PORTAL` - Own children only
        """)

# ============================================================================
# SCHOOL ANALYTICS PAGE
# ============================================================================

def render_school_analytics():
    """Render school analytics page"""
    
    st.markdown("""
    <div class="main-header">
        <h1>📊 School Analytics</h1>
        <p>Capacity, performance, and staffing metrics</p>
    </div>
    """, unsafe_allow_html=True)
    
    session = get_session()
    
    try:
        schools_df = session.sql("""
            SELECT 
                SCHOOL_NAME,
                SCHOOL_TYPE,
                DISTRICT_NAME,
                BUILDING_CAPACITY,
                CURRENT_ENROLLMENT,
                CAPACITY_UTILIZATION_PCT,
                CAPACITY_STATUS,
                STUDENT_TEACHER_RATIO,
                ACCOUNTABILITY_RATING
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL
            ORDER BY CURRENT_ENROLLMENT DESC
            LIMIT 50
        """).to_pandas()
        
        if not schools_df.empty:
            st.dataframe(schools_df, use_container_width=True)
            
            st.divider()
            
            col1, col2 = st.columns(2)
            with col1:
                st.markdown("### Capacity Utilization")
                cap_data = schools_df[['SCHOOL_TYPE', 'CAPACITY_UTILIZATION_PCT']].groupby('SCHOOL_TYPE').mean()
                st.bar_chart(cap_data)
            
            with col2:
                st.markdown("### Student-Teacher Ratio")
                ratio_data = schools_df[['SCHOOL_TYPE', 'STUDENT_TEACHER_RATIO']].groupby('SCHOOL_TYPE').mean()
                st.bar_chart(ratio_data)
        else:
            st.info("No school data available")
            
    except Exception as e:
        st.error(f"Error loading school data: {str(e)}")

# ============================================================================
# STUDENT DATA PAGE
# ============================================================================

def render_student_data():
    """Render student data page with role-based access demo"""
    
    st.markdown("""
    <div class="main-header">
        <h1>👥 Student Data</h1>
        <p>Role-based access to student information (FERPA protected)</p>
    </div>
    """, unsafe_allow_html=True)
    
    session = get_session()
    
    # Show current role
    try:
        role_df = session.sql("SELECT CURRENT_ROLE() AS ROLE").to_pandas()
        current_role = role_df['ROLE'].iloc[0] if not role_df.empty else "Unknown"
        
        st.info(f"**Viewing as role:** `{current_role}` - Data visibility is controlled by Horizon policies")
        
    except:
        current_role = "Unknown"
    
    st.divider()
    
    try:
        # Show aggregate student data (safe for all roles)
        st.markdown("### 📈 Enrollment Summary by Grade")
        
        summary_df = session.sql("""
            SELECT 
                GRADE_LEVEL,
                COUNT(*) AS STUDENT_COUNT,
                SUM(CASE WHEN SPECIAL_EDUCATION THEN 1 ELSE 0 END) AS SPED_COUNT,
                SUM(CASE WHEN ELL_STATUS THEN 1 ELSE 0 END) AS ELL_COUNT
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
            WHERE ENROLLMENT_STATUS = 'Active'
            GROUP BY GRADE_LEVEL
            ORDER BY GRADE_LEVEL
        """).to_pandas()
        
        if not summary_df.empty:
            st.dataframe(summary_df, use_container_width=True)
        
        st.divider()
        
        # Show sample student records (masked based on role)
        st.markdown("### 👤 Sample Student Records")
        st.caption("PII fields are masked based on your role and Horizon masking policies")
        
        student_df = session.sql("""
            SELECT 
                STUDENT_ID,
                DISPLAY_NAME,
                GRADE_LEVEL,
                SCHOOL_NAME,
                ENROLLMENT_STATUS,
                AT_RISK_FLAG
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
            WHERE ENROLLMENT_STATUS = 'Active'
            LIMIT 10
        """).to_pandas()
        
        if not student_df.empty:
            st.dataframe(student_df, use_container_width=True)
            
    except Exception as e:
        st.error(f"Error loading student data: {str(e)}")

# ============================================================================
# ABOUT PAGE
# ============================================================================

def render_about():
    """Render about page"""
    
    st.markdown("""
    <div class="main-header">
        <h1>ℹ️ About This Demo</h1>
        <p>Massachusetts School District - Snowflake Horizon Demo</p>
    </div>
    """, unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        ### 🔮 Snowflake Horizon
        
        Education data governance with:
        
        - **FERPA Tagging** — FERPA_CATEGORY, PII_TYPE, AI_ALLOWED
        - **Dynamic Masking** — Role-based PII protection
        - **Row Access Policies** — Teacher/Parent/Principal filtering
        - **Audit Trail** — Complete access history
        """)
        
        st.markdown("""
        ### 🏗️ Data Architecture
        
        - **RAW Layer** — SCD Type 2 history tracking
        - **CURATED Layer** — Dynamic Tables with derived attributes
        - **SEMANTIC Layer** — Native Snowflake Semantic Views
        - **Data Contracts** — Quality rules and SLAs
        """)
    
    with col2:
        st.markdown("""
        ### 🤖 Snowflake Cortex
        
        AI for education analytics:
        
        - **Cortex Analyst** — Natural language queries
        - **Semantic Views** — Business-friendly metrics
        - **LLM Functions** — Summarization, translation
        """)
        
        st.markdown("""
        ### 📊 Sample Data
        
        - **100,000** Students (K-12)
        - **250** Schools
        - **25** Districts (Greater Boston)
        - **12,000** Staff members
        - **150,000** Guardians
        """)
    
    st.divider()
    
    st.markdown("""
    ### 🎯 FERPA Compliance
    
    > *"The Family Educational Rights and Privacy Act (FERPA) protects the privacy of student education records."*
    
    This demo implements FERPA controls through Snowflake Horizon governance tags and policies.
    """)

# ============================================================================
# MAIN APP
# ============================================================================

def main():
    """Main application entry point"""
    page = render_sidebar()
    
    if page == "🤖 Cortex Analyst":
        render_cortex_page()
    elif page == "🔮 FERPA Dashboard":
        render_ferpa_dashboard()
    elif page == "📊 School Analytics":
        render_school_analytics()
    elif page == "👥 Student Data":
        render_student_data()
    elif page == "ℹ️ About":
        render_about()

if __name__ == "__main__":
    main()
