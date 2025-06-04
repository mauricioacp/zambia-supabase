#!/usr/bin/env -S deno run -A

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

// Get these from your Supabase dashboard
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'https://your-project.supabase.co';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || 'your-service-role-key';

if (!SUPABASE_URL || SUPABASE_URL.includes('your-project')) {
  console.error('❌ Please set SUPABASE_URL environment variable or update the script');
  Deno.exit(1);
}

if (!SUPABASE_SERVICE_ROLE_KEY || SUPABASE_SERVICE_ROLE_KEY.includes('your-service-role-key')) {
  console.error('❌ Please set SUPABASE_SERVICE_ROLE_KEY environment variable or update the script');
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function createSuperAdmin() {
  try {
    console.log('🚀 Creating superadmin user for production...');
    
    // 1. Get headquarter and season
    console.log('📍 Fetching headquarter...');
    const { data: hq, error: hqError } = await supabase
      .from('headquarters')
      .select('id, name')
      .limit(1)
      .single();

    if (hqError) throw new Error(`Failed to fetch headquarter: ${hqError.message}`);
    console.log(`✓ Using headquarter: ${hq.name}`);

    console.log('📅 Fetching season...');
    const { data: season, error: seasonError } = await supabase
      .from('seasons')
      .select('id, name')
      .eq('headquarter_id', hq.id)
      .eq('status', 'active')
      .limit(1)
      .single();

    if (seasonError) throw new Error(`Failed to fetch season: ${seasonError.message}`);
    console.log(`✓ Using season: ${season.name}`);

    console.log('👤 Fetching superadmin role...');
    const { data: role, error: roleError } = await supabase
      .from('roles')
      .select('id, level, name')
      .eq('code', 'superadmin')
      .single();

    if (roleError) throw new Error(`Failed to fetch superadmin role: ${roleError.message}`);
    console.log(`✓ Found role: ${role.name} (Level ${role.level})`);

    // 2. Check if user already exists
    const email = 'mcpo@mcpo.com';
    console.log(`\n🔍 Checking if user ${email} already exists...`);
    
    const { data: existingUsers } = await supabase.auth.admin.listUsers();
    const existingUser = existingUsers?.users.find(u => u.email === email);
    
    if (existingUser) {
      console.error(`❌ User ${email} already exists!`);
      console.log('ℹ️  If you need to reset this user, please delete it first from the Supabase dashboard');
      Deno.exit(1);
    }

    // 3. Create agreement
    console.log('\n📝 Creating agreement...');
    const { data: agreement, error: agreementError } = await supabase
      .from('agreements')
      .insert({
        headquarter_id: hq.id,
        season_id: season.id,
        role_id: role.id,
        status: 'prospect',
        email: email,
        name: 'MCPO',
        last_name: 'Admin',
        address: 'HQ',
        volunteering_agreement: true,
        ethical_document_agreement: true,
        mailing_agreement: true,
        age_verification: true,
        signature_data: 'mcpo-admin-signature',
        document_number: '00000001',
        phone: '+5491100000001'
      })
      .select('id')
      .single();

    if (agreementError) throw new Error(`Failed to create agreement: ${agreementError.message}`);
    console.log(`✓ Agreement created: ${agreement.id}`);

    // 4. Generate secure random password
    const password = crypto.randomUUID() + '-' + Math.random().toString(36).substring(2, 15);
    
    // 5. Create user
    console.log('\n👤 Creating superadmin user...');
    const { data: user, error: userError } = await supabase.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true,
      user_metadata: {
        role: 'superadmin',
        role_level: 100,
        role_id: role.id,
        agreement_id: agreement.id,
        first_name: 'MCPO',
        last_name: 'Admin',
        document_number: '00000001',
        phone: '+5491100000001'
      }
    });

    if (userError) throw new Error(`Failed to create user: ${userError.message}`);
    console.log(`✓ User created: ${user.user.id}`);

    // 6. Update agreement with user_id
    console.log('\n🔗 Linking agreement to user...');
    const { error: updateError } = await supabase
      .from('agreements')
      .update({ user_id: user.user.id, status: 'active' })
      .eq('id', agreement.id);

    if (updateError) throw new Error(`Failed to update agreement: ${updateError.message}`);
    console.log('✓ Agreement updated to active status');

    // Success message
    console.log('\n' + '='.repeat(60));
    console.log('✅ SUPERADMIN CREATED SUCCESSFULLY!');
    console.log('='.repeat(60));
    console.log('📧 Email:', email);
    console.log('🔑 Password:', password);
    console.log('='.repeat(60));
    console.log('⚠️  IMPORTANT: Save this password securely!');
    console.log('⚠️  This password will not be shown again!');
    console.log('='.repeat(60));

    // Also save to a temporary file for safety
    const credentials = {
      created_at: new Date().toISOString(),
      email: email,
      password: password,
      user_id: user.user.id,
      role: 'superadmin',
      role_level: 100
    };
    
    const filename = `superadmin-credentials-${Date.now()}.json`;
    await Deno.writeTextFile(filename, JSON.stringify(credentials, null, 2));
    console.log(`\n📄 Credentials also saved to: ${filename}`);
    console.log('🗑️  Remember to delete this file after saving the password!');

  } catch (error) {
    console.error('\n❌ Error creating superadmin:', error.message);
    console.error('\nTroubleshooting tips:');
    console.error('1. Make sure you have the correct SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
    console.error('2. Ensure the database has been reset and seeded');
    console.error('3. Check that roles, headquarters, and seasons tables have data');
    Deno.exit(1);
  }
}

// Run the function
await createSuperAdmin();