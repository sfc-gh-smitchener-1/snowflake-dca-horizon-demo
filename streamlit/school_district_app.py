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
    """
    Calls the Cortex Analyst API for natural language to SQL on semantic views.
    Uses the internal REST client available in Streamlit in Snowflake.
    """
    session = get_session()
    
    # Method 1: Try internal REST client (works in Streamlit in Snowflake)
    try:
        rest_client = session._conn._rest
        
        request_body = {
            "messages": [
                {
                    "role": "user", 
                    "content": [{"type": "text", "text": prompt}]
                }
            ],
            "semantic_model": semantic_view
        }
        
        response = rest_client.request(
            url="/api/v2/cortex/analyst/message",
            method="post",
            body=request_body,
            headers={"Content-Type": "application/json"}
        )
        
        if response and isinstance(response, dict):
            if 'message' in response:
                return response, None
            else:
                return {"message": {"content": [{"type": "text", "text": str(response)}]}}, None
        else:
            return None, "Cortex Analyst returned an empty response. Please try a different question."
            
    except AttributeError:
        # REST client not available - try _call_rest method
        pass
    except Exception as e:
        error_str = str(e).lower()
        if "404" in str(e) or "not found" in error_str:
            return None, f"Semantic view '{semantic_view}' not found. Run: SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV;"
        elif "401" in str(e) or "unauthorized" in error_str:
            return None, "Authentication failed. Please refresh the application."
        elif "403" in str(e) or "forbidden" in error_str or "permission" in error_str:
            return None, f"Permission denied. Ensure your role can access '{semantic_view}'."
        # Continue to try other methods
    
    # Method 2: Try using _call_rest if available
    try:
        if hasattr(session._conn, '_call_rest'):
            response = session._conn._call_rest(
                method="post",
                path="/api/v2/cortex/analyst/message",
                body={
                    "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
                    "semantic_model": semantic_view
                }
            )
            if response and 'message' in response:
                return response, None
    except:
        pass
    
    # Method 3: Check if semantic views exist and provide guidance
    try:
        sv_check = session.sql(f"SHOW SEMANTIC VIEWS LIKE '%' IN DATABASE SEM_DEV").to_pandas()
        if sv_check.empty:
            return None, """No semantic views found in SEM_DEV database.

Please run the semantic layer setup:
1. Execute sql/06_semantic_layer.sql to create semantic views
2. Then refresh this application"""
        
        # Semantic views exist but API isn't working
        return None, f"""Cortex Analyst API connection failed.

The semantic view exists but the API could not be reached. This may be because:
1. Cortex Analyst is not enabled for your account region
2. The REST client is not available in this Streamlit environment

Try running this test in a Snowflake worksheet:
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'test');

If that works but Analyst doesn't, contact Snowflake support about enabling Cortex Analyst."""
        
    except Exception as e:
        return None, f"""Could not connect to Cortex Analyst.

Error: {str(e)}

Please verify:
1. Semantic views exist: SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV;
2. Cortex is enabled: ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
3. Role has access: GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <your_role>;"""

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

def get_available_roles():
    """Get list of education roles available for switching"""
    return [
        ("DATA_ADMIN", "🔧 Data Admin", "Full system access - sees all data unmasked"),
        ("DISTRICT_ADMIN", "🏛️ District Admin", "District-wide access - sees all schools"),
        ("PRINCIPAL", "🎓 Principal", "School-level access - sees their school only"),
        ("TEACHER", "👨‍🏫 Teacher", "Classroom access - sees their students only"),
        ("COUNSELOR", "💬 Counselor", "Student services - sees assigned students"),
        ("REGISTRAR", "📋 Registrar", "Enrollment data - limited PII access"),
        ("PARENT_PORTAL", "👨‍👩‍👧 Parent", "Portal access - sees own children only"),
        ("AI_AGENT", "🤖 AI Agent", "Analytics access - no PII, aggregates only"),
    ]

def switch_role(role_name: str) -> bool:
    """Attempt to switch to a different role"""
    session = get_session()
    try:
        session.sql(f"USE ROLE {role_name}").collect()
        return True
    except Exception as e:
        return False

