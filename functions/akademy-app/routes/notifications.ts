import { Context } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import { createAdminSupabaseClient } from '../services/supabaseService.ts';

// Schemas
const SearchUsersSchema = z.object({
	query: z.string().min(1),
	role_code: z.string().optional(),
	min_role_level: z.number().optional(),
	limit: z.number().min(1).max(100).default(10),
	offset: z.number().min(0).default(0),
});

const SendNotificationSchema = z.object({
	recipient_id: z.string().uuid(),
	title: z.string().min(1),
	body: z.string().min(1),
	type: z.enum(['system', 'direct_message', 'action_required', 'reminder', 'alert', 'achievement', 'role_based']).default('direct_message'),
	priority: z.enum(['low', 'medium', 'high', 'urgent']).default('medium'),
	data: z.record(z.any()).optional(),
	action_url: z.string().optional(),
	related_entity_type: z.string().optional(),
	related_entity_id: z.string().uuid().optional(),
});

const SendRoleNotificationSchema = z.object({
	role_codes: z.array(z.string()),
	min_role_level: z.number().optional(),
	title: z.string().min(1),
	body: z.string().min(1),
	type: z.enum(['system', 'role_based', 'alert', 'reminder']).default('role_based'),
	priority: z.enum(['low', 'medium', 'high', 'urgent']).default('medium'),
	data: z.record(z.any()).optional(),
});

const MarkNotificationsReadSchema = z.object({
	notification_ids: z.array(z.string().uuid()),
});

const GetNotificationsSchema = z.object({
	limit: z.number().min(1).max(100).default(20),
	offset: z.number().min(0).default(0),
	type: z.enum(['system', 'direct_message', 'action_required', 'reminder', 'alert', 'achievement', 'role_based']).optional(),
	priority: z.enum(['low', 'medium', 'high', 'urgent']).optional(),
	is_read: z.boolean().optional(),
	category: z.string().optional(),
});

export async function searchUsers(c: Context): Promise<Response> {
	try {
		const query = c.req.query();
		const validatedData = SearchUsersSchema.parse({
			query: query.q,
			role_code: query.role_code,
			min_role_level: query.min_role_level ? parseInt(query.min_role_level) : undefined,
			limit: query.limit ? parseInt(query.limit) : 10,
			offset: query.offset ? parseInt(query.offset) : 0,
		});

		const supabase = createAdminSupabaseClient();
		
		const { data, error } = await supabase.rpc('search_users_vector', {
			p_query: validatedData.query,
			p_role_code: validatedData.role_code || null,
			p_min_role_level: validatedData.min_role_level || null,
			p_limit: validatedData.limit,
			p_offset: validatedData.offset,
		});

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ data });
	} catch (error) {
		if (error instanceof z.ZodError) {
			throw new HTTPException(400, { message: 'Invalid query parameters' });
		}
		throw error;
	}
}

export async function sendNotification(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData = SendNotificationSchema.parse(body);
		const senderId = c.get('userId') as string;
		const userLevel = c.get('userLevel') as number;

		if (validatedData.type !== 'direct_message' && userLevel < 30) {
			throw new HTTPException(403, { 
				message: 'Insufficient permissions to send system notifications' 
			});
		}

		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase
			.from('notifications')
			.insert({
				...validatedData,
				sender_id: senderId,
				sender_type: 'user',
			})
			.select()
			.single();

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		// Create delivery record for in-app channel
		await supabase
			.from('notification_deliveries')
			.insert({
				notification_id: data.id,
				channel: 'in_app',
			});

		return c.json({ data }, 201);
	} catch (error) {
		if (error instanceof z.ZodError) {
			throw new HTTPException(400, { message: 'Invalid notification data' });
		}
		throw error;
	}
}

// Send notification to users by role
export async function sendRoleNotification(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData = SendRoleNotificationSchema.parse(body);
		const userLevel = c.get('userLevel') as number;

		// Only managers and above can send role-based notifications
		if (userLevel < 50) {
			throw new HTTPException(403, { 
				message: 'Only managers can send role-based notifications' 
			});
		}

		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase.rpc('send_role_based_notification', {
			p_role_codes: validatedData.role_codes,
			p_min_role_level: validatedData.min_role_level || null,
			p_title: validatedData.title,
			p_body: validatedData.body,
			p_type: validatedData.type,
			p_priority: validatedData.priority,
			p_data: validatedData.data || {},
		});

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ 
			data: { 
				recipients_count: data,
				message: `Notification sent to ${data} users` 
			} 
		}, 201);
	} catch (error) {
		if (error instanceof z.ZodError) {
			throw new HTTPException(400, { message: 'Invalid notification data' });
		}
		throw error;
	}
}

