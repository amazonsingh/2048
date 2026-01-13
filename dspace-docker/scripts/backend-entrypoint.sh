#!/bin/bash
# ===========================================
# DSpace Backend Entrypoint Script
# ===========================================
# This script handles:
#   1. Waiting for PostgreSQL to be ready
#   2. Waiting for Solr to be ready (CRITICAL - DSpace requires Solr at startup)
#   3. Running Flyway database migrations
#   4. Starting the DSpace server
# ===========================================

set -e

echo "========================================"
echo "DSpace Backend Starting..."
echo "========================================"
echo "Timestamp: $(date)"

# ===========================================
# Configuration from environment variables
# ===========================================
DB_HOST="${DB_HOST:-dspacedb}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-dspace}"
DB_USER="${DB_USER:-dspace}"
DB_PASSWORD="${DB_PASSWORD:-dspace}"
SOLR_HOST="${SOLR_HOST:-dspacesolr}"
SOLR_PORT="${SOLR_PORT:-8983}"

echo "Configuration:"
echo "  Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "  Solr: ${SOLR_HOST}:${SOLR_PORT}"

# ===========================================
# Wait for PostgreSQL
# ===========================================
echo ""
echo "Waiting for PostgreSQL to be ready..."

max_retries=60
retry_count=0

while ! (</dev/tcp/${DB_HOST}/${DB_PORT}) 2>/dev/null; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo "ERROR: PostgreSQL did not become ready after ${max_retries} attempts"
        exit 1
    fi
    echo "  PostgreSQL not ready (attempt ${retry_count}/${max_retries})..."
    sleep 2
done

echo "✓ PostgreSQL is ready!"

# ===========================================
# Wait for Solr (CRITICAL)
# ===========================================
# DSpace REQUIRES Solr to be accessible during Spring Boot initialization
# Without Solr, DSpace will fail with: "Failed to contact Solr"
# ===========================================
echo ""
echo "Waiting for Solr to be ready..."
echo "  (DSpace requires Solr to be accessible at startup)"

max_retries=60
retry_count=0

# Check if Solr search core is responding
until curl -sf "http://${SOLR_HOST}:${SOLR_PORT}/solr/search/admin/ping" > /dev/null 2>&1; do
    retry_count=$((retry_count + 1))
    if [ $retry_count -ge $max_retries ]; then
        echo "ERROR: Solr did not become ready after ${max_retries} attempts"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check if dspacesolr container is running: docker ps"
        echo "  2. Check Solr logs: docker logs dspacesolr"
        echo "  3. Ensure all 7 cores are created: authority, oai, search, statistics, qaevent, suggestion, audit"
        exit 1
    fi
    echo "  Solr not ready (attempt ${retry_count}/${max_retries})..."
    sleep 2
done

echo "✓ Solr is ready!"

# Verify all required cores exist
echo ""
echo "Verifying Solr cores..."
REQUIRED_CORES="authority oai search statistics qaevent suggestion audit"
for core in $REQUIRED_CORES; do
    if curl -sf "http://${SOLR_HOST}:${SOLR_PORT}/solr/${core}/admin/ping" > /dev/null 2>&1; then
        echo "  ✓ Core '${core}' is ready"
    else
        echo "  ✗ Core '${core}' is NOT ready"
        echo "ERROR: Required Solr core '${core}' is missing or not responding"
        exit 1
    fi
done

# ===========================================
# Run Database Migrations
# ===========================================
echo ""
echo "Running database migrations (Flyway)..."

if /dspace/bin/dspace database migrate; then
    echo "✓ Database migrations completed successfully!"
else
    echo "ERROR: Database migration failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check database credentials in local.cfg"
    echo "  2. Verify pgcrypto extension is enabled"
    echo "  3. Check database logs: docker logs dspacedb"
    exit 1
fi

# ===========================================
# Create Admin Account (if env vars set)
# ===========================================
if [ -n "${ADMIN_EMAIL}" ] && [ -n "${ADMIN_PASSWORD}" ]; then
    echo ""
    echo "Creating administrator account..."
    /dspace/bin/dspace create-administrator \
        -e "${ADMIN_EMAIL}" \
        -f "${ADMIN_FIRSTNAME:-Admin}" \
        -l "${ADMIN_LASTNAME:-User}" \
        -p "${ADMIN_PASSWORD}" \
        -c en 2>/dev/null || echo "  (Administrator may already exist)"
fi

# ===========================================
# Start DSpace Server
# ===========================================
echo ""
echo "========================================"
echo "Starting DSpace Server..."
echo "========================================"
echo "REST API will be available at: http://localhost:8080/server/api"
echo ""

# Execute the command passed to the container (or default to starting the server)
if [ $# -eq 0 ]; then
    exec java -jar /dspace/webapps/server-boot.jar --dspace.dir=/dspace
else
    exec "$@"
fi
