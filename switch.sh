#!/bin/bash

CONF="nginx/nginx.conf"

# Detect current active server
CURRENT=$(grep -E "^\s*server (blue|green):5000;" $CONF | grep -v "#" | awk '{print $2}' | cut -d':' -f1)

# fallback if detection fails
[ -z "$CURRENT" ] && CURRENT="green"

if [ "$CURRENT" == "blue" ]; then
    TARGET="green"
    PORT=5002
else
    TARGET="blue"
    PORT=5001
fi

echo "Switching $CURRENT → $TARGET"

# Health check
echo "⏳ Checking health..."

for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health)
    [ "$STATUS" == "200" ] && break
    echo "Retry $i..."
    sleep 2
done

if [ "$STATUS" != "200" ]; then
    echo "❌ Target unhealthy"
    exit 1
fi

echo "🔁 Switching traffic..."

# SAFE REWRITE of upstream block ONLY
if [ "$TARGET" == "blue" ]; then
    sed -i '/upstream backend {/,/}/c\
    upstream backend {\
        server blue:5000;\
        # server green:5000;\
    }' $CONF
else
    sed -i '/upstream backend {/,/}/c\
    upstream backend {\
        # server blue:5000;\
        server green:5000;\
    }' $CONF
fi

# Validate config BEFORE reload
docker exec nginx nginx -t || { echo "❌ Bad config"; exit 1; }

docker exec nginx nginx -s reload

echo "✅ Switched successfully!"