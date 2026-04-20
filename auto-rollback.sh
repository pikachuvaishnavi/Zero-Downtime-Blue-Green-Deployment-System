#!/bin/bash

echo "🔍 Checking app health..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)

if [ "$STATUS" != "200" ]; then
    echo "❌ App unhealthy! Rolling back..."

    # Detect current active service
    if grep -q "server green" nginx/nginx.conf; then
        CURRENT="green"
        TARGET="blue"
    else
        CURRENT="blue"
        TARGET="green"
    fi

    echo "Switching $CURRENT → $TARGET"

    sed -i "s/server $CURRENT:5000;/# server $CURRENT:5000;/g" nginx/nginx.conf
    sed -i "s/# server $TARGET:5000;/server $TARGET:5000;/g" nginx/nginx.conf

    docker exec nginx nginx -s reload

    echo "✅ Rollback complete 🚨"
else
    echo "✅ App healthy"
fi