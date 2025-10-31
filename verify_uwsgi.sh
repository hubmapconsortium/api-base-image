#!/usr/bin/env bash
set -euo pipefail
#set -x  # show commands as they execute

APP_DIR=/tmp/uwsgi_test_app
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create a minimal WSGI app
cat > test_wsgi.py <<'EOF'
def app(environ, start_response):
    import sys
    start_response("200 OK", [("Content-Type", "text/plain")])
    return [f"Python version: {sys.version}\n".encode()]
EOF

# uwsgi.ini forcing Python 3.13
cat > uwsgi.ini <<'EOF'
[uwsgi]
module = test_wsgi:app
http-socket = :8080
master = true
processes = 1
threads = 1
pythonpath = /usr/local/bin/python3.13
enable-threads = true
vacuum = true
die-on-term = true
EOF

echo "=== Starting uWSGI with Python 3.13 ==="
/usr/local/python3.13/bin/uwsgi --ini uwsgi.ini &
UWSGI_PID=$!

# Give uWSGI a moment to start
sleep 3

echo "=== Querying uWSGI ==="
curl -s http://localhost:8080 | tee /tmp/uwsgi_python.txt

echo "=== Checking that uWSGI is using Python 3.13 ==="
if grep -q '3\.13' /tmp/uwsgi_python.txt; then
    echo "✅ uWSGI is using Python 3.13"
else
    echo "❌ uWSGI is NOT using Python 3.13"
    exit 1
fi

# Cleanup
kill "$UWSGI_PID" || true
wait "$UWSGI_PID" 2>/dev/null || true
rm -rf "$APP_DIR"

echo "=== Checking system Python version ==="

/usr/bin/python3 --version | grep -E "^Python 3.12.[0-9][0-9]*$" > /dev/null
[ $? -eq 0 ] && echo "✅ system Python at /usr/bin/python3 is set to `/usr/bin/python3 --version`."