def get_current_role() -> str:
    """Get the current active role"""
    session = get_session()
    try:
        role_df = session.sql("SELECT CURRENT_ROLE() AS ROLE").to_pandas()
        return role_df['ROLE'].iloc[0] if not role_df.empty else "Unknown"
    except:
        return "Unknown"

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
        
        # =================================================================
        # ROLE SWITCHER - Demonstrates RBAC/ABAC
        # =================================================================
        st.markdown("### 🔐 Role Switcher")
        st.caption("Switch roles to see RBAC/ABAC in action")
        
        available_roles = get_available_roles()
        current_role = get_current_role()
        
        # Create role options for dropdown
        role_options = [f"{r[1]}" for r in available_roles]
        role_names = [r[0] for r in available_roles]
        role_descriptions = {r[0]: r[2] for r in available_roles}
        
        # Find current role index
        try:
            current_idx = role_names.index(current_role)
        except ValueError:
            current_idx = 0
        
        # Role selector dropdown
        selected_role_display = st.selectbox(
            "Select Role",
            role_options,
            index=current_idx,
            key="role_selector",
            label_visibility="collapsed"
        )
        
        # Get the role name from the display value
        selected_idx = role_options.index(selected_role_display)
        selected_role = role_names[selected_idx]
        
        # Show role description
        st.markdown(f"""
        <div style="background: rgba(41, 181, 232, 0.2); padding: 8px 12px; border-radius: 8px; margin: 8px 0;">
            <small style="color: #E3F5FC;">{role_descriptions.get(selected_role, '')}</small>
        </div>
        """, unsafe_allow_html=True)
        
        # Switch role button
        if selected_role != current_role:
            if st.button("🔄 Switch Role", use_container_width=True, key="switch_role_btn"):
                if switch_role(selected_role):
                    st.success(f"Switched to {selected_role}")
                    st.cache_data.clear()
                    st.experimental_rerun()
                else:
                    st.error(f"Cannot switch to {selected_role}. Role may not be granted.")
        else:
            st.markdown(f"""
            <div style="text-align: center; padding: 5px;">
                <span style="color: #18794E;">✓ Active</span>
            </div>
            """, unsafe_allow_html=True)
        
        st.divider()
        
        # Navigation
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
                s.SCHOOL_NAME,
                s.SCHOOL_TYPE,
                d.DISTRICT_NAME,
                s.BUILDING_CAPACITY,
                s.CURRENT_ENROLLMENT,
                s.CAPACITY_UTILIZATION_PCT,
                s.CAPACITY_STATUS,
                s.STUDENT_TEACHER_RATIO,
                s.ACCOUNTABILITY_RATING
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL s
            LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT d ON s.DISTRICT_ID = d.DISTRICT_ID
            ORDER BY s.CURRENT_ENROLLMENT DESC
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

def get_role_access_info(role: str) -> dict:
    """Get information about what each role can see"""
    role_info = {
        "DATA_ADMIN": {
            "icon": "🔧",
            "color": "#CD2B31",
            "access": "FULL ACCESS",
            "description": "Sees all data unmasked including SSN, addresses, and sensitive records",
            "pii_visible": True,
            "all_students": True
        },
        "DISTRICT_ADMIN": {
            "icon": "🏛️",
            "color": "#6E56CF",
            "access": "DISTRICT WIDE",
            "description": "Sees all students in district, SSN masked, addresses visible",
            "pii_visible": "Partial",
            "all_students": True
        },
        "PRINCIPAL": {
            "icon": "🎓",
            "color": "#AD5700",
            "access": "SCHOOL ONLY",
            "description": "Sees students in their school only, limited PII",
            "pii_visible": "Limited",
            "all_students": False
        },
        "TEACHER": {
            "icon": "👨‍🏫",
            "color": "#29B5E8",
            "access": "CLASSROOM ONLY",
            "description": "Sees only assigned students, minimal PII",
            "pii_visible": False,
            "all_students": False
        },
        "COUNSELOR": {
            "icon": "💬",
            "color": "#18794E",
            "access": "ASSIGNED STUDENTS",
            "description": "Sees assigned students with some sensitive data access",
            "pii_visible": "Partial",
            "all_students": False
        },
        "PARENT_PORTAL": {
            "icon": "👨‍👩‍👧",
            "color": "#E3F5FC",
            "access": "OWN CHILDREN",
            "description": "Sees only their own children's records",
            "pii_visible": False,
            "all_students": False
        },
        "AI_AGENT": {
            "icon": "🤖",
            "color": "#64748B",
            "access": "AGGREGATES ONLY",
            "description": "No individual student data, only anonymized aggregates",
            "pii_visible": False,
            "all_students": False
        }
    }
    return role_info.get(role, {
        "icon": "👤",
        "color": "#64748B",
        "access": "UNKNOWN",
        "description": "Role access level unknown",
        "pii_visible": False,
        "all_students": False
    })

