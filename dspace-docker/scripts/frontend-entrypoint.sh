#!/bin/sh
# ===========================================
# DSpace Frontend Entrypoint Script
# Configures Angular UI and starts server
# ===========================================

set -e

echo "========================================"
echo "DSpace Frontend Starting..."
echo "========================================"

# Generate runtime configuration
cat > /app/dist/browser/assets/config.json << EOF
{
  "ui": {
    "ssl": ${DSPACE_UI_SSL:-false},
    "host": "${DSPACE_UI_HOST:-localhost}",
    "port": ${DSPACE_UI_PORT:-4000},
    "nameSpace": "${DSPACE_UI_NAMESPACE:-/}"
  },
  "rest": {
    "ssl": ${DSPACE_REST_SSL:-false},
    "host": "${DSPACE_REST_HOST:-localhost}",
    "port": ${DSPACE_REST_PORT:-8080},
    "nameSpace": "${DSPACE_REST_NAMESPACE:-/server}"
  }
}
EOF

echo "Configuration:"
cat /app/dist/browser/assets/config.json

# Wait for backend to be ready
echo "Waiting for DSpace backend..."
until curl -sf "http://${DSPACE_REST_HOST:-localhost}:${DSPACE_REST_PORT:-8080}/server/api" > /dev/null 2>&1; do
    echo "Backend is not ready yet. Waiting..."
    sleep 5
done
echo "Backend is ready!"

echo "========================================"
echo "DSpace Frontend Ready!"
echo "UI available at: http://localhost:${DSPACE_UI_PORT:-4000}"
echo "========================================"

# Execute the main command
exec "$@"
