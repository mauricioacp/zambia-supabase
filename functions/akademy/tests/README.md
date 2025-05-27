# Comprehensive Integration Testing for Akademy API

This directory contains a complete testing suite for the Akademy Edge Function
with multiple testing strategies:

## 📋 **Test Types Overview**

### 🧪 **Unit Tests** (`akademy.test.ts`)

- Basic function unit testing
- Mock-based authentication testing
- Input validation testing
- Individual component testing

### 🔗 **Integration Tests** (`integration.test.ts`)

- Real database interactions
- Complete API workflow testing
- Authentication and authorization testing
- Cross-service communication testing
- Error handling and edge cases

### 🎬 **End-to-End Tests** (`e2e.test.ts`)

- Complete user journey testing
- Multi-step workflow validation
- Business process verification
- Real-world scenario simulation

### 🚀 **Performance Tests** (`performance.test.ts`)

- Load testing under various conditions
- Response time benchmarking
- Concurrent request handling
- Memory usage patterns
- Sustained load testing

## 🛠️ **Test Setup Requirements**

### Prerequisites

1. **Local Supabase instance running**:
   ```bash
   npx supabase start
   ```

2. **Edge Functions served locally**:
   ```bash
   npx supabase functions serve
   ```

3. **Environment variables set**:
   - `SUPABASE_URL`: Local Supabase URL
   - `SUPABASE_ANON_KEY`: Anonymous key
   - `SUPABASE_SERVICE_ROLE_KEY`: Service role key

### Database Requirements

- All schema migrations applied
- Seed data loaded
- Test database clean state

## 🚀 **Running Tests**

### Individual Test Suites

```bash
# Unit tests only
deno task test

# Integration tests (requires running Supabase + Functions)
deno task test:integration

# End-to-end tests (full system testing)
deno task test:e2e

# Performance tests (load testing)
deno task test:performance

# All tests (comprehensive)
deno task test:all
```

### Manual Test Execution

```bash
# Run specific test file
deno run --allow-all tests/integration.test.ts

# Run with custom environment
SUPABASE_URL=http://custom:54321 deno run --allow-all tests/e2e.test.ts
```

## 📊 **What Each Test Suite Covers**

### Integration Tests

- ✅ **Authentication Flow**: JWT validation, role-based access
- ✅ **API Endpoints**: All CRUD operations with real data
- ✅ **Database Operations**: User creation, agreement management
- ✅ **Error Handling**: Invalid inputs, missing data, authorization failures
- ✅ **Security**: Permission escalation prevention, input validation
- ✅ **Cross-Service**: Supabase Auth + Database integration

### E2E Tests

- ✅ **Complete User Journey**: Prospect → Agreement → User Creation →
  Activation
- ✅ **Password Reset Flow**: Identity verification → Password update
- ✅ **User Deactivation**: Account suspension → Agreement status update
- ✅ **Permission Boundaries**: Role-level access enforcement
- ✅ **Data Integrity**: Consistency across operations
- ✅ **Error Recovery**: Graceful failure handling

### Performance Tests

- ✅ **Sequential Load**: Response times under normal load
- ✅ **Concurrent Load**: System behavior with parallel requests
- ✅ **Endpoint Performance**: Individual API endpoint benchmarks
- ✅ **Memory Usage**: Resource consumption patterns
- ✅ **Sustained Load**: Long-term stability testing
- ✅ **Scalability Metrics**: Requests/second, response time distribution

## 🎯 **Test Coverage Areas**

### Security Testing

- JWT token validation and expiration
- Role-based access control enforcement
- Input sanitization and validation
- SQL injection prevention
- Cross-origin request handling

### Functionality Testing

- User creation from agreements
- Password reset with identity verification
- User account deactivation
- Migration endpoint dual authentication
- Health check and monitoring endpoints

### Performance Testing

- Response time under load (< 1s average)
- Concurrent request handling (95% success rate)
- Memory usage patterns
- Database connection pooling
- Error rate monitoring

### Integration Testing

- Supabase Auth integration
- Database transaction consistency
- External API communication
- Error propagation and handling
- Service dependency management

## 📈 **Success Criteria**

### Performance Benchmarks

- **Average Response Time**: < 1000ms
- **P95 Response Time**: < 2000ms
- **Success Rate**: > 95% under normal load
- **Concurrent Load**: Handle 20+ simultaneous requests
- **Memory Usage**: Stable under sustained load

### Functional Requirements

- All authentication flows work correctly
- Role-based permissions enforced
- Data integrity maintained across operations
- Error handling provides appropriate feedback
- Security measures prevent unauthorized access

## 🔧 **Test Utilities**

### TestDataManager

Handles creation and cleanup of test data:

- Creates test users with different permission levels
- Generates test agreements and related entities
- Automatic cleanup of created data
- Tracks all created records for teardown

### ApiTestHelper

Simplifies API testing:

- Authenticated request helpers
- Error expectation utilities
- Response validation
- Standard headers and formatting

### Test Environment Setup

Configures complete testing environment:

- Database client initialization
- Function URL configuration
- Authentication token management
- Environment variable handling

## 🚨 **Troubleshooting**

### Common Issues

**Tests fail with connection errors**:

```bash
# Ensure Supabase is running
npx supabase status

# Check function serving
curl http://localhost:54321/functions/v1/akademy/health
```

**Authentication errors in tests**:

```bash
# Verify environment variables
echo $SUPABASE_SERVICE_ROLE_KEY

# Check token validity
deno run --allow-all -e "console.log(atob('JWT_PAYLOAD_PART'))"
```

**Database state issues**:

```bash
# Reset database to clean state
npx supabase db reset

# Verify migrations applied
npx supabase db diff
```

### Test Data Cleanup

Tests automatically clean up created data, but manual cleanup:

```sql
-- Remove test users
DELETE FROM auth.users WHERE email LIKE '%@test.com';

-- Remove test agreements
DELETE FROM agreements WHERE email LIKE '%@test.com';
```

## 📚 **Best Practices**

### Test Development

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up created data
3. **Assertions**: Use specific, meaningful assertions
4. **Error Cases**: Test both success and failure scenarios
5. **Performance**: Monitor test execution time

### Test Maintenance

1. **Update with API changes**: Keep tests synchronized
2. **Review regularly**: Ensure tests remain relevant
3. **Monitor flakiness**: Fix unstable tests promptly
4. **Documentation**: Keep test documentation current

## 🎉 **Next Steps**

To enhance the testing suite further:

1. **Add chaos testing**: Random failure injection
2. **Implement contract testing**: API schema validation
3. **Add security scanning**: Automated vulnerability testing
4. **Create visual testing**: UI component testing if applicable
5. **Set up CI/CD integration**: Automated test execution

This comprehensive testing strategy ensures the Akademy API is production-ready
with robust error handling, security measures, and performance characteristics!
🚀
