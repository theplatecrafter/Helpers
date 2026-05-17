#!/bin/bash

# ────────────────────────────────────────────────────────────────────────────
# new_webapp.sh — Create a new Flask-SocketIO webapp baseline
#
# This script creates a new web application directory with the same structure
# and baseline setup as HansHub, including all necessary files and folders
# for a production-ready Flask-SocketIO application.
# ────────────────────────────────────────────────────────────────────────────

set -e

# ─── Colors for output ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# ─── Helper functions ───────────────────────────────────────────────────────

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# ────────────────────────────────────────────────────────────────────────────
# Main Script
# ────────────────────────────────────────────────────────────────────────────

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     New Flask-SocketIO Web Application Generator              ║${NC}"
echo -e "${BLUE}║         (Based on HansHub Architecture)                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Prompt for webapp name ──────────────────────────────────────────────────
# Propmt user for the parent directory of this new webapp directory


read -p "Enter the name of your new web application: " APP_NAME

# Validate input
if [[ -z "$APP_NAME" ]]; then
    error "Application name cannot be empty."
    exit 1
fi

# Check if directory already exists
if [[ -d "$APP_NAME" ]]; then
    error "Directory '$APP_NAME' already exists. Choose a different name."
    exit 1
fi

info "Creating new Flask-SocketIO web application: $APP_NAME"
echo ""


# ─── Create root directory ───────────────────────────────────────────────────

mkdir -p "$APP_NAME"
cd "$APP_NAME"

info "Setting up directory structure..."

# ─── Create folder structure ─────────────────────────────────────────────────

mkdir -p blueprints
mkdir -p socket_events
mkdir -p static/js
mkdir -p static/css
mkdir -p templates
mkdir -p functions
mkdir -p tests
mkdir -p logs

success "Created directory structure"

# ────────────────────────────────────────────────────────────────────────────
# Create dependencies.txt
# ────────────────────────────────────────────────────────────────────────────

cat > dependencies.txt << 'EOF'
flask
flask-socketio
python-socketio
gevent
gevent-websocket
apscheduler
requests
python-dotenv
EOF

success "Created dependencies.txt"

# ────────────────────────────────────────────────────────────────────────────
# Create config.py
# ────────────────────────────────────────────────────────────────────────────

cat > config.py << 'EOF'
# config.py
"""
Configuration file for the web application.
All configuration variables are defined here for easy access throughout the app.
"""

import os
import secrets

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ─── Flask Configuration ─────────────────────────────────────────────────────

PORT = int(os.getenv("PORT", 5000))
SECRET_KEY = os.getenv("SECRET_KEY", secrets.token_hex(32))
DEBUG = os.getenv("DEBUG", "True").lower() == "true"

# ─── CORS Configuration ──────────────────────────────────────────────────────

CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")

# ─── Session Configuration ──────────────────────────────────────────────────

SESSION_TIMEOUT = int(os.getenv("SESSION_TIMEOUT", 3600))  # 1 hour in seconds

# ─── Database Configuration (if needed) ──────────────────────────────────────

DB_PATH = os.path.join(BASE_DIR, "app.db")

# ─── Logging Configuration ──────────────────────────────────────────────────

LOG_DIR = "logs"
LOG_MAXBYTES = 5 * 1024 * 1024  # 5 MB
LOG_BACKUPCOUNT = 3
EOF

success "Created config.py"

# ────────────────────────────────────────────────────────────────────────────
# Create glob_vars.py (Global variables and logging setup)
# ────────────────────────────────────────────────────────────────────────────

cat > glob_vars.py << 'EOF'
# glob_vars.py
"""
Global variables and logging configuration.
This module sets up application-wide loggers and exposes configuration.
"""

from config import *
import os
import logging
from logging.handlers import RotatingFileHandler

# ─── Logging Setup ──────────────────────────────────────────────────────────

def setup_logger(name, log_file, level=logging.INFO):
    """Create and configure a logger with file and console handlers."""
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(name)s: %(message)s')

    # File handler with rotation
    file_handler = RotatingFileHandler(
        os.path.join(LOG_DIR, log_file),
        maxBytes=LOG_MAXBYTES,
        backupCount=LOG_BACKUPCOUNT
    )
    file_handler.setFormatter(formatter)

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    # Create and configure logger
    logger = logging.getLogger(name)
    logger.setLevel(level)

    if not logger.handlers:
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger

