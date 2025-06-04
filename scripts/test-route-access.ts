#!/usr/bin/env -S deno run -A

/**
 * Test route access with different user role levels
 * Tests that only users with level 95+ can access the /migrate route
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../_environment.ts';

// Colors for console output
const green = '\x1b[32m';
const red = '\x1b[31m';
const yellow = '\x1b[33m';
const blue = '\x1b[34m';
const reset = '\x1b[0m';


const credentials = JSON.parse(await Deno.readTextFile('./credentials.json'));

const roleLevels: Record<string, number> = {
  'superadmin': 100,
  'general_director': 95,
  'executive_leader': 90,
  'pedagogical_leader': 90,
  'communication_leader': 90,
  'coordination_leader': 90,
  'innovation_leader': 80,
  'community_leader': 80,
  'utopik_foundation_user': 80,
  'coordinator': 80,
  'legal_advisor': 80,
  'konsejo_member': 80,
  'headquarter_manager': 50,
  'pedagogical_manager': 50,
  'communication_manager': 50,
  'companion_director': 50,
  'manager_assistant': 30,
  'companion': 20,
  'facilitator': 20,
  'student': 1
};

interface TestResult {
  role: string;
  level: number;
  status: number;
  success: boolean;
  message: string;
}

async function testRouteAccess(route: string, requiredLevel: number) {
  console.log(`\n${blue}Testing route: ${route}${reset}`);
  console.log(`${yellow}Required level: ${requiredLevel}+${reset}\n`);

  const results: TestResult[] = [];

  // Test with users of different levels
  const testUsers = [
    credentials.find((c: any) => c.role === 'student'),           // Level 1
    credentials.find((c: any) => c.role === 'manager_assistant'), // Level 30
    credentials.find((c: any) => c.role === 'coordinator'),       // Level 80
    credentials.find((c: any) => c.role === 'general_director'),  // Level 95
    credentials.find((c: any) => c.role === 'superadmin'),        // Level 100
  ].filter(Boolean);

  for (const user of testUsers) {
    const level = roleLevels[user.role];
    console.log(`${yellow}Testing with ${user.role} (Level ${level})...${reset}`);

    try {
      const supabase = createClient(SUPABASE_URL!, SUPABASE_ANON_KEY!);
      const { data: session, error: signInError } = await supabase.auth.signInWithPassword({
        email: user.email,
        password: user.password
      });

      if (signInError || !session.session) {
        console.error(`${red}Failed to sign in as ${user.email}${reset}`);
        continue;
      }

      let body = {};
      if (route.includes('/create-user')) {
        body = { agreement_id: '00000000-0000-0000-0000-000000000000' };
      } else if (route.includes('/reset-password')) {
        body = {
          email: 'test@example.com',
          document_number: '12345678',
          new_password: 'NewPassword123!',
          phone: '+1234567890',
          first_name: 'Test',
          last_name: 'User'
        };
      } else if (route.includes('/deactivate-user')) {
        body = { user_id: '00000000-0000-0000-0000-000000000000' };
      }

      const response = await fetch(`http://127.0.0.1:54321/functions/v1${route}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${session.session.access_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(body)
      });

      const shouldHaveAccess = level >= requiredLevel;

      const hasAccess = response.status === 200 || 
        (shouldHaveAccess && route !== '/akademy-app/migrate' && (response.status === 400 || response.status === 404));
      const accessDenied = response.status === 401 || response.status === 403;

      const success = shouldHaveAccess ? !accessDenied : accessDenied;

      results.push({
        role: user.role,
        level,
        status: response.status,
        success,
        message: shouldHaveAccess 
          ? (accessDenied ? `Access denied (${response.status})` : `Access granted (${response.status})`)
          : (accessDenied ? `Correctly denied (${response.status})` : `Unexpected access (${response.status})`)
      });

      if (success) {
        console.log(`  ${green}✓ ${user.role}: ${results[results.length - 1].message}${reset}`);
      } else {
        console.log(`  ${red}✗ ${user.role}: ${results[results.length - 1].message}${reset}`);
      }

    } catch (error) {
      console.error(`  ${red}✗ ${user.role}: Error - ${error.message}${reset}`);
      results.push({
        role: user.role,
        level,
        status: 0,
        success: false,
        message: `Error: ${error.message}`
      });
    }
  }

  console.log(`\n${blue}Summary:${reset}`);
  console.log('─'.repeat(50));
  
  const passed = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;
  
  console.log(`${green}Passed: ${passed}${reset} | ${red}Failed: ${failed}${reset}`);
  
  if (failed > 0) {
    console.log(`\n${red}Failed tests:${reset}`);
    results.filter(r => !r.success).forEach(r => {
      console.log(`  - ${r.role} (Level ${r.level}): ${r.message}`);
    });
  }

  return results;
}

async function main() {
  console.log(`${blue}═══════════════════════════════════════════════════${reset}`);
  console.log(`${blue}       Route Access Level Testing${reset}`);
  console.log(`${blue}═══════════════════════════════════════════════════${reset}`);

  console.log(`\n${yellow}Note: Make sure akademy-app function is running${reset}`);
  console.log(`Run: ${green}npx supabase functions serve akademy-app --env-file .env.local${reset}`);

  await testRouteAccess('/akademy-app/migrate', 95);
  await testRouteAccess('/akademy-app/create-user', 30);
  await testRouteAccess('/akademy-app/reset-password', 1);
  await testRouteAccess('/akademy-app/deactivate-user', 50);

  console.log(`\n${blue}═══════════════════════════════════════════════════${reset}`);
  console.log(`${green}Testing complete!${reset}`);
}

await main();
