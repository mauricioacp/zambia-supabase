import {
	SUPA_CLIENT,
	TEST_USER_EMAIL_PREFIX,
	TEST_USER_PASSWORD,
} from '../_environment.ts';

interface Role {
	id: string;
	code: string;
	name: string;
	description?: string;
	status: string;
	level: number;
}

interface Credentials {
	role: string;
	email: string;
	password: string;
	jwt: string;
}

async function fetchActiveRoles(): Promise<Role[]> {
	const { data, error } = await SUPA_CLIENT
		.from('roles')
		.select('*')
		.eq('status', 'active');

	if (error) {
		console.error('Error fetching roles:', error.message);
		throw error;
	}

	return data || [];
}

async function checkTestUserExists(roleCode: string): Promise<string | null> {
	const email = `${TEST_USER_EMAIL_PREFIX}${roleCode}@example.com`;

	const { data, error } = await SUPA_CLIENT
		.auth
		.admin.listUsers();

	if (error) {
		console.error('Error checking if user exists:', error.message);
		throw error;
	}

	const user = data.users.find((u) => u.email === email);
	return user ? user.id : null;
}

async function deleteTestUser(userId: string): Promise<void> {
	const { error } = await SUPA_CLIENT
		.auth
		.admin
		.deleteUser(userId);

	if (error) {
		console.error('Error deleting user:', error.message);
		throw error;
	}
}

async function fetchDefaultHeadquarter(): Promise<string> {
	const { data, error } = await SUPA_CLIENT
		.from('headquarters')
		.select('id')
		.limit(1)
		.single();

	if (error) throw error;
	return data.id;
}

async function fetchDefaultSeason(hqId: string): Promise<string> {
	const { data, error } = await SUPA_CLIENT
		.from('seasons')
		.select('id')
		.eq('headquarter_id', hqId)
		.order('start_date', { ascending: false })
		.limit(1)
		.single();
	if (error) throw error;
	return data.id;
}

async function createTestUser(
	role: Role,
	hqId: string,
	seasonId: string,
	agreementId: string,
): Promise<{ userId: string; email: string; password: string }> {
	const email = `${TEST_USER_EMAIL_PREFIX}${role.code}@example.com`;

	const { data, error } = await SUPA_CLIENT
		.auth
		.admin
		.createUser({
			email,
			password: TEST_USER_PASSWORD,
			email_confirm: true,
			user_metadata: {
				role: role.code,
				role_level: role.level,
				role_id: role.id,
				hq_id: hqId,
				season_id: seasonId,
				agreement_id: agreementId,
				comments: {}, // special comments for future use
			},
		});

	if (error) {
		console.error(
			`Error creating user for role ${role.name}:`,
			error.message,
		);
		throw error;
	}

	return {
		userId: data.user.id,
		email,
		password: TEST_USER_PASSWORD,
	};
}

async function manageTestUsers() {
	try {
		console.log('Fetching active roles...');
		const roles = await fetchActiveRoles();
		const defaultHqId = await fetchDefaultHeadquarter();
		const defaultSeasonId = await fetchDefaultSeason(defaultHqId);
		console.log(`Found ${roles.length} active roles`);

		const credentials: Credentials[] = [];

		for (const role of roles) {
			console.log(`\nProcessing role: ${role.name} (${role.code})`);

			const existingUserId = await checkTestUserExists(role.code);

			if (existingUserId) {
				console.log(
					`Deleting existing test user for role ${role.name}...`,
				);
				await deleteTestUser(existingUserId);
			}

			const { data: agData, error: agInsertErr } = await SUPA_CLIENT
				.from('agreements')
				.insert({
					headquarter_id: defaultHqId,
					season_id: defaultSeasonId,
					role_id: role.id,
					status: 'prospect',
					email: `${TEST_USER_EMAIL_PREFIX}${role.code}@example.com`,
					name: `${TEST_USER_EMAIL_PREFIX}${role.code}`,
					last_name: `${TEST_USER_EMAIL_PREFIX}${role.code}`,
					address: `${TEST_USER_EMAIL_PREFIX}${role.code}`,
					volunteering_agreement: true,
					ethical_document_agreement: true,
					mailing_agreement: true,
					age_verification: true,
					signature_data: 'abcdef',
					document_number: 13456789,
					phone: 123456789,
				})
				.select('id')
				.single();
			if (agInsertErr) throw agInsertErr;
			const agreementId = agData.id;

			console.log(`Creating new test user for role ${role.name}...`);
			const { userId, email, password } = await createTestUser(
				role,
				defaultHqId,
				defaultSeasonId,
				agreementId,
			);

			console.log(
				`Updating agreement ${agreementId} for user ${userId}...`,
			);

			const { error: agUpdateErr } = await SUPA_CLIENT
				.from('agreements')
				.update({ user_id: userId, status: 'active' })
				.eq('id', agreementId);

			if (agUpdateErr) {
				console.error(
					`Error updating agreement ${agreementId}:`,
					agUpdateErr.message,
				);
				throw agUpdateErr;
			}

			console.log('\n=== TEST USER CREDENTIALS ===');
			console.log(`Role: ${role.code}`);
			console.log(`Email: ${email}`);
			console.log(`Password: ${password}`);
			console.log('============================\n');
			credentials.push({
				role: role.code,
				email,
				password,
				jwt: 'not-needed',
			});
		}

		await writeCredentialsToJsonFile(credentials);
		console.log('Test user management completed successfully!');
	} catch (error) {
		console.error('Error managing test users:', error);
	}
}

async function writeCredentialsToJsonFile(credentials: Credentials[]) {
	const credentialsJson = JSON.stringify(credentials, null, 2);
	const credentialsFilePath = './credentials.json';
	await Deno.writeTextFile(credentialsFilePath, credentialsJson);
}

await manageTestUsers();