// Get user notifications
export async function getNotifications(c: Context): Promise<Response> {
	try {
		const query = c.req.query();
		const validatedData = GetNotificationsSchema.parse({
			limit: query.limit ? parseInt(query.limit) : 20,
			offset: query.offset ? parseInt(query.offset) : 0,
			type: query.type,
			priority: query.priority,
			is_read: query.is_read ? query.is_read === 'true' : undefined,
			category: query.category,
		});

		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase.rpc('get_user_notifications', {
			p_limit: validatedData.limit,
			p_offset: validatedData.offset,
			p_type: validatedData.type || null,
			p_priority: validatedData.priority || null,
			p_is_read: validatedData.is_read ?? null,
			p_category: validatedData.category || null,
		});

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		// Extract pagination info from first row
		const totalCount = data?.[0]?.total_count || 0;
		const notifications = data?.map(({ total_count, ...notification }) => notification) || [];

		return c.json({
			data: notifications,
			pagination: {
				total: totalCount,
				limit: validatedData.limit,
				offset: validatedData.offset,
				page: Math.floor(validatedData.offset / validatedData.limit) + 1,
				pages: Math.ceil(totalCount / validatedData.limit),
			},
		});
	} catch (error) {
		if (error instanceof z.ZodError) {
			throw new HTTPException(400, { message: 'Invalid query parameters' });
		}
		throw error;
	}
}

// Get unread notification count
export async function getUnreadCount(c: Context): Promise<Response> {
	try {
		const supabase = createAdminSupabaseClient();
		const userId = c.get('userId') as string;

		const { data, error } = await supabase.rpc('get_unread_notification_count', {
			p_user_id: userId,
		});

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ data: { count: data } });
	} catch (error) {
		throw error;
	}
}

// Mark notifications as read
export async function markNotificationsRead(c: Context): Promise<Response> {
	try {
		const body = await c.req.json();
		const validatedData = MarkNotificationsReadSchema.parse(body);

		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase.rpc('mark_notifications_read', {
			p_notification_ids: validatedData.notification_ids,
		});

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ 
			data: { 
				updated_count: data,
				message: `${data} notifications marked as read` 
			} 
		});
	} catch (error) {
		if (error instanceof z.ZodError) {
			throw new HTTPException(400, { message: 'Invalid request data' });
		}
		throw error;
	}
}

// Archive notification
export async function archiveNotification(c: Context): Promise<Response> {
	try {
		const notificationId = c.req.param('id');
		const userId = c.get('userId') as string;

		if (!notificationId) {
			throw new HTTPException(400, { message: 'Notification ID required' });
		}

		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase
			.from('notifications')
			.update({ 
				is_archived: true,
				archived_at: new Date().toISOString()
			})
			.eq('id', notificationId)
			.eq('recipient_id', userId)
			.select()
			.single();

		if (error) {
			if (error.code === 'PGRST116') {
				throw new HTTPException(404, { message: 'Notification not found' });
			}
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ data });
	} catch (error) {
		throw error;
	}
}

// Get notification preferences
export async function getNotificationPreferences(c: Context): Promise<Response> {
	try {
		const userId = c.get('userId') as string;
		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase
			.from('notification_preferences')
			.select('*')
			.eq('user_id', userId)
			.single();

		if (error) {
			if (error.code === 'PGRST116') {
				// No preferences found, return defaults
				return c.json({
					data: {
						user_id: userId,
						enabled: true,
						channel_preferences: {},
						blocked_senders: [],
						blocked_categories: [],
						priority_threshold: 'low',
					}
				});
			}
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ data });
	} catch (error) {
		throw error;
	}
}

// Update notification preferences
export async function updateNotificationPreferences(c: Context): Promise<Response> {
	try {
		const userId = c.get('userId') as string;
		const body = await c.req.json();

		const supabase = createAdminSupabaseClient();

		const { data, error } = await supabase
			.from('notification_preferences')
			.upsert({
				user_id: userId,
				...body,
			})
			.select()
			.single();

		if (error) {
			throw new HTTPException(500, { message: error.message });
		}

		return c.json({ data });
	} catch (error) {
		throw error;
	}
}
