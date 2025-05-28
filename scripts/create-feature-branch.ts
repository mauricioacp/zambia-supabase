#!/usr/bin/env deno

/**
 * Creates feature or hotfix branches following project conventions
 * 
 * Usage:
 *   deno task branch:feature [feature-name]
 *   deno task branch:hotfix [hotfix-name]
 * 
 * Branch naming convention:
 *   - Features: feat/feature-name-here
 *   - Hotfixes: hotfix/issue-description
 */

import { parseArgs } from 'https://deno.land/std@0.208.0/cli/parse_args.ts';

interface BranchConfig {
	type: 'feature' | 'hotfix';
	name?: string;
}

function sanitizeBranchName(name: string): string {
	return name
		.toLowerCase()
		.replace(/[^a-z0-9-]/g, '-')
		.replace(/--+/g, '-')
		.replace(/^-|-$/g, '');
}

function getBranchPrefix(type: string): string {
	switch (type) {
		case 'hotfix':
			return 'hotfix/';
		default:
			return 'feat/';
	}
}

async function runCommand(cmd: string[]): Promise<{ success: boolean; output: string }> {
	try {
		const process = new Deno.Command(cmd[0], {
			args: cmd.slice(1),
			stdout: 'piped',
			stderr: 'piped',
		});

		const { code, stdout, stderr } = await process.output();
		const output = new TextDecoder().decode(stdout) + new TextDecoder().decode(stderr);

		return {
			success: code === 0,
			output: output.trim(),
		};
	} catch (error) {
		return {
			success: false,
			output: `Failed to run command: ${error.message}`,
		};
	}
}

async function getCurrentBranch(): Promise<string> {
	const result = await runCommand(['git', 'branch', '--show-current']);
	if (!result.success) {
		throw new Error('Failed to get current branch');
	}
	return result.output;
}

async function hasUncommittedChanges(): Promise<boolean> {
	const result = await runCommand(['git', 'status', '--porcelain']);
	return result.success && result.output.length > 0;
}

async function createBranch(config: BranchConfig): Promise<void> {
	// Check if we're in a git repository
	const gitCheck = await runCommand(['git', 'rev-parse', '--git-dir']);
	if (!gitCheck.success) {
		console.error('❌ Not in a git repository');
		Deno.exit(1);
	}

	// Check for uncommitted changes
	if (await hasUncommittedChanges()) {
		console.error('❌ You have uncommitted changes. Please commit or stash them first.');
		Deno.exit(1);
	}

	// Get branch name from user if not provided
	let branchName = config.name;
	if (!branchName) {
		const prompt = config.type === 'hotfix' 
			? 'Enter hotfix description: '
			: 'Enter feature name: ';
		branchName = globalThis.prompt(prompt);
		
		if (!branchName) {
			console.error('❌ Branch name is required');
			Deno.exit(1);
		}
	}

	// Sanitize and create full branch name
	const sanitizedName = sanitizeBranchName(branchName);
	const fullBranchName = getBranchPrefix(config.type) + sanitizedName;

	console.log(`🔄 Creating ${config.type} branch: ${fullBranchName}`);

	// Ensure we're on master/main and up to date
	const currentBranch = await getCurrentBranch();
	const mainBranch = ['master', 'main'].includes(currentBranch) ? currentBranch : 'master';

	if (currentBranch !== mainBranch) {
		console.log(`📦 Switching to ${mainBranch}...`);
		const checkoutResult = await runCommand(['git', 'checkout', mainBranch]);
		if (!checkoutResult.success) {
			console.error(`❌ Failed to checkout ${mainBranch}: ${checkoutResult.output}`);
			Deno.exit(1);
		}
	}

	// Pull latest changes
	console.log('📥 Pulling latest changes...');
	const pullResult = await runCommand(['git', 'pull', 'origin', mainBranch]);
	if (!pullResult.success) {
		console.log(`⚠️  Warning: Could not pull latest changes: ${pullResult.output}`);
	}

	// Create and checkout new branch
	console.log(`🌿 Creating branch: ${fullBranchName}`);
	const branchResult = await runCommand(['git', 'checkout', '-b', fullBranchName]);
	if (!branchResult.success) {
		console.error(`❌ Failed to create branch: ${branchResult.output}`);
		Deno.exit(1);
	}

	// Show success message with next steps
	console.log('✅ Branch created successfully!');
	console.log('');
	console.log('📝 Next steps:');
	console.log(`   1. Make your ${config.type} changes`);
	console.log('   2. Commit your work: git add . && git commit -m "your message"');
	console.log(`   3. Push branch: git push -u origin ${fullBranchName}`);
	console.log(`   4. Create PR when ready`);
	console.log('');
	console.log('🔧 Useful commands:');
	console.log('   - supabase db reset     # Reset database with latest schema');
	console.log('   - deno task test        # Run tests');
	console.log('   - deno fmt              # Format code');
	console.log('   - deno lint             # Lint code');
}

function showUsage(): void {
	console.log('');
	console.log('🌿 Branch Creator - Akademia Project');
	console.log('');
	console.log('Creates feature or hotfix branches following project conventions');
	console.log('');
	console.log('Usage:');
	console.log('  deno task branch:feature [name]   # Create feat/name branch');
	console.log('  deno task branch:hotfix [name]    # Create hotfix/name branch');
	console.log('');
	console.log('Examples:');
	console.log('  deno task branch:feature user-dashboard');
	console.log('  deno task branch:feature "workflow notifications"');
	console.log('  deno task branch:hotfix auth-bug');
	console.log('');
	console.log('Branch naming convention:');
	console.log('  - Features: feat/feature-name-here');
	console.log('  - Hotfixes: hotfix/issue-description');
	console.log('');
}

async function main(): Promise<void> {
	const args = parseArgs(Deno.args, {
		string: ['type'],
		boolean: ['help'],
		alias: { h: 'help' },
	});

	if (args.help) {
		showUsage();
		return;
	}

	// Determine branch type
	let type: 'feature' | 'hotfix' = 'feature';
	if (args.type === 'hotfix') {
		type = 'hotfix';
	}

	// Get branch name from remaining args
	const name = args._.join(' ') || undefined;

	const config: BranchConfig = { type, name };

	try {
		await createBranch(config);
	} catch (error) {
		console.error(`❌ Error: ${error.message}`);
		Deno.exit(1);
	}
}

if (import.meta.main) {
	await main();
}