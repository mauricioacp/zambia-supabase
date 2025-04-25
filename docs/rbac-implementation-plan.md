## Frontend-Backend Integration

### Authentication Flow

1. User logs in via the `AuthService.signIn()` method.
2. Supabase authenticates the user and returns a session with a JWT token.
3. The JWT token includes the user's roles in the `user_metadata` claim.
4. The `AuthService` stores the session and exposes the user's roles via the `userRoles` computed signal.
5. The `RolesService` uses the user's roles to determine their permissions.

### Data Access Flow

1. User navigates to a route protected by `rolesGuard` or `roleLevelGuard`.
2. Guard checks if the user has the required roles or role level.
3. If authorized, the component is loaded and makes API requests to Supabase.
4. Supabase applies RLS policies based on the user's JWT token.
5. Only authorized data is returned to the component.

```typescript
// Data access flow in a service
public getDashboardStats(): Observable<DashboardStat[]> {
  const supabase = this.supabaseService.getClient();

  // Call RPC function for global stats
  return from(supabase.rpc('get_global_dashboard_stats')).pipe(
    map(response => this.supabaseService.handleResponse(response, 'Fetch Dashboard Stats')),
    map(data => this.mapToStatsList(data))
  );
}
```

## Role-Based Dashboard Design

### Component Structure

The dashboard is structured as a set of components that adapt to the user's role:

1. **DashboardSmartComponent**: The main dashboard component that includes the sidebar and layout.
2. **PanelSmartComponent**: The main dashboard panel that displays role-specific content.
3. **StatsWidgetComponent**: Displays statistics relevant to the user's role.
4. **RecentActivityComponent**: Displays recent activities relevant to the user's role.
5. **RoleSpecificSummaryComponent**: Displays summaries specific to the user's role (e.g., headquarter summary for managers).

```typescript
// PanelSmartComponent structure
@Component({
  selector: 'z-panel',
  standalone: true,
  imports: [CommonModule, RouterLink, HasRoleDirective, HasAnyRoleDirective, HasRoleLevelDirective],
  template: `
    <div class="p-6">
      <h1 class="mb-6 text-2xl font-bold">Panel de Control</h1>

      <!-- Welcome message based on role -->
      <div class="mb-8 rounded-lg bg-white p-6 shadow-md">
        <h2 class="mb-2 text-xl font-semibold">Bienvenido, {{ getUserDisplayName() }}</h2>
        <p class="text-gray-600">
          @if (rolesService.hasRole(Role.SUPERADMIN)) {
            Tienes acceso completo a todas las funciones del sistema.
          } @else if (rolesService.hasRole(Role.GENERAL_DIRECTOR)) {
            Tienes acceso a la información de todas las sedes.
          } @else if (rolesService.hasRole(Role.HEADQUARTER_MANAGER)) {
            Tienes acceso a la información de tu sede.
          } @else {
            Bienvenido al sistema.
          }
        </p>
      </div>

      <!-- Stats Section -->
      <div class="mb-8">
        <h2 class="mb-4 text-xl font-semibold">Estadísticas</h2>
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          @for (stat of stats(); track stat.label) {
            <div class="rounded-lg bg-white p-4 shadow-md">
              <!-- Stat content -->
            </div>
          }
        </div>
      </div>

      <!-- Role-specific sections -->
      <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <!-- Admin Section -->
        <div *hasRole="Role.SUPERADMIN" class="rounded-lg bg-white p-6 shadow-md">
          <!-- Admin content -->
        </div>

        <!-- Director Section -->
        <div *hasAnyRole="[Role.GENERAL_DIRECTOR, Role.EXECUTIVE_LEADER]" class="rounded-lg bg-white p-6 shadow-md">
          <!-- Director content -->
        </div>

        <!-- Headquarter Manager Section -->
        <div *hasRoleLevel="Role.HEADQUARTER_MANAGER" class="rounded-lg bg-white p-6 shadow-md">
          <!-- Manager content -->
        </div>

        <!-- Recent Activity Section - visible to all -->
        <div class="rounded-lg bg-white p-6 shadow-md">
          <!-- Recent activity content -->
        </div>
      </div>
    </div>
  `,
})
export class PanelSmartComponent {
  // Component implementation
}
```

### Data Fetching Strategy

The dashboard uses a dedicated service (`DashboardDataService`) to fetch role-specific data from Supabase:

