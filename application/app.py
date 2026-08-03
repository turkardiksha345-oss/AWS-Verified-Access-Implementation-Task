"""
Secure Access Portal Application

Production-grade Flask application protected by AWS Verified Access.
Accessible only through Verified Access endpoint with IAM Identity Center auth.
"""

import json
import logging
import os
import signal
import sys
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template, request

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
APP_ENV = os.environ.get("APP_ENV", "production")
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
    format=json.dumps(
        {
            "timestamp": "%(asctime)s",
            "level": "%(levelname)s",
            "logger": "%(name)s",
            "message": "%(message)s",
        }
    ),
    stream=sys.stdout,
)
logger = logging.getLogger("secure-access-portal")

app = Flask(__name__)
app.config["DEBUG"] = False
app.config["TESTING"] = False
app.config["PROPAGATE_EXCEPTIONS"] = True

_shutdown_requested = False


def _handle_shutdown(signum, frame):
    global _shutdown_requested
    logger.info("Graceful shutdown initiated", extra={"signal": signum})
    _shutdown_requested = True


signal.signal(signal.SIGTERM, _handle_shutdown)
signal.signal(signal.SIGINT, _handle_shutdown)


@app.after_request
def set_security_headers(response):
    response.headers["Strict-Transport-Security"] = (
        "max-age=31536000; includeSubDomains; preload"
    )
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; frame-ancestors 'none'"
    )
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    return response


@app.before_request
def log_request():
    logger.info(
        "Request received",
        extra={
            "method": request.method,
            "path": request.path,
            "remote_addr": request.remote_addr,
            "user_agent": request.headers.get("User-Agent", ""),
        },
    )


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/readiness")
def readiness():
    if _shutdown_requested:
        return jsonify({"status": "not_ready", "reason": "shutting_down"}), 503
    return jsonify({"status": "ready"}), 200


@app.route("/version")
def version():
    return jsonify(
        {
            "version": APP_VERSION,
            "environment": APP_ENV,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    ), 200


@app.errorhandler(404)
def not_found(error):
    logger.warning("Not found: %s", request.path)
    return jsonify({"error": "not_found"}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error("Internal server error")
    return jsonify({"error": "internal_server_error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))

    # Only for local development.
    app.run(host="127.0.0.1", port=port, debug=False)
