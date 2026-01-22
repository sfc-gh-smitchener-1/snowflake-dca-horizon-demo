# Sample Questions for Cortex Analyst

> 100+ sample questions organized by persona and semantic model for natural language analytics on Massachusetts school district data.

---

## District Leadership Questions

### Enrollment & Demographics

1. "What is the total enrollment by district?"
2. "Show me enrollment trends over the past 5 years"
3. "Which districts have the highest student growth rate?"
4. "What is the breakdown of students by grade level?"
5. "How many students are classified as English Language Learners?"
6. "What percentage of students qualify for free or reduced lunch?"
7. "Show me the demographic breakdown by ethnicity across districts"
8. "Which schools are over or under capacity?"
9. "What is the student-to-teacher ratio by district?"
10. "How many new students enrolled this year vs. last year?"

### Academic Performance

11. "What is the average graduation rate by district?"
12. "Which districts have the highest SAT/MCAS scores?"
13. "Show me the trend in math proficiency over 5 years"
14. "What percentage of students are meeting grade-level standards?"
15. "Which schools have the most improvement in reading scores?"
16. "Compare AP course enrollment across districts"
17. "What is the college enrollment rate for graduates?"
18. "Which districts have the largest achievement gaps?"
19. "Show me dropout rates by district and grade level"
20. "What is the average GPA by district and school type?"

### Attendance & Behavior

21. "What is the chronic absenteeism rate by district?"
22. "Which schools have the highest attendance rates?"
23. "Show me attendance patterns by day of week"
24. "What is the suspension rate across districts?"
25. "Which grade levels have the highest absenteeism?"
26. "Compare attendance rates between elementary and high school"
27. "What is the trend in chronic absenteeism over 3 years?"
28. "Which schools saw the biggest improvement in attendance?"
29. "Show me the correlation between attendance and grades"
30. "What percentage of students have perfect attendance?"

### Staff & Resources

31. "How many teachers are there per district?"
32. "What is the average teacher experience by district?"
33. "Which schools have the highest teacher turnover?"
34. "How many open teaching positions are there?"
35. "What is the breakdown of staff by role type?"
36. "Which districts have the most diverse teaching staff?"
37. "What is the average teacher salary by district?"
38. "How many teachers have advanced degrees?"
39. "What is the counselor-to-student ratio by school?"
40. "Show me substitute teacher usage by month"

---

## Principal Questions

### School Performance

41. "How are my students performing compared to the district average?"
42. "Which grade levels are struggling in math?"
43. "Show me the top 10 performing students by GPA"
44. "What is the pass rate for state assessments at my school?"
45. "Which courses have the highest failure rates?"
46. "How does my school compare to similar schools?"
47. "What is the trend in our school's rating over 5 years?"
48. "Which students improved the most from last semester?"
49. "Show me grade distributions by subject"
50. "What percentage of seniors are on track to graduate?"

### Student Engagement

51. "Which students are chronically absent at my school?"
52. "Show me attendance patterns for the current month"
53. "Which homerooms have the best attendance?"
54. "How many students are in extracurricular activities?"
55. "What is our tardy rate by period?"
56. "Which students have had discipline referrals this year?"
57. "Show me participation in after-school programs"
58. "How many students use the school library regularly?"
59. "What is our retention rate vs. other schools?"
60. "Which grade has the most behavior incidents?"

### Staff Management

61. "Which teachers have the highest student performance?"
62. "Show me professional development hours by teacher"
63. "What is our staff absence rate this month?"
64. "Which classes have had the most substitute coverage?"
65. "How are new teachers performing vs. experienced ones?"
66. "What is teacher satisfaction based on surveys?"
67. "Which departments have open positions?"
68. "Show me class sizes by teacher"
69. "What is our staff retention rate?"
70. "Which teachers are due for evaluations?"

---

## Teacher Questions

### Classroom Performance

