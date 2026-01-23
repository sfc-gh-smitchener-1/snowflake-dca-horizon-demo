"""
Faker-based Synthetic Data Generator for Massachusetts School District Demo

Generates highly realistic, diverse synthetic education data using Faker:
- 100,000+ Students with diverse names from multiple cultures
- 250+ Schools with unique names across Boston metro area
- 25+ Districts across Greater Boston and surrounding areas
- 12,000+ Staff members with realistic credentials
- 150,000+ Guardians with family relationships
- Realistic addresses throughout Massachusetts

Features:
- Culturally diverse name generation (representing MA demographics)
- Real Massachusetts cities, zip codes, and street names
- Realistic school naming conventions
- Proper grade-level to age mapping
- Referential integrity between all tables

Usage:
  python faker_data_generator.py --output-dir ./output --format csv
  python faker_data_generator.py --output-dir ./output --format parquet --students 100000

For Snowflake deployment:
  Upload output files to a stage and use COPY INTO for bulk loading.
"""

import os
import random
import hashlib
from datetime import datetime, timedelta, date
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass, field, asdict
import json
import csv
import argparse

# Faker for realistic data generation
try:
    from faker import Faker
    from faker.providers import BaseProvider
except ImportError:
    print("Faker not installed. Run: pip install faker")
    raise

# ============================================================================
# CUSTOM FAKER PROVIDERS FOR EDUCATION DATA
# ============================================================================

