"""Unit tests for the Secure Access Portal application."""

import json
import os
import unittest

import app as application


class TestApplication(unittest.TestCase):
    def setUp(self):
        application.app.config["TESTING"] = True
        self.client = application.app.test_client()

    def test_index_returns_demo_message(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)

        html = response.data.decode()

        # Verify the HTML page is rendered correctly
        self.assertIn("<title>Secure Access Portal</title>", html)
        self.assertIn("Secure Access Portal", html)
        self.assertIn("Application Running Successfully", html)

    def test_health_returns_200(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "healthy")

    def test_readiness_returns_ready(self):
        response = self.client.get("/readiness")
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data["status"], "ready")

    def test_version_endpoint(self):
        response = self.client.get("/version")
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn("version", data)
        self.assertIn("environment", data)
        self.assertIn("timestamp", data)

    def test_security_headers_present(self):
        response = self.client.get("/health")
        headers = response.headers
        self.assertEqual(headers.get("X-Content-Type-Options"), "nosniff")
        self.assertEqual(headers.get("X-Frame-Options"), "DENY")
        self.assertIn("Strict-Transport-Security", headers)
        self.assertIn("Content-Security-Policy", headers)

    def test_debug_mode_disabled(self):
        self.assertFalse(application.app.config["DEBUG"])

    def test_not_found_returns_404(self):
        response = self.client.get("/nonexistent")
        self.assertEqual(response.status_code, 404)

    def test_graceful_shutdown_readiness(self):
        application._shutdown_requested = True
        response = self.client.get("/readiness")
        self.assertEqual(response.status_code, 503)
        application._shutdown_requested = False


class TestEnvironment(unittest.TestCase):
    def test_production_env_default(self):
        self.assertEqual(os.environ.get("APP_ENV", "production"), "production")


if __name__ == "__main__":
    unittest.main()
