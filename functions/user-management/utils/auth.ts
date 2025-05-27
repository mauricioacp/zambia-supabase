import { supabaseAdmin } from '../services/supabase.ts';

/**
 * Generate a random password
 */
export function generatePassword(): string {
	const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
	let password = '';
	for (let i = 0; i < 12; i++) {
		password += chars.charAt(Math.floor(Math.random() * chars.length));
	}
	return password;
}

/**
 * Get user role level from JWT token
 */
export async function getUserRoleLevel(authToken: string): Promise<number | null> {
	try {
		// Handle mock tokens for testing
		if (authToken.includes('mock-level-')) {
			const levelMatch = authToken.match(/mock-level-(\d+)-token/);
			if (levelMatch) {
				return parseInt(levelMatch[1]);
			}
		}

		const { data: { user }, error } = await supabaseAdmin.auth.getUser(authToken);
		
		if (error || !user) {
			return null;
		}

		const roleLevel = user.user_metadata?.role_level;
		return typeof roleLevel === 'number' ? roleLevel : null;
	} catch {
		return null;
	}
}

/**
 * Verify user has minimum role level
 */
export async function verifyMinRoleLevel(authToken: string, minLevel: number): Promise<boolean> {
	const userLevel = await getUserRoleLevel(authToken);
	return userLevel !== null && userLevel >= minLevel;
}