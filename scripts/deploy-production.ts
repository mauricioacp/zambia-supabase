#!/usr/bin/env -S deno run --allow-all

/**
 * Production Deployment Script for Akademia Supabase Project
 *
 * This script handles the complete deployment process:
 * - Database migrations deployment
 * - Edge Functions deployment
 * - Database backup and restore
 * - Production database reset with safety measures
 * - Schema comparison between local and remote
 * - Environment configuration
 * - Validation and rollback capabilities
 *
 * Usage:
 *   deno run --allow-all scripts/deploy-production.ts [options]
 *
 * Options:
 *   --mode <mode>      Operation mode: deploy, backup, reset, diff (default: deploy)
 *   --dry-run          Show what would be executed without running
 *   --functions-only   Deploy only Edge Functions (deploy mode)
 *   --db-only         Deploy only database migrations (deploy mode)
 *   --force           Skip confirmation prompts
 *   --project-ref     Specify project reference ID
 *   --backup-name     Custom name for backup file (backup mode)
 *   --skip-backup     Skip backup before reset (reset mode - DANGEROUS!)
 *   --help            Show this help message
 */

import { parseArgs } from '@std/cli/parse-args';
import { exists } from '@std/fs/exists';
import * as colors from '@std/fmt/colors';
import {SUPABASE_DB_PASSWORD, SUPABASE_PROJECT_ID} from "../_environment.ts";

interface DeploymentConfig {
	projectRef: string;
	environment: 'staging' | 'production';
	mode: 'deploy' | 'backup' | 'reset' | 'diff';
	dryRun: boolean;
	functionsOnly: boolean;
	dbOnly: boolean;
	force: boolean;
	skipTests: boolean;
	backupName?: string;
	skipBackup?: boolean;
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
	private readonly projectRoot: string;

	constructor(config: DeploymentConfig) {
		this.config = config;
		// Get the project root directory (where this script is located)
		this.projectRoot = new URL('../', import.meta.url).pathname;
		// Fix Windows path if needed
		if (Deno.build.os === 'windows') {
			this.projectRoot = this.projectRoot.substring(1);
		}
	}

	// Main orchestrator
	async execute(): Promise<boolean> {
		try {
			this.printHeader();

			if (!await this.preflightChecks()) {
				return false;
			}

			// Execute based on mode
			switch (this.config.mode) {
				case 'deploy':
					return await this.deployMode();
				case 'backup':
					return await this.backupMode();
				case 'reset':
					return await this.resetMode();
				case 'diff':
					return await this.diffMode();
				default:
					this.log('❌', `Unknown mode: ${this.config.mode}`, 'error');
					return false;
			}
		} catch (error) {
			this.log('💥', `Operation failed: ${error.message}`, 'error');
			return false;
		}
	}

	// Deployment mode (existing functionality)
	private async deployMode(): Promise<boolean> {
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
	}

	// Backup mode - creates database backup
	private async backupMode(): Promise<boolean> {
		this.log('💾', 'Starting database backup...', 'info');

		if (!this.config.force && !this.confirmBackup()) {
			this.log('⚠️', 'Backup cancelled by user', 'warn');
			return false;
		}

		const backupResult = await this.createBackup();
		if (!backupResult) {
			return false;
		}

		this.printSummary();
		return true;
	}

	// Reset mode - resets production database with safety measures
	private async resetMode(): Promise<boolean> {
		this.log('🔥', 'PRODUCTION DATABASE RESET', 'warn');
		this.log('⚠️', 'This will DELETE ALL DATA in production!', 'error');

		if (!this.config.force && !this.confirmReset()) {
			this.log('⚠️', 'Reset cancelled by user', 'warn');
			return false;
		}

		// Create backup first unless explicitly skipped
		if (!this.config.skipBackup) {
			this.log('📦', 'Creating backup before reset...', 'info');
			const backupResult = await this.createBackup('pre-reset');
			if (!backupResult) {
				this.log('❌', 'Backup failed, aborting reset for safety', 'error');
				return false;
			}
		}

		// Perform reset
		const resetResult = await this.resetProductionDatabase();
		if (!resetResult) {
			return false;
		}

		this.printSummary();
		return true;
	}