```typescript
// DashboardDataService
@Injectable({
  providedIn: 'root',
})
export class DashboardDataService {
  private supabaseService = inject(SupabaseService);
  private authService = inject(AuthService);
  private rolesService = inject(RolesService);

  public getDashboardStats(): Observable<DashboardStat[]> {
    const supabase = this.supabaseService.getClient();

    if (this.rolesService.hasRole(Role.SUPERADMIN) || this.rolesService.hasRole(Role.GENERAL_DIRECTOR)) {
      // Call RPC function for global stats
      return from(supabase.rpc('get_global_dashboard_stats')).pipe(
        map((response) => this.supabaseService.handleResponse(response, 'Fetch Dashboard Stats')),
        map((data) => this.mapToStatsList(data))
      );
    } else if (this.rolesService.hasRole(Role.HEADQUARTER_MANAGER)) {
      // Call RPC function for headquarter-specific stats
      return from(supabase.rpc('get_headquarter_dashboard_stats')).pipe(
        map((response) => this.supabaseService.handleResponse(response, 'Fetch Dashboard Stats')),
        map((data) => this.mapToStatsList(data))
      );
    } else {
      // Call RPC function for user-specific stats
      return from(supabase.rpc('get_user_dashboard_stats')).pipe(
        map((response) => this.supabaseService.handleResponse(response, 'Fetch Dashboard Stats')),
        map((data) => this.mapToStatsList(data))
      );
    }
  }

  // Other methods for fetching role-specific data
}
```

This service calls different RPC functions based on the user's role, ensuring that only authorized data is fetched and displayed.

### Role-Specific Views

The dashboard displays different views based on the user's role:

1. **SUPERADMIN**: Full access to all data and functionality, including agreement management and user creation.
2. **GENERAL_DIRECTOR**: Access to aggregated data across all headquarters, with the ability to drill down into specific headquarters.
3. **HEADQUARTER_MANAGER**: Access to data for their specific headquarter, including students, facilitators, and workshops.
4. **FACILITATOR/COMPANION**: Access to data for their assigned students and workshops.
5. **STUDENT**: Access to their own data, enrolled workshops, and assignments.

Each view includes relevant statistics, recent activities, and action buttons appropriate for the user's role.

## Scalability and Maintainability

### Centralized Role Definitions

Roles are defined in a centralized location (`GUARDS_CONSTANTS.ts`) to ensure consistency across the application:

```typescript
export const Role = {
  /* level 100 */
  SUPERADMIN: 'superadmin',
  /* level 90 */
  GENERAL_DIRECTOR: 'general_director',
  EXECUTIVE_LEADER: 'executive_leader',
  /* level 80 */
  PEDAGOGICAL_LEADER: 'pedagogical_leader',
  // ... other roles
} as const;

export type RoleCode = (typeof Role)[keyof typeof Role];
```

This approach makes it easy to add, remove, or modify roles without having to update multiple files.

### Role Hierarchy Management

The role hierarchy is defined in the `RolesService` using a Map that assigns a level to each role:

```typescript
private readonly roleLevels = new Map<RoleCode, number>([
  [Role.SUPERADMIN, 100],
  [Role.GENERAL_DIRECTOR, 90],
  [Role.EXECUTIVE_LEADER, 90],
  // ... other roles
]);
```

This approach makes it easy to adjust the role hierarchy without having to update multiple files.

### Testing Strategy

To ensure the RBAC system works correctly, the following testing approach is recommended:

1. **Unit Tests**: Test individual components of the RBAC system, such as directives, guards, and services.
2. **Integration Tests**: Test the interaction between frontend and backend components, ensuring that RLS policies are correctly applied.
3. **End-to-End Tests**: Test the complete user flow, from login to accessing protected resources.


### Documentation

To ensure the RBAC system is well-documented and maintainable, the following documentation is recommended:

1. **Code Comments**: All components of the RBAC system should be well-commented, explaining their purpose and usage.
2. **API Documentation**: The public API of the RBAC system should be documented using JSDoc comments.
3. **Usage Examples**: Provide examples of how to use the RBAC system in different scenarios.
4. **Architecture Diagrams**: Create diagrams that illustrate the architecture of the RBAC system and how its components interact.

## Implementation Roadmap

1. **Phase 1: Frontend RBAC Components**

   - Implement structural directives (`HasRoleDirective`, `HasAnyRoleDirective`, `HasRoleLevelDirective`)
   - Implement route guards (`rolesGuard`, `roleLevelGuard`)
   - Implement `RolesService` with role hierarchy

2. **Phase 2: Backend RLS Policies**

   - Implement RLS policies for all tables
   - Implement RPC functions for complex operations
   - Test policies and functions to ensure they work correctly

3. **Phase 3: Role-Based Dashboard**

   - Implement `DashboardDataService` for fetching role-specific data
   - Implement role-specific dashboard components
   - Test dashboard with different user roles
