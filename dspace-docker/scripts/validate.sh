#!/bin/bash
# ===========================================
# DSpace Docker Deployment Validation Script
# Run this script to verify your deployment
# ===========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "DSpace Docker Deployment Validator"
echo "========================================"
echo ""

# Configuration
BACKEND_URL="${DSPACE_SERVER_URL:-http://localhost:8080}"
FRONTEND_URL="${DSPACE_UI_URL:-http://localhost:4000}"
SOLR_URL="http://localhost:8983"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    if [ -n "$2" ]; then
        echo -e "  ${YELLOW}Hint${NC}: $2"
    fi
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((TOTAL_CHECKS++))
}

# =========================================
# STEP 1: Check Prerequisites
# =========================================
echo "Step 1: Checking Prerequisites"
echo "----------------------------------------"

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    check_pass "Docker installed (version: $DOCKER_VERSION)"
else
    check_fail "Docker is not installed" "Install Docker: https://docs.docker.com/get-docker/"
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
    check_pass "Docker Compose available"
else
    check_fail "Docker Compose is not available" "Install Docker Compose"
fi

# Check .env file
if [ -f ".env" ]; then
    check_pass ".env file exists"
    
    # Verify required variables
    source .env
    
    if [ -n "$SUPABASE_HOST" ]; then
        check_pass "SUPABASE_HOST is configured"
    else
        check_fail "SUPABASE_HOST not set in .env"
    fi
    
    if [ -n "$SUPABASE_PASSWORD" ]; then
        check_pass "SUPABASE_PASSWORD is configured"
    else
        check_fail "SUPABASE_PASSWORD not set in .env"
    fi
else
    check_fail ".env file not found" "Copy .env.example to .env and configure it"
fi

echo ""

# =========================================
# STEP 2: Check Container Status
# =========================================
echo "Step 2: Checking Container Status"
echo "----------------------------------------"

# Check if containers are running
for container in dspace-backend dspace-frontend dspace-solr; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "no health check")
        check_pass "Container '$container' is running (health: $STATUS)"
    else
        check_fail "Container '$container' is not running" "Run: docker-compose up -d"
    fi
done

echo ""

# =========================================
# STEP 3: Check Service Health
# =========================================
echo "Step 3: Checking Service Health"
echo "----------------------------------------"

# Check Solr
echo "Testing Solr..."
if curl -sf "${SOLR_URL}/solr/admin/cores?action=STATUS" > /dev/null 2>&1; then
    check_pass "Solr is responding"
    
    # Check individual cores
    for core in search authority statistics oai; do
        if curl -sf "${SOLR_URL}/solr/${core}/admin/ping" > /dev/null 2>&1; then
            check_pass "Solr core '${core}' is healthy"
        else
            check_warn "Solr core '${core}' may not be initialized yet"
        fi
    done
else
    check_fail "Solr is not responding" "Check Solr container logs: docker logs dspace-solr"
fi

# Check Backend API
echo ""
echo "Testing DSpace Backend..."
if curl -sf "${BACKEND_URL}/server/api" > /dev/null 2>&1; then
    check_pass "DSpace Backend API is responding"
    
    # Check API endpoint
    API_RESPONSE=$(curl -sf "${BACKEND_URL}/server/api" 2>&1)
    if echo "$API_RESPONSE" | grep -q "dspaceVersion"; then
        DSPACE_VERSION=$(echo "$API_RESPONSE" | grep -o '"dspaceVersion":"[^"]*"' | cut -d'"' -f4)
        check_pass "DSpace version: $DSPACE_VERSION"
    fi
    
    # Check HAL browser
    if curl -sf "${BACKEND_URL}/server/api/core/communities" > /dev/null 2>&1; then
        check_pass "Backend Communities endpoint accessible"
    else
        check_warn "Communities endpoint returned an error"
    fi
else
    check_fail "DSpace Backend API is not responding" "Check backend logs: docker logs dspace-backend"