class MassachusettsProvider(BaseProvider):
    """Custom Faker provider for Massachusetts-specific data"""
    
    # Greater Boston and Eastern MA cities with zip codes
    MA_CITIES = [
        # Boston neighborhoods
        ("Boston", "02108", "Suffolk", 42.3601, -71.0589),
        ("Boston", "02109", "Suffolk", 42.3611, -71.0545),
        ("Boston", "02110", "Suffolk", 42.3570, -71.0545),
        ("Boston", "02111", "Suffolk", 42.3513, -71.0603),
        ("Boston", "02113", "Suffolk", 42.3647, -71.0542),
        ("Boston", "02114", "Suffolk", 42.3612, -71.0696),
        ("Boston", "02115", "Suffolk", 42.3420, -71.0895),
        ("Boston", "02116", "Suffolk", 42.3501, -71.0769),
        ("Boston", "02118", "Suffolk", 42.3389, -71.0726),
        ("Boston", "02119", "Suffolk", 42.3234, -71.0847),
        ("Boston", "02120", "Suffolk", 42.3317, -71.0974),
        ("Boston", "02121", "Suffolk", 42.3067, -71.0873),
        ("Boston", "02122", "Suffolk", 42.2914, -71.0532),
        ("Boston", "02124", "Suffolk", 42.2869, -71.0736),
        ("Boston", "02125", "Suffolk", 42.3148, -71.0604),
        ("Boston", "02126", "Suffolk", 42.2723, -71.0933),
        ("Boston", "02127", "Suffolk", 42.3384, -71.0389),
        ("Boston", "02128", "Suffolk", 42.3642, -71.0258),
        ("Boston", "02129", "Suffolk", 42.3821, -71.0618),
        ("Boston", "02130", "Suffolk", 42.3097, -71.1151),
        ("Boston", "02131", "Suffolk", 42.2843, -71.1217),
        ("Boston", "02132", "Suffolk", 42.2799, -71.1589),
        ("Boston", "02134", "Suffolk", 42.3534, -71.1314),
        ("Boston", "02135", "Suffolk", 42.3505, -71.1520),
        ("Boston", "02136", "Suffolk", 42.2547, -71.1289),
        # Cambridge & Somerville
        ("Cambridge", "02138", "Middlesex", 42.3770, -71.1167),
        ("Cambridge", "02139", "Middlesex", 42.3650, -71.1037),
        ("Cambridge", "02140", "Middlesex", 42.3933, -71.1317),
        ("Cambridge", "02141", "Middlesex", 42.3697, -71.0893),
        ("Cambridge", "02142", "Middlesex", 42.3625, -71.0843),
        ("Somerville", "02143", "Middlesex", 42.3800, -71.0995),
        ("Somerville", "02144", "Middlesex", 42.3979, -71.1220),
        ("Somerville", "02145", "Middlesex", 42.3910, -71.0870),
        # North Shore
        ("Lynn", "01901", "Essex", 42.4668, -70.9495),
        ("Lynn", "01902", "Essex", 42.4729, -70.9281),
        ("Lynn", "01904", "Essex", 42.4884, -70.9661),
        ("Lynn", "01905", "Essex", 42.4597, -70.9689),
        ("Salem", "01970", "Essex", 42.5195, -70.8967),
        ("Peabody", "01960", "Essex", 42.5278, -70.9286),
        ("Beverly", "01915", "Essex", 42.5584, -70.8800),
        ("Marblehead", "01945", "Essex", 42.5000, -70.8578),
        ("Swampscott", "01907", "Essex", 42.4731, -70.9056),
        ("Nahant", "01908", "Essex", 42.4264, -70.9231),
        ("Gloucester", "01930", "Essex", 42.6159, -70.6620),
        ("Rockport", "01966", "Essex", 42.6559, -70.6203),
        # South Shore
        ("Quincy", "02169", "Norfolk", 42.2529, -71.0023),
        ("Quincy", "02170", "Norfolk", 42.2676, -71.0209),
        ("Quincy", "02171", "Norfolk", 42.2862, -71.0140),
        ("Braintree", "02184", "Norfolk", 42.2043, -71.0017),
        ("Weymouth", "02188", "Norfolk", 42.2071, -70.9395),
        ("Weymouth", "02189", "Norfolk", 42.2243, -70.9576),
        ("Milton", "02186", "Norfolk", 42.2496, -71.0662),
        ("Dedham", "02026", "Norfolk", 42.2418, -71.1662),
        ("Norwood", "02062", "Norfolk", 42.1945, -71.1995),
        ("Canton", "02021", "Norfolk", 42.1584, -71.1448),
        ("Randolph", "02368", "Norfolk", 42.1626, -71.0407),
        ("Holbrook", "02343", "Norfolk", 42.1551, -70.9936),
        ("Hingham", "02043", "Plymouth", 42.2418, -70.8898),
        ("Hull", "02045", "Plymouth", 42.3018, -70.8578),
        ("Cohasset", "02025", "Norfolk", 42.2418, -70.8073),
        # West/Metro West
        ("Newton", "02458", "Middlesex", 42.3500, -71.2000),
        ("Newton", "02459", "Middlesex", 42.3125, -71.1987),
        ("Newton", "02460", "Middlesex", 42.3534, -71.2137),
        ("Newton", "02461", "Middlesex", 42.3231, -71.2071),
        ("Newton", "02462", "Middlesex", 42.2964, -71.2350),
        ("Newton", "02464", "Middlesex", 42.3367, -71.2259),
        ("Newton", "02465", "Middlesex", 42.3512, -71.2262),
        ("Newton", "02466", "Middlesex", 42.3529, -71.2521),
        ("Newton", "02467", "Middlesex", 42.3145, -71.1675),
        ("Newton", "02468", "Middlesex", 42.3267, -71.2301),
        ("Brookline", "02445", "Norfolk", 42.3418, -71.1309),
        ("Brookline", "02446", "Norfolk", 42.3445, -71.1220),
        ("Brookline", "02467", "Norfolk", 42.3145, -71.1675),
        ("Wellesley", "02481", "Norfolk", 42.2968, -71.2926),
        ("Wellesley", "02482", "Norfolk", 42.3095, -71.2757),
        ("Needham", "02492", "Norfolk", 42.2793, -71.2376),
        ("Needham", "02494", "Norfolk", 42.2973, -71.2343),
        ("Natick", "01760", "Middlesex", 42.2834, -71.3462),
        ("Framingham", "01701", "Middlesex", 42.2793, -71.4162),
        ("Framingham", "01702", "Middlesex", 42.2976, -71.4370),
        ("Waltham", "02451", "Middlesex", 42.3765, -71.2356),
        ("Waltham", "02452", "Middlesex", 42.3951, -71.2287),
        ("Waltham", "02453", "Middlesex", 42.3685, -71.2600),
        ("Watertown", "02472", "Middlesex", 42.3704, -71.1773),
        ("Belmont", "02478", "Middlesex", 42.3959, -71.1778),
        ("Arlington", "02474", "Middlesex", 42.4154, -71.1564),
        ("Arlington", "02476", "Middlesex", 42.4226, -71.1784),
        ("Lexington", "02420", "Middlesex", 42.4462, -71.2245),
        ("Lexington", "02421", "Middlesex", 42.4621, -71.2317),
        # North suburbs
        ("Medford", "02155", "Middlesex", 42.4184, -71.1062),
        ("Malden", "02148", "Middlesex", 42.4251, -71.0662),
        ("Everett", "02149", "Middlesex", 42.4084, -71.0537),
        ("Revere", "02151", "Suffolk", 42.4084, -70.9920),
        ("Chelsea", "02150", "Suffolk", 42.3918, -71.0328),
        ("Winthrop", "02152", "Suffolk", 42.3751, -70.9828),
        ("Melrose", "02176", "Middlesex", 42.4584, -71.0662),
        ("Wakefield", "01880", "Middlesex", 42.5065, -71.0731),
        ("Reading", "01867", "Middlesex", 42.5256, -71.1065),
        ("Woburn", "01801", "Middlesex", 42.4793, -71.1523),
        ("Stoneham", "02180", "Middlesex", 42.4834, -71.0995),
        ("Winchester", "01890", "Middlesex", 42.4521, -71.1373),
        ("Burlington", "01803", "Middlesex", 42.5048, -71.1956),
        ("Bedford", "01730", "Middlesex", 42.4906, -71.2759),
        ("Concord", "01742", "Middlesex", 42.4604, -71.3489),
        # Worcester area
        ("Worcester", "01602", "Worcester", 42.2626, -71.8023),
        ("Worcester", "01603", "Worcester", 42.2451, -71.8234),
        ("Worcester", "01604", "Worcester", 42.2451, -71.7689),
        ("Worcester", "01605", "Worcester", 42.2876, -71.7867),
        ("Worcester", "01606", "Worcester", 42.2984, -71.8212),
        ("Worcester", "01607", "Worcester", 42.2234, -71.7523),
        ("Worcester", "01608", "Worcester", 42.2626, -71.7978),
        ("Worcester", "01609", "Worcester", 42.2818, -71.7634),
        ("Worcester", "01610", "Worcester", 42.2543, -71.7812),
    ]
    
    # Common Massachusetts street names
    MA_STREET_NAMES = [
        "Main", "Washington", "Commonwealth", "Beacon", "Tremont",
        "Boylston", "Newbury", "Charles", "Cambridge", "Harvard",
        "Massachusetts", "Huntington", "Columbus", "Atlantic", "Summer",
        "Winter", "Spring", "Maple", "Oak", "Pine", "Elm", "Cedar",
        "Chestnut", "Park", "Church", "School", "High", "Mill", "River",
        "Lake", "Hill", "Valley", "Forest", "Garden", "Pleasant", "Union",
        "Liberty", "Franklin", "Adams", "Lincoln", "Jefferson", "Madison",
        "Monroe", "Jackson", "Harrison", "Tyler", "Polk", "Taylor",
        "Concord", "Lexington", "Bunker Hill", "Freedom Trail", "Revere",
        "Quincy", "Hancock", "Warren", "Putnam", "Greene", "Knox",
        "Salem", "Marblehead", "Gloucester", "Plymouth", "Pilgrim",
        "Puritan", "Colonial", "Heritage", "Patriot", "Liberty Bell",
        "Independence", "Constitution", "Federal", "State", "Court",
        "Centre", "Central", "North", "South", "East", "West"
    ]
    
    MA_STREET_SUFFIXES = [
        "Street", "Avenue", "Road", "Drive", "Lane", "Way", "Court",
        "Place", "Circle", "Boulevard", "Terrace", "Path", "Trail"
    ]
    
    def ma_city(self) -> Tuple[str, str, str, float, float]:
        """Return a random MA city with zip, county, lat, lon"""
        return self.random_element(self.MA_CITIES)
    
    def ma_street_address(self) -> str:
        """Generate a realistic MA street address"""
        number = self.random_int(1, 9999)
        street = self.random_element(self.MA_STREET_NAMES)
        suffix = self.random_element(self.MA_STREET_SUFFIXES)
        return f"{number} {street} {suffix}"
    
    def ma_apartment(self) -> str:
        """Generate apartment/unit number"""
        if self.random_int(1, 100) <= 30:  # 30% chance of apartment
            apt_type = self.random_element(["Apt", "Unit", "#", "Suite"])
            apt_num = self.random_element([
                str(self.random_int(1, 50)),
                f"{self.random_int(1, 12)}{self.random_element(['A', 'B', 'C', 'D'])}",
                str(self.random_int(101, 999))
            ])
            return f"{apt_type} {apt_num}"
        return ""


