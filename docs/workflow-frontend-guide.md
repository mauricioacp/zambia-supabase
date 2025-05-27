# Workflow System Frontend Guide

## Headquarters Registration Process Example

This guide demonstrates how to use the Supabase client with TypeScript to implement a headquarters registration workflow.

## Setup

### 1. Install Dependencies

```bash
npm install @supabase/supabase-js
```

### 2. Initialize Supabase Client

```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/supabase.type'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey)

// Type helpers
export type Tables<T extends keyof Database['public']['Tables']> = 
  Database['public']['Tables'][T]['Row']
export type Enums<T extends keyof Database['public']['Enums']> = 
  Database['public']['Enums'][T]
```

## Workflow Types

```typescript
// types/workflow.types.ts
import type { Tables } from '@/lib/supabase'

export type WorkflowTemplate = Tables<'workflow_templates'>
export type WorkflowInstance = Tables<'workflow_instances'>
export type WorkflowAction = Tables<'workflow_actions'>
export type WorkflowStageInstance = Tables<'workflow_stage_instances'>

export interface WorkflowStatus {
  workflow_id: string
  template_name: string
  status: string
  current_stage: string
  total_stages: number
  completed_stages: number
  total_actions: number
  completed_actions: number
  pending_actions: number
  overdue_actions: number
}

export interface PendingAction {
  action_id: string
  workflow_id: string
  workflow_name: string
  stage_name: string
  action_type: string
  priority: 'high' | 'medium' | 'low'
  due_date: string | null
  is_overdue: boolean
  assigned_at: string
}

export interface HeadquartersRegistrationData {
  name: string
  country_id: string
  city: string
  address: string
  contact_email: string
  contact_phone: string
  director_id: string
  capacity: number
  facilities: string[]
}
```

## Workflow Service

```typescript
// services/workflow.service.ts
import { supabase } from '@/lib/supabase'
import type { 
  WorkflowTemplate, 
  WorkflowInstance, 
  WorkflowAction,
  WorkflowStatus,
  PendingAction,
  HeadquartersRegistrationData 
} from '@/types/workflow.types'

export class WorkflowService {
  /**
   * Get available workflow templates
   */
  static async getTemplates() {
    const { data, error } = await supabase
      .from('workflow_templates')
      .select('*')
      .eq('is_active', true)
      .order('name')

    if (error) throw error
    return data as WorkflowTemplate[]
  }

  /**
   * Create a new headquarters registration workflow
   */
  static async createHeadquartersRegistration(data: HeadquartersRegistrationData) {
    // First, find the HQ registration template
    const { data: templates, error: templateError } = await supabase
      .from('workflow_templates')
      .select('id')
      .eq('name', 'Headquarters Registration')
      .single()

    if (templateError) throw templateError

    // Create workflow instance with the HQ data
    const { data: workflowId, error } = await supabase
      .rpc('create_workflow_instance', {
        p_template_id: templates.id,
        p_data: data
      })

    if (error) throw error
    return workflowId as string
  }

  /**
   * Get workflow status and progress
   */
  static async getWorkflowStatus(workflowId: string) {
    const { data, error } = await supabase
      .rpc('get_workflow_status', {
        p_workflow_id: workflowId
      })
      .single()

    if (error) throw error
    return data as WorkflowStatus
  }

  /**
   * Get user's pending actions
   */
  static async getMyPendingActions() {
    const { data, error } = await supabase
      .rpc('get_my_pending_actions')

    if (error) throw error
    return data as PendingAction[]
  }

  /**
   * Get specific workflow instance details
   */
  static async getWorkflowInstance(workflowId: string) {
    const { data, error } = await supabase
      .from('workflow_instances')
      .select(`
        *,
        workflow_templates (
          name,
          description
        ),
        workflow_stage_instances (
          *,
          workflow_template_stages (
            name,
            description
          ),
          workflow_actions (
            *,
            assigned_to_user:auth.users!assigned_to (
              email,
              raw_user_meta_data
            )
          )
        )
      `)
      .eq('id', workflowId)
      .single()

    if (error) throw error
    return data
  }

  /**
   * Complete a workflow action
   */
  static async completeAction(
    actionId: string, 
    result: Record<string, any> = {},
    comment?: string
  ) {
    const { data, error } = await supabase
      .rpc('complete_workflow_action', {
        p_action_id: actionId,
        p_result: result,
        p_comment: comment
      })

    if (error) throw error
    return data
  }

  /**
   * Reject a workflow action
   */
  static async rejectAction(
    actionId: string,
    reason: string,
    comment?: string
  ) {
    const { data, error } = await supabase
      .rpc('reject_workflow_action', {
        p_action_id: actionId,
        p_reason: reason,
        p_comment: comment
      })

    if (error) throw error
    return data
  }

  /**
   * Assign an action to a user
   */
  static async assignAction(
    stageInstanceId: string,
    actionType: string,
    assignedTo: string,
    dueDate?: Date,
    priority: 'high' | 'medium' | 'low' = 'medium'
  ) {
    const { data, error } = await supabase
      .rpc('assign_workflow_action', {
        p_stage_instance_id: stageInstanceId,
        p_action_type: actionType,
        p_assigned_to: assignedTo,
        p_due_date: dueDate?.toISOString(),
        p_priority: priority,
        p_data: {}
      })

    if (error) throw error
    return data as string
  }
}
```

