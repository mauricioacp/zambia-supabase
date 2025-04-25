# Akademia Registration Process Guide

## Step-by-Step Registration Process

### 1. Initial Registration
- **User Action**: Completes the registration form with:
  - Personal details (name, email, document number, phone)
  - Selected headquarters and role
  - Current headquarter season will be assigned
  - Agreement consents (volunteering, ethical document, etc.)
  - Digital signature
- **System Action**: Creates an `agreements` record with:
  - Status set to `prospect`
  - All personal information fields populated
  - Role, headquarter,season, and agreement fields set
  - No user_id (these remain NULL)

### 2. Administrative Review
- **Admin Action**: Reviews the prospect registration application
- **Admin Decision**: Approve or reject the application
  - If rejected: Agreement status is set to `inactive`
  - If approved: Process continues to account creation

### 3. Account Creation
- **System Action**: Creates a Supabase auth user account
  - Uses the email from the agreement record
  - Sets a secure initial password
- **System Action**: Updates the agreement record:
  - Links the new `user_id` to the agreement
  - Assigns appropriate `season_id`
  - Updates other necessary fields

### 4. Role-Based Record Creation
- **System Action**: Based on the user's role, creates:
  - **For students**: Record in the `students` table
  - **For collaborators**: Record in the `collaborators` table
  - **For konsejo members**: Records in both `collaborators` and `konsejo_members` tables
- **System Action**: Sets agreement status to `active`

### 5. Credential Delivery (Two Options)
- **Option 1: In-Person Delivery**
  - Administrator provides login credentials directly to the user
  - We may use in mail delivery in MVP2
  
- **Option 2: Self-Service Password Reset**
  - User uses a "forgot password" feature
  - Validates identity using their:
    - Document number
    - Email
    - Phone number
  - Sets their own password

### 6. System Access
- User can now log in to the system
- Access is granted based on their role permissions

<br>

```mermaid 
flowchart TD
    A[User Completes Registration Form] --> B[System Creates Agreement Record]
    B --> C[Status: PROSPECT]
    C --> D[Administrator Reviews Application]
    
    D -->|Rejected| E[Status: INACTIVE]
    D -->|Approved| F[Create Supabase Auth User]
    
    F --> G[Update Agreement with User ID]
    G --> H[Create Role-Specific Record Collaborator/Student]
    
    H -->|Student Role| I[Create Student Record]
    H -->|Other Roles| J[Create Collaborator Record]

    
    I --> L[Status: ACTIVE]
    J --> L
    
    L --> M[User Gets Credentials]
    L --> N[User Resets Password Using Personal Info]
    
    M --> O[User Can Log In]
    N --> O
    
    classDef process fill:#d4f1f9,stroke:#05a0c8,stroke-width:2px;
    classDef decision fill:#ffe6cc,stroke:#d79b00,stroke-width:2px;
    classDef status fill:#d5e8d4,stroke:#82b366,stroke-width:2px;
    classDef user fill:#e1d5e7,stroke:#9673a6,stroke-width:2px;
    
    class A,M,N,O user;
    class B,F,G,H,I,J,K process;
    class D decision;
    class C,E,L status;
```