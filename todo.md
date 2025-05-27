#### **✅ Required Database Functions:**

##### **For Level 51+ Users (Global View):**
- [ ] **Create `get_homepage_statistics()` Supabase function** returning:
  ```sql
  {
    total_countries: number,
    total_headquarters: number,
    total_agreements: number,
    total_workshops: number,
    total_students: number,
    active_seasons: number,
    recent_activity_count: number,
    system_health_metrics: object
  }
  ```

##### **For Level 50 Users (HQ Directors):**
- [ ] **Create `get_homepage_statistics_hq(p_hq_id, p_season_id)` Supabase function** returning:
  ```sql
  {
    hq_agreements_count: number,
    hq_workshops_count: number,
    hq_students_count: number,
    enrollment_trends: object,
    completion_rates: object,
    upcoming_workshops: array,
    recent_agreements: array
  }
  ```
## 📊 **MEDIUM PRIORITY TASKS**

### **3. Role-Based KPI Data Architecture**

#### **Level 51+ Users (Global Leaders) KPI Design:**
- [ ] **Design role-specific KPI data structure for level 51+ users:**
    - **Global Countries Overview**: Total countries, active operations, expansion opportunities
    - **Global Headquarters Network**: Total HQs, regional distribution, capacity utilization (agreements per regional distribution)
    - **Organization-wide Agreements**: Total agreements, compliance rates, role distribution
    - **Workshop Completion Rates**: System-wide completion
    - **Student Enrollment Trends**: Cross-country enrollment, success metrics
    - **System Performance Metrics**: Platform health, user activity, operational efficiency

#### **Level 50 Users (HQ Directors) KPI Design:**
- [ ] **Design HQ-specific KPI data structure for level 50 users:**
    - **Local Headquarters Stats**: Capacity (usually each headquarter per season should have 25 students), utilization, facility status
    - **Regional Agreement Status**: HQ-specific agreements, local compliance, verification rates
    - **Workshop Schedule & Attendance**: Local workshops, attendance trends, facilitator availability
    - **Student Progress Tracking**: HQ student enrollment, progress rates, completion status
    - **Resource Utilization**: Local resource usage, budget tracking, efficiency metrics
    - **Monthly Performance Trends**: Month-over-month growth, seasonal patterns, goal tracking
---

### **4. Advanced Analytics Functions**

#### **Activity & Engagement:**
- [ ] **Create `get_recent_activity(p_user_role, p_hq_id, p_limit)` function** for activity feed showing role-appropriate recent actions:
    - New agreements signed
    - Workshop completions
    - Student enrollments
    - System updates and notifications

#### **Workshop Analytics:**
- [ ] **Create `get_workshop_analytics(p_hq_id, p_season_id)` function** returning:
  ```sql
  {
    total_workshops: number,
    completed_workshops: number,
    avg_attendance: number,
    facilitator_performance: object,
    upcoming_schedule: array,
    completion_trends: object
  }
  ```

#### **Agreement Analytics:**
- [ ] **Create `get_agreement_analytics(p_hq_id, p_season_id)` function** returning:
  ```sql
  {
    total_agreements: number,
    by_status_breakdown: object,
    verification_rates: object,
    role_distribution: object,
    monthly_trends: object,
    document_completion_rates: object
  }
  ```

#### **Student Analytics:**
- [ ] **Create `get_student_analytics(p_hq_id, p_season_id)` function** returning:
  ```sql
  {
    total_students: number,
    enrollment_status: object,
    workshop_attendance_rates: object,
    progress_tracking: object,
    dropout_analysis: object,
    performance_metrics: object
  }
  ```

### **6. System Administration**

#### **System Health Monitoring:**
- [ ] **Create `get_system_health_metrics()` function** for administrators returning:
  ```sql
  {
    database_performance: object,
    active_users: number,
    error_rates: object,
    backup_status: object,
    security_metrics: object,
    resource_usage: object
  }
  ```
