#!/bin/bash

# Detect active backend safely
CURRENT=$(grep -E "^\s*server (blue|green):5000;" nginx/nginx.conf | grep -v "#" | awk '{print $2}' | cut -d':' -f1)

# Fallback detection (if empty)
if [ -z "$CURRENT" ]; then
    echo "⚠️ Could not detect active server. Defaulting to green"
    CURRENT="green"
fi

# Decide target
if [ "$CURRENT" == "blue" ]; then
    TARGET="green"
    PORT=5002
else
    TARGET="blue"
    PORT=5001
fi

echo "Switching $CURRENT → $TARGET"

# Health check
echo "⏳ Checking health on localhost:$PORT..."

for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health)

    if [ "$STATUS" == "200" ]; then
        echo "✅ $TARGET is healthy!"
        break
    fi

    echo "Retry $i..."
    sleep 2
done

if [ "$STATUS" != "200" ]; then
    echo "❌ Target unhealthy. Abort."
    exit 1
fi

echo "🔁 Switching traffic..."

# Reset config safely (ensure at least one server always exists)
sed -i 's/# server blue:5000;/server blue:5000;/g' nginx/nginx.conf
sed -i 's/# server green:5000;/server green:5000;/g' nginx/nginx.conf

# Now disable CURRENT only
sed -i "s/server $CURRENT:5000;/# server $CURRENT:5000;/g" nginx/nginx.conf

# Reload nginx safely
docker exec nginx nginx -t || { echo "❌ Nginx config invalid! Aborting"; exit 1; }

docker exec nginx nginx -s reload

echo "✅ Switched successfully!"