#!/bin/bash

CONF="nginx/nginx.conf"

# Detect current active server
CURRENT=$(grep -E "^\s*server (blue|green):5000;" $CONF | grep -v "#" | awk '{print $2}' | cut -d':' -f1)

[ -z "$CURRENT" ] && CURRENT="blue"

if [ "$CURRENT" == "blue" ]; then
    TARGET="green"
    PORT=5002
else
    TARGET="blue"
    PORT=5001
fi

echo "🔍 Current: $CURRENT | Checking: $TARGET"

# Health check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health)

if [ "$STATUS" != "200" ]; then
    echo "❌ $TARGET is not healthy. No switch."
    exit 0
fi

echo "✅ $TARGET is healthy → switching..."

# Replace upstream block safely
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

# Validate config
docker exec nginx nginx -t || { echo "❌ Bad config"; exit 1; }

docker exec nginx nginx -s reload

echo "🚀 Auto switch complete!"