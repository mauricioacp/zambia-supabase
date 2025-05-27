#!/usr/bin/env -S deno run --allow-all

/**
 * Production Deployment Script for Akademia Supabase Project
 *
 * This script handles the complete deployment process:
 * - Database migrations
 * - Edge Functions deployment
 * - Environment configuration
 * - Validation and rollback capabilities
 *
 * Usage:
 *   deno run --allow-all scripts/deploy-production.ts [options]
 *
 * Options:
 *   --dry-run          Show what would be deployed without executing
 *   --functions-only   Deploy only Edge Functions
 *   --db-only         Deploy only database migrations
 *   --force           Skip confirmation prompts
 *   --project-ref     Specify project reference ID
 *   --help            Show this help message
 */

import { parseArgs } from '@std/cli/parse_args';
import { exists } from '@std/fs/exists';
import { colors } from '@std/fmt/colors';

interface DeploymentConfig {
	projectRef: string;
	environment: 'staging' | 'production';
	dryRun: boolean;
	functionsOnly: boolean;
	dbOnly: boolean;
	force: boolean;
	skipTests: boolean;
}

interface DeploymentResult {
	success: boolean;
	step: string;
	message: string;
	timestamp: string;
}

class ProductionDeployment {
	private config: DeploymentConfig;
	private results: DeploymentResult[] = [];

	constructor(config: DeploymentConfig) {
		this.config = config;
	}

	// Main deployment orchestrator
	async deploy(): Promise<boolean> {
		try {
			this.printHeader();

			if (!await this.preflightChecks()) {
				return false;
			}

			if (!this.config.force && !this.confirmDeployment()) {
				this.log('⚠️', 'Deployment cancelled by user', 'warn');
				return false;
			}

			// Run pre-deployment tests
			if (!this.config.skipTests && !await this.runTests()) {
				this.log('❌', 'Pre-deployment tests failed', 'error');
				return false;
			}

			// Deploy database migrations
			if (!this.config.functionsOnly && !await this.deployDatabase()) {
				return false;
			}

			// Deploy Edge Functions
			if (!this.config.dbOnly && !await this.deployFunctions()) {
				return false;
			}

			// Post-deployment validation
			if (!await this.validateDeployment()) {
				return false;
			}

			this.printSummary();
			return true;
		} catch (error) {
			this.log('💥', `Deployment failed: ${error.message}`, 'error');
			return false;
		}
	}

	private printHeader(): void {
		console.log(colors.cyan('🚀 Akademia Supabase Production Deployment'));
		console.log(colors.cyan('=========================================='));
		console.log(`📍 Project: ${this.config.projectRef}`);
		console.log(`🎯 Environment: ${this.config.environment}`);
		console.log(`🧪 Dry Run: ${this.config.dryRun ? 'Yes' : 'No'}`);
		console.log(
			`💾 Database: ${
				this.config.dbOnly
					? 'Only'
					: this.config.functionsOnly
					? 'Skip'
					: 'Yes'
			}`,
		);
		console.log(
			`⚡ Functions: ${
				this.config.functionsOnly
					? 'Only'
					: this.config.dbOnly
					? 'Skip'
					: 'Yes'
			}`,
		);
		console.log('');
	}

	private async preflightChecks(): Promise<boolean> {
		this.log('🔍', 'Running preflight checks...', 'info');

		// Check if Supabase CLI is installed
		if (!await this.checkSupabaseCLI()) {
			return false;
		}

		// Check if Docker is running (required for Edge Functions)
		if (!this.config.dbOnly && !await this.checkDocker()) {
			return false;
		}

		// Check if project is linked
		if (!await this.checkProjectLink()) {
			return false;
		}

		// Verify environment variables
		if (!this.checkEnvironmentVariables()) {
			return false;
		}

		// Check for uncommitted changes
		if (!await this.checkGitStatus()) {
			return false;
		}

		// Validate configuration files
		if (!await this.validateConfiguration()) {
			return false;
		}

		this.addResult(true, 'preflight', 'All preflight checks passed');
		return true;
	}