# Create application loggers
app_log = setup_logger('app', 'app.log')
access_log = setup_logger('access', 'access.log')
error_log = setup_logger('error', 'error.log', level=logging.ERROR)
EOF

success "Created glob_vars.py"

# ────────────────────────────────────────────────────────────────────────────
# Create socketio_instance.py
# ────────────────────────────────────────────────────────────────────────────

cat > socketio_instance.py << 'EOF'
# socketio_instance.py
"""
Flask-SocketIO instance configuration.
Uses gevent for async mode to enable WebSocket support and reverse proxying.
"""

from glob_vars import *
from flask_socketio import SocketIO

# Initialize SocketIO with gevent async mode
socketio = SocketIO(
    cors_allowed_origins="*",
    async_mode='gevent',
    ping_timeout=10,
    ping_interval=5
)
EOF

success "Created socketio_instance.py"

# ────────────────────────────────────────────────────────────────────────────
# Create app.py (Main Flask application)
# ────────────────────────────────────────────────────────────────────────────

cat > app.py << 'EOF'
# app.py
"""
Main Flask-SocketIO application.
This is the entry point for the web application.
"""

# CRITICAL: Gevent monkey patching MUST be at the absolute top, before any other imports
# This patches the standard library (sockets, threading, etc.) to be Gevent-aware,
# preventing the event loop from blocking during synchronous I/O operations.
from gevent import monkey
monkey.patch_all()

# Import global variables and configuration
from glob_vars import *
import os
from flask import Flask, render_template, session, redirect, url_for, request
from werkzeug.middleware.proxy_fix import ProxyFix
from socketio_instance import socketio
import config as _config
import signal
import gevent
import sys

# Get project directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ─── Create Flask app ────────────────────────────────────────────────────────

app = Flask(__name__)
app.secret_key = _config.SECRET_KEY

# Apply ProxyFix middleware for proper URL handling behind proxies
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1, x_prefix=1)

# Initialize SocketIO with the Flask app
socketio.init_app(app)

# ─── Template filters ────────────────────────────────────────────────────────

import datetime

@app.template_filter("timestamp_fmt")
def timestamp_fmt(ts):
    """Convert Unix timestamp to formatted date string."""
    try:
        return datetime.datetime.fromtimestamp(float(ts)).strftime("%Y-%m-%d %H:%M")
    except Exception:
        return str(ts)

# ─── Error handlers ──────────────────────────────────────────────────────────

@app.errorhandler(404)
def not_found(e):
    return render_template("404.html"), 404

@app.errorhandler(500)
def server_error(e):
    app_log.error(f"Server error: {e}")
    return render_template("500.html"), 500

# ─── Context processors ──────────────────────────────────────────────────────

@app.context_processor
def inject_globals():
    """Inject global variables into all templates."""
    return {
        "app_name": "MyApp",
        "app_version": "1.0.0",
    }

# ─── WebSocket event handlers ───────────────────────────────────────────────

@socketio.on("connect")
def handle_connect():
    """Handle client connection."""
    app_log.info(f"Client connected: {request.sid}")

@socketio.on("disconnect")
def handle_disconnect():
    """Handle client disconnection."""
    app_log.info(f"Client disconnected: {request.sid}")

# ─── Routes ──────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    """Home page."""
    return render_template("index.html")

@app.route("/about")
def about():
    """About page."""
    return render_template("about.html")

# ─── Graceful shutdown handler ───────────────────────────────────────────────

def graceful_shutdown(*args, **kwargs):
    """
    Graceful server shutdown handler.
    Closes connections and cleans up resources before exiting.
    """
    app_log.info("[shutdown] Shutdown signal received — starting graceful shutdown...")

    # Notify all connected clients
    try:
        socketio.emit("server_shutdown", {
            "message": "The server is shutting down. See you soon!"
        })
        app_log.info("[shutdown] Shutdown notice sent to all connected clients.")
    except Exception as e:
        app_log.warning(f"[shutdown] Could not notify clients: {e}")

    # Brief pause to let socket messages finish
    from gevent import sleep as gevent_sleep
    gevent_sleep(1.5)

    app_log.info("[shutdown] Shutdown complete. Goodbye.")
    sys.exit(0)

