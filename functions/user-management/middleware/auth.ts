import { Context, Next } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { getUserRoleLevel } from '../utils/auth.ts';

/**
 * Middleware to verify JWT token and minimum role level
 */
export function requireMinRoleLevel(minLevel: number) {
	return async (c: Context, next: Next) => {
		const authHeader = c.req.header('Authorization');
		
		if (!authHeader || !authHeader.startsWith('Bearer ')) {
			throw new HTTPException(401, { message: 'Missing or invalid authorization header' });
		}

		const token = authHeader.split(' ')[1];
		const userLevel = await getUserRoleLevel(token);

		if (userLevel === null) {
			throw new HTTPException(401, { message: 'Invalid token or user not found' });
		}

		if (userLevel < minLevel) {
			throw new HTTPException(403, { 
				message: `Insufficient permissions. Required level: ${minLevel}, current level: ${userLevel}` 
			});
		}

		// Store user info in context for later use
		c.set('userLevel', userLevel);
		c.set('authToken', token);
		
		await next();
	};
}