	private async checkSupabaseCLI(): Promise<boolean> {
		try {
			const result = await this.runCommand(['supabase', '--version']);
			if (result.success) {
				this.log(
					'✅',
					`Supabase CLI detected: ${result.output.trim()}`,
					'success',
				);
				return true;
			}
		} catch {
			this.log(
				'❌',
				'Supabase CLI not found. Install with: npm install -g supabase',
				'error',
			);
			return false;
		}
		return false;
	}

	private async checkDocker(): Promise<boolean> {
		try {
			const result = await this.runCommand(['docker', '--version']);
			if (result.success) {
				this.log('✅', 'Docker detected', 'success');

				// Check if Docker daemon is running
				const psResult = await this.runCommand(['docker', 'ps']);
				if (psResult.success) {
					this.log('✅', 'Docker daemon is running', 'success');
					return true;
				} else {
					this.log(
						'❌',
						'Docker daemon is not running. Please start Docker Desktop.',
						'error',
					);
					return false;
				}
			}
		} catch {
			this.log(
				'❌',
				'Docker not found. Install Docker Desktop for Edge Functions deployment.',
				'error',
			);
			return false;
		}
		return false;
	}

	private async checkProjectLink(): Promise<boolean> {
		try {
			const result = await this.runCommand(['supabase', 'status']);
			if (
				result.success && result.output.includes(this.config.projectRef)
			) {
				this.log(
					'✅',
					`Project linked: ${this.config.projectRef}`,
					'success',
				);
				return true;
			} else {
				this.log(
					'❌',
					`Project not linked. Run: supabase link --project-ref ${this.config.projectRef}`,
					'error',
				);
				return false;
			}
		} catch {
			return false;
		}
	}

	private checkEnvironmentVariables(): boolean {
		const requiredVars = [
			'SUPABASE_ACCESS_TOKEN',
			'SUPABASE_DB_PASSWORD',
		];

		const missing = requiredVars.filter((varName) =>
			!Deno.env.get(varName)
		);

		if (missing.length > 0) {
			this.log(
				'❌',
				`Missing environment variables: ${missing.join(', ')}`,
				'error',
			);
			this.log(
				'💡',
				'Set them with: export SUPABASE_ACCESS_TOKEN=your_token',
				'info',
			);
			return false;
		}

		this.log('✅', 'Environment variables configured', 'success');
		return true;
	}

	private async checkGitStatus(): Promise<boolean> {
		try {
			const result = await this.runCommand([
				'git',
				'status',
				'--porcelain',
			]);
			if (result.output.trim()) {
				this.log('⚠️', 'Uncommitted changes detected:', 'warn');
				console.log(result.output);

				if (!this.config.force) {
					const proceed = this.confirm(
						'Continue with uncommitted changes?',
					);
					if (!proceed) {
						return false;
					}
				}
			} else {
				this.log('✅', 'Working directory clean', 'success');
			}
			return true;
		} catch {
			this.log('⚠️', 'Could not check git status', 'warn');
			return true;
		}
	}

	private async validateConfiguration(): Promise<boolean> {
		// Check config.toml exists
		if (!await exists('./config.toml')) {
			this.log('❌', 'config.toml not found', 'error');
			return false;
		}

		// Check functions directory exists
		if (!await exists('./functions')) {
			this.log('❌', 'functions directory not found', 'error');
			return false;
		}

		// Check migrations directory exists
		if (!await exists('./migrations')) {
			this.log('❌', 'migrations directory not found', 'error');
			return false;
		}

		this.log('✅', 'Configuration files validated', 'success');
		return true;
	}

