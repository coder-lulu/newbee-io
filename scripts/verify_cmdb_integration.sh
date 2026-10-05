#!/bin/bash
# Quick Verification Script: Unified-IO → CMDB Integration
# Purpose: Verify basic connectivity and RPC communication

set -e

echo "========================================="
echo "Unified-IO → CMDB Integration Test"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CMDB_HOST="localhost:9300"
IO_HOST="localhost:9500"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘${NC} $1"
}

# Test 1: Check if CMDB RPC is running
echo "Test 1: CMDB RPC Connectivity"
if grpcurl -plaintext -max-time 3 $CMDB_HOST list > /dev/null 2>&1; then
    test_pass "CMDB RPC service is reachable"
else
    test_fail "CMDB RPC service is NOT reachable at $CMDB_HOST"
    echo "  → Start CMDB service: cd /opt/code/newbee/cmdb/rpc && ./rpc -f etc/cmdb.yaml"
fi

# Test 2: Check if Unified-IO RPC is running
echo "Test 2: Unified-IO RPC Connectivity"
if grpcurl -plaintext -max-time 3 $IO_HOST list > /dev/null 2>&1; then
    test_pass "Unified-IO RPC service is reachable"
else
    test_fail "Unified-IO RPC service is NOT reachable at $IO_HOST"
    echo "  → Start Unified-IO service: cd /opt/code/newbee/unified-io/rpc && ./rpc -f etc/io.yaml"
fi

# Test 3: Check CMDB WriteDiscoveredCI method exists
echo "Test 3: CMDB WriteDiscoveredCI Method"
if grpcurl -plaintext $CMDB_HOST list cmdb.Cmdb 2>&1 | grep -q "writeDiscoveredCI"; then
    test_pass "CMDB WriteDiscoveredCI method is available"
else
    test_fail "CMDB WriteDiscoveredCI method NOT found"
    echo "  → Make sure CMDB service is rebuilt with the new proto"
fi

# Test 4: Check Unified-IO OutputTask methods
echo "Test 4: Unified-IO OutputTask Methods"
if grpcurl -plaintext $IO_HOST list io.Io 2>&1 | grep -q "approveOutputTask"; then
    test_pass "Unified-IO approveOutputTask method is available"
else
    test_fail "Unified-IO approveOutputTask method NOT found"
    echo "  → Run 'make gen-rpc' in unified-io/rpc"
fi

# Test 5: Check if OutputProcessor is initialized (indirect check via config)
echo "Test 5: CmdbRpc Configuration"
if grep -q "CmdbRpc:" /opt/code/newbee/unified-io/rpc/etc/io.yaml; then
    CMDB_ENDPOINT=$(grep -A 2 "CmdbRpc:" /opt/code/newbee/unified-io/rpc/etc/io.yaml | grep "127.0.0.1" | awk '{print $2}')
    if [ -n "$CMDB_ENDPOINT" ]; then
        test_pass "CmdbRpc configuration found: $CMDB_ENDPOINT"
    else
        test_fail "CmdbRpc endpoint not configured in io.yaml"
    fi
else
    test_fail "CmdbRpc configuration missing in io.yaml"
fi

# Test 6: Check database connectivity (basic check)
echo "Test 6: Database Schema Check"
if [ -f "/opt/code/newbee/unified-io/rpc/etc/io.yaml" ]; then
    DB_HOST=$(grep "Host:" /opt/code/newbee/unified-io/rpc/etc/io.yaml | awk '{print $2}')
    DB_PORT=$(grep "Port:" /opt/code/newbee/unified-io/rpc/etc/io.yaml | awk '{print $2}')
    DB_NAME=$(grep "DBName:" /opt/code/newbee/unified-io/rpc/etc/io.yaml | awk '{print $2}')

    if command -v mysql > /dev/null 2>&1; then
        # Try to connect to database
        if mysql -h $DB_HOST -P $DB_PORT -u root -p123456 -e "USE $DB_NAME; SELECT COUNT(*) FROM io_output_tasks;" > /dev/null 2>&1; then
            test_pass "Database connection OK (io_output_tasks table exists)"
        else
            test_fail "Cannot connect to database or io_output_tasks table missing"
        fi
    else
        test_skip "mysql command not available, skipping database check"
    fi
else
    test_fail "Configuration file not found"
fi

# Test 7: Test CMDB WriteDiscoveredCI (dry run)
echo "Test 7: CMDB WriteDiscoveredCI Dry Run"
if command -v grpcurl > /dev/null 2>&1; then
    # Try to call with minimal data (expect validation error, but confirms method is callable)
    RESULT=$(grpcurl -plaintext -d '{"ci_type_id": 999999}' $CMDB_HOST cmdb.Cmdb/writeDiscoveredCI 2>&1)
    if [[ "$RESULT" == *"CI类型ID"* ]] || [[ "$RESULT" == *"not found"* ]] || [[ "$RESULT" == *"不存在"* ]]; then
        test_pass "CMDB WriteDiscoveredCI method is callable (validation works)"
    elif [[ "$RESULT" == *"Unimplemented"* ]]; then
        test_fail "CMDB WriteDiscoveredCI method NOT implemented"
    else
        test_skip "CMDB WriteDiscoveredCI returned unexpected response"
        echo "  Response: $RESULT"
    fi
else
    test_skip "grpcurl not installed, skipping RPC call test"
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run full E2E test: See /opt/code/newbee/unified-io/docs/E2E_TEST_UNIFIED_IO_TO_CMDB.md"
    echo "2. Create test data in CMDB (CI types, attributes)"
    echo "3. Create InputTask in Unified-IO"
    echo "4. Create OutputTask with CMDB target"
    echo "5. Verify data flow"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please fix the issues above.${NC}"
    exit 1
fi