## React Components

### Workflow Creation Component

```tsx
// components/workflows/CreateHeadquartersWorkflow.tsx
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { WorkflowService } from '@/services/workflow.service'
import type { HeadquartersRegistrationData } from '@/types/workflow.types'

export function CreateHeadquartersWorkflow() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState<HeadquartersRegistrationData>({
    name: '',
    country_id: '',
    city: '',
    address: '',
    contact_email: '',
    contact_phone: '',
    director_id: '',
    capacity: 0,
    facilities: []
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      const workflowId = await WorkflowService.createHeadquartersRegistration(formData)
      router.push(`/workflows/${workflowId}`)
    } catch (error) {
      console.error('Error creating workflow:', error)
      alert('Failed to create workflow')
    } finally {
      setLoading(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <h2 className="text-2xl font-bold">Register New Headquarters</h2>
      
      <div>
        <label className="block text-sm font-medium">Headquarters Name</label>
        <input
          type="text"
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium">City</label>
        <input
          type="text"
          value={formData.city}
          onChange={(e) => setFormData({ ...formData, city: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium">Contact Email</label>
        <input
          type="email"
          value={formData.contact_email}
          onChange={(e) => setFormData({ ...formData, contact_email: e.target.value })}
          className="mt-1 block w-full rounded-md border-gray-300"
          required
        />
      </div>

      <button
        type="submit"
        disabled={loading}
        className="bg-blue-500 text-white px-4 py-2 rounded disabled:opacity-50"
      >
        {loading ? 'Creating...' : 'Start Registration Process'}
      </button>
    </form>
  )
}
```

### Workflow Status Component

```tsx
// components/workflows/WorkflowStatus.tsx
import { useEffect, useState } from 'react'
import { WorkflowService } from '@/services/workflow.service'
import type { WorkflowStatus } from '@/types/workflow.types'

interface Props {
  workflowId: string
}

export function WorkflowStatusDisplay({ workflowId }: Props) {
  const [status, setStatus] = useState<WorkflowStatus | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadStatus()
  }, [workflowId])

  const loadStatus = async () => {
    try {
      const data = await WorkflowService.getWorkflowStatus(workflowId)
      setStatus(data)
    } catch (error) {
      console.error('Error loading status:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div>Loading...</div>
  if (!status) return <div>No status available</div>

  const progressPercentage = (status.completed_stages / status.total_stages) * 100

  return (
    <div className="bg-white shadow rounded-lg p-6">
      <h3 className="text-lg font-semibold mb-4">{status.template_name}</h3>
      
      <div className="space-y-3">
        <div>
          <div className="flex justify-between text-sm">
            <span>Overall Progress</span>
            <span>{status.completed_stages} / {status.total_stages} stages</span>
          </div>
          <div className="mt-1 bg-gray-200 rounded-full h-2">
            <div 
              className="bg-blue-500 h-2 rounded-full transition-all"
              style={{ width: `${progressPercentage}%` }}
            />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4 mt-4">
          <div>
            <p className="text-sm text-gray-500">Status</p>
            <p className="font-medium capitalize">{status.status}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Current Stage</p>
            <p className="font-medium">{status.current_stage || 'N/A'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Pending Actions</p>
            <p className="font-medium">{status.pending_actions}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Overdue Actions</p>
            <p className="font-medium text-red-600">{status.overdue_actions}</p>
          </div>
        </div>
      </div>
    </div>
  )
}
```