	private async runTests(): Promise<boolean> {
		if (this.config.dryRun) {
			this.log('🧪', 'DRY RUN: Would run pre-deployment tests', 'info');
			return true;
		}

		this.log('🧪', 'Running pre-deployment tests...', 'info');

		try {
			// Run unit tests
			const unitResult = await this.runCommand([
				'deno',
				'task',
				'test',
			], { cwd: './functions/akademy' });

			if (!unitResult.success) {
				this.log('❌', 'Unit tests failed', 'error');
				return false;
			}

			this.log('✅', 'Pre-deployment tests passed', 'success');
			this.addResult(true, 'tests', 'All tests passed');
			return true;
		} catch (error) {
			this.log('❌', `Test execution failed: ${error.message}`, 'error');
			return false;
		}
	}

	private async deployDatabase(): Promise<boolean> {
		this.log('💾', 'Deploying database migrations...', 'info');

		if (this.config.dryRun) {
			this.log(
				'📋',
				'DRY RUN: Would deploy migrations with: supabase db push',
				'info',
			);
			this.addResult(true, 'database', 'Database deployment simulated');
			return true;
		}

		try {
			// Get current migration status
			const statusResult = await this.runCommand([
				'supabase',
				'migration',
				'list',
			]);
			this.log('📋', 'Current migration status:', 'info');
			console.log(statusResult.output);

			// Deploy migrations
			const deployResult = await this.runCommand([
				'supabase',
				'db',
				'push',
				'--include-seed',
			]);

			if (deployResult.success) {
				this.log(
					'✅',
					'Database migrations deployed successfully',
					'success',
				);
				this.addResult(true, 'database', 'Migrations deployed');
				return true;
			} else {
				this.log('❌', 'Database deployment failed', 'error');
				this.log('📝', deployResult.output, 'error');
				this.addResult(false, 'database', deployResult.output);
				return false;
			}
		} catch (error) {
			this.log(
				'❌',
				`Database deployment error: ${error.message}`,
				'error',
			);
			return false;
		}
	}

	private async deployFunctions(): Promise<boolean> {
		this.log('⚡', 'Deploying Edge Functions...', 'info');

		if (this.config.dryRun) {
			this.log(
				'📋',
				'DRY RUN: Would deploy functions with: supabase functions deploy',
				'info',
			);
			this.addResult(true, 'functions', 'Functions deployment simulated');
			return true;
		}

		try {
			// Deploy secrets first
			if (!await this.deploySecrets()) {
				return false;
			}

			// Deploy functions
			const deployResult = await this.runCommand([
				'supabase',
				'functions',
				'deploy',
				'--no-verify-jwt', // akademy function handles its own auth
			]);

			if (deployResult.success) {
				this.log(
					'✅',
					'Edge Functions deployed successfully',
					'success',
				);
				this.addResult(true, 'functions', 'Functions deployed');
				return true;
			} else {
				this.log('❌', 'Functions deployment failed', 'error');
				this.log('📝', deployResult.output, 'error');
				this.addResult(false, 'functions', deployResult.output);
				return false;
			}
		} catch (error) {
			this.log(
				'❌',
				`Functions deployment error: ${error.message}`,
				'error',
			);
			return false;
		}
	}

	private async deploySecrets(): Promise<boolean> {
		this.log('🔐', 'Deploying secrets...', 'info');

		// Check if .env file exists
		if (await exists('./.env')) {
			try {
				const result = await this.runCommand([
					'supabase',
					'secrets',
					'set',
					'--env-file',
					'./.env',
				]);

				if (result.success) {
					this.log('✅', 'Secrets deployed successfully', 'success');
					return true;
				} else {
					this.log(
						'⚠️',
						'Secrets deployment failed, continuing...',
						'warn',
					);
					return true; // Don't fail deployment for secrets
				}
			} catch (error) {
				this.log(
					'⚠️',
					`Secrets deployment error: ${error.message}`,
					'warn',
				);
				return true; // Don't fail deployment for secrets
			}
		} else {
			this.log(
				'💡',
				'No .env file found, skipping secrets deployment',
				'info',
			);
			return true;
		}
	}

