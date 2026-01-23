# Snowflake School District Horizon Demo

> A comprehensive demonstration of **Snowflake Horizon** governance, privacy, and observability capabilities using synthetic Massachusetts school district data with 100,000 students across 250 schools in the Greater Boston area.

## Snowflake Horizon Governance

This demo showcases the full capabilities of **[Snowflake Horizon](https://www.snowflake.com/en/data-cloud/horizon/)** unified governance for sensitive education data:

| Horizon Capability | Implementation in This Demo |
|-------------------|----------------------------|
| **Object Tagging** | `FERPA_CATEGORY`, `DATA_CLASSIFICATION`, `PII_TYPE`, `AI_ALLOWED` tags |
| **Tag-Based Masking Policies** | Dynamic masking of student PII based on role and need |
| **Row Access Policies** | Teachers see only their students, principals see their school |
| **Data Classification** | Automatic FERPA and PII sensitivity labeling |
| **Access History** | Full audit trail for FERPA compliance |
| **Dynamic Tables** | Automated data pipelines with freshness guarantees |
| **Semantic Views** | Native Snowflake Semantic Views for Cortex Analyst |
| **SCD Type 2 Loading** | Historical tracking with MERGE-based data loading |
| **Role-Based Access Control** | Education hierarchy: District → School → Classroom |

## Demo Overview

This demo implements a **synthetic Massachusetts school district** modeled after real Greater Boston area school systems:

### Data Scale

| Entity | Count | Description |
|--------|-------|-------------|
| **Students** | 100,000 | K-12 students with demographics, enrollment, performance |
| **Schools** | 250 | Elementary, Middle, High Schools across counties |
| **Districts** | 25 | School districts in Greater Boston area |
| **Staff** | 12,000 | Teachers, administrators, support staff |
| **Guardians** | 150,000 | Parents/guardians with contact information |
| **Enrollments** | 500,000 | Historical enrollment records (5 years) |
| **Grades** | 2,000,000 | Course grades and assessments |
| **Attendance** | 18,000,000 | Daily attendance records |

### Geographic Coverage

Schools are distributed across Massachusetts counties:
- **Suffolk County** (Boston, Chelsea, Revere)
- **Middlesex County** (Cambridge, Somerville, Newton, Lexington)
- **Norfolk County** (Brookline, Quincy, Milton)
- **Essex County** (Salem, Lynn, Peabody)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MASSACHUSETTS SCHOOL DISTRICT ARCHITECTURE               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                     SOURCE SYSTEMS (Synthetic)                      │    │
│  │  📚 SIS (Student Info)  │  👥 HR (Staff)  │  📊 Assessment  │ 🚌 Ops│    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                          RAW LAYER                                  │    │
│  │  STUDENT_RAW  │  STAFF_RAW  │  SCHOOL_RAW  │  ENROLLMENT_RAW  │  ...│    │
│  │  + SCD Type 2 History  + Governance Tags  + Quality Rules           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    CURATED LAYER (Dynamic Tables)                   │    │
│  │  DIM_STUDENT  │  DIM_STAFF  │  DIM_SCHOOL  │  FACT_ENROLLMENT  │ ...│    │
│  │  + Business Rules  + Derived Attributes  + Pseudonymization         │    │
│  │  + Auto-refresh via TARGET_LAG  + Governance Tags                   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                  SEMANTIC LAYER (Semantic Views)                    │    │
│  │  📊 Enrollment Analytics  │  🎓 School Performance  │  👨‍🏫 Staff     │    │
│  │  + Native Snowflake Semantic Views for Cortex Analyst               │    │
│  │  + Pre-defined Dimensions & Metrics  + AI-Ready                     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    🔮 SNOWFLAKE HORIZON GOVERNANCE                  │    │
│  │  Tags  │  Masking  │  Row Access  │  Access History  │  Lineage     │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │               ❄️ STREAMLIT IN SNOWFLAKE APPLICATION                 │    │
│  │  🤖 Cortex Analyst  │  🔮 Horizon Dashboard  │  📊 School Analytics │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Role Hierarchy (Education Personas)

```
                          ACCOUNTADMIN
                               │
                          DATA_ADMIN ◄── System administration
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
```

| Role | Access Level | Use Case |
|------|-------------|----------|
| **DATA_ADMIN** | Full access all layers | IT administration |
| **DATA_ENGINEER** | RAW + CURATED management | Data pipeline management |
| **DATA_STEWARD** | Contracts + Observability | Data governance |
| **DISTRICT_ADMIN** | All schools in district | Superintendent, district leadership |
| **PRINCIPAL** | Single school, all students | School principal, assistant principal |
| **REGISTRAR** | Student enrollment data | School registrar, enrollment |
| **TEACHER** | Own classroom students only | Classroom teacher |
| **COUNSELOR** | Assigned students, sensitive data | Guidance counselor |
| **PARENT_PORTAL** | Own children only | Parent/guardian self-service |
| **PII_VIEWER** | Unmasked PII (audited) | Compliance, legal |
| **AI_AGENT** | AI-safe aggregated data only | Analytics, ML workloads |

## FERPA Compliance & PII Protection

This demo implements comprehensive **FERPA (Family Educational Rights and Privacy Act)** compliance:

### PII Categories

| Tag Value | Description | Example Fields |
|-----------|-------------|----------------|
| **DIRECTORY** | FERPA directory information | Name, grade level, school |
| **EDUCATIONAL_RECORD** | Protected educational records | Grades, transcripts, IEP |
| **SENSITIVE** | Highly sensitive information | SSN, disciplinary records |
| **HEALTH** | Health information (HIPAA overlap) | Medical conditions, 504 plans |

### Masking Policies

| Role | Student Name | SSN | Grades | Address | Health Records |
|------|-------------|-----|--------|---------|----------------|
| DISTRICT_ADMIN | ✓ Full | Last 4 | ✓ Full | ✓ Full | ✗ Masked |
| PRINCIPAL | ✓ Full | ✗ Masked | ✓ Full | ✓ Full | Summary only |
| TEACHER | ✓ Full | ✗ Masked | Own class | ✗ Masked | ✗ Masked |
| COUNSELOR | ✓ Full | ✗ Masked | ✓ Full | ✓ Full | ✓ Full |
| PARENT_PORTAL | Own child | ✗ Masked | Own child | Own only | Own child |
| AI_AGENT | ✗ Hash | ✗ Masked | Aggregate | ✗ Masked | ✗ Masked |

## Quick Start

### Prerequisites

- Snowflake account with ACCOUNTADMIN role
- Access to Snowflake Cortex (for AI features)
- Python 3.9+ with Faker library (for data generation)

### Installation

#### Option A: Generate Diverse Data with Python (Recommended)

1. **Install Python dependencies**
   ```bash
   cd tools
   pip install -r requirements.txt
   ```

2. **Generate synthetic data with Faker**
   ```bash
   # Full dataset (100K students, ~5-10 minutes)
   python faker_data_generator.py --output-dir ../data --format csv
   
   # Quick test dataset (1K students, ~30 seconds)
   python faker_data_generator.py --output-dir ../data --format csv --quick
   ```

3. **Run Snowflake setup scripts**
   ```sql
   -- Step 1: Initial Setup (AS ACCOUNTADMIN)
   @sql/01_setup.sql
   
   -- Step 2: Contract Registry (AS DATA_ADMIN)
   @sql/02_contract_registry.sql
   
   -- Step 3: RAW Layer Tables (AS DATA_ADMIN)
   @sql/03_raw_layer_tables.sql
   ```

4. **Upload CSV files to Snowflake stage**
   ```bash
   # Using SnowSQL
   snowsql -c my_connection -q "PUT file://data/*.csv @RAW_DEV.STAGING.DATA_STAGE/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE"
   ```

5. **Load data into RAW tables**
   ```sql
   -- Step 4: Load Faker-generated data (AS DATA_ADMIN)
   @sql/04_load_synthetic_data.sql
   ```

6. **Complete remaining setup**
   ```sql
   -- Step 5: Curated Layer Dynamic Tables
   @sql/05_curated_layer_dynamic_tables.sql
   
   -- Step 6: Semantic Layer (Semantic Views)
   @sql/06_semantic_layer.sql
   
   -- Step 7: Horizon Policies
   @sql/07_horizon_policies.sql
   
   -- Step 8: Observability
   @sql/08_observability.sql
   
   -- Step 9: Streamlit App
   @sql/09_streamlit_app.sql
   ```

7. **Upload Streamlit Python file**
   ```bash
   PUT file://streamlit/school_district_app.py @SEM_DEV.STREAMLIT_APPS.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
   ```

8. **Launch the Streamlit App**
   
   Navigate to: **Projects → Streamlit → SCHOOL_DISTRICT_DEMO**

#### Option B: Quick Setup with SQL-only Generation

For a faster demo with simpler generated data:

```sql
-- Run all SQL scripts in order (01-09)
-- Script 04_generate_synthetic_data.sql generates data within Snowflake
@sql/01_setup.sql
@sql/02_contract_registry.sql
@sql/03_raw_layer_tables.sql
@sql/04_generate_synthetic_data.sql  -- Uses SQL GENERATOR (less diverse names)
@sql/05_curated_layer_dynamic_tables.sql
@sql/06_semantic_layer.sql
@sql/07_horizon_policies.sql
@sql/08_observability.sql
@sql/09_streamlit_app.sql
```

### Data Generation Features

The Faker-based Python generator (`tools/faker_data_generator.py`) creates highly diverse, realistic data:

| Feature | Description |
|---------|-------------|
| **Culturally Diverse Names** | Names from 15+ language locales reflecting MA demographics |
| **Realistic Addresses** | 100+ MA cities with real zip codes, streets, and coordinates |
| **School Naming** | Historical figures, geographic features, neighborhood names |
| **Demographics** | Accurate ethnicity/language distributions for MA schools |
| **Referential Integrity** | All foreign keys properly maintained across tables |
| **SCD Type 2 Ready** | Row hashes computed for change detection |

**Data volumes:**
```bash
# Full generation (default)
python faker_data_generator.py --students 100000 --schools 250 --staff 12000 --guardians 150000

# Custom generation
python faker_data_generator.py --students 50000 --schools 100 --format parquet
```

## Directory Structure

```
snowflake-dca-horizon-demo/
│
├── README.md                           # This file
├── DESCRIPTION.md                      # Repository description
│
├── docs/                               # Documentation
│   ├── ARCHITECTURE.md                 # Detailed architecture
│   ├── DEMO_SCRIPT.md                  # 10-15 minute demo walkthrough
│   ├── FERPA_COMPLIANCE.md             # FERPA implementation details
│   └── SAMPLE_QUESTIONS.md             # Cortex Analyst sample questions
│
├── contracts/                          # Data Contract Definitions
│   ├── data/                           # Source system contracts
│   │   ├── student_v1.yml
│   │   ├── staff_v1.yml
│   │   ├── school_v1.yml
│   │   ├── district_v1.yml
│   │   ├── guardian_v1.yml
│   │   ├── enrollment_v1.yml
│   │   ├── grade_v1.yml
│   │   ├── attendance_v1.yml
│   │   ├── course_v1.yml
│   │   └── class_section_v1.yml
│   └── products/                       # Semantic layer contracts
│       ├── student_analytics_v1.yml
│       ├── school_performance_v1.yml
│       └── staff_analytics_v1.yml
│
├── sql/                                # Snowflake SQL Scripts
│   ├── 01_setup.sql                    # Roles, warehouses, databases, tags
│   ├── 02_contract_registry.sql        # Contract tables and procedures
│   ├── 03_raw_layer_tables.sql         # RAW tables with SCD Type 2 columns
│   ├── 04_generate_synthetic_data.sql  # SQL-based synthetic data (quick)
│   ├── 04_load_synthetic_data.sql      # Load Faker CSV data (recommended)
│   ├── 05_curated_layer_dynamic_tables.sql  # Dynamic Tables (dims/facts)
│   ├── 06_semantic_layer.sql           # Native Snowflake Semantic Views
│   ├── 07_horizon_policies.sql         # Masking and row access policies
│   ├── 08_observability.sql            # Monitoring views
│   ├── 09_streamlit_app.sql            # Streamlit app deployment
│   └── 99_cleanup.sql                  # Reset/cleanup script
│
├── streamlit/                          # Streamlit in Snowflake App
│   └── school_district_app.py          # Main Cortex Analyst application
│
├── tools/                              # Python utilities
│   ├── __init__.py
│   ├── requirements.txt                # Python dependencies (Faker, etc.)
│   ├── faker_data_generator.py         # Faker-based diverse data generation
│   ├── synthetic_data_generator.py     # Original simpler generator
│   ├── contract_validator.py           # Validate contracts
│   └── ferpa_tagger.py                 # Auto-tag FERPA categories
│
├── data/                               # Generated synthetic data (gitignored)
│   ├── districts.csv
│   ├── schools.csv
│   ├── students.csv
│   ├── staff.csv
│   ├── guardians.csv
│   └── student_guardians.csv
│
├── schemas/                            # JSON Schemas
│   └── education_contract_schema.json  # Education-specific schema
│
└── templates/                          # Contract Templates
    ├── student_contract_template.yml
    └── staff_contract_template.yml
```

## Demo Script Overview (10-15 minutes)

### Act 1: The Data Foundation (3 minutes)
- Show the synthetic school district data
- Demonstrate the three-layer architecture (RAW → CURATED → SEMANTIC)
- Highlight data contracts and quality rules

### Act 2: Horizon Governance in Action (5 minutes)
- **Object Tagging**: Show FERPA and PII tags on columns
- **Masking Policies**: Query as different roles to see masking
- **Row Access Policies**: Teacher sees only their students
- **Access History**: Show audit trail for compliance

### Act 3: Role-Based Experience (4 minutes)
- **As Superintendent**: District-wide analytics, all schools
- **As Principal**: School-level view, student performance
- **As Teacher**: Classroom view, own students only
- **As Parent**: Portal view, own children only

### Act 4: AI & Observability (3 minutes)
- **Cortex Analyst**: Natural language queries on school data
- **Governance Dashboard**: Health, compliance, tag coverage
- **Alerts & SLAs**: Real-time monitoring

## Sample Cortex Analyst Questions

### District Leadership
- "What is the average graduation rate by district?"
- "Which schools have the highest chronic absenteeism?"
- "Show me enrollment trends over the past 5 years"

### Principal Queries
- "How are my 8th graders performing in math?"
- "Which students are at risk of not graduating?"
- "What is our teacher retention rate?"

### Teacher Queries
- "Show me the grades for my Period 3 Algebra class"
- "Which students have missed more than 5 days this month?"

### Governance Queries
- "How many PII columns are properly tagged?"
- "Which contracts have SLA violations?"
- "Show me access history for student records"

## Key Features Demonstrated

### 1. FERPA-Compliant Data Governance
- Automatic classification of educational records
- Tag-based masking for student PII
- Row-level security by role and relationship

### 2. Education-Specific Role Hierarchy
- Realistic school district personas
- Hierarchical access (District → School → Classroom)
- Parent portal with child-only access

### 3. Comprehensive Synthetic Data
- 100,000 realistic student records
- Massachusetts school names and locations
- Realistic grade distributions and attendance patterns

### 4. Full Observability
- Contract health dashboards
- FERPA compliance monitoring
- Access audit trails

### 5. Native Snowflake Semantic Views
- Native `CREATE SEMANTIC VIEW` objects (not YAML models)
- Pre-defined dimensions and metrics for Cortex Analyst
- Role-aware responses (respects masking and row access)
- Sample questions for each persona

**Available Semantic Views:**
| Schema | View | Purpose |
|--------|------|---------|
| `SEM_STUDENT` | `STUDENT_ENROLLMENT_ANALYTICS` | Enrollment, demographics, program participation |
| `SEM_STUDENT` | `STUDENT_DEMOGRAPHICS_ANALYTICS` | Demographics and equity reporting |
| `SEM_STUDENT` | `ATTENDANCE_ANALYTICS` | Attendance tracking and truancy |
| `SEM_SCHOOL` | `SCHOOL_PERFORMANCE_ANALYTICS` | Capacity, performance, staffing |
| `SEM_STAFF` | `STAFF_WORKFORCE_ANALYTICS` | HR and workforce metrics |
| `SEM_GOVERNANCE` | `GOVERNANCE_ANALYTICS` | Contract health and quality |
| `SEM_GOVERNANCE` | `DATA_QUALITY_ANALYTICS` | Quality rule execution |
| `SEM_GOVERNANCE` | `FERPA_COMPLIANCE_ANALYTICS` | FERPA compliance monitoring |

## Resources

### Snowflake Horizon
- [Snowflake Horizon Overview](https://www.snowflake.com/en/data-cloud/horizon/)
- [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
- [Tag-Based Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)
- [Access History](https://docs.snowflake.com/en/sql-reference/account-usage/access_history)

### Compliance
- [FERPA Overview (US Dept of Education)](https://www2.ed.gov/policy/gen/guid/fpco/ferpa/index.html)
- [Student Privacy Compass](https://studentprivacycompass.org/)

### Snowflake Features
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please read CONTRIBUTING.md for guidelines.
