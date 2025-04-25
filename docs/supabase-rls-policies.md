# Supabase Row-Level Security (RLS) Policies

This document outlines the Row-Level Security (RLS) policies for the Akademia application's Supabase database. These policies ensure that users can only access and modify data according to their assigned roles and permissions.

## Table of Contents

1. [Overview](#overview)
2. [Role Hierarchy](#role-hierarchy)
3. [RLS Policies by Table](#rls-policies-by-table)
   - [Headquarters Table](#headquarters-table)
   - [Students Table](#students-table)
   - [Collaborators Table](#collaborators-table)
   - [Agreements Table](#agreements-table)
   - [Workshops Table](#workshops-table)
4. [Database Functions (RPC)](#database-functions-rpc)
5. [Security Considerations](#security-considerations)

## Overview

Row-Level Security (RLS) in Supabase allows us to define access policies at the row level for each table. These policies are enforced by the database itself, ensuring that users can only access data they are authorized to see, regardless of how the data is accessed (API, direct SQL, etc.).

Our RLS strategy follows these principles:

1. **Default Deny**: All tables have RLS enabled with a default deny policy, meaning no access is granted unless explicitly allowed by a policy.
2. **Role-Based Access**: Policies are primarily based on user roles stored in the JWT token.
3. **Scope-Based Restrictions**: Users are restricted to data within their scope (e.g., headquarter managers can only access data for their headquarter). The relation is Agreement - Role - User - and depending on the user role a headquarters or several headquarters are allowed.
4. **Operation-Specific Policies**: Different policies for SELECT, INSERT, UPDATE, and DELETE operations.
5. **Hierarchical Access**: Higher-level roles inherit access from lower-level roles.

## Role Hierarchy

Our application uses the following role hierarchy (from highest to lowest access level):

1. SUPERADMIN (level 100) - Complete access to all data
2. GENERAL_DIRECTOR, EXECUTIVE_LEADER (level 90) - Access to all headquarters and their data, managers, students, collaborators, agreements, countries, etc...
3. Various LEADER roles (level 80) - Access to specific domains across all headquarters, right now it has same level access as level 90 in the future some clause will be added.
4. COORDINATOR, KONSEJO_MEMBER (level 70) - Coordination-level access right now same as level 80
5. HEADQUARTER_MANAGER (level 50) - Access to a specific headquarter and its data, agreements, collaborators, students etc...
6. Various MANAGER roles (level 40) - Access to specific domains within a headquarter right now same as level 50
7. MANAGER_ASSISTANT (level 30) - Limited management access
8. COMPANION, FACILITATOR (level 20) - Access to assigned students/groups
9. STUDENT (level 1) - Access to own data only and events, workshops and part of the headquarter data.

This Roles may change in the near future.

