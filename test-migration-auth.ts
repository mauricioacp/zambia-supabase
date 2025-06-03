#!/usr/bin/env -S deno run --allow-net --allow-env

// Test script to debug migration endpoint authentication

const SUPABASE_URL = 'http://localhost:54321';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

// Test different super password values
const passwords = [
    'super-long-jwt-secret-with-long-long-characters',  // From root .env
    'sjmmnTlQdozEKzEjH5a1iZlIjD2jIku2BVNEQaQSHGo=',   // From functions .env
    '123456789',  // ADMIN_SECRET from functions .env
];

console.log('Testing migration endpoint authentication...\n');

// First, test the health endpoint
console.log('1. Testing health endpoint (no auth required):');
try {
    const healthResponse = await fetch(`${SUPABASE_URL}/functions/v1/akademy/health`);
    console.log(`   Status: ${healthResponse.status}`);
    const healthData = await healthResponse.json();
    console.log(`   Response:`, healthData);
} catch (error) {
    console.log(`   Error: ${error.message}`);
}

console.log('\n2. Testing migration endpoint with different passwords:');

for (const password of passwords) {
    console.log(`\n   Testing with password: "${password}"`);
    
    try {
        const response = await fetch(`${SUPABASE_URL}/functions/v1/akademy/migrate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                'x-super-password': password,
            },
            body: JSON.stringify({}),
        });
        
        console.log(`   Status: ${response.status}`);
        const data = await response.json();
        console.log(`   Response:`, data);
        
        if (response.status === 200 || response.status === 500) {
            console.log(`   ✓ Authentication successful with this password!`);
            break;
        }
    } catch (error) {
        console.log(`   Error: ${error.message}`);
    }
}

console.log('\n3. Testing without super password header:');
try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/akademy/migrate`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({}),
    });
    
    console.log(`   Status: ${response.status}`);
    const data = await response.json();
    console.log(`   Response:`, data);
} catch (error) {
    console.log(`   Error: ${error.message}`);
}

console.log('\n4. Testing without Authorization header:');
try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/akademy/migrate`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-super-password': passwords[0],
        },
        body: JSON.stringify({}),
    });
    
    console.log(`   Status: ${response.status}`);
    const data = await response.json();
    console.log(`   Response:`, data);
} catch (error) {
    console.log(`   Error: ${error.message}`);
}