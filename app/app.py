from flask import Flask, jsonify, request, render_template_string
import os, psutil, socket, time, logging

app = Flask(__name__)

# ---- CONFIG ----
VERSION = os.environ.get("APP_VERSION", "Unknown")
COLOR = os.environ.get("APP_COLOR", "gray")
PORT = int(os.environ.get("PORT", 5000))

# ---- STATE ----
IS_HEALTHY = True
REQUEST_COUNT = 0
START_TIME = time.time()

logging.basicConfig(level=logging.INFO)

# ---- UI ----
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
<title>Deployment Dashboard</title>
<style>
body { font-family: sans-serif; text-align: center; background:#f4f4f4; }
.card { background:white; padding:20px; border-radius:10px; display:inline-block;
       border-top:10px solid {{ color }}; }
</style>
</head>
<body>
<div class="card">
<h1>🚀 {{ version }}</h1>
<p>{{ hostname }}</p>
<p>Status: {{ 'HEALTHY' if healthy else 'FAIL' }}</p>
<p>Requests: {{ requests }}</p>
<p>Uptime: {{ uptime }} sec</p>
<p>CPU: {{ cpu }}%</p>
<p>RAM: {{ mem }}%</p>

<form action="/toggle-health" method="post">
<button>Toggle Health</button>
</form>
</div>
</body>
</html>
"""

# ---- ROUTES ----
@app.route("/")
def dashboard():
    global REQUEST_COUNT
    REQUEST_COUNT += 1

    logging.info("Request served")

    return render_template_string(HTML_TEMPLATE,
        version=VERSION,
        color=COLOR,
        hostname=socket.gethostname(),
        healthy=IS_HEALTHY,
        requests=REQUEST_COUNT,
        uptime=int(time.time() - START_TIME),
        cpu=psutil.cpu_percent(),
        mem=psutil.virtual_memory().percent
    )

@app.route("/health")
def health():
    return ("OK", 200) if IS_HEALTHY else ("FAIL", 503)

@app.route("/toggle-health", methods=["GET", "POST"])
def toggle_health():
    global IS_HEALTHY
    IS_HEALTHY = not IS_HEALTHY
    return {"healthy": IS_HEALTHY}

@app.route("/api/info")
def info():
    return jsonify({
        "version": VERSION,
        "hostname": socket.gethostname(),
        "healthy": IS_HEALTHY
    })

@app.route("/api/data", methods=["POST"])
def data():
    payload = request.json
    return jsonify({
        "received": payload,
        "handled_by": VERSION
    })

# ---- RUN ----
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)