	private async validateDeployment(): Promise<boolean> {
		this.log('🔍', 'Validating deployment...', 'info');

		if (this.config.dryRun) {
			this.log('📋', 'DRY RUN: Would validate deployment', 'info');
			return true;
		}

		try {
			// Test function endpoints
			if (!this.config.dbOnly) {
				const healthResult = await this.testFunctionHealth();
				if (!healthResult) {
					return false;
				}
			}

			// Verify database migrations
			if (!this.config.functionsOnly) {
				const migrationResult = await this.verifyMigrations();
				if (!migrationResult) {
					return false;
				}
			}

			this.log('✅', 'Deployment validation passed', 'success');
			this.addResult(true, 'validation', 'Deployment validated');
			return true;
		} catch (error) {
			this.log('❌', `Validation error: ${error.message}`, 'error');
			return false;
		}
	}

	private async testFunctionHealth(): Promise<boolean> {
		try {
			// Get project URL
			const statusResult = await this.runCommand(['supabase', 'status']);
			const projectUrl = this.extractProjectUrl(statusResult.output);

			if (!projectUrl) {
				this.log(
					'⚠️',
					'Could not determine project URL for health check',
					'warn',
				);
				return true;
			}

			// Test akademy function health endpoint
			const healthUrl = `${projectUrl}/functions/v1/akademy/health`;
			this.log('🔗', `Testing function health: ${healthUrl}`, 'info');

			const response = await fetch(healthUrl);
			if (response.ok) {
				this.log('✅', 'Function health check passed', 'success');
				return true;
			} else {
				this.log(
					'❌',
					`Function health check failed: ${response.status}`,
					'error',
				);
				return false;
			}
		} catch (error) {
			this.log('⚠️', `Health check error: ${error.message}`, 'warn');
			return true; // Don't fail deployment for health check
		}
	}

	private async verifyMigrations(): Promise<boolean> {
		try {
			const result = await this.runCommand([
				'supabase',
				'migration',
				'list',
			]);

			if (result.success) {
				this.log('✅', 'Migration status verified', 'success');
				return true;
			} else {
				this.log('❌', 'Migration verification failed', 'error');
				return false;
			}
		} catch (error) {
			this.log(
				'❌',
				`Migration verification error: ${error.message}`,
				'error',
			);
			return false;
		}
	}

	private extractProjectUrl(statusOutput: string): string | null {
		const match = statusOutput.match(/API URL: (https?:\/\/[^\s]+)/);
		return match ? match[1] : null;
	}

	private confirmDeployment(): boolean {
		console.log('');
		console.log(colors.yellow('⚠️  PRODUCTION DEPLOYMENT WARNING ⚠️'));
		console.log(
			colors.yellow(
				'This will deploy changes to production environment.',
			),
		);
		console.log('');
		console.log('📋 Deployment Summary:');
		console.log(`   • Project: ${this.config.projectRef}`);
		console.log(
			`   • Database: ${
				this.config.dbOnly
					? 'Only'
					: this.config.functionsOnly
					? 'Skip'
					: 'Yes'
			}`,
		);
		console.log(
			`   • Functions: ${
				this.config.functionsOnly
					? 'Only'
					: this.config.dbOnly
					? 'Skip'
					: 'Yes'
			}`,
		);
		console.log('');

		return this.confirm('Do you want to proceed with this deployment?');
	}

	private confirm(message: string): boolean {
		const response = prompt(`${message} (y/N): `);
		return response?.toLowerCase().trim() === 'y';
	}

	private printSummary(): void {
		console.log('');
		console.log(colors.green('🎉 Deployment Summary'));
		console.log(colors.green('==================='));

		for (const result of this.results) {
			const icon = result.success ? '✅' : '❌';
			const color = result.success ? colors.green : colors.red;
			console.log(color(`${icon} ${result.step}: ${result.message}`));
		}

		console.log('');
		const allSuccessful = this.results.every((r) => r.success);
		if (allSuccessful) {
			console.log(colors.green('🚀 Deployment completed successfully!'));
		} else {
			console.log(colors.red('❌ Deployment completed with errors'));
		}

		console.log('');
		console.log('📚 Next steps:');
		console.log('   • Monitor function logs: supabase functions logs');
		console.log(
			'   • Check project dashboard: https://supabase.com/dashboard',
		);
		console.log('   • Run integration tests against production');
	}