class EducationProvider(BaseProvider):
    """Custom Faker provider for education-specific data"""
    
    # School name prefixes (historical figures, geographic features)
    SCHOOL_PREFIXES_ELEMENTARY = [
        # Historical figures
        "Abraham Lincoln", "George Washington", "Thomas Jefferson",
        "Benjamin Franklin", "John Adams", "John Hancock", "Paul Revere",
        "Samuel Adams", "Patrick Henry", "James Madison", "Alexander Hamilton",
        "Frederick Douglass", "Harriet Tubman", "Rosa Parks",
        "Martin Luther King Jr.", "César Chávez", "Thurgood Marshall",
        # Massachusetts historical figures
        "John F. Kennedy", "Robert F. Kennedy", "Edward M. Kennedy",
        "John Quincy Adams", "Calvin Coolidge", "Henry Cabot Lodge",
        "Clara Barton", "Emily Dickinson", "Louisa May Alcott",
        "Horace Mann", "Dorothy Height", "W.E.B. Du Bois",
        # Geographic/Nature
        "Oak Hill", "Maple Grove", "Pine Ridge", "Cedar Valley",
        "Riverside", "Lakeside", "Hillside", "Brookside", "Meadowbrook",
        "Sunnydale", "Pleasant Valley", "Forest Hills", "Green Acres",
        "Rolling Hills", "Spring Valley", "Willow Creek", "Crystal Lake",
        # Directional
        "North", "South", "East", "West", "Central", "Highland",
        # Massachusetts places
        "Beacon Hill", "Back Bay", "Jamaica Plain", "Dorchester",
        "Charlestown", "Brighton", "Allston", "Roxbury", "Mattapan"
    ]
    
    SCHOOL_PREFIXES_MIDDLE = [
        "John F. Kennedy", "Martin Luther King Jr.", "Rosa Parks",
        "César Chávez", "Thurgood Marshall", "Barack Obama", "Eleanor Roosevelt",
        "Heritage", "Innovation", "Discovery", "Exploration", "Unity",
        "Renaissance", "Gateway", "Challenger", "Pioneer", "Voyager",
        "North", "South", "East", "West", "Central", "Highland", "Lakewood"
    ]
    
    SCHOOL_PREFIXES_HIGH = [
        # High schools often named after cities or regions
        "Boston Latin", "Boston English", "Boston Arts", "Boston Technical",
        "Cambridge Rindge and Latin", "Brookline", "Newton North", "Newton South",
        "Lexington", "Arlington", "Somerville", "Medford", "Malden",
        "Chelsea", "Revere", "Everett", "Quincy", "Braintree",
        # Academy style
        "Excel Academy", "Academy of Arts", "Academy of Science",
        "Classical Academy", "International Academy", "STEM Academy",
        "Leadership Academy", "Conservatory", "Preparatory", "Polytechnic"
    ]
    
    SCHOOL_TYPES = ["Elementary", "Middle", "High"]
    
    GRADE_LEVELS = {
        "Elementary": ["PK", "K", "01", "02", "03", "04", "05"],
        "Middle": ["06", "07", "08"],
        "High": ["09", "10", "11", "12"]
    }
    
    GRADE_RANGES = {
        "Elementary": "PK-5",
        "Middle": "6-8", 
        "High": "9-12"
    }
    
    POSITION_TITLES = {
        "Teacher": [
            "Classroom Teacher", "Lead Teacher", "Department Chair",
            "Literacy Specialist", "Math Intervention Specialist",
            "Reading Specialist", "Science Teacher", "Social Studies Teacher",
            "Music Teacher", "Art Teacher", "Physical Education Teacher",
            "Technology Teacher", "Library Media Specialist"
        ],
        "Special Education": [
            "Special Education Teacher", "Special Needs Coordinator",
            "Inclusion Specialist", "Behavior Specialist", "Resource Room Teacher",
            "Life Skills Teacher", "Autism Specialist"
        ],
        "Administrator": [
            "Principal", "Vice Principal", "Assistant Principal",
            "Dean of Students", "Dean of Academics", "Department Head",
            "Curriculum Coordinator", "Director of Special Education"
        ],
        "Counselor": [
            "School Counselor", "Guidance Counselor", "College Counselor",
            "Social Worker", "School Psychologist", "Adjustment Counselor"
        ],
        "Support": [
            "Paraprofessional", "Teacher Assistant", "Instructional Aide",
            "Administrative Assistant", "School Secretary", "Attendance Officer",
            "Nurse", "Cafeteria Worker", "Custodian", "Security Officer",
            "Bus Driver", "Crossing Guard"
        ]
    }
    
    DEPARTMENTS = [
        "Mathematics", "English Language Arts", "Science", "Social Studies",
        "Special Education", "Physical Education", "Fine Arts", "Music",
        "World Languages", "Technology", "Library/Media", "Guidance",
        "Administration", "Student Services", "Health Services", "Operations"
    ]
    
    DEGREES = [
        ("Bachelor of Arts", "BA"),
        ("Bachelor of Science", "BS"),
        ("Bachelor of Education", "BEd"),
        ("Master of Arts", "MA"),
        ("Master of Science", "MS"),
        ("Master of Education", "MEd"),
        ("Master of Arts in Teaching", "MAT"),
        ("Certificate of Advanced Graduate Study", "CAGS"),
        ("Doctor of Education", "EdD"),
        ("Doctor of Philosophy", "PhD")
    ]
    
    ACCOUNTABILITY_RATINGS = [
        "Exceeds Expectations",
        "Meets Expectations", "Meets Expectations", "Meets Expectations",
        "Partially Meets Expectations",
        "Not Meeting Expectations"
    ]
    
    def school_name(self, school_type: str = "Elementary") -> str:
        """Generate a realistic school name"""
        if school_type == "Elementary":
            prefix = self.random_element(self.SCHOOL_PREFIXES_ELEMENTARY)
            return f"{prefix} Elementary School"
        elif school_type == "Middle":
            prefix = self.random_element(self.SCHOOL_PREFIXES_MIDDLE)
            return f"{prefix} Middle School"
        else:  # High
            prefix = self.random_element(self.SCHOOL_PREFIXES_HIGH)
            if "Academy" in prefix or "Preparatory" in prefix or "Polytechnic" in prefix:
                return prefix
            return f"{prefix} High School"
    
    def grade_level(self, school_type: str = "Elementary") -> str:
        """Get a random grade level for school type"""
        return self.random_element(self.GRADE_LEVELS.get(school_type, ["K"]))
    
    def grade_range(self, school_type: str) -> str:
        """Get grade range for school type"""
        return self.GRADE_RANGES.get(school_type, "K-12")
    
    def position_title(self, role_category: str = "Teacher") -> str:
        """Get a position title for role category"""
        titles = self.POSITION_TITLES.get(role_category, self.POSITION_TITLES["Teacher"])
        return self.random_element(titles)
    
    def department(self) -> str:
        """Get a random department"""
        return self.random_element(self.DEPARTMENTS)
    
    def degree(self) -> Tuple[str, str]:
        """Get a random degree (full name, abbreviation)"""
        return self.random_element(self.DEGREES)
    
    def accountability_rating(self) -> str:
        """Get an accountability rating"""
        return self.random_element(self.ACCOUNTABILITY_RATINGS)


# ============================================================================
# DATA MODELS
# ============================================================================