### Action Management Component

```tsx
// components/workflows/ActionManager.tsx
import { useState } from 'react'
import { WorkflowService } from '@/services/workflow.service'
import type { WorkflowAction } from '@/types/workflow.types'

interface Props {
  action: WorkflowAction
  onComplete: () => void
}

export function ActionManager({ action, onComplete }: Props) {
  const [loading, setLoading] = useState(false)
  const [comment, setComment] = useState('')
  const [showRejectDialog, setShowRejectDialog] = useState(false)
  const [rejectReason, setRejectReason] = useState('')

  const handleComplete = async () => {
    setLoading(true)
    try {
      await WorkflowService.completeAction(
        action.id,
        { completed: true },
        comment
      )
      onComplete()
    } catch (error) {
      console.error('Error completing action:', error)
      alert('Failed to complete action')
    } finally {
      setLoading(false)
    }
  }

  const handleReject = async () => {
    if (!rejectReason.trim()) {
      alert('Please provide a reason for rejection')
      return
    }

    setLoading(true)
    try {
      await WorkflowService.rejectAction(
        action.id,
        rejectReason,
        comment
      )
      onComplete()
    } catch (error) {
      console.error('Error rejecting action:', error)
      alert('Failed to reject action')
    } finally {
      setLoading(false)
      setShowRejectDialog(false)
    }
  }

  return (
    <div className="border rounded-lg p-4">
      <div className="flex justify-between items-start mb-4">
        <div>
          <h4 className="font-medium capitalize">{action.action_type} Action</h4>
          <p className="text-sm text-gray-500">
            Priority: <span className={`font-medium ${
              action.priority === 'high' ? 'text-red-600' : 
              action.priority === 'medium' ? 'text-yellow-600' : 
              'text-green-600'
            }`}>{action.priority}</span>
          </p>
          {action.due_date && (
            <p className="text-sm text-gray-500">
              Due: {new Date(action.due_date).toLocaleDateString()}
            </p>
          )}
        </div>
        <span className={`px-2 py-1 text-xs rounded ${
          action.status === 'completed' ? 'bg-green-100 text-green-800' :
          action.status === 'rejected' ? 'bg-red-100 text-red-800' :
          action.status === 'in_progress' ? 'bg-blue-100 text-blue-800' :
          'bg-gray-100 text-gray-800'
        }`}>
          {action.status}
        </span>
      </div>

      {action.status === 'pending' || action.status === 'in_progress' && (
        <>
          <div className="mb-4">
            <label className="block text-sm font-medium mb-1">Comments</label>
            <textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              className="w-full rounded-md border-gray-300"
              rows={3}
              placeholder="Add any relevant comments..."
            />
          </div>

          <div className="flex gap-2">
            <button
              onClick={handleComplete}
              disabled={loading}
              className="bg-green-500 text-white px-4 py-2 rounded disabled:opacity-50"
            >
              Complete Action
            </button>
            <button
              onClick={() => setShowRejectDialog(true)}
              disabled={loading}
              className="bg-red-500 text-white px-4 py-2 rounded disabled:opacity-50"
            >
              Reject
            </button>
          </div>
        </>
      )}

      {showRejectDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 className="text-lg font-semibold mb-4">Reject Action</h3>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              className="w-full rounded-md border-gray-300 mb-4"
              rows={4}
              placeholder="Please provide a reason for rejection..."
              required
            />
            <div className="flex gap-2">
              <button
                onClick={handleReject}
                disabled={loading}
                className="bg-red-500 text-white px-4 py-2 rounded disabled:opacity-50"
              >
                Confirm Rejection
              </button>
              <button
                onClick={() => setShowRejectDialog(false)}
                className="bg-gray-300 text-gray-700 px-4 py-2 rounded"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
```

