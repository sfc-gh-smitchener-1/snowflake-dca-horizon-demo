"""
Synthetic Data Generator for Massachusetts School District

Generates realistic synthetic education data for:
- Students (100,000)
- Schools (250)
- Districts (25)
- Staff (12,000)
- Guardians (150,000)
- Enrollments, Grades, Attendance

Data patterns are based on Massachusetts school district demographics
and realistic educational distributions.
"""

import random
import string
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import json


@dataclass
class District:
    district_id: str
    district_name: str
    county: str
    city: str
    superintendent_name: str


@dataclass
class School:
    school_id: str
    school_name: str
    school_type: str
    district_id: str
    city: str
    county: str
    zip_code: str
    capacity: int
    principal_name: str


# Massachusetts districts in Greater Boston
MA_DISTRICTS = [
    ("D001", "Boston Public Schools", "Suffolk", "Boston"),
    ("D002", "Cambridge Public Schools", "Middlesex", "Cambridge"),
    ("D003", "Newton Public Schools", "Middlesex", "Newton"),
    ("D004", "Brookline Public Schools", "Norfolk", "Brookline"),
    ("D005", "Somerville Public Schools", "Middlesex", "Somerville"),
    ("D006", "Quincy Public Schools", "Norfolk", "Quincy"),
    ("D007", "Lexington Public Schools", "Middlesex", "Lexington"),
    ("D008", "Arlington Public Schools", "Middlesex", "Arlington"),
    ("D009", "Wellesley Public Schools", "Norfolk", "Wellesley"),
    ("D010", "Needham Public Schools", "Norfolk", "Needham"),
    ("D011", "Waltham Public Schools", "Middlesex", "Waltham"),
    ("D012", "Malden Public Schools", "Middlesex", "Malden"),
    ("D013", "Medford Public Schools", "Middlesex", "Medford"),
    ("D014", "Revere Public Schools", "Suffolk", "Revere"),
    ("D015", "Chelsea Public Schools", "Suffolk", "Chelsea"),
    ("D016", "Everett Public Schools", "Middlesex", "Everett"),
    ("D017", "Lynn Public Schools", "Essex", "Lynn"),
    ("D018", "Salem Public Schools", "Essex", "Salem"),
    ("D019", "Peabody Public Schools", "Essex", "Peabody"),
    ("D020", "Beverly Public Schools", "Essex", "Beverly"),
    ("D021", "Milton Public Schools", "Norfolk", "Milton"),
    ("D022", "Dedham Public Schools", "Norfolk", "Dedham"),
    ("D023", "Natick Public Schools", "Middlesex", "Natick"),
    ("D024", "Framingham Public Schools", "Middlesex", "Framingham"),
    ("D025", "Watertown Public Schools", "Middlesex", "Watertown"),
]

# Name components
FIRST_NAMES = [
    "Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason",
    "Isabella", "William", "Mia", "James", "Charlotte", "Benjamin", "Amelia",
    "Lucas", "Harper", "Henry", "Evelyn", "Alexander", "Abigail", "Michael",
    "Emily", "Daniel", "Elizabeth", "Jacob", "Sofia", "Logan", "Avery",
    "Wei", "Ming", "Yuki", "Hiroshi", "Priya", "Raj", "Fatima", "Ahmed",
    "Jose", "Maria", "Carlos", "Ana", "Miguel", "Carmen", "Luis", "Rosa"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
    "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
    "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
    "Chen", "Kim", "Patel", "Shah", "Wang", "Zhang", "Singh", "Kumar",
    "Nguyen", "Tran", "O'Connor", "Murphy", "Sullivan", "Kelly", "Cohen"
]