@dataclass
class District:
    district_id: str
    district_name: str
    county: str
    city: str
    state: str
    superintendent_name: str
    phone_main: str
    website: str
    current_school_year: str


@dataclass 
class School:
    school_id: str
    school_name: str
    school_name_short: str
    school_type: str
    grade_levels_served: str
    is_title_i: bool
    is_magnet: bool
    is_charter: bool
    district_id: str
    district_name: str
    address: str
    city: str
    state: str
    zip_code: str
    county: str
    latitude: float
    longitude: float
    phone_main: str
    phone_fax: str
    email_main: str
    website: str
    principal_staff_id: str
    principal_name: str
    building_capacity: int
    current_enrollment: int
    staff_count: int
    teacher_count: int
    school_year: str
    first_day_of_school: str
    last_day_of_school: str
    accountability_rating: str
    graduation_rate: Optional[float]
    attendance_rate: float


@dataclass
class Student:
    student_id: str
    first_name: str
    middle_name: str
    last_name: str
    preferred_name: str
    suffix: str
    ssn: str
    state_id: str
    date_of_birth: str
    gender: str
    ethnicity: str
    race: str
    primary_language: str
    ell_status: bool
    home_address_line1: str
    home_address_line2: str
    city: str
    state: str
    zip_code: str
    county: str
    current_school_id: str
    current_district_id: str
    grade_level: str
    homeroom: str
    enrollment_status: str
    enrollment_date: str
    expected_graduation_year: int
    special_education: bool
    section_504: bool
    gifted_talented: bool
    free_reduced_lunch: str
    homeless_status: bool


@dataclass
class Staff:
    staff_id: str
    first_name: str
    middle_name: str
    last_name: str
    preferred_name: str
    email: str
    personal_email: str
    phone_work: str
    phone_mobile: str
    ssn: str
    date_of_birth: str
    home_address: str
    city: str
    state: str
    zip_code: str
    employee_type: str
    position_title: str
    role_category: str
    department: str
    primary_school_id: str
    district_id: str
    hire_date: str
    start_date_current_position: str
    termination_date: Optional[str]
    employment_status: str
    highest_degree: str
    teaching_license: str
    license_expiration: str
    years_experience: int
    highly_qualified: bool
    salary: float
    pay_grade: str
    union_membership: str


@dataclass
class Guardian:
    guardian_id: str
    first_name: str
    last_name: str
    relationship_type: str
    email_primary: str
    email_secondary: str
    phone_home: str
    phone_mobile: str
    phone_work: str
    address_line1: str
    address_line2: str
    city: str
    state: str
    zip_code: str
    employer: str
    preferred_language: str
    portal_account_active: bool
    portal_username: str
    receives_district_communications: bool


@dataclass
class StudentGuardian:
    relationship_id: str
    student_id: str
    guardian_id: str
    relationship_type: str
    is_primary_contact: bool
    authorized_pickup: bool
    emergency_contact: bool


# ============================================================================
# MAIN GENERATOR CLASS
# ============================================================================