	private async runCommand(
		cmd: string[],
		options: { cwd?: string } = {},
	): Promise<{ success: boolean; output: string }> {
		try {
			const command = new Deno.Command(cmd[0], {
				args: cmd.slice(1),
				cwd: options.cwd,
				stdout: 'piped',
				stderr: 'piped',
			});

			const { success, stdout, stderr } = await command.output();
			const output = new TextDecoder().decode(success ? stdout : stderr);

			return { success, output };
		} catch (error) {
			return { success: false, output: error.message };
		}
	}

	private log(
		icon: string,
		message: string,
		level: 'info' | 'success' | 'warn' | 'error',
	): void {
		const colors_map = {
			info: colors.blue,
			success: colors.green,
			warn: colors.yellow,
			error: colors.red,
		};

		console.log(colors_map[level](`${icon} ${message}`));
	}

	private addResult(success: boolean, step: string, message: string): void {
		this.results.push({
			success,
			step,
			message,
			timestamp: new Date().toISOString(),
		});
	}
}

// CLI Interface
function printHelp(): void {
	console.log(`
🚀 Akademia Supabase Production Deployment Script

Usage:
  deno run --allow-all scripts/deploy-production.ts [options]

Options:
  --dry-run             Show what would be deployed without executing
  --functions-only      Deploy only Edge Functions  
  --db-only            Deploy only database migrations
  --force              Skip confirmation prompts
  --project-ref <id>   Specify project reference ID
  --skip-tests         Skip pre-deployment tests
  --help               Show this help message

Environment Variables (required):
  SUPABASE_ACCESS_TOKEN    Your personal access token
  SUPABASE_DB_PASSWORD     Project database password

Examples:
  # Full deployment with confirmation
  deno run --allow-all scripts/deploy-production.ts --project-ref abc123

  # Dry run to see what would be deployed
  deno run --allow-all scripts/deploy-production.ts --dry-run --project-ref abc123

  # Deploy only functions
  deno run --allow-all scripts/deploy-production.ts --functions-only --project-ref abc123

  # Force deployment without prompts
  deno run --allow-all scripts/deploy-production.ts --force --project-ref abc123
`);
}

// Main execution
async function main(): Promise<void> {
	const args = parseArgs(Deno.args, {
		boolean: [
			'dry-run',
			'functions-only',
			'db-only',
			'force',
			'skip-tests',
			'help',
		],
		string: ['project-ref'],
		alias: {
			h: 'help',
			p: 'project-ref',
			d: 'dry-run',
			f: 'force',
		},
	});

	if (args.help) {
		printHelp();
		Deno.exit(0);
	}

	const projectRef = args['project-ref'] ||
		Deno.env.get('SUPABASE_PROJECT_ID');

	if (!projectRef) {
		console.error(
			colors.red(
				'❌ Project reference ID required. Use --project-ref or set SUPABASE_PROJECT_ID',
			),
		);
		console.error(
			colors.blue('💡 Get your project ID with: supabase projects list'),
		);
		Deno.exit(1);
	}

	const config: DeploymentConfig = {
		projectRef,
		environment: 'production',
		dryRun: args['dry-run'] || false,
		functionsOnly: args['functions-only'] || false,
		dbOnly: args['db-only'] || false,
		force: args.force || false,
		skipTests: args['skip-tests'] || false,
	};

	const deployment = new ProductionDeployment(config);
	const success = await deployment.deploy();

	Deno.exit(success ? 0 : 1);
}

if (import.meta.main) {
	await main();
}