SCHOOL_NAME_PARTS = [
    ("Lincoln", "Elementary"),
    ("Washington", "Elementary"),
    ("Kennedy", "Elementary"),
    ("Roosevelt", "Elementary"),
    ("Franklin", "Elementary"),
    ("Oak Hill", "Elementary"),
    ("Maple Grove", "Elementary"),
    ("Riverside", "Elementary"),
    ("Martin Luther King Jr.", "Middle"),
    ("Central", "Middle"),
    ("North", "Middle"),
    ("South", "Middle"),
    ("Heritage", "Middle"),
    ("Innovation", "Middle"),
    ("Regional", "High"),
    ("Memorial", "High"),
    ("Technical", "High"),
    ("Academy", "High"),
    ("Preparatory", "High"),
]


class SyntheticDataGenerator:
    """Generate synthetic Massachusetts school district data"""
    
    def __init__(self, seed: int = 42):
        """Initialize generator with random seed for reproducibility"""
        random.seed(seed)
        self.districts: List[District] = []
        self.schools: List[School] = []
    
    def generate_ssn(self) -> str:
        """Generate fake SSN (not real)"""
        area = random.randint(100, 999)
        group = random.randint(10, 99)
        serial = random.randint(1000, 9999)
        return f"{area:03d}-{group:02d}-{serial:04d}"
    
    def generate_phone(self, area_code: str = "617") -> str:
        """Generate phone number"""
        exchange = random.randint(200, 999)
        subscriber = random.randint(1000, 9999)
        return f"{area_code}-{exchange:03d}-{subscriber:04d}"
    
    def generate_date_of_birth(self, min_age: int, max_age: int) -> str:
        """Generate date of birth for given age range"""
        today = datetime.now()
        age = random.randint(min_age, max_age)
        days_offset = random.randint(0, 365)
        dob = today - timedelta(days=(age * 365) + days_offset)
        return dob.strftime("%Y-%m-%d")
    
    def generate_districts(self) -> List[Dict]:
        """Generate district records"""
        districts = []
        superintendent_names = [
            "Dr. Sarah Johnson", "Dr. Michael Chen", "Dr. Patricia Williams",
            "Dr. Robert Garcia", "Dr. Jennifer Martinez", "Dr. David Brown",
            "Dr. Elizabeth Taylor", "Dr. James Wilson", "Dr. Maria Rodriguez",
            "Dr. Thomas Anderson"
        ]
        
        for i, (did, name, county, city) in enumerate(MA_DISTRICTS):
            district = {
                "district_id": did,
                "district_name": name,
                "county": county,
                "city": city,
                "state": "MA",
                "superintendent_name": superintendent_names[i % len(superintendent_names)],
                "phone_main": self.generate_phone(),
                "website": f"https://www.{name.lower().replace(' ', '')}.org",
                "current_school_year": "2025-2026"
            }
            districts.append(district)
            self.districts.append(District(**{k: v for k, v in district.items() 
                                             if k in District.__annotations__}))
        
        return districts
    
    def generate_schools(self, count: int = 250) -> List[Dict]:
        """Generate school records"""
        schools = []
        school_id = 1
        
        # Distribute schools across districts
        schools_per_district = count // len(self.districts)
        
        for district in self.districts:
            for _ in range(schools_per_district):
                name_part, school_type = random.choice(SCHOOL_NAME_PARTS)
                
                if school_type == "Elementary":
                    capacity = random.randint(300, 600)
                    grade_range = "K-5"
                elif school_type == "Middle":
                    capacity = random.randint(500, 900)
                    grade_range = "6-8"
                else:  # High
                    capacity = random.randint(800, 1500)
                    grade_range = "9-12"
                
                school = {
                    "school_id": f"SCH-{school_id:04d}",
                    "school_name": f"{name_part} {school_type} School",
                    "school_type": school_type,
                    "grade_levels_served": grade_range,
                    "is_title_i": random.random() < 0.3,
                    "is_charter": random.random() < 0.05,
                    "district_id": district.district_id,
                    "district_name": district.district_name,
                    "address": f"{random.randint(100, 999)} Main Street",
                    "city": district.city,
                    "state": "MA",
                    "zip_code": f"02{random.randint(100, 199)}",
                    "county": district.county,
                    "phone_main": self.generate_phone(),
                    "building_capacity": capacity,
                    "current_enrollment": int(capacity * random.uniform(0.7, 0.95)),
                    "teacher_count": capacity // random.randint(15, 25),
                    "principal_name": f"Principal {random.choice(LAST_NAMES)}",
                    "attendance_rate": round(random.uniform(92, 98), 1),
                    "graduation_rate": round(random.uniform(85, 98), 1) if school_type == "High" else None
                }
                schools.append(school)
                school_id += 1
        
        self.schools = [School(
            school_id=s["school_id"],
            school_name=s["school_name"],
            school_type=s["school_type"],
            district_id=s["district_id"],
            city=s["city"],
            county=s["county"],
            zip_code=s["zip_code"],
            capacity=s["building_capacity"],
            principal_name=s["principal_name"]
        ) for s in schools]
        
        return schools
    
    def generate_students(self, count: int = 100000) -> List[Dict]:
        """Generate student records"""
        students = []
        
        ethnicities = ["White", "Hispanic/Latino", "Black/African American", 
                      "Asian", "Two or More Races"]
        ethnicity_weights = [0.55, 0.2, 0.1, 0.1, 0.05]
        
        languages = ["English", "Spanish", "Portuguese", "Chinese", 
                    "Vietnamese", "Haitian Creole"]
        language_weights = [0.75, 0.1, 0.05, 0.03, 0.03, 0.04]
        
        for i in range(count):
            school = random.choice(self.schools)
            
            # Determine grade based on school type
            if school.school_type == "Elementary":
                grade = random.choice(["K", "01", "02", "03", "04", "05"])
                age_range = (5, 11)
            elif school.school_type == "Middle":
                grade = random.choice(["06", "07", "08"])
                age_range = (11, 14)
            else:
                grade = random.choice(["09", "10", "11", "12"])
                age_range = (14, 18)
            
            student = {
                "student_id": f"STU-{i+1:06d}",
                "first_name": random.choice(FIRST_NAMES),
                "last_name": random.choice(LAST_NAMES),
                "ssn": self.generate_ssn(),
                "state_id": f"MA-{i+1:08d}",
                "date_of_birth": self.generate_date_of_birth(*age_range),
                "gender": random.choice(["Male", "Female", "Non-binary"]) 
                         if random.random() < 0.02 else random.choice(["Male", "Female"]),
                "ethnicity": random.choices(ethnicities, weights=ethnicity_weights)[0],
                "primary_language": random.choices(languages, weights=language_weights)[0],
                "ell_status": random.random() < 0.1,
                "home_address_line1": f"{random.randint(1, 9999)} {random.choice(['Oak', 'Maple', 'Main', 'Park'])} Street",
                "city": school.city,
                "state": "MA",
                "zip_code": school.zip_code,
                "county": school.county,
                "current_school_id": school.school_id,
                "current_district_id": school.district_id,
                "grade_level": grade,
                "enrollment_status": "Active",
                "special_education": random.random() < 0.14,
                "section_504": random.random() < 0.05,
                "gifted_talented": random.random() < 0.07,
                "free_reduced_lunch": random.choice(["Free", "Reduced", "Full", "Full"]),
                "homeless_status": random.random() < 0.02
            }
            students.append(student)
        
        return students
    
    def generate_staff(self, count: int = 12000) -> List[Dict]:
        """Generate staff records"""
        staff = []
        
        roles = [
            ("Teacher", 0.7),
            ("Special Education Teacher", 0.1),
            ("Administrator", 0.05),
            ("Counselor", 0.03),
            ("Paraprofessional", 0.07),
            ("Support Staff", 0.05)
        ]
        
        departments = [
            "Mathematics", "English Language Arts", "Science", 
            "Social Studies", "Special Education", "Physical Education",
            "Arts", "World Languages", "General"
        ]
        
        for i in range(count):
            school = random.choice(self.schools)
            role = random.choices([r[0] for r in roles], weights=[r[1] for r in roles])[0]
            
            staff_member = {
                "staff_id": f"S-{i+1:05d}",
                "first_name": random.choice(FIRST_NAMES),
                "last_name": random.choice(LAST_NAMES),
                "email": f"staff{i+1}@district.edu",
                "ssn": self.generate_ssn(),
                "date_of_birth": self.generate_date_of_birth(25, 65),
                "phone_work": self.generate_phone(),
                "phone_mobile": self.generate_phone(),
                "employee_type": "Full-Time" if random.random() < 0.9 else "Part-Time",
                "position_title": role,
                "role_category": role if role in ["Teacher", "Administrator", "Counselor"] else "Support",
                "department": random.choice(departments),
                "primary_school_id": school.school_id,
                "district_id": school.district_id,
                "hire_date": (datetime.now() - timedelta(days=random.randint(30, 10000))).strftime("%Y-%m-%d"),
                "employment_status": "Active",
                "highest_degree": random.choice(["Bachelor", "Master", "Master", "Doctorate"]),
                "years_experience": random.randint(1, 35),
                "salary": random.randint(45000, 95000)
            }
            staff.append(staff_member)
        
        return staff
    
    def generate_guardians(self, count: int = 150000) -> List[Dict]:
        """Generate guardian/parent records"""
        guardians = []
        
        relationships = ["Mother", "Father", "Grandmother", "Grandfather", 
                        "Legal Guardian", "Foster Parent"]
        relationship_weights = [0.4, 0.4, 0.08, 0.05, 0.05, 0.02]
        
        for i in range(count):
            guardian = {
                "guardian_id": f"G-{i+1:06d}",
                "first_name": random.choice(FIRST_NAMES),
                "last_name": random.choice(LAST_NAMES),
                "relationship_type": random.choices(relationships, weights=relationship_weights)[0],
                "email_primary": f"parent{i+1}@gmail.com",
                "phone_home": self.generate_phone(),
                "phone_mobile": self.generate_phone(),
                "address_line1": f"{random.randint(1, 9999)} {random.choice(['Oak', 'Maple', 'Main'])} Street",
                "city": random.choice([d.city for d in self.districts]),
                "state": "MA",
                "zip_code": f"02{random.randint(100, 199)}",
                "preferred_language": random.choice(["English", "Spanish", "Portuguese", "Chinese"]),
                "portal_account_active": random.random() < 0.8
            }
            guardians.append(guardian)
        
        return guardians
    
    def generate_all(self) -> Dict[str, List[Dict]]:
        """Generate all synthetic data"""
        print("Generating districts...")
        districts = self.generate_districts()
        
        print("Generating schools...")
        schools = self.generate_schools(250)
        
        print("Generating students...")
        students = self.generate_students(100000)
        
        print("Generating staff...")
        staff = self.generate_staff(12000)
        
        print("Generating guardians...")
        guardians = self.generate_guardians(150000)
        
        return {
            "districts": districts,
            "schools": schools,
            "students": students,
            "staff": staff,
            "guardians": guardians
        }


def main():
    """CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate synthetic school district data")
    parser.add_argument(
        "--output-dir",
        "-o",
        default="./data",
        help="Output directory for generated JSON files"
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for reproducibility"
    )
    parser.add_argument(
        "--students",
        type=int,
        default=100000,
        help="Number of students to generate"
    )
    
    args = parser.parse_args()
    
    generator = SyntheticDataGenerator(seed=args.seed)
    
    print("Starting synthetic data generation...")
    data = generator.generate_all()
    
    print(f"\nGeneration complete!")
    print(f"  Districts: {len(data['districts'])}")
    print(f"  Schools: {len(data['schools'])}")
    print(f"  Students: {len(data['students'])}")
    print(f"  Staff: {len(data['staff'])}")
    print(f"  Guardians: {len(data['guardians'])}")


if __name__ == "__main__":
    main()