class FakerDataGenerator:
    """
    Comprehensive synthetic data generator using Faker.
    Generates diverse, realistic Massachusetts school district data.
    """
    
    def __init__(self, seed: int = 42):
        """Initialize with random seed for reproducibility"""
        self.seed = seed
        random.seed(seed)
        
        # Create localized Faker instances for diverse names
        self.fake_en = Faker('en_US')
        self.fake_en.seed_instance(seed)
        
        self.fake_es = Faker('es_MX')  # Spanish/Latino names
        self.fake_es.seed_instance(seed + 1)
        
        self.fake_pt = Faker('pt_BR')  # Portuguese/Brazilian names
        self.fake_pt.seed_instance(seed + 2)
        
        self.fake_zh = Faker('zh_CN')  # Chinese names
        self.fake_zh.seed_instance(seed + 3)
        
        self.fake_vi = Faker('vi_VN')  # Vietnamese names
        self.fake_vi.seed_instance(seed + 4)
        
        self.fake_hi = Faker('hi_IN')  # Hindi/Indian names
        self.fake_hi.seed_instance(seed + 5)
        
        self.fake_ko = Faker('ko_KR')  # Korean names
        self.fake_ko.seed_instance(seed + 6)
        
        self.fake_ar = Faker('ar_SA')  # Arabic names
        self.fake_ar.seed_instance(seed + 7)
        
        self.fake_ru = Faker('ru_RU')  # Russian names
        self.fake_ru.seed_instance(seed + 8)
        
        self.fake_ja = Faker('ja_JP')  # Japanese names
        self.fake_ja.seed_instance(seed + 9)
        
        self.fake_fr = Faker('fr_FR')  # French names
        self.fake_fr.seed_instance(seed + 10)
        
        self.fake_de = Faker('de_DE')  # German names
        self.fake_de.seed_instance(seed + 11)
        
        self.fake_it = Faker('it_IT')  # Italian names
        self.fake_it.seed_instance(seed + 12)
        
        self.fake_pl = Faker('pl_PL')  # Polish names
        self.fake_pl.seed_instance(seed + 13)
        
        self.fake_ie = Faker('en_IE')  # Irish names
        self.fake_ie.seed_instance(seed + 14)
        
        self.fake_gr = Faker('el_GR')  # Greek names
        self.fake_gr.seed_instance(seed + 15)
        
        # Add custom providers
        self.fake_en.add_provider(MassachusettsProvider)
        self.fake_en.add_provider(EducationProvider)
        
        # Storage
        self.districts: List[District] = []
        self.schools: List[School] = []
        self.students: List[Student] = []
        self.staff: List[Staff] = []
        self.guardians: List[Guardian] = []
        self.student_guardians: List[StudentGuardian] = []
        
        # Lookup maps
        self.school_by_id: Dict[str, School] = {}
        self.district_by_id: Dict[str, District] = {}
        
        # Demographics weights (based on MA school demographics)
        self.ethnicity_weights = {
            "White": 0.52,
            "Hispanic/Latino": 0.22,
            "Black/African American": 0.09,
            "Asian": 0.08,
            "Two or More Races": 0.05,
            "Native American/Alaska Native": 0.003,
            "Native Hawaiian/Pacific Islander": 0.001,
            "Other": 0.026
        }
        
        self.language_weights = {
            "English": 0.72,
            "Spanish": 0.12,
            "Portuguese": 0.04,
            "Chinese": 0.025,
            "Vietnamese": 0.02,
            "Haitian Creole": 0.02,
            "Arabic": 0.015,
            "Russian": 0.01,
            "Korean": 0.01,
            "Japanese": 0.005,
            "French": 0.005,
            "Hindi": 0.005,
            "Other": 0.015
        }
    
    def _weighted_choice(self, weights: Dict[str, float]) -> str:
        """Make a weighted random choice from a dictionary"""
        items = list(weights.keys())
        probs = list(weights.values())
        return random.choices(items, weights=probs, k=1)[0]
    
    def _get_name_for_ethnicity(self, ethnicity: str, gender: str = None) -> Tuple[str, str, str]:
        """Get culturally appropriate first, middle, last names based on ethnicity"""
        
        # Map ethnicities to faker instances and probabilities
        faker_map = {
            "White": [
                (self.fake_en, 0.4),
                (self.fake_ie, 0.15),
                (self.fake_it, 0.12),
                (self.fake_pl, 0.1),
                (self.fake_de, 0.08),
                (self.fake_ru, 0.08),
                (self.fake_gr, 0.04),
                (self.fake_fr, 0.03)
            ],
            "Hispanic/Latino": [
                (self.fake_es, 0.7),
                (self.fake_pt, 0.25),
                (self.fake_en, 0.05)
            ],
            "Black/African American": [
                (self.fake_en, 0.85),
                (self.fake_fr, 0.15)  # Francophone African
            ],
            "Asian": [
                (self.fake_zh, 0.35),
                (self.fake_vi, 0.2),
                (self.fake_hi, 0.2),
                (self.fake_ko, 0.1),
                (self.fake_ja, 0.1),
                (self.fake_en, 0.05)
            ],
            "Two or More Races": [
                (self.fake_en, 0.5),
                (self.fake_es, 0.2),
                (self.fake_zh, 0.15),
                (self.fake_hi, 0.15)
            ],
            "Native American/Alaska Native": [
                (self.fake_en, 1.0)
            ],
            "Native Hawaiian/Pacific Islander": [
                (self.fake_en, 1.0)
            ],
            "Other": [
                (self.fake_ar, 0.4),
                (self.fake_en, 0.3),
                (self.fake_hi, 0.3)
            ]
        }
        
        # Get faker instances for this ethnicity
        fakers = faker_map.get(ethnicity, [(self.fake_en, 1.0)])
        faker_instances = [f[0] for f in fakers]
        faker_weights = [f[1] for f in fakers]
        
        # Select a faker instance
        fake = random.choices(faker_instances, weights=faker_weights, k=1)[0]
        
        # Generate names
        try:
            if gender == "Male":
                first_name = fake.first_name_male()
            elif gender == "Female":
                first_name = fake.first_name_female()
            else:
                first_name = fake.first_name()
            
            middle_name = fake.first_name() if random.random() < 0.7 else ""
            last_name = fake.last_name()
        except:
            # Fallback to English if locale doesn't support gendered names
            first_name = self.fake_en.first_name()
            middle_name = self.fake_en.first_name() if random.random() < 0.7 else ""
            last_name = self.fake_en.last_name()
        
        return first_name, middle_name, last_name
    
    def _generate_ssn(self) -> str:
        """Generate fake SSN (for demo only)"""
        area = random.randint(100, 999)
        group = random.randint(10, 99)
        serial = random.randint(1000, 9999)
        return f"{area:03d}-{group:02d}-{serial:04d}"
    
    def _generate_phone(self) -> str:
        """Generate MA phone number"""
        area_codes = ["617", "508", "781", "978", "413", "339", "351", "774", "857"]
        area = random.choice(area_codes)
        exchange = random.randint(200, 999)
        subscriber = random.randint(1000, 9999)
        return f"{area}-{exchange:03d}-{subscriber:04d}"
    
    def _calculate_hash(self, data: Dict) -> str:
        """Calculate row hash for SCD Type 2"""
        # Exclude system columns
        hash_data = {k: v for k, v in data.items() if not k.startswith('_')}
        hash_str = json.dumps(hash_data, sort_keys=True, default=str)
        return hashlib.sha256(hash_str.encode()).hexdigest()
    
    def generate_districts(self, count: int = 25) -> List[Dict]:
        """Generate district records"""
        print(f"Generating {count} districts...")
        
        # Get unique cities for districts
        cities = list(set([c[0] for c in MassachusettsProvider.MA_CITIES]))
        random.shuffle(cities)
        
        district_records = []
        
        for i in range(count):
            city = cities[i % len(cities)]
            
            # Find city details
            city_info = next((c for c in MassachusettsProvider.MA_CITIES if c[0] == city), None)
            if not city_info:
                continue
            
            city_name, zip_code, county, lat, lon = city_info
            
            district_id = f"D{i+1:03d}"
            
            # Generate superintendent name
            gender = random.choice(["Male", "Female"])
            fake = random.choice([self.fake_en, self.fake_es, self.fake_zh])
            if gender == "Male":
                supt_name = f"Dr. {fake.first_name_male()} {fake.last_name()}"
            else:
                supt_name = f"Dr. {fake.first_name_female()} {fake.last_name()}"
            
            district = District(
                district_id=district_id,
                district_name=f"{city_name} Public Schools",
                county=county,
                city=city_name,
                state="MA",
                superintendent_name=supt_name,
                phone_main=self._generate_phone(),
                website=f"https://www.{city_name.lower().replace(' ', '')}.k12.ma.us",
                current_school_year="2025-2026"
            )
            
            self.districts.append(district)
            self.district_by_id[district_id] = district
            district_records.append(asdict(district))
        
        return district_records
    
    def generate_schools(self, count: int = 250) -> List[Dict]:
        """Generate school records with realistic distribution"""
        print(f"Generating {count} schools...")
        
        # Distribution: 50% elementary, 30% middle, 20% high
        school_type_dist = {
            "Elementary": int(count * 0.50),
            "Middle": int(count * 0.30),
            "High": count - int(count * 0.50) - int(count * 0.30)
        }
        
        school_records = []
        school_id = 0
        used_names = set()
        
        for school_type, type_count in school_type_dist.items():
            for _ in range(type_count):
                school_id += 1
                
                # Assign to a district (weighted by population)
                district = random.choice(self.districts)
                
                # Find city location
                city_info = next(
                    (c for c in MassachusettsProvider.MA_CITIES if c[0] == district.city),
                    MassachusettsProvider.MA_CITIES[0]
                )
                city_name, zip_code, county, lat, lon = city_info
                
                # Generate unique school name
                attempts = 0
                while True:
                    name = self.fake_en.school_name(school_type)
                    if name not in used_names or attempts > 10:
                        used_names.add(name)
                        break
                    attempts += 1
                
                # School capacity based on type
                if school_type == "Elementary":
                    capacity = random.randint(250, 650)
                elif school_type == "Middle":
                    capacity = random.randint(400, 900)
                else:
                    capacity = random.randint(700, 2000)
                
                # Enrollment (70-95% of capacity typically)
                enrollment = int(capacity * random.uniform(0.70, 0.98))
                
                # Staff counts
                teacher_count = enrollment // random.randint(14, 22)
                staff_count = teacher_count + random.randint(10, 30)
                
                # Principal name
                principal_gender = random.choice(["Male", "Female"])
                ethnicity = self._weighted_choice(self.ethnicity_weights)
                p_first, _, p_last = self._get_name_for_ethnicity(ethnicity, principal_gender)
                principal_name = f"{p_first} {p_last}"
                principal_id = f"S-P{school_id:04d}"
                
                school = School(
                    school_id=f"SCH-{school_id:04d}",
                    school_name=name,
                    school_name_short=name.split()[0] if len(name.split()) > 2 else name[:20],
                    school_type=school_type,
                    grade_levels_served=self.fake_en.grade_range(school_type),
                    is_title_i=random.random() < 0.35,
                    is_magnet=random.random() < 0.08,
                    is_charter=random.random() < 0.05,
                    district_id=district.district_id,
                    district_name=district.district_name,
                    address=self.fake_en.ma_street_address(),
                    city=city_name,
                    state="MA",
                    zip_code=zip_code,
                    county=county,
                    latitude=lat + random.uniform(-0.02, 0.02),
                    longitude=lon + random.uniform(-0.02, 0.02),
                    phone_main=self._generate_phone(),
                    phone_fax=self._generate_phone(),
                    email_main=f"office@{name.lower().replace(' ', '').replace('.', '')[:20]}.edu",
                    website=f"https://www.{name.lower().replace(' ', '').replace('.', '')[:20]}.edu",
                    principal_staff_id=principal_id,
                    principal_name=principal_name,
                    building_capacity=capacity,
                    current_enrollment=enrollment,
                    staff_count=staff_count,
                    teacher_count=teacher_count,
                    school_year="2025-2026",
                    first_day_of_school="2025-09-03",
                    last_day_of_school="2026-06-19",
                    accountability_rating=self.fake_en.accountability_rating(),
                    graduation_rate=round(random.uniform(82, 99), 1) if school_type == "High" else None,
                    attendance_rate=round(random.uniform(91, 98), 1)
                )
                
                self.schools.append(school)
                self.school_by_id[school.school_id] = school
                school_records.append(asdict(school))
        
        return school_records
    
    def generate_students(self, count: int = 100000) -> List[Dict]:
        """Generate diverse student records"""
        print(f"Generating {count} students...")
        
        student_records = []
        
        # Age ranges by grade
        grade_ages = {
            "PK": (3, 4), "K": (5, 6), "01": (6, 7), "02": (7, 8),
            "03": (8, 9), "04": (9, 10), "05": (10, 11),
            "06": (11, 12), "07": (12, 13), "08": (13, 14),
            "09": (14, 15), "10": (15, 16), "11": (16, 17), "12": (17, 19)
        }
        
        # Gender distribution
        genders = ["Male", "Female", "Non-binary", "Not specified"]
        gender_weights = [0.49, 0.49, 0.015, 0.005]
        
        suffixes = ["", "", "", "", "", "", "", "", "", "", "Jr.", "III", "IV"]
        
        enrollment_statuses = ["Active", "Active", "Active", "Active", "Active",
                             "Active", "Active", "Active", "Active",
                             "Transferred", "Withdrawn", "Graduated"]
        
        frl_options = ["Free", "Reduced", "Full Price", "Full Price", "Full Price"]
        
        for i in range(count):
            if i % 10000 == 0 and i > 0:
                print(f"  Generated {i:,} students...")
            
            # Select school (weighted by enrollment capacity)
            school = random.choice(self.schools)
            
            # Get grade based on school type
            grade = self.fake_en.grade_level(school.school_type)
            
            # Determine age from grade
            min_age, max_age = grade_ages.get(grade, (5, 18))
            today = date.today()
            age_days = random.randint(min_age * 365, max_age * 365)
            dob = today - timedelta(days=age_days)
            
            # Calculate expected graduation year
            if grade == "PK":
                grad_year = today.year + 14
            elif grade == "K":
                grad_year = today.year + 13
            else:
                try:
                    grade_num = int(grade)
                    grad_year = today.year + (12 - grade_num) + 1
                except:
                    grad_year = today.year + 4
            
            # Demographics
            ethnicity = self._weighted_choice(self.ethnicity_weights)
            gender = random.choices(genders, weights=gender_weights, k=1)[0]
            language = self._weighted_choice(self.language_weights)
            
            # Get culturally appropriate name
            first_name, middle_name, last_name = self._get_name_for_ethnicity(ethnicity, gender)
            
            # Preferred name (sometimes different)
            if random.random() < 0.15:
                preferred_name = self.fake_en.first_name()
            else:
                preferred_name = ""
            
            # ELL status correlates with non-English primary language
            if language != "English":
                ell_status = random.random() < 0.6
            else:
                ell_status = random.random() < 0.02
            
            # Address - use school's city
            city_info = next(
                (c for c in MassachusettsProvider.MA_CITIES if c[0] == school.city),
                MassachusettsProvider.MA_CITIES[0]
            )
            
            student = Student(
                student_id=f"STU-{i+1:06d}",
                first_name=first_name,
                middle_name=middle_name,
                last_name=last_name,
                preferred_name=preferred_name,
                suffix=random.choice(suffixes),
                ssn=self._generate_ssn(),
                state_id=f"MA-{random.randint(10000000, 99999999)}",
                date_of_birth=dob.strftime("%Y-%m-%d"),
                gender=gender,
                ethnicity=ethnicity,
                race=ethnicity,  # Simplified for demo
                primary_language=language,
                ell_status=ell_status,
                home_address_line1=self.fake_en.ma_street_address(),
                home_address_line2=self.fake_en.ma_apartment(),
                city=school.city,
                state="MA",
                zip_code=city_info[1],
                county=city_info[2],
                current_school_id=school.school_id,
                current_district_id=school.district_id,
                grade_level=grade,
                homeroom=f"{grade}-{random.choice('ABCDEF')}{random.randint(1,3)}",
                enrollment_status=random.choice(enrollment_statuses),
                enrollment_date=(today - timedelta(days=random.randint(30, 2000))).strftime("%Y-%m-%d"),
                expected_graduation_year=grad_year,
                special_education=random.random() < 0.14,
                section_504=random.random() < 0.06,
                gifted_talented=random.random() < 0.07,
                free_reduced_lunch=random.choice(frl_options),
                homeless_status=random.random() < 0.025
            )
            
            self.students.append(student)
            student_records.append(asdict(student))
        
        return student_records
    
    def generate_staff(self, count: int = 12000) -> List[Dict]:
        """Generate staff records"""
        print(f"Generating {count} staff members...")
        
        staff_records = []
        
        # Role distribution
        role_weights = {
            "Teacher": 0.65,
            "Special Education": 0.10,
            "Support": 0.15,
            "Administrator": 0.05,
            "Counselor": 0.05
        }
        
        employment_types = ["Full-Time", "Full-Time", "Full-Time", "Full-Time", "Part-Time"]
        pay_grades = ["G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8", "G9", "G10"]
        unions = ["MTA", "AFT", "NEA", "None", "None"]
        
        for i in range(count):
            if i % 5000 == 0 and i > 0:
                print(f"  Generated {i:,} staff...")
            
            # Assign to school
            school = random.choice(self.schools)
            
            # Role
            role = self._weighted_choice(role_weights)
            
            # Demographics
            ethnicity = self._weighted_choice(self.ethnicity_weights)
            gender = random.choice(["Male", "Female"])
            
            first_name, middle_name, last_name = self._get_name_for_ethnicity(ethnicity, gender)
            
            # Dates
            today = date.today()
            age_days = random.randint(25 * 365, 68 * 365)
            dob = today - timedelta(days=age_days)
            
            years_exp = random.randint(1, 40)
            hire_date = today - timedelta(days=years_exp * 365 + random.randint(0, 365))
            position_start = hire_date + timedelta(days=random.randint(0, years_exp * 180))
            
            # Degree
            degree_full, degree_abbr = self.fake_en.degree()
            
            # Salary based on experience and role
            base_salary = 45000
            if role == "Administrator":
                base_salary = 85000
            elif role == "Counselor":
                base_salary = 55000
            
            salary = base_salary + (years_exp * random.randint(1000, 2000))
            salary = min(salary, 150000)
            
            # License
            license_types = ["Initial", "Professional", "Permanent"]
            license_exp = today + timedelta(days=random.randint(180, 1825))
            
            staff_member = Staff(
                staff_id=f"S-{i+1:05d}",
                first_name=first_name,
                middle_name=middle_name,
                last_name=last_name,
                preferred_name="" if random.random() > 0.1 else self.fake_en.first_name(),
                email=f"{first_name.lower()}.{last_name.lower()}@{school.district_name.split()[0].lower()}.k12.ma.us",
                personal_email=f"{first_name.lower()}{last_name.lower()}{random.randint(1,99)}@{random.choice(['gmail.com', 'yahoo.com', 'outlook.com', 'icloud.com'])}",
                phone_work=self._generate_phone(),
                phone_mobile=self._generate_phone(),
                ssn=self._generate_ssn(),
                date_of_birth=dob.strftime("%Y-%m-%d"),
                home_address=self.fake_en.ma_street_address(),
                city=random.choice([c[0] for c in MassachusettsProvider.MA_CITIES[:50]]),
                state="MA",
                zip_code=random.choice([c[1] for c in MassachusettsProvider.MA_CITIES[:50]]),
                employee_type=random.choice(employment_types),
                position_title=self.fake_en.position_title(role),
                role_category=role,
                department=self.fake_en.department(),
                primary_school_id=school.school_id,
                district_id=school.district_id,
                hire_date=hire_date.strftime("%Y-%m-%d"),
                start_date_current_position=position_start.strftime("%Y-%m-%d"),
                termination_date=None,
                employment_status="Active" if random.random() > 0.05 else "On Leave",
                highest_degree=degree_full,
                teaching_license=f"MA {random.choice(license_types)} License - {role}",
                license_expiration=license_exp.strftime("%Y-%m-%d"),
                years_experience=years_exp,
                highly_qualified=random.random() < 0.85,
                salary=round(salary, 2),
                pay_grade=random.choice(pay_grades),
                union_membership=random.choice(unions)
            )
            
            self.staff.append(staff_member)
            staff_records.append(asdict(staff_member))
        
        return staff_records
    
    def generate_guardians(self, count: int = 150000) -> List[Dict]:
        """Generate guardian records and relationships"""
        print(f"Generating {count} guardians...")
        
        guardian_records = []
        
        relationships = ["Mother", "Father", "Grandmother", "Grandfather",
                        "Legal Guardian", "Foster Parent", "Stepmother", "Stepfather",
                        "Aunt", "Uncle"]
        relationship_weights = [0.38, 0.38, 0.06, 0.04, 0.05, 0.02, 0.03, 0.02, 0.01, 0.01]
        
        employers = [
            "Massachusetts General Hospital", "Boston Children's Hospital",
            "Harvard University", "MIT", "Boston University",
            "State Street Corporation", "Fidelity Investments", "Liberty Mutual",
            "Raytheon Technologies", "General Electric", "EMC Corporation",
            "Biogen", "Moderna", "Boston Scientific",
            "City of Boston", "Commonwealth of Massachusetts",
            "Boston Public Schools", "Self-Employed", "Retired",
            "Amazon", "Google", "Microsoft", "Apple",
            "Target", "CVS Health", "Walgreens", "Stop & Shop",
            "Partners Healthcare", "Beth Israel Deaconess",
            "Northeastern University", "Boston College", "Tufts University"
        ]
        
        for i in range(count):
            if i % 25000 == 0 and i > 0:
                print(f"  Generated {i:,} guardians...")
            
            relationship = random.choices(relationships, weights=relationship_weights, k=1)[0]
            
            # Determine gender from relationship
            if relationship in ["Mother", "Grandmother", "Stepmother", "Aunt"]:
                gender = "Female"
            elif relationship in ["Father", "Grandfather", "Stepfather", "Uncle"]:
                gender = "Male"
            else:
                gender = random.choice(["Male", "Female"])
            
            # Demographics
            ethnicity = self._weighted_choice(self.ethnicity_weights)
            language = self._weighted_choice(self.language_weights)
            
            first_name, _, last_name = self._get_name_for_ethnicity(ethnicity, gender)
            
            city_info = random.choice(MassachusettsProvider.MA_CITIES[:50])
            
            guardian = Guardian(
                guardian_id=f"G-{i+1:06d}",
                first_name=first_name,
                last_name=last_name,
                relationship_type=relationship,
                email_primary=f"{first_name.lower()}.{last_name.lower()}{random.randint(1,999)}@{random.choice(['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'icloud.com', 'aol.com'])}",
                email_secondary=f"{first_name.lower()}{last_name.lower()}@{random.choice(['work.com', 'company.com', 'corp.com'])}" if random.random() < 0.3 else "",
                phone_home=self._generate_phone() if random.random() < 0.6 else "",
                phone_mobile=self._generate_phone(),
                phone_work=self._generate_phone() if random.random() < 0.5 else "",
                address_line1=self.fake_en.ma_street_address(),
                address_line2=self.fake_en.ma_apartment(),
                city=city_info[0],
                state="MA",
                zip_code=city_info[1],
                employer=random.choice(employers) if random.random() < 0.8 else "",
                preferred_language=language if random.random() < 0.3 else "English",
                portal_account_active=random.random() < 0.75,
                portal_username=f"{first_name.lower()}.{last_name.lower()}{random.randint(1,99)}",
                receives_district_communications=random.random() < 0.9
            )
            
            self.guardians.append(guardian)
            guardian_records.append(asdict(guardian))
        
        return guardian_records
    
    def generate_student_guardian_relationships(self) -> List[Dict]:
        """Create relationships between students and guardians"""
        print("Generating student-guardian relationships...")
        
        relationship_records = []
        guardian_pool = list(self.guardians)
        random.shuffle(guardian_pool)
        
        guardian_idx = 0
        
        for student in self.students:
            # Each student gets 1-3 guardians
            num_guardians = random.choices([1, 2, 3], weights=[0.15, 0.70, 0.15], k=1)[0]
            
            for g in range(num_guardians):
                if guardian_idx >= len(guardian_pool):
                    guardian_idx = 0
                    random.shuffle(guardian_pool)
                
                guardian = guardian_pool[guardian_idx]
                guardian_idx += 1
                
                relationship = StudentGuardian(
                    relationship_id=f"REL-{student.student_id}-{guardian.guardian_id}",
                    student_id=student.student_id,
                    guardian_id=guardian.guardian_id,
                    relationship_type=guardian.relationship_type,
                    is_primary_contact=(g == 0),
                    authorized_pickup=random.random() < 0.9,
                    emergency_contact=random.random() < 0.95 if g < 2 else random.random() < 0.5
                )
                
                self.student_guardians.append(relationship)
                relationship_records.append(asdict(relationship))
        
        return relationship_records
    
    def generate_all(self, 
                     num_districts: int = 25,
                     num_schools: int = 250,
                     num_students: int = 100000,
                     num_staff: int = 12000,
                     num_guardians: int = 150000) -> Dict[str, List[Dict]]:
        """Generate all synthetic data"""
        
        print("=" * 60)
        print("FAKER SYNTHETIC DATA GENERATOR")
        print("Massachusetts School District Demo")
        print("=" * 60)
        
        districts = self.generate_districts(num_districts)
        schools = self.generate_schools(num_schools)
        students = self.generate_students(num_students)
        staff = self.generate_staff(num_staff)
        guardians = self.generate_guardians(num_guardians)
        student_guardians = self.generate_student_guardian_relationships()
        
        print("\n" + "=" * 60)
        print("GENERATION COMPLETE")
        print("=" * 60)
        print(f"  Districts:           {len(districts):,}")
        print(f"  Schools:             {len(schools):,}")
        print(f"  Students:            {len(students):,}")
        print(f"  Staff:               {len(staff):,}")
        print(f"  Guardians:           {len(guardians):,}")
        print(f"  Relationships:       {len(student_guardians):,}")
        print("=" * 60)
        
        return {
            "districts": districts,
            "schools": schools,
            "students": students,
            "staff": staff,
            "guardians": guardians,
            "student_guardians": student_guardians
        }