# Use Gevent's signal handler for proper async-safe shutdown
gevent.signal_handler(signal.SIGINT, graceful_shutdown)
gevent.signal_handler(signal.SIGTERM, graceful_shutdown)

# ────────────────────────────────────────────────────────────────────────────
# Application entry point
# ────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    app_log.info(f"[startup] Starting application on port {_config.PORT}...")
    socketio.run(
        app,
        host="0.0.0.0",
        debug=_config.DEBUG,
        port=_config.PORT,
        allow_unsafe_werkzeug=True,
        use_reloader=False
    )
EOF

success "Created app.py"

# ────────────────────────────────────────────────────────────────────────────
# Create base template
# ────────────────────────────────────────────────────────────────────────────

cat > templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ app_name }} - {% block title %}Welcome{% endblock %}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    {% block extra_css %}{% endblock %}
</head>
<body>
    <header>
        <nav>
            <h1><a href="/">{{ app_name }}</a></h1>
            <ul>
                <li><a href="/">Home</a></li>
                <li><a href="/about">About</a></li>
            </ul>
        </nav>
    </header>

    <main>
        {% block content %}{% endblock %}
    </main>

    <footer>
        <p>&copy; 2026 {{ app_name }}. All rights reserved.</p>
    </footer>

    <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
    <script src="{{ url_for('static', filename='js/main.js') }}"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
EOF

success "Created templates/base.html"

# ────────────────────────────────────────────────────────────────────────────
# Create index template
# ────────────────────────────────────────────────────────────────────────────

cat > templates/index.html << 'EOF'
{% extends "base.html" %}

{% block title %}Home{% endblock %}

{% block content %}
<div class="container">
    <h2>Welcome to {{ app_name }}</h2>
    <p>This is your home page. Edit this file at <code>templates/index.html</code></p>
    
    <section class="status">
        <h3>Server Status</h3>
        <p id="server-status">Connecting to server...</p>
    </section>
</div>
{% endblock %}

{% block extra_js %}
<script>
    // Show connection status
    const socket = io();
    
    socket.on('connect', () => {
        document.getElementById('server-status').textContent = '✓ Connected to server';
        document.getElementById('server-status').style.color = 'green';
    });
    
    socket.on('disconnect', () => {
        document.getElementById('server-status').textContent = '✗ Disconnected from server';
        document.getElementById('server-status').style.color = 'red';
    });
</script>
{% endblock %}
EOF

success "Created templates/index.html"

# ────────────────────────────────────────────────────────────────────────────
# Create about template
# ────────────────────────────────────────────────────────────────────────────

cat > templates/about.html << 'EOF'
{% extends "base.html" %}

{% block title %}About{% endblock %}

{% block content %}
<div class="container">
    <h2>About {{ app_name }}</h2>
    <p>This is your about page. Edit this file at <code>templates/about.html</code></p>
    <p>Version: {{ app_version }}</p>
</div>
{% endblock %}
EOF

success "Created templates/about.html"

# ────────────────────────────────────────────────────────────────────────────
# Create 404 error template
# ────────────────────────────────────────────────────────────────────────────

cat > templates/404.html << 'EOF'
{% extends "base.html" %}

{% block title %}Not Found{% endblock %}

{% block content %}
<div class="container error-page">
    <h2>404 - Page Not Found</h2>
    <p>The page you're looking for doesn't exist.</p>
    <a href="/">← Back to Home</a>
</div>
{% endblock %}
EOF

success "Created templates/404.html"

# ────────────────────────────────────────────────────────────────────────────
# Create 500 error template
# ────────────────────────────────────────────────────────────────────────────

cat > templates/500.html << 'EOF'
{% extends "base.html" %}

{% block title %}Server Error{% endblock %}

{% block content %}
<div class="container error-page">
    <h2>500 - Server Error</h2>
    <p>Something went wrong on the server. Please try again later.</p>
    <a href="/">← Back to Home</a>
</div>
{% endblock %}
EOF

success "Created templates/500.html"

# ────────────────────────────────────────────────────────────────────────────
# Create basic CSS
# ────────────────────────────────────────────────────────────────────────────

cat > static/css/style.css << 'EOF'
/* style.css - Basic stylesheet for the application */

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f5f5f5;
}

