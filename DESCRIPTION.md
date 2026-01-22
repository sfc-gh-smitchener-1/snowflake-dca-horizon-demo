# Repository Description

## Short Description (for GitHub)

**Snowflake Massachusetts School District Horizon Demo** — A comprehensive demonstration of **Snowflake Horizon** governance, privacy, and observability using synthetic education data. Features 100K students across 250 schools with FERPA-compliant data governance, role-based masking, row-level security, and a 10-15 minute demo script showcasing Horizon's full capabilities.

---

## Full Description

### Snowflake Horizon Education Demo

> *"Demonstrate the full power of Snowflake Horizon governance with realistic education data and FERPA compliance."*

A production-ready demonstration of **Snowflake Horizon** unified governance capabilities, built on a synthetic Massachusetts school district dataset. This demo showcases how education organizations can implement enterprise-grade data governance while maintaining FERPA compliance and enabling analytics across all organizational levels.

#### 🎯 Demo Purpose

This demo is designed for a **10-15 minute presentation** that demonstrates:

1. **Horizon Governance**: Object tagging, classification, lineage
2. **Privacy Controls**: Tag-based masking, row access policies
3. **Role-Based Access**: Education hierarchy from superintendent to teacher
4. **Observability**: Contract health, compliance dashboards, audit trails
5. **AI Integration**: Cortex Analyst with governance-aware queries

#### 📊 Synthetic Data

| Entity | Count | Description |
|--------|-------|-------------|
| Students | 100,000 | K-12 with demographics, enrollment, grades |
| Schools | 250 | Elementary, Middle, High across Boston area |
| Districts | 25 | Greater Boston area school districts |
| Staff | 12,000 | Teachers, admins, support |
| Guardians | 150,000 | Parents with contact info |

**Geographic Coverage:**
- Suffolk County (Boston, Chelsea, Revere)
- Middlesex County (Cambridge, Somerville, Newton)
- Norfolk County (Brookline, Quincy, Milton)
- Essex County (Salem, Lynn, Peabody)

#### 🔐 FERPA Compliance

Comprehensive implementation of **Family Educational Rights and Privacy Act** requirements:

| FERPA Category | Example Data | Protection Level |
|----------------|--------------|-----------------|
| Directory Information | Name, grade, school | Opt-out available |
| Educational Records | Grades, transcripts | Role-based access |
| Sensitive Records | Disciplinary, IEP | Need-to-know only |
| Health Information | 504 plans, medical | Counselor/nurse only |

#### 👥 Education Role Hierarchy

```
DISTRICT_ADMIN (Superintendent)
       │
  PRINCIPAL (School Leader)
       │
   ┌───┴───┐
TEACHER  COUNSELOR
       │
 PARENT_PORTAL
```

Each role sees only the data appropriate to their function:
- **Superintendent**: All schools, aggregated metrics
- **Principal**: Own school, all students
- **Teacher**: Own classroom students only
- **Parent**: Own children only

#### 🔮 Snowflake Horizon Features Demonstrated

| Feature | Implementation |
|---------|---------------|
| **Object Tagging** | FERPA_CATEGORY, PII_TYPE, AI_ALLOWED tags |
| **Tag-Based Masking** | SSN, address, health records masked by role |
| **Row Access Policies** | Teachers see only their assigned students |
| **Data Classification** | Automatic sensitivity labeling |
| **Access History** | Full audit trail for compliance |
| **Dynamic Tables** | Automated refresh with SLA monitoring |
| **Semantic Views** | Cortex Analyst integration |

#### 🎬 Demo Script Outline (10-15 minutes)

**Act 1 - Foundation (3 min)**
- Show synthetic school data at scale
- Three-layer architecture walkthrough
- Data contracts and quality rules

**Act 2 - Governance (5 min)**
- Object tags on FERPA-protected columns
- Masking demonstration across roles
- Row-level security in action
- Access history audit trail

**Act 3 - Personas (4 min)**
- Query as superintendent (district view)
- Query as principal (school view)
- Query as teacher (classroom view)
- Query as parent (child view)

**Act 4 - AI & Observability (3 min)**
- Cortex Analyst natural language queries
- Governance health dashboard
- Alert and SLA monitoring

---

## GitHub About Section

**Snowflake Horizon Demo** — Massachusetts school district synthetic data (100K students, 250 schools) demonstrating FERPA-compliant governance with object tagging, tag-based masking, row access policies, role hierarchy, and Cortex Analyst integration.

---

## One-Liner

Demonstrate Snowflake Horizon governance with 100K synthetic students: FERPA tagging, role-based masking, row access policies, and observability dashboards.

---

## Topics/Tags

```
snowflake, snowflake-horizon, education, ferpa, data-governance, 
privacy, masking-policies, row-access-policies, synthetic-data,
cortex-analyst, semantic-models, object-tagging, compliance,
school-district, k12, data-contracts, observability
```

---

## Target Audience

| Persona | Interest |
|---------|----------|
| **Solutions Architects** | Horizon implementation patterns |
| **Data Engineers** | Three-layer architecture, dynamic tables |
| **Security/Compliance** | FERPA, masking, row access policies |
| **Education IT** | School district data governance |
| **Sales Engineers** | Customer demo for education sector |

---

## Key Differentiators

1. **Realistic Education Domain**: Not generic sample data, but education-specific with FERPA requirements
2. **Complete Role Hierarchy**: From superintendent to parent portal
3. **Production-Ready Patterns**: Masking, row access, audit trails
4. **Demo-Ready Script**: 10-15 minute guided walkthrough
5. **Cortex Integration**: Natural language queries with governance awareness