# ============================================================================
# OUTPUT FUNCTIONS
# ============================================================================

def save_to_csv(data: Dict[str, List[Dict]], output_dir: str):
    """Save data to CSV files"""
    os.makedirs(output_dir, exist_ok=True)
    
    for table_name, records in data.items():
        if not records:
            continue
        
        filepath = os.path.join(output_dir, f"{table_name}.csv")
        print(f"Writing {filepath}...")
        
        with open(filepath, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=records[0].keys())
            writer.writeheader()
            writer.writerows(records)


def save_to_json(data: Dict[str, List[Dict]], output_dir: str):
    """Save data to JSON files"""
    os.makedirs(output_dir, exist_ok=True)
    
    for table_name, records in data.items():
        if not records:
            continue
        
        filepath = os.path.join(output_dir, f"{table_name}.json")
        print(f"Writing {filepath}...")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(records, f, indent=2, default=str)


def save_to_parquet(data: Dict[str, List[Dict]], output_dir: str):
    """Save data to Parquet files (requires pyarrow)"""
    try:
        import pyarrow as pa
        import pyarrow.parquet as pq
    except ImportError:
        print("pyarrow not installed. Run: pip install pyarrow")
        print("Falling back to CSV format...")
        save_to_csv(data, output_dir)
        return
    
    os.makedirs(output_dir, exist_ok=True)
    
    for table_name, records in data.items():
        if not records:
            continue
        
        filepath = os.path.join(output_dir, f"{table_name}.parquet")
        print(f"Writing {filepath}...")
        
        # Convert to table
        table = pa.Table.from_pylist(records)
        pq.write_table(table, filepath)


