# Flask-SocketIO Web Application Generator

## Overview

The `new_webapp.sh` script creates a new Flask-SocketIO web application with the exact structure and baseline code as **HansHub**. It's a complete scaffolding tool that sets up a production-ready Flask application in seconds.

## Quick Start

```bash
cd /path/to/your/projects
bash /home/hans/HansLand/new_webapp.sh
```

When prompted, enter your application name (e.g., `MyAwesomeApp`).

The script will:
1. Create a new directory with your app name
2. Set up the complete directory structure
3. Generate all baseline files with working code
4. Create example blueprints and socket events
5. Provide setup instructions

## Generated Project Structure

```
MyAwesomeApp/
├── app.py                     # Main Flask-SocketIO application
├── config.py                  # Configuration variables
├── glob_vars.py              # Global variables and logging
├── socketio_instance.py      # SocketIO initialization
├── start.sh                  # Application startup script (executable)
├── dependencies.txt          # Python dependencies
├── .gitignore               # Git ignore rules
├── README.md                # Project documentation
├── SETUP_INSTRUCTIONS.md    # Step-by-step setup guide
├── blueprints/
│   ├── __init__.py
│   └── example.py           # Example blueprint template
├── socket_events/
│   ├── __init__.py
│   └── example_events.py    # Example WebSocket handlers
├── functions/
│   └── __init__.py          # Helper functions package
├── static/
│   ├── css/
│   │   └── style.css        # Basic stylesheet
│   └── js/
│       └── main.js          # Client-side JavaScript
├── templates/
│   ├── base.html            # Base template
│   ├── index.html           # Home page
│   ├── about.html           # About page
│   ├── example.html         # Example page
│   ├── 404.html             # 404 error page
│   └── 500.html             # 500 error page
├── tests/
│   └── __init__.py          # Unit tests package
└── logs/                    # Application logs directory
```

## Key Features

### 1. Flask-SocketIO Integration
- Gevent-based async mode (just like HansHub)
- Proper monkey patching at application start
- WebSocket support for real-time communication
- No development server warning

### 2. Complete Baseline Code
- Working Flask app with blueprints support
- Example WebSocket event handlers
- Proper logging configuration
- Error handlers (404, 500)
- Graceful shutdown handler

### 3. Production-Ready Structure
- Organized blueprints for routes
- Socket events in separate modules
- Functions package for utilities
- Static files for CSS/JavaScript
- Comprehensive templates with Jinja2

### 4. Documentation
- Detailed README.md with examples
- SETUP_INSTRUCTIONS.md for quick onboarding
- Inline code comments throughout
- Example blueprint and socket handlers

## Setup After Generation

```bash
# 1. Navigate to your new app
cd MyAwesomeApp

# 2. Create virtual environment
python3 -m venv venv

# 3. Activate it
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows

# 4. Install dependencies
pip install -r dependencies.txt

# 5. Run the app
bash start.sh

# Open http://localhost:5000 in your browser
```

## Comparison: Generated App vs HansHub

| Feature | Generated App | HansHub |
|---------|---------------|---------|
| Flask-SocketIO | ✓ | ✓ |
| Gevent async mode | ✓ | ✓ |
| Blueprints structure | ✓ | ✓ |
| Socket events | ✓ | ✓ |
| Logging setup | ✓ | ✓ |
| ProxyFix middleware | ✓ | ✓ |
| Graceful shutdown | ✓ | ✓ |
| Example templates | ✓ | ✓ |
| Static files (CSS/JS) | ✓ | ✓ |

The main difference is that the generated app is simplified and ready for **you to customize**, while HansHub includes many specific features like chat, games, admin panel, etc.

## Adding New Routes

Create a new blueprint file:

```python
# blueprints/api.py
from flask import Blueprint, jsonify

api_bp = Blueprint('api', __name__, url_prefix='/api')

@api_bp.route('/data')
def get_data():
    return jsonify({'status': 'ok', 'data': []})
```

Register it in `app.py`:

```python
from blueprints.api import api_bp
app.register_blueprint(api_bp)
```

## Adding Socket Events

Create event handlers:

```python
# socket_events/custom_events.py
from socketio_instance import socketio
from glob_vars import app_log

@socketio.on('my_event')
def handle_my_event(data):
    app_log.info(f"Event received: {data}")
    socketio.emit('my_response', {'status': 'processed'})
```

Import in `app.py`:

```python
import socket_events.custom_events
```

## Configuration

Edit `config.py` to customize:

```python
PORT = 5000                    # Server port
SECRET_KEY = "..."            # Flask secret key
DEBUG = True                   # Debug mode
CORS_ORIGINS = "*"           # CORS settings
SESSION_TIMEOUT = 3600       # Session timeout (seconds)
```

## Logging

Use the pre-configured loggers:

```python
from glob_vars import app_log, access_log, error_log

app_log.info("General application message")
access_log.info("User accessed /route")
error_log.error("Something went wrong!")
```

All logs go to both console and files in the `logs/` directory.

## Deployment

For production with Gunicorn:

```bash
pip install gunicorn gevent-websocket

gunicorn \
  --worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker \
  --workers 4 \
  --bind 0.0.0.0:5000 \
  app:app
```

## Troubleshooting

**Port already in use?**
```bash
# Change port in config.py
PORT = 5001
```

**Import errors?**
```bash
# Make sure virtual environment is activated
source venv/bin/activate
pip install -r dependencies.txt
```

**WebSocket not connecting?**
```bash
# Check that SocketIO is properly initialized in socketio_instance.py
# Verify client-side socket.io library is loaded in templates
```

## Files Generated

The script creates approximately **20 files** organized in **10 directories**:
- ✓ 1 main application file (`app.py`)
- ✓ 3 configuration modules
- ✓ 5 HTML templates
- ✓ 2 static files (CSS, JavaScript)
- ✓ 2 example modules (blueprint, socket events)
- ✓ 2 documentation files
- ✓ Startup script and git ignore

## Script Location

```
/home/hans/HansLand/new_webapp.sh
```

Make sure it's executable:
```bash
chmod +x /home/hans/HansLand/new_webapp.sh
```

Then use it from anywhere:
```bash
bash /home/hans/HansLand/new_webapp.sh
```

## Tips

1. **Naming Convention**: Use PascalCase for app names (e.g., `MyApp`, `ChatServer`)
2. **Custom Domains**: Blueprints are perfect for organizing by domain (e.g., `api`, `admin`, `dashboard`)
3. **Testing**: Organize your tests in the `tests/` folder with pytest
4. **Documentation**: Keep your `README.md` updated as you develop
5. **Version Control**: Use the generated `.gitignore` with Git from the start

---

**Created by**: New Flask-SocketIO Web Application Generator  
**Based on**: HansHub Architecture  
**Version**: 1.0
