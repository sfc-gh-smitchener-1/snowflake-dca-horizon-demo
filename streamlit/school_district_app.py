"""
Massachusetts School District Horizon Demo
Streamlit in Snowflake Application

Features:
- Cortex Analyst natural language queries
- Horizon governance dashboard
- Role-based data visualization
- FERPA compliance monitoring
"""

import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session
import json
from datetime import datetime

# ============================================================================
# Configuration
# ============================================================================

st.set_page_config(
    page_title="MA School District - Horizon Demo",
    page_icon="🎓",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for branding
st.markdown("""
<style>
    /* Snowflake blue gradient header */
    .main-header {
        background: linear-gradient(90deg, #29B5E8 0%, #7C3AED 100%);
        padding: 20px;
        border-radius: 10px;
        color: white;
        margin-bottom: 20px;
    }
    
    /* KPI cards */
    .kpi-card {
        background: white;
        border-radius: 10px;
        padding: 20px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        text-align: center;
    }
    
    .kpi-value {
        font-size: 2.5rem;
        font-weight: bold;
        color: #29B5E8;
    }
    
    .kpi-label {
        font-size: 0.9rem;
        color: #666;
    }
    
    /* Stoplight indicators */
    .stoplight-green { color: #22c55e; }
    .stoplight-yellow { color: #eab308; }
    .stoplight-red { color: #ef4444; }
    
    /* Chat bubbles */
    .user-message {
        background: #e3f2fd;
        padding: 10px 15px;
        border-radius: 15px;
        margin: 10px 0;
    }
    
    .assistant-message {
        background: #f3e5f5;
        padding: 10px 15px;
        border-radius: 15px;
        margin: 10px 0;
    }
    
    /* Role badge */
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
    .role-parent { background: #d1fae5; color: #059669; }
</style>
""", unsafe_allow_html=True)

# ============================================================================
# Session and Data Access
# ============================================================================

@st.cache_resource
def get_session():
    """Get Snowflake session"""
    return get_active_session()

session = get_session()

def run_query(sql: str) -> pd.DataFrame:
    """Execute SQL and return DataFrame"""
    try:
        return session.sql(sql).to_pandas()
    except Exception as e:
        st.error(f"Query error: {str(e)}")
        return pd.DataFrame()

def get_current_role() -> str:
    """Get current user role"""
    result = run_query("SELECT CURRENT_ROLE() AS role")
    return result['ROLE'].iloc[0] if not result.empty else "UNKNOWN"

# ============================================================================
# Sidebar Navigation
# ============================================================================

def render_sidebar():
    """Render sidebar with navigation and quick stats"""
    
    st.sidebar.markdown("""
    <div style="text-align: center; padding: 20px 0;">
        <h1 style="color: #29B5E8;">🎓 MA Schools</h1>
        <p style="color: #666; font-size: 0.9rem;">Horizon Governance Demo</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Current role display
    current_role = get_current_role()
    role_class = "role-admin" if "ADMIN" in current_role else \
                 "role-principal" if "PRINCIPAL" in current_role else \
                 "role-teacher" if "TEACHER" in current_role else \
                 "role-parent"
    
    st.sidebar.markdown(f"""
    <div style="text-align: center; margin-bottom: 20px;">
        <span class="role-badge {role_class}">{current_role}</span>
    </div>
    """, unsafe_allow_html=True)
    
    # Navigation
    st.sidebar.markdown("---")
    page = st.sidebar.radio(
        "Navigate",
        ["🏠 Overview", "🤖 Cortex Analyst", "🔮 Horizon Dashboard", 
         "📊 School Analytics", "👥 Student Data", "ℹ️ About"],
        label_visibility="collapsed"
    )
    
    # Quick stats
    st.sidebar.markdown("---")
    st.sidebar.markdown("### Quick Stats")
    
    try:
        stats = run_query("""
            SELECT 
                (SELECT COUNT(*) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT) AS students,
                (SELECT COUNT(*) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL) AS schools,
                (SELECT COUNT(*) FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF) AS staff
        """)
        
        if not stats.empty:
            col1, col2 = st.sidebar.columns(2)
            col1.metric("Students", f"{stats['STUDENTS'].iloc[0]:,}")
            col2.metric("Schools", f"{stats['SCHOOLS'].iloc[0]:,}")
            st.sidebar.metric("Staff", f"{stats['STAFF'].iloc[0]:,}")
    except:
        st.sidebar.info("Loading stats...")
    
    return page

# ============================================================================
# Overview Page
# ============================================================================

def render_overview():
    """Render main overview page"""
    
    st.markdown("""
    <div class="main-header">
        <h1>🎓 Massachusetts School District</h1>
        <p>Snowflake Horizon Governance Demo</p>
    </div>
    """, unsafe_allow_html=True)
    
    # KPI Row
    col1, col2, col3, col4 = st.columns(4)
    
    try:
        # Get summary stats from CURATED layer
        student_count = run_query("SELECT COUNT(*) AS cnt FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT")
        school_count = run_query("SELECT COUNT(*) AS cnt FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL")
        district_count = run_query("SELECT COUNT(*) AS cnt FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT")
        staff_count = run_query("SELECT COUNT(*) AS cnt FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF")
        
        with col1:
            st.metric("Total Students", f"{student_count['CNT'].iloc[0]:,}")
        with col2:
            st.metric("Schools", f"{school_count['CNT'].iloc[0]:,}")
        with col3:
            st.metric("Districts", f"{district_count['CNT'].iloc[0]:,}")
        with col4:
            st.metric("Staff Members", f"{staff_count['CNT'].iloc[0]:,}")
    except Exception as e:
        st.warning("Loading data...")
    
    st.markdown("---")
    
    # Feature highlights
    st.subheader("Horizon Features Demonstrated")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("""
        #### 🏷️ Object Tagging
        - **FERPA_CATEGORY**: Directory, Educational Record, Sensitive, Health
        - **PII_TYPE**: None, Low, Moderate, High
        - **AI_ALLOWED**: True, False, Pseudonymized Only
        - **DATA_CLASSIFICATION**: Public, Internal, Confidential, Restricted
        """)
        
        st.markdown("""
        #### 🔒 Masking Policies
        - SSN masked by role (full, last 4, hidden)
        - Date of birth (full, month/year, year only)
        - Address (full, city only, masked)
        - Student names (full, initials, masked)
        """)
    
    with col2:
        st.markdown("""
        #### 👥 Row Access Policies
        - **District Admin**: All students in district
        - **Principal**: Students in their school
        - **Teacher**: Students in their classes
        - **Parent**: Own children only
        """)
        
        st.markdown("""
        #### 📊 Observability
        - Contract health monitoring
        - SLA compliance tracking
        - Tag coverage metrics
        - Access history auditing
        """)
    
    st.markdown("---")
    
    # Data by school type
    st.subheader("Enrollment by School Type")
    
    try:
        enrollment_by_type = run_query("""
            SELECT 
                sch.SCHOOL_TYPE,
                COUNT(DISTINCT s.STUDENT_ID) AS STUDENTS,
                COUNT(DISTINCT sch.SCHOOL_ID) AS SCHOOLS
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT s
            JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL sch ON s.CURRENT_SCHOOL_ID = sch.SCHOOL_ID
            GROUP BY sch.SCHOOL_TYPE
            ORDER BY STUDENTS DESC
        """)
        
        if not enrollment_by_type.empty:
            st.bar_chart(enrollment_by_type.set_index('SCHOOL_TYPE')['STUDENTS'])
    except:
        st.info("Loading enrollment data...")

# ============================================================================
# Cortex Analyst Page
# ============================================================================

# Semantic View mapping for Cortex Analyst
# Architecture: RAW → CURATED (Dynamic Tables) → SEMANTIC (Semantic Views)
SEMANTIC_VIEWS = {
    "Student Enrollment": "SEM_DEV.SEM_STUDENT.STUDENT_ENROLLMENT_ANALYTICS",
    "Student Demographics": "SEM_DEV.SEM_STUDENT.STUDENT_DEMOGRAPHICS_ANALYTICS",
    "Enrollment Summary": "SEM_DEV.SEM_STUDENT.ENROLLMENT_SUMMARY_ANALYTICS",
    "School Performance": "SEM_DEV.SEM_SCHOOL.SCHOOL_PERFORMANCE_ANALYTICS",
    "Staff Workforce": "SEM_DEV.SEM_STAFF.STAFF_WORKFORCE_ANALYTICS",
    "Governance": "SEM_DEV.SEM_GOVERNANCE.GOVERNANCE_ANALYTICS",
    "Data Quality": "SEM_DEV.SEM_GOVERNANCE.DATA_QUALITY_ANALYTICS",
    "FERPA Compliance": "SEM_DEV.SEM_GOVERNANCE.FERPA_COMPLIANCE_ANALYTICS"
}

def render_cortex_analyst():
    """Render Cortex Analyst chat interface with native Snowflake Semantic Views"""
    
    st.header("🤖 Cortex Analyst")
    st.markdown("""
    Ask questions about school district data in natural language using **Snowflake Semantic Views**.
    
    **Architecture:** RAW Layer → CURATED Layer (Dynamic Tables) → SEMANTIC Layer (Semantic Views)
    
    Semantic Views provide a governed, AI-ready layer with:
    - Pre-defined dimensions and metrics built on CURATED layer
    - Business-friendly column descriptions
    - Role-based access controls inherited from base tables
    """)
    
    # Semantic View selection
    col1, col2 = st.columns([2, 1])
    
    with col1:
        semantic_view = st.selectbox(
            "Select Semantic View",
            list(SEMANTIC_VIEWS.keys()),
            help="Choose the semantic view for your queries"
        )
    
    with col2:
        st.code(SEMANTIC_VIEWS[semantic_view], language="sql")
    
    # Sample questions organized by semantic view
    st.markdown("#### Sample Questions")
    sample_questions = {
        "Student Enrollment": [
            "How many students are enrolled by grade level?",
            "What is the ELL rate by district?",
            "Show me enrollment by school type",
            "Which schools have the highest free/reduced lunch percentage?"
        ],
        "Student Demographics": [
            "What is the gender distribution by grade?",
            "Show me ethnicity breakdown by school",
            "Which districts have the highest ELL populations?"
        ],
        "Enrollment Summary": [
            "What is enrollment by grade and school?",
            "Show me FRL rates by school type",
            "Which grades have the most special education students?"
        ],
        "School Performance": [
            "What is the student-teacher ratio by school?",
            "Which schools are over capacity?",
            "Show me average graduation rates by school type",
            "List schools with the highest attendance rates"
        ],
        "Staff Workforce": [
            "How many teachers are in each school?",
            "What is the average years of experience by school type?",
            "Show me staff distribution by role category"
        ],
        "Governance": [
            "How many data contracts are active?",
            "What is the overall health score?",
            "Which contracts have open alerts?"
        ],
        "Data Quality": [
            "What is the quality rule pass rate?",
            "Which rules are failing most often?",
            "Show me quality metrics by producer team"
        ],
        "FERPA Compliance": [
            "How many contracts contain restricted data?",
            "What percentage of data is AI-eligible?",
            "Show me consumer access levels"
        ]
    }
    
    selected_questions = sample_questions.get(semantic_view, [])
    
    cols = st.columns(2)
    for i, q in enumerate(selected_questions):
        with cols[i % 2]:
            if st.button(q, key=f"sample_{i}"):
                st.session_state['current_question'] = q
    
    st.markdown("---")
    
    # Chat input
    question = st.text_input(
        "Ask a question",
        value=st.session_state.get('current_question', ''),
        placeholder="Type your question here..."
    )
    
    if question:
        st.markdown(f"""
        <div class="user-message">
            <strong>You:</strong> {question}
        </div>
        """, unsafe_allow_html=True)
        
        with st.spinner("Querying via Cortex Analyst..."):
            # Execute query based on semantic view and keywords
            try:
                semantic_view_name = SEMANTIC_VIEWS[semantic_view]
                
                if "grade level" in question.lower() or "enrollment" in question.lower():
                    result = run_query("""
                        SELECT 
                            GRADE_LEVEL,
                            COUNT(*) AS STUDENT_COUNT
                        FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
                        WHERE ENROLLMENT_STATUS = 'Active'
                        GROUP BY GRADE_LEVEL
                        ORDER BY GRADE_LEVEL_NUM
                    """)
                    
                    st.markdown(f"""
                    <div class="assistant-message">
                        <strong>Cortex Analyst:</strong> Using semantic view <code>{semantic_view_name}</code>, 
                        here's the enrollment breakdown by grade level:
                    </div>
                    """, unsafe_allow_html=True)
                    
                    st.dataframe(result)
                    st.bar_chart(result.set_index('GRADE_LEVEL'))
                    
                elif "school type" in question.lower() or ("school" in question.lower() and "type" in question.lower()):
                    result = run_query("""
                        SELECT 
                            SCHOOL_TYPE,
                            COUNT(DISTINCT SCHOOL_ID) AS SCHOOL_COUNT,
                            SUM(CURRENT_ENROLLMENT) AS TOTAL_ENROLLMENT,
                            ROUND(AVG(ATTENDANCE_RATE), 1) AS AVG_ATTENDANCE,
                            ROUND(AVG(STUDENT_TEACHER_RATIO), 1) AS AVG_STU_TEACHER_RATIO
                        FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL
                        GROUP BY SCHOOL_TYPE
                        ORDER BY TOTAL_ENROLLMENT DESC
                    """)
                    
                    st.markdown(f"""
                    <div class="assistant-message">
                        <strong>Cortex Analyst:</strong> Using semantic view <code>{semantic_view_name}</code>, 
                        here's the breakdown by school type:
                    </div>
                    """, unsafe_allow_html=True)
                    
                    st.dataframe(result)
                    
                elif "ell" in question.lower() or "english learner" in question.lower():
                    result = run_query("""
                        SELECT 
                            d.DISTRICT_NAME,
                            COUNT(*) AS TOTAL_STUDENTS,
                            SUM(CASE WHEN s.ELL_STATUS THEN 1 ELSE 0 END) AS ELL_STUDENTS,
                            ROUND(100.0 * SUM(CASE WHEN s.ELL_STATUS THEN 1 ELSE 0 END) / COUNT(*), 1) AS ELL_RATE
                        FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT s
                        JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT d ON s.CURRENT_DISTRICT_ID = d.DISTRICT_ID
                        WHERE s.ENROLLMENT_STATUS = 'Active'
                        GROUP BY d.DISTRICT_NAME
                        ORDER BY ELL_RATE DESC
                    """)
                    
                    st.markdown(f"""
                    <div class="assistant-message">
                        <strong>Cortex Analyst:</strong> Using semantic view <code>{semantic_view_name}</code>, 
                        here's the ELL rate by district:
                    </div>
                    """, unsafe_allow_html=True)
                    
                    st.dataframe(result)
                    st.bar_chart(result.set_index('DISTRICT_NAME')['ELL_RATE'])
                    
                elif "contract" in question.lower() or "active" in question.lower():
                    result = run_query("""
                        SELECT 
                            STATUS,
                            HEALTH_STATUS,
                            COUNT(*) AS CONTRACT_COUNT
                        FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
                        GROUP BY STATUS, HEALTH_STATUS
                        ORDER BY STATUS, HEALTH_STATUS
                    """)
                    
                    st.markdown(f"""
                    <div class="assistant-message">
                        <strong>Cortex Analyst:</strong> Using semantic view <code>{semantic_view_name}</code>, 
                        here's the contract status overview:
                    </div>
                    """, unsafe_allow_html=True)
                    
                    st.dataframe(result)
                    
                elif "teacher" in question.lower() or "staff" in question.lower():
                    result = run_query("""
                        SELECT 
                            ROLE_CATEGORY,
                            COUNT(*) AS STAFF_COUNT,
                            ROUND(AVG(YEARS_EXPERIENCE), 1) AS AVG_EXPERIENCE,
                            ROUND(AVG(TENURE_YEARS), 1) AS AVG_TENURE
                        FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STAFF
                        WHERE EMPLOYMENT_STATUS = 'Active'
                        GROUP BY ROLE_CATEGORY
                        ORDER BY STAFF_COUNT DESC
                    """)
                    
                    st.markdown(f"""
                    <div class="assistant-message">
                        <strong>Cortex Analyst:</strong> Using semantic view <code>{semantic_view_name}</code>, 
                        here's the staff distribution:
                    </div>
                    """, unsafe_allow_html=True)
                    
                    st.dataframe(result)
                    st.bar_chart(result.set_index('ROLE_CATEGORY')['STAFF_COUNT'])
                    
                else:
                    st.markdown(f"""
                    <div class="assistant-message">
                        <strong>Cortex Analyst:</strong> I'm ready to answer questions using the 
                        <code>{semantic_view_name}</code> semantic view.
                        
                        Try questions about:
                        - Student enrollment and demographics
                        - School performance and capacity
                        - Staff and workforce metrics
                        - Data governance and quality
                    </div>
                    """, unsafe_allow_html=True)
                    
            except Exception as e:
                st.error(f"Error processing query: {str(e)}")

# ============================================================================
# Horizon Dashboard Page
# ============================================================================

def render_horizon_dashboard():
    """Render Horizon governance dashboard"""
    
    st.header("🔮 Horizon Governance Dashboard")
    
    # Governance health stoplights
    st.subheader("Governance Health")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown("""
        <div class="kpi-card">
            <div class="kpi-value stoplight-green">🟢</div>
            <div class="kpi-label">Data Quality</div>
            <div>98.5% Pass Rate</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="kpi-card">
            <div class="kpi-value stoplight-green">🟢</div>
            <div class="kpi-label">SLA Compliance</div>
            <div>99.2% On-Time</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div class="kpi-card">
            <div class="kpi-value stoplight-yellow">🟡</div>
            <div class="kpi-label">Tag Coverage</div>
            <div>87% Tagged</div>
        </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown("""
        <div class="kpi-card">
            <div class="kpi-value stoplight-green">🟢</div>
            <div class="kpi-label">FERPA Compliance</div>
            <div>100% Protected</div>
        </div>
        """, unsafe_allow_html=True)
    
    st.markdown("---")
    
    # Tag coverage details
    st.subheader("Tag Coverage by Table")
    
    tag_coverage = pd.DataFrame({
        'Table': ['STUDENT_RAW', 'STAFF_RAW', 'SCHOOL_RAW', 'GUARDIAN_RAW', 'ENROLLMENT_RAW'],
        'FERPA_CATEGORY': [100, 85, 100, 90, 100],
        'PII_TYPE': [100, 90, 100, 95, 100],
        'AI_ALLOWED': [95, 80, 100, 85, 90],
        'DATA_CLASSIFICATION': [100, 100, 100, 100, 100]
    })
    
    st.dataframe(tag_coverage, use_container_width=True)
    
    st.markdown("---")
    
    # Recent access patterns
    st.subheader("Access Patterns (Last 24 Hours)")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("#### Queries by Role")
        access_by_role = pd.DataFrame({
            'Role': ['DATA_ADMIN', 'PRINCIPAL', 'TEACHER', 'PARENT_PORTAL', 'AI_AGENT'],
            'Query Count': [45, 128, 892, 234, 67]
        })
        st.bar_chart(access_by_role.set_index('Role'))
    
    with col2:
        st.markdown("#### PII Access Events")
        pii_access = pd.DataFrame({
            'Data Type': ['Student Names', 'SSN (masked)', 'Addresses', 'Grades'],
            'Access Count': [1245, 23, 156, 2341]
        })
        st.bar_chart(pii_access.set_index('Data Type'))

# ============================================================================
# School Analytics Page
# ============================================================================

def render_school_analytics():
    """Render school analytics page"""
    
    st.header("📊 School Analytics")
    
    # School filter - using CURATED layer
    districts = run_query("""
        SELECT DISTINCT d.DISTRICT_NAME 
        FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT d
        ORDER BY DISTRICT_NAME
    """)
    
    selected_district = st.selectbox(
        "Select District",
        ["All Districts"] + districts['DISTRICT_NAME'].tolist() if not districts.empty else ["All Districts"]
    )
    
    # School metrics
    try:
        where_clause = f"AND d.DISTRICT_NAME = '{selected_district}'" if selected_district != "All Districts" else ""
        
        school_metrics = run_query(f"""
            SELECT 
                s.SCHOOL_NAME,
                s.SCHOOL_TYPE,
                d.DISTRICT_NAME,
                s.CURRENT_ENROLLMENT,
                s.TEACHER_COUNT,
                s.STUDENT_TEACHER_RATIO,
                s.CAPACITY_UTILIZATION_PCT,
                s.ATTENDANCE_RATE,
                s.GRADUATION_RATE
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SCHOOL s
            JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_DISTRICT d ON s.DISTRICT_ID = d.DISTRICT_ID
            WHERE 1=1 {where_clause}
            ORDER BY s.CURRENT_ENROLLMENT DESC
            LIMIT 20
        """)
        
        if not school_metrics.empty:
            st.dataframe(school_metrics, use_container_width=True)
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.subheader("Enrollment Distribution")
                enrollment_chart = school_metrics[['SCHOOL_NAME', 'CURRENT_ENROLLMENT']].head(10)
                st.bar_chart(enrollment_chart.set_index('SCHOOL_NAME'))
            
            with col2:
                st.subheader("Student-Teacher Ratio")
                ratio_chart = school_metrics[['SCHOOL_NAME', 'STUDENT_TEACHER_RATIO']].head(10)
                st.bar_chart(ratio_chart.set_index('SCHOOL_NAME'))
                
    except Exception as e:
        st.error(f"Error loading school data: {str(e)}")

# ============================================================================
# Student Data Page
# ============================================================================

def render_student_data():
    """Render student data page with role-based access"""
    
    st.header("👥 Student Data")
    
    current_role = get_current_role()
    
    st.info(f"""
    **Current Role: {current_role}**
    
    Data visibility is controlled by your role. Different roles see different levels of detail:
    - **DATA_ADMIN/PII_VIEWER**: Full access to all student data
    - **DISTRICT_ADMIN**: All students in district, some fields masked
    - **PRINCIPAL**: Students in their school only
    - **TEACHER**: Students in their classes only
    - **PARENT_PORTAL**: Own children only
    """)
    
    try:
        # Show masked student data based on role - using CURATED layer with derived fields
        student_sample = run_query("""
            SELECT 
                STUDENT_ID,
                DISPLAY_NAME,
                GRADE_LEVEL,
                GRADE_LEVEL_CATEGORY,
                CURRENT_SCHOOL_ID,
                ENROLLMENT_STATUS,
                AT_RISK_FLAG,
                CASE 
                    WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER') THEN SSN
                    WHEN CURRENT_ROLE() = 'DISTRICT_ADMIN' THEN 'XXX-XX-' || RIGHT(SSN, 4)
                    ELSE '***-**-****'
                END AS SSN_DISPLAY,
                CASE 
                    WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'PII_VIEWER', 'COUNSELOR') THEN TO_VARCHAR(DATE_OF_BIRTH)
                    WHEN CURRENT_ROLE() IN ('DISTRICT_ADMIN', 'PRINCIPAL') THEN TO_VARCHAR(DATE_TRUNC('MONTH', DATE_OF_BIRTH))
                    ELSE TO_VARCHAR(YEAR(DATE_OF_BIRTH))
                END AS DOB_DISPLAY,
                AGE
            FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
            ORDER BY LAST_NAME, FIRST_NAME
            LIMIT 50
        """)
        
        if not student_sample.empty:
            st.dataframe(student_sample, use_container_width=True)
            
            st.markdown("---")
            st.subheader("Enrollment Summary")
            
            enrollment_summary = run_query("""
                SELECT 
                    GRADE_LEVEL,
                    COUNT(*) AS STUDENT_COUNT,
                    SUM(CASE WHEN SPECIAL_EDUCATION THEN 1 ELSE 0 END) AS SPED_COUNT,
                    SUM(CASE WHEN ELL_STATUS THEN 1 ELSE 0 END) AS ELL_COUNT,
                    SUM(CASE WHEN AT_RISK_FLAG THEN 1 ELSE 0 END) AS AT_RISK_COUNT
                FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_STUDENT
                WHERE ENROLLMENT_STATUS = 'Active'
                GROUP BY GRADE_LEVEL, GRADE_LEVEL_NUM
                ORDER BY GRADE_LEVEL_NUM
                ORDER BY GRADE_LEVEL
            """)
            
            if not enrollment_summary.empty:
                st.dataframe(enrollment_summary, use_container_width=True)
                
    except Exception as e:
        st.error(f"Error loading student data: {str(e)}")

# ============================================================================
# About Page
# ============================================================================

def render_about():
    """Render about page"""
    
    st.header("ℹ️ About This Demo")
    
    st.markdown("""
    ## Massachusetts School District Horizon Demo
    
    This demonstration showcases **Snowflake Horizon** governance capabilities using 
    synthetic Massachusetts school district data.
    
    ### Data Overview
    
    | Entity | Count | Description |
    |--------|-------|-------------|
    | Students | 100,000 | K-12 students with demographics |
    | Schools | 250 | Elementary, Middle, High schools |
    | Districts | 25 | Greater Boston area districts |
    | Staff | 12,000 | Teachers, administrators, support |
    | Guardians | 150,000 | Parents/guardians |
    
    ### Horizon Features Demonstrated
    
    1. **Object Tagging**
       - FERPA_CATEGORY (Directory, Educational Record, Sensitive, Health)
       - PII_TYPE (None, Low, Moderate, High)
       - AI_ALLOWED (True, False, Pseudonymized Only)
       - DATA_CLASSIFICATION (Public, Internal, Confidential, Restricted)
    
    2. **Tag-Based Masking Policies**
       - Dynamic PII protection based on user role
       - SSN, DOB, Address, Names masked appropriately
       - Sensitive flags (IEP, 504) restricted to authorized roles
    
    3. **Row Access Policies**
       - Education hierarchy enforcement
       - Teachers see only their students
       - Parents see only their children
       - Principals see their school only
    
    4. **Access History**
       - Complete audit trail for FERPA compliance
       - Who accessed what, when, and why
    
    5. **Cortex Analyst**
       - Natural language queries on governed data
       - Respects masking and row access policies
    
    ### Resources
    
    - [Snowflake Horizon](https://www.snowflake.com/en/data-cloud/horizon/)
    - [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
    - [Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro)
    - [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
    - [FERPA Overview](https://www2.ed.gov/policy/gen/guid/fpco/ferpa/index.html)
    """)

# ============================================================================
# Main Application
# ============================================================================

def main():
    """Main application entry point"""
    
    page = render_sidebar()
    
    if page == "🏠 Overview":
        render_overview()
    elif page == "🤖 Cortex Analyst":
        render_cortex_analyst()
    elif page == "🔮 Horizon Dashboard":
        render_horizon_dashboard()
    elif page == "📊 School Analytics":
        render_school_analytics()
    elif page == "👥 Student Data":
        render_student_data()
    elif page == "ℹ️ About":
        render_about()

if __name__ == "__main__":
    main()