# ============================================================================
# CLI ENTRY POINT
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Generate synthetic Massachusetts school district data using Faker"
    )
    
    parser.add_argument(
        "--output-dir", "-o",
        default="./synthetic_data",
        help="Output directory for generated files (default: ./synthetic_data)"
    )
    
    parser.add_argument(
        "--format", "-f",
        choices=["csv", "json", "parquet"],
        default="csv",
        help="Output format (default: csv)"
    )
    
    parser.add_argument(
        "--seed", "-s",
        type=int,
        default=42,
        help="Random seed for reproducibility (default: 42)"
    )
    
    parser.add_argument(
        "--districts",
        type=int,
        default=25,
        help="Number of districts to generate (default: 25)"
    )
    
    parser.add_argument(
        "--schools",
        type=int,
        default=250,
        help="Number of schools to generate (default: 250)"
    )
    
    parser.add_argument(
        "--students",
        type=int,
        default=100000,
        help="Number of students to generate (default: 100000)"
    )
    
    parser.add_argument(
        "--staff",
        type=int,
        default=12000,
        help="Number of staff to generate (default: 12000)"
    )
    
    parser.add_argument(
        "--guardians",
        type=int,
        default=150000,
        help="Number of guardians to generate (default: 150000)"
    )
    
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Generate a smaller dataset for testing (1000 students)"
    )
    
    args = parser.parse_args()
    
    # Quick mode for testing
    if args.quick:
        args.districts = 5
        args.schools = 20
        args.students = 1000
        args.staff = 100
        args.guardians = 1500
    
    # Generate data
    generator = FakerDataGenerator(seed=args.seed)
    data = generator.generate_all(
        num_districts=args.districts,
        num_schools=args.schools,
        num_students=args.students,
        num_staff=args.staff,
        num_guardians=args.guardians
    )
    
    # Save output
    print(f"\nSaving to {args.output_dir} in {args.format} format...")
    
    if args.format == "csv":
        save_to_csv(data, args.output_dir)
    elif args.format == "json":
        save_to_json(data, args.output_dir)
    elif args.format == "parquet":
        save_to_parquet(data, args.output_dir)
    
    print(f"\nDone! Files saved to: {args.output_dir}/")
    print("\nTo load into Snowflake:")
    print(f"  1. PUT file://{args.output_dir}/*.{args.format} @YOUR_STAGE")
    print("  2. COPY INTO table_name FROM @YOUR_STAGE/file.csv")


if __name__ == "__main__":
    main()
