# ===========================================
# SAMPLE PYTHON APPLICATION
# ===========================================
# A simple Flask API for demonstrating GitOps deployment

import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)

# Configuration from environment variables
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")


@app.route("/")
def home():
    """Root endpoint"""
    return jsonify({
        "message": "Welcome to GitOps Demo API",
        "version": APP_VERSION,
        "environment": ENVIRONMENT
    })


@app.route("/health")
def health():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({
        "status": "healthy",
        "hostname": socket.gethostname()
    })


@app.route("/ready")
def ready():
    """Readiness check endpoint"""
    return jsonify({
        "status": "ready",
        "version": APP_VERSION
    })


@app.route("/api/info")
def info():
    """Application info endpoint"""
    return jsonify({
        "app": "gitops-demo",
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "hostname": socket.gethostname(),
        "python_version": os.popen("python --version").read().strip()
    })


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