def render_student_data():
    """Render student data page with role-based access demo"""
    
    st.markdown("""
    <div class="main-header">
        <h1>👥 Student Data</h1>
        <p>Role-based access to student information (FERPA protected)</p>
    </div>
    """, unsafe_allow_html=True)
    
    session = get_session()
    current_role = get_current_role()
    role_info = get_role_access_info(current_role)
    
    # =================================================================
    # ROLE ACCESS INDICATOR
    # =================================================================
    st.markdown(f"""
    <div style="background: linear-gradient(135deg, {role_info['color']}22 0%, {role_info['color']}11 100%); 
                border-left: 4px solid {role_info['color']}; 
                padding: 1rem 1.5rem; 
                border-radius: 8px; 
                margin-bottom: 1.5rem;">
        <div style="display: flex; align-items: center; gap: 12px;">
            <span style="font-size: 2rem;">{role_info['icon']}</span>
            <div>
                <div style="font-weight: 700; font-size: 1.1rem; color: {role_info['color']};">
                    {current_role} - {role_info['access']}
                </div>
                <div style="color: #64748B; font-size: 0.9rem;">
                    {role_info['description']}
                </div>
            </div>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    # Access comparison table
    with st.expander("📋 View Role Access Comparison", expanded=False):
        st.markdown("""
        | Role | Student Scope | Name | SSN | Address | Grades | Health/IEP |
        |------|--------------|------|-----|---------|--------|------------|
        | 🔧 DATA_ADMIN | All | ✓ Full | ✓ Full | ✓ Full | ✓ Full | ✓ Full |
        | 🏛️ DISTRICT_ADMIN | District | ✓ Full | Last 4 | ✓ Full | ✓ Full | Summary |
        | 🎓 PRINCIPAL | School | ✓ Full | ✗ Masked | ✓ Full | ✓ Full | Summary |
        | 👨‍🏫 TEACHER | Classroom | ✓ Full | ✗ Masked | ✗ Masked | Own Class | ✗ Masked |
        | 💬 COUNSELOR | Assigned | ✓ Full | ✗ Masked | ✓ Full | ✓ Full | ✓ Full |
        | 👨‍👩‍👧 PARENT | Own Child | Own Child | ✗ Masked | Own Only | Own Child | Own Child |
        | 🤖 AI_AGENT | Aggregates | ✗ Hash | ✗ Masked | ✗ Masked | Aggregate | ✗ Masked |
        """)
    
    st.divider()
    
    try:
        # =================================================================
        # AGGREGATE DATA (Safe for all roles)
        # =================================================================
        st.markdown("### 📈 Enrollment Summary by Grade")
        st.caption("Aggregate data is visible to all roles")
        
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
        
        # =================================================================
        # PII DATA (Varies by role)
        # =================================================================
        st.markdown("### 👤 Student Records with PII Fields")
        st.caption("⚠️ PII fields are masked/filtered based on your current role. Switch roles in the sidebar to see the difference.")
        
        # Different query based on role capabilities
        # In production, the masking policies handle this automatically
        # Here we show different columns to demonstrate what each role sees
        
        if current_role in ['DATA_ADMIN', 'PII_VIEWER']:
            # Full PII access
            student_df = session.sql("""
                SELECT 
                    st.STUDENT_ID,
                    st.FIRST_NAME,
                    st.LAST_NAME,
                    st.SSN,
                    st.DATE_OF_BIRTH,
                    st.HOME_ADDRESS_LINE1,
                    st.CITY,
                    st.GRADE_LEVEL,
                    s.SCHOOL_NAME,
                    st.SPECIAL_EDUCATION,
                    st.AT_RISK_FLAG
                FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT st
                LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL s ON st.CURRENT_SCHOOL_ID = s.SCHOOL_ID
                WHERE st.ENROLLMENT_STATUS = 'Active'
                LIMIT 15
            """).to_pandas()
            st.success("🔓 Full PII Access - All fields visible (SSN, DOB, Address)")
            
        elif current_role in ['DISTRICT_ADMIN', 'PRINCIPAL', 'COUNSELOR']:
            # Partial PII access
            student_df = session.sql("""
                SELECT 
                    st.STUDENT_ID,
                    st.DISPLAY_NAME,
                    st.GRADE_LEVEL,
                    st.GRADE_LEVEL_CATEGORY,
                    s.SCHOOL_NAME,
                    st.CITY,
                    st.ETHNICITY,
                    st.ELL_STATUS,
                    st.SPECIAL_EDUCATION,
                    st.AT_RISK_FLAG
                FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT st
                LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL s ON st.CURRENT_SCHOOL_ID = s.SCHOOL_ID
                WHERE st.ENROLLMENT_STATUS = 'Active'
                LIMIT 15
            """).to_pandas()
            st.warning("🔒 Partial PII Access - SSN masked, limited address info")
            
        elif current_role == 'AI_AGENT':
            # No individual student data
            student_df = session.sql("""
                SELECT 
                    st.STUDENT_ID_HASH AS STUDENT_ID_ANONYMIZED,
                    st.GRADE_LEVEL_CATEGORY,
                    st.ETHNICITY,
                    st.ELL_STATUS,
                    st.FREE_REDUCED_LUNCH,
                    st.AT_RISK_FLAG
                FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT st
                WHERE st.ENROLLMENT_STATUS = 'Active'
                LIMIT 15
            """).to_pandas()
            st.info("🤖 AI Access - Pseudonymized IDs, no names or addresses")
            
        else:
            # Minimal access (Teacher, Parent, etc.)
            student_df = session.sql("""
                SELECT 
                    st.STUDENT_ID,
                    st.DISPLAY_NAME,
                    st.GRADE_LEVEL,
                    s.SCHOOL_NAME,
                    st.ENROLLMENT_STATUS
                FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT st
                LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL s ON st.CURRENT_SCHOOL_ID = s.SCHOOL_ID
                WHERE st.ENROLLMENT_STATUS = 'Active'
                LIMIT 15
            """).to_pandas()
            st.error("🔐 Restricted Access - Minimal data visible, PII hidden")
        
        if not student_df.empty:
            st.dataframe(student_df, use_container_width=True)
        else:
            st.warning("No student records visible for this role")
        
        # =================================================================
        # ROW COUNT COMPARISON
        # =================================================================
        st.divider()
        st.markdown("### 📊 Data Visibility Metrics")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            try:
                count_df = session.sql("""
                    SELECT COUNT(*) AS CNT FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT 
                    WHERE ENROLLMENT_STATUS = 'Active'
                """).to_pandas()
                visible_count = count_df['CNT'].iloc[0] if not count_df.empty else 0
                st.metric("Students Visible", f"{int(visible_count):,}")
            except:
                st.metric("Students Visible", "N/A")
        
        with col2:
            pii_status = "Full" if current_role in ['DATA_ADMIN', 'PII_VIEWER'] else (
                "Partial" if current_role in ['DISTRICT_ADMIN', 'PRINCIPAL', 'COUNSELOR'] else "Masked"
            )
            st.metric("PII Access Level", pii_status)
        
        with col3:
            scope = "All" if current_role in ['DATA_ADMIN', 'DISTRICT_ADMIN'] else (
                "School" if current_role == 'PRINCIPAL' else "Limited"
            )
            st.metric("Geographic Scope", scope)
            
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