## Real-time Updates

```typescript
// hooks/useWorkflowSubscription.ts
import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import type { WorkflowInstance, WorkflowAction } from '@/types/workflow.types'

export function useWorkflowSubscription(workflowId: string) {
  const [workflow, setWorkflow] = useState<WorkflowInstance | null>(null)
  const [actions, setActions] = useState<WorkflowAction[]>([])

  useEffect(() => {
    // Subscribe to workflow instance changes
    const workflowSubscription = supabase
      .channel(`workflow-${workflowId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'workflow_instances',
          filter: `id=eq.${workflowId}`
        },
        (payload) => {
          if (payload.eventType === 'UPDATE') {
            setWorkflow(payload.new as WorkflowInstance)
          }
        }
      )
      .subscribe()

    // Subscribe to action changes
    const actionSubscription = supabase
      .channel(`workflow-actions-${workflowId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'workflow_actions',
          filter: `stage_instance_id=in.(
            SELECT id FROM workflow_stage_instances 
            WHERE workflow_instance_id = '${workflowId}'
          )`
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setActions(prev => [...prev, payload.new as WorkflowAction])
          } else if (payload.eventType === 'UPDATE') {
            setActions(prev => 
              prev.map(action => 
                action.id === payload.new.id ? payload.new as WorkflowAction : action
              )
            )
          }
        }
      )
      .subscribe()

    // Cleanup
    return () => {
      workflowSubscription.unsubscribe()
      actionSubscription.unsubscribe()
    }
  }, [workflowId])

  return { workflow, actions }
}
```

## Complete Workflow Page

```tsx
// app/workflows/[id]/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { useParams } from 'next/navigation'
import { WorkflowService } from '@/services/workflow.service'
import { WorkflowStatusDisplay } from '@/components/workflows/WorkflowStatus'
import { ActionManager } from '@/components/workflows/ActionManager'
import { useWorkflowSubscription } from '@/hooks/useWorkflowSubscription'

export default function WorkflowDetailPage() {
  const params = useParams()
  const workflowId = params.id as string
  const [workflowData, setWorkflowData] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const { workflow, actions } = useWorkflowSubscription(workflowId)

  useEffect(() => {
    loadWorkflowData()
  }, [workflowId])

  const loadWorkflowData = async () => {
    try {
      const data = await WorkflowService.getWorkflowInstance(workflowId)
      setWorkflowData(data)
    } catch (error) {
      console.error('Error loading workflow:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div>Loading workflow...</div>
  if (!workflowData) return <div>Workflow not found</div>

  return (
    <div className="max-w-6xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">
        {workflowData.workflow_templates.name}
      </h1>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <WorkflowStatusDisplay workflowId={workflowId} />

          <div className="mt-6">
            <h2 className="text-xl font-semibold mb-4">Workflow Stages</h2>
            <div className="space-y-4">
              {workflowData.workflow_stage_instances.map((stage: any) => (
                <div key={stage.id} className="border rounded-lg p-4">
                  <div className="flex justify-between items-center mb-3">
                    <h3 className="font-medium">
                      {stage.workflow_template_stages.name}
                    </h3>
                    <span className={`px-2 py-1 text-xs rounded ${
                      stage.status === 'completed' ? 'bg-green-100 text-green-800' :
                      stage.status === 'active' ? 'bg-blue-100 text-blue-800' :
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {stage.status}
                    </span>
                  </div>

                  {stage.workflow_actions.length > 0 && (
                    <div className="space-y-3">
                      {stage.workflow_actions.map((action: any) => (
                        <ActionManager
                          key={action.id}
                          action={action}
                          onComplete={loadWorkflowData}
                        />
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>

        <div>
          <div className="bg-gray-50 rounded-lg p-4">
            <h3 className="font-semibold mb-3">Workflow Data</h3>
            <pre className="text-xs overflow-auto">
              {JSON.stringify(workflowData.data, null, 2)}
            </pre>
          </div>
        </div>
      </div>
    </div>
  )
}
```

## Dashboard Component

```tsx
// components/workflows/WorkflowDashboard.tsx
import { useEffect, useState } from 'react'
import { WorkflowService } from '@/services/workflow.service'
import type { PendingAction } from '@/types/workflow.types'

export function WorkflowDashboard() {
  const [pendingActions, setPendingActions] = useState<PendingAction[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadPendingActions()
  }, [])

  const loadPendingActions = async () => {
    try {
      const data = await WorkflowService.getMyPendingActions()
      setPendingActions(data)
    } catch (error) {
      console.error('Error loading pending actions:', error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) return <div>Loading...</div>

  return (
    <div className="bg-white shadow rounded-lg p-6">
      <h2 className="text-xl font-semibold mb-4">My Pending Actions</h2>
      
      {pendingActions.length === 0 ? (
        <p className="text-gray-500">No pending actions</p>
      ) : (
        <div className="space-y-3">
          {pendingActions.map((action) => (
            <div 
              key={action.action_id} 
              className="border rounded p-3 hover:bg-gray-50"
            >
              <div className="flex justify-between items-start">
                <div>
                  <h4 className="font-medium">{action.workflow_name}</h4>
                  <p className="text-sm text-gray-600">
                    {action.stage_name} - {action.action_type}
                  </p>
                  {action.due_date && (
                    <p className={`text-sm ${action.is_overdue ? 'text-red-600' : 'text-gray-500'}`}>
                      Due: {new Date(action.due_date).toLocaleDateString()}
                      {action.is_overdue && ' (Overdue)'}
                    </p>
                  )}
                </div>
                <a 
                  href={`/workflows/${action.workflow_id}`}
                  className="text-blue-500 hover:underline text-sm"
                >
                  View →
                </a>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
```

## Usage Example

```tsx
// app/headquarters/new/page.tsx
import { CreateHeadquartersWorkflow } from '@/components/workflows/CreateHeadquartersWorkflow'

export default function NewHeadquartersPage() {
  return (
    <div className="max-w-4xl mx-auto p-6">
      <CreateHeadquartersWorkflow />
    </div>
  )
}

// app/dashboard/page.tsx
import { WorkflowDashboard } from '@/components/workflows/WorkflowDashboard'

export default function DashboardPage() {
  return (
    <div className="max-w-6xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-6">My Dashboard</h1>
      <WorkflowDashboard />
    </div>
  )
}
```

## Error Handling

```typescript
// utils/workflow-errors.ts
export class WorkflowError extends Error {
  constructor(
    message: string,
    public code: string,
    public details?: any
  ) {
    super(message)
    this.name = 'WorkflowError'
  }
}

export function handleWorkflowError(error: any): WorkflowError {
  if (error.code === 'PGRST116') {
    return new WorkflowError(
      'Workflow not found',
      'WORKFLOW_NOT_FOUND'
    )
  }
  
  if (error.message?.includes('permission')) {
    return new WorkflowError(
      'You do not have permission to perform this action',
      'PERMISSION_DENIED'
    )
  }

  return new WorkflowError(
    error.message || 'An unexpected error occurred',
    'UNKNOWN_ERROR',
    error
  )
}
```

## Best Practices

1. **Type Safety**: Always use the generated types from `supabase.type.ts`
2. **Error Handling**: Implement proper error handling for all API calls
3. **Loading States**: Show loading indicators during async operations
4. **Real-time Updates**: Use subscriptions for live workflow updates
5. **Permissions**: Check user permissions before showing actions
6. **Optimistic Updates**: Update UI optimistically for better UX
7. **Caching**: Consider using React Query or SWR for data caching

## Security Considerations

1. **RLS Policies**: Ensure all tables have proper Row Level Security
2. **Input Validation**: Validate all inputs on both client and server
3. **Authentication**: Always verify user authentication status
4. **Authorization**: Check user roles before allowing actions
5. **Audit Trail**: All actions are automatically logged in the history table