fi

# Check Frontend
echo ""
echo "Testing DSpace Frontend..."
if curl -sf "${FRONTEND_URL}" > /dev/null 2>&1; then
    check_pass "DSpace Frontend is responding"
    
    # Check if it's serving HTML
    if curl -sf "${FRONTEND_URL}" | grep -q "<html" 2>&1; then
        check_pass "Frontend is serving HTML content"
    else
        check_warn "Frontend response may not be complete"
    fi
else
    check_fail "DSpace Frontend is not responding" "Check frontend logs: docker logs dspace-frontend"
fi

echo ""

# =========================================
# STEP 4: Check Database Connection
# =========================================
echo "Step 4: Checking Database Connection"
echo "----------------------------------------"

# Try to check database via backend container
if docker ps --format '{{.Names}}' | grep -q "^dspace-backend$"; then
    DB_CHECK=$(docker exec dspace-backend /dspace/bin/dspace database status 2>&1 || echo "error")
    if echo "$DB_CHECK" | grep -qi "database is up-to-date\|Flyway\|migration"; then
        check_pass "Database connection successful"
    elif echo "$DB_CHECK" | grep -qi "error\|failed\|connection"; then
        check_fail "Database connection failed" "Verify Supabase credentials in .env"
    else
        check_warn "Could not determine database status"
    fi
else
    check_warn "Cannot check database - backend container not running"
fi

echo ""

# =========================================
# STEP 5: Check Network Connectivity
# =========================================
echo "Step 5: Checking Network Connectivity"
echo "----------------------------------------"

# Check internal network
if docker network ls | grep -q "dspace-network\|dspace-docker_dspace-network"; then
    check_pass "Docker network exists"
else
    check_warn "Docker network may not be configured correctly"
fi

# Check container connectivity
if docker ps --format '{{.Names}}' | grep -q "^dspace-backend$"; then
    # Test backend can reach Solr
    SOLR_CHECK=$(docker exec dspace-backend curl -sf http://dspace-solr:8983/solr/admin/cores 2>&1 || echo "error")
    if [ "$SOLR_CHECK" != "error" ]; then
        check_pass "Backend can reach Solr internally"
    else
        check_fail "Backend cannot reach Solr" "Check Docker network configuration"
    fi
fi

echo ""

# =========================================
# STEP 6: Check Volumes and Storage
# =========================================
echo "Step 6: Checking Volumes and Storage"
echo "----------------------------------------"

for volume in dspace-docker_dspace-assetstore dspace-docker_dspace-exports dspace-docker_solr-data; do
    if docker volume ls | grep -q "$volume"; then
        SIZE=$(docker system df -v 2>/dev/null | grep "$volume" | awk '{print $3}' || echo "unknown")
        check_pass "Volume '$volume' exists (size: $SIZE)"
    else
        check_warn "Volume '$volume' not found (may use different prefix)"
    fi
done

echo ""

# =========================================
# RESULTS SUMMARY
# =========================================
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo -e "Total Checks: ${TOTAL_CHECKS}"
echo -e "${GREEN}Passed: ${PASSED_CHECKS}${NC}"
echo -e "${RED}Failed: ${FAILED_CHECKS}${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Your DSpace deployment appears to be working correctly."
    echo ""
    echo "Access URLs:"
    echo "  - Frontend UI: ${FRONTEND_URL}"
    echo "  - Backend API: ${BACKEND_URL}/server/api"
    echo "  - Solr Admin:  ${SOLR_URL}/solr/"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review the errors above.${NC}"
    echo ""
    echo "Troubleshooting Commands:"
    echo "  - View all logs:    docker-compose logs -f"
    echo "  - Backend logs:     docker logs -f dspace-backend"
    echo "  - Frontend logs:    docker logs -f dspace-frontend"
    echo "  - Solr logs:        docker logs -f dspace-solr"
    echo "  - Restart services: docker-compose restart"
    echo ""
    exit 1
fi