71. "What are the grades for my Period 3 class?"
72. "Which students are below passing in my algebra class?"
73. "Show me the grade distribution for my last test"
74. "What is the class average for the homework assignment?"
75. "Which students improved from the last quiz?"
76. "Show me missing assignments for this week"
77. "What is the overall GPA for my advisory students?"
78. "Which students are on the honor roll?"
79. "Show me grade trends for Student X over the semester"
80. "What percentage of my students passed the unit test?"

### Attendance & Participation

81. "Which of my students have missed more than 5 days?"
82. "Show me today's attendance for all my classes"
83. "Which students were absent yesterday?"
84. "What is the attendance rate for my homeroom?"
85. "Which students are frequently tardy?"
86. "Show me attendance patterns for my struggling students"
87. "Which students have perfect attendance this month?"
88. "What is the absence rate for my first period class?"
89. "Show me students who missed the test and need makeups"
90. "Which days have the lowest attendance?"

---

## Counselor Questions

### At-Risk Students

91. "Which students are at risk of not graduating?"
92. "Show me students with declining GPA this semester"
93. "Which students have high absence rates and low grades?"
94. "What is the caseload summary for my assigned students?"
95. "Which students need credit recovery?"
96. "Show me students with 504 plans in my caseload"
97. "Which seniors are missing required courses?"
98. "What is the intervention success rate?"
99. "Which students have shown improvement after counseling?"
100. "Show me students who need schedule changes"

### College & Career

101. "How many seniors have applied to college?"
102. "What is the average SAT score for my caseload?"
103. "Which students have completed FAFSA?"
104. "Show me scholarship applications by student"
105. "Which students are interested in vocational programs?"

---

## Parent Portal Questions

### My Child's Progress

106. "What are my child's current grades?"
107. "When is the next parent-teacher conference?"
108. "What assignments are due this week?"
109. "Show me my child's attendance record"
110. "What is my child's GPA compared to last semester?"
111. "When is the next report card?"
112. "What courses is my child enrolled in?"
113. "Who are my child's teachers and how can I contact them?"
114. "What after-school activities is my child in?"
115. "Are there any missing assignments?"

---

## Governance Questions

### Contract & Data Health

116. "How many data contracts are active?"
117. "Which contracts have SLA violations?"
118. "What is the overall data quality score?"
119. "Show me contracts with failing quality rules"
120. "Which tables have stale data?"
121. "What is the tag coverage percentage?"
122. "Which columns are missing FERPA tags?"
123. "Show me recent data quality trends"
124. "What is the freshness SLA compliance rate?"
125. "Which contracts need attention?"

### Access & Compliance

126. "Who accessed student data in the last 24 hours?"
127. "Show me access patterns by role"
128. "Which users accessed sensitive PII?"
129. "What tables have the most query activity?"
130. "Are there any unusual access patterns?"
131. "Show me the audit log for student records"
132. "Which roles have PII access?"
133. "What is the FERPA compliance score?"
134. "Show me data access by time of day"
135. "Which external systems accessed our data?"

---

## How to Use These Questions

### In Cortex Analyst

1. Navigate to the Streamlit app
2. Select the appropriate semantic model:
   - `DISTRICT_ANALYTICS` for leadership questions
   - `SCHOOL_PERFORMANCE` for principal questions
   - `CLASSROOM_ANALYTICS` for teacher questions
   - `STUDENT_SUCCESS` for counselor questions
   - `GOVERNANCE_ANALYTICS` for compliance questions

3. Type or speak your question
4. Review the generated SQL and results
5. The response respects your role's masking and row access policies

### Tips for Better Results

- Be specific about time periods ("this month", "last year", "past 5 years")
- Use entity names when possible ("Boston district", "Lincoln Elementary")
- Ask follow-up questions to drill down
- The system understands synonyms ("kids" = "students", "teachers" = "staff")

### Sample Follow-up Patterns

**Initial**: "What is the average GPA by school?"
**Follow-up**: "Show me just the top 5"
**Follow-up**: "Now show elementary schools only"
**Follow-up**: "Compare to last year"