header {
    background-color: #2c3e50;
    color: white;
    padding: 1rem 0;
    margin-bottom: 2rem;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

header h1 {
    font-size: 1.5rem;
}

header h1 a {
    color: white;
    text-decoration: none;
}

header h1 a:hover {
    opacity: 0.8;
}

header nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 1rem;
}

header nav ul {
    list-style: none;
    display: flex;
    gap: 2rem;
}

header nav a {
    color: white;
    text-decoration: none;
    transition: opacity 0.3s;
}

header nav a:hover {
    opacity: 0.7;
}

main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 1rem;
    min-height: calc(100vh - 200px);
}

.container {
    background: white;
    padding: 2rem;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.container h2 {
    margin-bottom: 1rem;
    color: #2c3e50;
}

.container p {
    margin-bottom: 1rem;
}

code {
    background-color: #f4f4f4;
    padding: 2px 6px;
    border-radius: 3px;
    font-family: 'Courier New', monospace;
}

.status {
    margin-top: 2rem;
    padding: 1rem;
    background-color: #ecf0f1;
    border-left: 4px solid #3498db;
    border-radius: 4px;
}

.status h3 {
    margin-bottom: 0.5rem;
}

.error-page {
    text-align: center;
    padding: 4rem 2rem;
}

.error-page h2 {
    color: #e74c3c;
    margin-bottom: 1rem;
}

.error-page a {
    display: inline-block;
    margin-top: 1rem;
    padding: 0.75rem 1.5rem;
    background-color: #3498db;
    color: white;
    text-decoration: none;
    border-radius: 4px;
    transition: background-color 0.3s;
}

.error-page a:hover {
    background-color: #2980b9;
}

footer {
    text-align: center;
    padding: 2rem 1rem;
    color: #7f8c8d;
    border-top: 1px solid #ecf0f1;
    margin-top: 2rem;
}
EOF

success "Created static/css/style.css"

# ────────────────────────────────────────────────────────────────────────────
# Create main JavaScript file
# ────────────────────────────────────────────────────────────────────────────

cat > static/js/main.js << 'EOF'
// main.js - Main JavaScript file for the application

console.log('Application loaded successfully');

// Example: Handle server messages
document.addEventListener('DOMContentLoaded', function() {
    // Add your client-side JavaScript here
});
EOF

success "Created static/js/main.js"

# ────────────────────────────────────────────────────────────────────────────
# Create __init__.py files for packages
# ────────────────────────────────────────────────────────────────────────────

cat > blueprints/__init__.py << 'EOF'
# blueprints/__init__.py
"""
Application blueprints package.
Register your route blueprints here.
"""
EOF

cat > socket_events/__init__.py << 'EOF'
# socket_events/__init__.py
"""
WebSocket event handlers package.
Define your SocketIO event handlers here.
"""
EOF

cat > functions/__init__.py << 'EOF'
# functions/__init__.py
"""
Helper functions and utilities package.
Place your application logic here.
"""
EOF

cat > tests/__init__.py << 'EOF'
# tests/__init__.py
"""
Unit tests package.
Write your tests here.
"""
EOF

success "Created package __init__.py files"

# ────────────────────────────────────────────────────────────────────────────
# Create start.sh
# ────────────────────────────────────────────────────────────────────────────

cat > start.sh << 'EOF'
#!/bin/bash

# start.sh - Start the Flask-SocketIO application

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Activate virtual environment if it exists
if [[ -d "venv" ]]; then
    source venv/bin/activate
fi

# Start the application
echo "Starting Flask-SocketIO application..."
python app.py
EOF

chmod +x start.sh
success "Created start.sh"

# ────────────────────────────────────────────────────────────────────────────
# Create .gitignore
# ────────────────────────────────────────────────────────────────────────────

cat > .gitignore << 'EOF'
# Virtual environment
venv/
env/
.venv

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
pip-log.txt
pip-delete-this-directory.txt

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Application
logs/
*.db
.env
.env.local
configvars.json

# Testing
.pytest_cache/
.coverage
htmlcov/
EOF

success "Created .gitignore"

# ────────────────────────────────────────────────────────────────────────────
# Create README.md
# ────────────────────────────────────────────────────────────────────────────

cat > README.md << 'EOF'
# $APP_NAME

A Flask-SocketIO web application built with modern Python web development practices.

## Features

- **Flask-SocketIO**: Real-time WebSocket support for live updates
- **Gevent-based**: Efficient async event handling
- **Modular Structure**: Organized blueprints, functions, and socket events
- **Logging**: Comprehensive logging to both file and console
- **Responsive Templates**: HTML templates with Jinja2 templating

## Project Structure

```
$APP_NAME/
├── app.py                 # Main Flask application entry point
├── config.py              # Configuration variables
├── glob_vars.py           # Global variables and logging setup
├── socketio_instance.py   # SocketIO initialization
├── start.sh               # Application startup script
├── dependencies.txt       # Python package dependencies
├── blueprints/            # Flask blueprints for route organization
├── socket_events/         # WebSocket event handlers
├── functions/             # Helper functions and utilities
├── static/                # Static files (CSS, JavaScript)
│   ├── css/
│   └── js/
├── templates/             # Jinja2 HTML templates
├── tests/                 # Unit tests
└── logs/                  # Application logs
```

## Setup

### 1. Create and activate virtual environment

\`\`\`bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\\Scripts\\activate
\`\`\`

### 2. Install dependencies

\`\`\`bash
pip install -r dependencies.txt
\`\`\`

### 3. Start the application

\`\`\`bash
bash start.sh
\`\`\`

The application will be available at \`http://localhost:5000\`

## Configuration

Edit \`config.py\` to customize:
- **PORT**: Server port (default: 5000)
- **DEBUG**: Debug mode (default: True)
- **SECRET_KEY**: Flask secret key
- **SESSION_TIMEOUT**: Session timeout in seconds

## Development

### Adding Routes

Create a new blueprint in \`blueprints/\`:

\`\`\`python
# blueprints/my_blueprint.py
from flask import Blueprint, render_template

my_bp = Blueprint('my', __name__)

@my_bp.route('/my-route')
def my_route():
    return render_template('my_template.html')
\`\`\`

Then register it in \`app.py\`:

\`\`\`python
from blueprints.my_blueprint import my_bp
app.register_blueprint(my_bp)
\`\`\`

### Adding Socket Events

Create event handlers in \`socket_events/\`:

\`\`\`python
# socket_events/my_events.py
from socketio_instance import socketio
from glob_vars import app_log

@socketio.on('my_event')
def handle_my_event(data):
    app_log.info(f"Received: {data}")
    socketio.emit('response', {'data': 'processed'})
\`\`\`

Then import it in \`app.py\`:

\`\`\`python
import socket_events.my_events
\`\`\`

## Logging

Loggers are pre-configured in \`glob_vars.py\`:

- \`app_log\`: General application logs
- \`access_log\`: Access and connection logs
- \`error_log\`: Error logs

Usage:

\`\`\`python
from glob_vars import app_log

app_log.info("Information message")
app_log.warning("Warning message")
app_log.error("Error message")
\`\`\`

## Deployment

For production:

1. Set \`DEBUG = False\` in \`config.py\`
2. Use a production WSGI server (Gunicorn, uWSGI, etc.)
3. Set secure \`SECRET_KEY\`
4. Configure CORS appropriately in \`socketio_instance.py\`

Example with Gunicorn:

\`\`\`bash
gunicorn --worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker \\
  --workers 4 --bind 0.0.0.0:5000 app:app
\`\`\`

## License

MIT
EOF

success "Created README.md"

# ────────────────────────────────────────────────────────────────────────────
# Create example blueprint
# ────────────────────────────────────────────────────────────────────────────

cat > blueprints/example.py << 'EOF'
# blueprints/example.py
"""
Example blueprint demonstrating how to organize routes.
You can create multiple blueprints for different sections of your application.
"""

from flask import Blueprint, render_template

# Create a blueprint
example_bp = Blueprint('example', __name__, url_prefix='/example')

@example_bp.route('/')
def example_index():
    """Example route."""
    return render_template('example.html')
EOF

success "Created blueprints/example.py"

# ────────────────────────────────────────────────────────────────────────────
# Create example socket events
# ────────────────────────────────────────────────────────────────────────────

cat > socket_events/example_events.py << 'EOF'
# socket_events/example_events.py
"""
Example WebSocket event handlers.
This demonstrates how to handle real-time communication with clients.
"""

from socketio_instance import socketio
from glob_vars import app_log

@socketio.on('test_message')
def handle_test_message(data):
    """Handle a test message from the client."""
    app_log.info(f"Received test message: {data}")
    socketio.emit('test_response', {'data': 'Message received on server'}, broadcast=True)
EOF

success "Created socket_events/example_events.py"

# ────────────────────────────────────────────────────────────────────────────
# Create example template
# ────────────────────────────────────────────────────────────────────────────

cat > templates/example.html << 'EOF'
{% extends "base.html" %}

{% block title %}Example{% endblock %}

{% block content %}
<div class="container">
    <h2>Example Page</h2>
    <p>This is an example page to show you how to structure templates.</p>
    
    <section class="example-section">
        <h3>WebSocket Example</h3>
        <p id="message-log">Waiting for messages...</p>
        <button id="send-test">Send Test Message</button>
    </section>
</div>
{% endblock %}

{% block extra_js %}
<script>
    const socket = io();
    
    document.getElementById('send-test').addEventListener('click', function() {
        socket.emit('test_message', { message: 'Hello from client!' });
    });
    
    socket.on('test_response', function(data) {
        document.getElementById('message-log').textContent = '✓ ' + data.data;
    });
</script>
{% endblock %}
EOF

success "Created templates/example.html"

# ────────────────────────────────────────────────────────────────────────────
# Create setup instructions
# ────────────────────────────────────────────────────────────────────────────

cat > SETUP_INSTRUCTIONS.md << 'EOF'
# Setup Instructions

## 1. Create Python Virtual Environment

\`\`\`bash
python3 -m venv venv
\`\`\`

## 2. Activate Virtual Environment

**Linux/macOS:**
\`\`\`bash
source venv/bin/activate
\`\`\`

**Windows:**
\`\`\`bash
venv\\Scripts\\activate
\`\`\`

## 3. Install Dependencies

\`\`\`bash
pip install --upgrade pip
pip install -r dependencies.txt
\`\`\`

## 4. Run the Application

\`\`\`bash
bash start.sh
\`\`\`

The application will start on \`http://localhost:5000\`

## 5. Next Steps

- Edit \`app.py\` to customize your application
- Add new routes in \`blueprints/\`
- Add WebSocket handlers in \`socket_events/\`
- Customize templates in \`templates/\`
- Add styles in \`static/css/\` and JavaScript in \`static/js/\`

## Need Help?

Check the \`README.md\` for detailed documentation on:
- Project structure
- Adding routes and blueprints
- WebSocket events
- Logging
- Deployment

Enjoy building! 🚀
EOF

success "Created SETUP_INSTRUCTIONS.md"

python3 -m venv venv
source venv/bin/activate

read -p "Do you want to initialize a new Git repository for this project? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git init
    git add .
    git commit -m "Initial commit - Create new Flask-SocketIO web application baseline"
    success "Initialized new Git repository and made initial commit"
else
    warn "Git repository not initialized. You can run 'git init' later to start version control."
fi

# ────────────────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Setup Complete! 🎉                                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

success "Created Flask-SocketIO web application: $APP_NAME"
echo ""
echo "📁 Project directory: ./$APP_NAME"
echo ""
echo "Next steps:"
echo ""
echo "  1. Navigate to the project:"
echo "     ${BLUE}cd $APP_NAME${NC}"
echo ""
echo "  2. Create and activate virtual environment:"
echo "     ${BLUE}python3 -m venv venv${NC}"
echo "     ${BLUE}source venv/bin/activate${NC}"
echo ""
echo "  3. Install dependencies:"
echo "     ${BLUE}pip install -r dependencies.txt${NC}"
echo ""
echo "  4. Start the application:"
echo "     ${BLUE}bash start.sh${NC}"
echo ""
echo "  5. Open your browser:"
echo "     ${BLUE}http://localhost:5000${NC}"
echo ""
echo "📚 Documentation:"
echo "   - README.md - Project overview and usage"
echo "   - SETUP_INSTRUCTIONS.md - Detailed setup guide"
echo "   - config.py - Configuration variables"
echo ""
echo "✨ Happy coding!"
EOF