	// Diff mode - compares local and remote schemas
	private async diffMode(): Promise<boolean> {
		this.log('🔍', 'Comparing local and remote schemas...', 'info');

		const diffResult = await this.compareSchemas();
		if (!diffResult) {
			return false;
		}

		return true;
	}

	private printHeader(): void {
		const modeEmojis = {
			deploy: '🚀',
			backup: '💾',
			reset: '🔥',
			diff: '🔍',
		};
		const modeTitle = {
			deploy: 'Production Deployment',
			backup: 'Database Backup',
			reset: 'Production Database Reset',
			diff: 'Schema Comparison',
		};
		
		console.log(colors.cyan(`${modeEmojis[this.config.mode]} Akademia Supabase ${modeTitle[this.config.mode]}`));
		console.log(colors.cyan('=========================================='));
		console.log(`📍 Project: ${this.config.projectRef}`);
		console.log(`🎯 Environment: ${this.config.environment}`);
		console.log(`🔄 Mode: ${this.config.mode.toUpperCase()}`);
		console.log(`🧪 Dry Run: ${this.config.dryRun ? 'Yes' : 'No'}`);
		
		if (this.config.mode === 'deploy') {
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
		}
		console.log('');
	}

	private async preflightChecks(): Promise<boolean> {
		this.log('🔍', 'Running preflight checks...', 'info');

		// Check if Supabase CLI is installed
		if (!await this.checkSupabaseCLI()) {
			return false;
		}

		// Check if Docker is running (required for Edge Functions in deploy mode, but not in dry-run)
		if (this.config.mode === 'deploy' && !this.config.dbOnly && !this.config.dryRun && !await this.checkDocker()) {
			return false;
		}

		// Check if project is linked
		if (!await this.checkProjectLink()) {
			return false;
		}

		// Verify environment variables (for deploy, diff, and reset modes)
		if (['deploy', 'diff', 'reset'].includes(this.config.mode) && !this.checkEnvironmentVariables()) {
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
			const result = await this.runCommand(
				['npx', 'supabase', '--version'],
				{ cwd: this.projectRoot }
			);
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
			// First try to read the project ID from .temp/project-ref
			const configPath = `${this.projectRoot}/.temp/project-ref`;
			try {
				const projectRef = await Deno.readTextFile(configPath);
				if (projectRef.trim() === this.config.projectRef) {
					this.log(
						'✅',
						`Project linked: ${this.config.projectRef}`,
						'success',
					);
					return true;
				}
			} catch {
				// File doesn't exist, fall back to status command
			}

			// Fall back to status command
			const result = await this.runCommand(
				['npx', 'supabase', 'status', '--workdir', this.projectRoot],
				{ cwd: this.projectRoot }
			);
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
					`Project not linked. Run: npx supabase link --project-ref ${this.config.projectRef}`,
					'error',
				);
				return false;
			}
		} catch {
			return false;
		}
	}

	private checkEnvironmentVariables(): boolean {
		// All operations that interact with remote project need DB password
		// when project is linked with DB password, it can do all operations
		if (!SUPABASE_DB_PASSWORD) {
			this.log(
				'❌',
				'Missing environment variable: SUPABASE_DB_PASSWORD',
				'error',
			);
			this.log(
				'💡',
				`Get your database password from: https://supabase.com/dashboard/project/${this.config.projectRef}/settings/database`,
				'info',
			);
			this.log(
				'💡',
				'Set it with: export SUPABASE_DB_PASSWORD=your_password',
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
		if (!await exists(`${this.projectRoot}/config.toml`)) {
			this.log('❌', 'config.toml not found', 'error');
			return false;
		}

		// Check functions directory exists
		if (!await exists(`${this.projectRoot}/functions`)) {
			this.log('❌', 'functions directory not found', 'error');
			return false;
		}

		// Check migrations directory exists
		if (!await exists(`${this.projectRoot}/migrations`)) {
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
				'DRY RUN: Would deploy migrations with: npx supabase db push',
				'info',
			);
			this.addResult(true, 'database', 'Database deployment simulated');
			return true;
		}

		try {
			// Get current migration status
			const statusResult = await this.runCommand(
				[
					'npx',
					'supabase',
					'migration',
					'list',
				],
				{ cwd: this.projectRoot }
			);
			this.log('📋', 'Current migration status:', 'info');
			console.log(statusResult.output);

			// Deploy migrations
			const deployResult = await this.runCommand(
				[
					'npx',
					'supabase',
					'db',
					'push',
					'--include-seed',
				],
				{ cwd: this.projectRoot }
			);

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
				'DRY RUN: Would deploy functions with: npx supabase functions deploy',
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
			const deployResult = await this.runCommand(
				[
					'npx',
					'supabase',
					'functions',
					'deploy',
					'--no-verify-jwt', // akademy function handles its own auth
				],
				{ cwd: this.projectRoot }
			);

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
		if (await exists(`${this.projectRoot}/.env`)) {
			try {
				const result = await this.runCommand(
					[
						'npx',
						'supabase',
						'secrets',
						'set',
						'--env-file',
						`${this.projectRoot}/.env`,
					],
					{ cwd: this.projectRoot }
				);

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
			const statusResult = await this.runCommand(
			['npx', 'supabase', 'status'],
			{ cwd: this.projectRoot }
		);
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
			const result = await this.runCommand(
				[
					'npx',
					'supabase',
					'migration',
					'list',
				],
				{ cwd: this.projectRoot }
			);

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

	// New methods for backup functionality
	private async createBackup(prefix?: string): Promise<boolean> {
		const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
		const backupName = this.config.backupName || 
			`${prefix || 'backup'}-${this.config.projectRef}-${timestamp}.sql`;
		
		this.log('💾', `Creating backup: ${backupName}`, 'info');

		if (this.config.dryRun) {
			this.log('📋', `DRY RUN: Would create backup with: npx supabase db dump -f ${backupName}`, 'info');
			this.addResult(true, 'backup', 'Backup creation simulated');
			return true;
		}

		try {
			// Create backups directory if it doesn't exist
			await Deno.mkdir(`${this.projectRoot}/backups`, { recursive: true });
			
			const dumpResult = await this.runCommand(
				[
					'npx',
					'supabase',
					'db',
					'dump',
					'-f',
					`${this.projectRoot}/backups/${backupName}`,
					'--data-only', // Or remove this to include schema
				],
				{ cwd: this.projectRoot }
			);

			if (dumpResult.success) {
				this.log('✅', `Backup created successfully: ./backups/${backupName}`, 'success');
				this.addResult(true, 'backup', `Backup saved to ./backups/${backupName}`);
				
				// Get file size
				const fileInfo = await Deno.stat(`${this.projectRoot}/backups/${backupName}`);
				const sizeMB = (fileInfo.size / 1024 / 1024).toFixed(2);
				this.log('📊', `Backup size: ${sizeMB} MB`, 'info');
				
				return true;
			} else {
				this.log('❌', 'Backup creation failed', 'error');
				this.log('📝', dumpResult.output, 'error');
				this.addResult(false, 'backup', dumpResult.output);
				return false;
			}
		} catch (error) {
			this.log('❌', `Backup error: ${error.message}`, 'error');
			return false;
		}
	}

	// Reset production database
	private async resetProductionDatabase(): Promise<boolean> {
		this.log('🔥', 'Resetting production database...', 'warn');

		if (this.config.dryRun) {
			this.log('📋', 'DRY RUN: Would reset database with: npx supabase db reset --linked', 'info');
			this.addResult(true, 'reset', 'Database reset simulated');
			return true;
		}

		try {
			// Final safety check
			const resetPhrase = prompt('This will DELETE ALL DATA. Type "RESET PRODUCTION" to confirm: ');
			if (resetPhrase !== 'RESET PRODUCTION') {
				this.log('⚠️', 'Reset aborted - confirmation failed', 'warn');
				return false;
			}

			const resetResult = await this.runCommand([
				'supabase',
				'db',
				'reset',
				'--linked',
			]);

			if (resetResult.success) {
				this.log('✅', 'Production database reset successfully', 'success');
				this.addResult(true, 'reset', 'Database reset completed');
				
				// Run seed if exists
				this.log('🌱', 'Running seed data...', 'info');
				const seedResult = await this.runCommand(
					[
						'npx',
						'supabase',
						'db',
						'push',
						'--include-seed',
					],
					{ cwd: this.projectRoot }
				);
				
				if (seedResult.success) {
					this.log('✅', 'Seed data applied', 'success');
				}
				
				return true;
			} else {
				this.log('❌', 'Database reset failed', 'error');
				this.log('📝', resetResult.output, 'error');
				this.addResult(false, 'reset', resetResult.output);
				return false;
			}
		} catch (error) {
			this.log('❌', `Reset error: ${error.message}`, 'error');
			return false;
		}
	}

	// Compare schemas between local and remote
	private async compareSchemas(): Promise<boolean> {
		this.log('🔍', 'Generating schema diff...', 'info');

		try {
			const diffResult = await this.runCommand(
				[
					'npx',
					'supabase',
					'db',
					'diff',
					'--use-migra',
					'--linked',
				],
				{ cwd: this.projectRoot }
			);

			if (diffResult.success || diffResult.output.includes('No differences')) {
				if (diffResult.output.includes('No differences')) {
					this.log('✅', 'Local and remote schemas are in sync', 'success');
					this.addResult(true, 'diff', 'Schemas are identical');
				} else {
					this.log('📋', 'Schema differences found:', 'info');
					console.log(colors.yellow(diffResult.output));
					this.addResult(true, 'diff', 'Schema differences displayed');
					
					// Offer to save diff as migration
					if (!this.config.dryRun && this.confirm('Save differences as a new migration?')) {
						const migrationName = prompt('Migration name: ');
						if (migrationName) {
							const saveResult = await this.runCommand(
								[
									'npx',
									'supabase',
									'db',
									'diff',
									'-f',
									migrationName,
									'--use-migra',
									'--linked',
								],
								{ cwd: this.projectRoot }
							);
							
							if (saveResult.success) {
								this.log('✅', `Migration saved: migrations/${migrationName}.sql`, 'success');
							}
						}
					}
				}
				return true;
			} else {
				this.log('❌', 'Schema comparison failed', 'error');
				this.log('📝', diffResult.output, 'error');
				this.addResult(false, 'diff', diffResult.output);
				return false;
			}
		} catch (error) {
			this.log('❌', `Diff error: ${error.message}`, 'error');
			return false;
		}
	}

	// Confirmation methods
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

	private confirmBackup(): boolean {
		console.log('');
		console.log('📦 Backup Configuration:');
		console.log(`   • Project: ${this.config.projectRef}`);
		console.log(`   • Backup name: ${this.config.backupName || 'auto-generated'}`);
		console.log('');
		
		return this.confirm('Create production database backup?');
	}

	private confirmReset(): boolean {
		console.log('');
		console.log(colors.red('🚨 EXTREME DANGER - PRODUCTION RESET 🚨'));
		console.log(colors.red('====================================='));
		console.log(colors.yellow('This operation will:'));
		console.log(colors.yellow('   • DELETE ALL DATA in production'));
		console.log(colors.yellow('   • Drop all tables, functions, and policies'));
		console.log(colors.yellow('   • Recreate database from migrations'));
		console.log(colors.yellow('   • Apply seed data (if configured)'));
		console.log('');
		console.log(colors.red('This action CANNOT be undone!'));
		console.log('');
		
		if (!this.config.skipBackup) {
			console.log(colors.green('✅ A backup will be created first'));
		} else {
			console.log(colors.red('❌ NO BACKUP WILL BE CREATED (--skip-backup flag)'));
		}
		console.log('');
		
		// Multiple confirmations for safety
		if (!this.confirm('Do you understand this will DELETE ALL PRODUCTION DATA?')) {
			return false;
		}
		
		if (!this.confirm('Are you ABSOLUTELY SURE you want to reset production?')) {
			return false;
		}
		
		const projectConfirm = prompt(`Type the project ID "${this.config.projectRef}" to confirm: `);
		if (projectConfirm !== this.config.projectRef) {
			this.log('❌', 'Project ID mismatch - reset aborted', 'error');
			return false;
		}
		
		return true;
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
🚀 Akademia Supabase Production Operations Script

Usage:
  deno run --allow-all scripts/deploy-production.ts --mode <mode> [options]

Modes:
  deploy    Deploy database migrations and/or Edge Functions (default)
  backup    Create a backup of the production database
  reset     Reset production database (DANGEROUS!)
  diff      Compare local and remote schemas

Common Options:
  --mode <mode>        Operation mode (default: deploy)
  --dry-run            Show what would be executed without running
  --force              Skip confirmation prompts
  --project-ref <id>   Specify project reference ID
  --help               Show this help message

Deploy Mode Options:
  --functions-only     Deploy only Edge Functions
  --db-only           Deploy only database migrations
  --skip-tests        Skip pre-deployment tests

Backup Mode Options:
  --backup-name <name> Custom name for backup file

Reset Mode Options:
  --skip-backup        Skip backup before reset (VERY DANGEROUS!)

Environment Variables (required):
  SUPABASE_DB_PASSWORD     Project database password

Examples:
  # Deploy changes to production
  deno run --allow-all scripts/deploy-production.ts --mode deploy --project-ref abc123

  # Create production backup
  deno run --allow-all scripts/deploy-production.ts --mode backup --project-ref abc123

  # Compare schemas (dry run by default)
  deno run --allow-all scripts/deploy-production.ts --mode diff --project-ref abc123

  # Reset production (with automatic backup)
  deno run --allow-all scripts/deploy-production.ts --mode reset --project-ref abc123

  # Deploy only functions
  deno run --allow-all scripts/deploy-production.ts --functions-only --project-ref abc123
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
			'skip-backup',
			'help',
		],
		string: ['project-ref', 'mode', 'backup-name'],
		alias: {
			h: 'help',
			p: 'project-ref',
			d: 'dry-run',
			f: 'force',
			m: 'mode',
		},
	});

	if (args.help) {
		printHelp();
		Deno.exit(0);
	}

	const projectRef = args['project-ref'] ||
        SUPABASE_PROJECT_ID;

	if (!projectRef) {
		console.error(
			colors.red(
				'❌ Project reference ID required. Use --project-ref or set SUPABASE_PROJECT_ID',
			),
		);
		console.error(
			colors.blue('💡 Get your project ID with: npx supabase projects list'),
		);
		Deno.exit(1);
	}

	// Determine mode
	let mode: DeploymentConfig['mode'] = 'deploy';
	if (args.mode) {
		const validModes = ['deploy', 'backup', 'reset', 'diff'];
		if (validModes.includes(args.mode)) {
			mode = args.mode as DeploymentConfig['mode'];
		} else {
			console.error(colors.red(`❌ Invalid mode: ${args.mode}`));
			console.error(colors.blue(`💡 Valid modes: ${validModes.join(', ')}`));
			Deno.exit(1);
		}
	}

	const config: DeploymentConfig = {
		projectRef,
		environment: 'production',
		mode,
		dryRun: args['dry-run'] || false,
		functionsOnly: args['functions-only'] || false,
		dbOnly: args['db-only'] || false,
		force: args.force || false,
		skipTests: args['skip-tests'] || false,
		backupName: args['backup-name'],
		skipBackup: args['skip-backup'] || false,
	};

	const deployment = new ProductionDeployment(config);
	const success = await deployment.execute();

	Deno.exit(success ? 0 : 1);
}

if (import.meta.main) {
	await main();
}
