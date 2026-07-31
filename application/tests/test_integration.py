"""Integration tests for Verified Access protected endpoints.

These tests run against deployed environments via CI/CD smoke/integration stages.
Set environment variables before running:

  VA_APP_URL=https://portal-dev.cdec-engineer.store
  VA_TEST_USER_EMAIL=authorized-user@cdec-engineer.store
  VA_TEST_DENIED_EMAIL=denied-user@example.net
"""

import os
import unittest

import requests

VA_APP_URL = os.environ.get("VA_APP_URL", "")
SKIP_INTEGRATION = os.environ.get("SKIP_INTEGRATION", "true").lower() == "true"


@unittest.skipUnless(
    not SKIP_INTEGRATION and VA_APP_URL, "Integration tests require VA_APP_URL"
)
class TestVerifiedAccessIntegration(unittest.TestCase):
    """End-to-end Verified Access authorization tests."""

    def test_endpoint_health_unauthenticated_redirects(self):
        """Unauthenticated users should be redirected to IAM Identity Center login."""
        response = requests.get(
            f"{VA_APP_URL}/health", allow_redirects=False, timeout=30
        )
        self.assertIn(response.status_code, [301, 302, 303, 307, 401, 403])

    def test_alb_not_directly_accessible(self):
        """Direct ALB access should not bypass Verified Access."""
        alb_url = os.environ.get("ALB_DIRECT_URL", "")
        if not alb_url:
            self.skipTest("ALB_DIRECT_URL not configured")
        response = requests.get(f"{alb_url}/health", allow_redirects=False, timeout=30)
        self.assertIn(response.status_code, [403, 404, 301, 302])


@unittest.skipUnless(not SKIP_INTEGRATION, "Integration tests disabled")
class TestAuthorizationScenarios(unittest.TestCase):
    """Authorization scenario documentation tests — run with test credentials."""

    def test_approved_user_expected_200(self):
        """Approved user in VerifiedAccessUsers group with an approved email → 200."""
        token = os.environ.get("VA_APPROVED_USER_TOKEN", "")
        if not token:
            self.skipTest("VA_APPROVED_USER_TOKEN not configured")
        response = requests.get(
            f"{VA_APP_URL}/",
            headers={"Authorization": f"Bearer {token}"},
            timeout=30,
        )
        self.assertEqual(response.status_code, 200)

    def test_wrong_group_expected_403(self):
        """User with wrong group membership → 403."""
        token = os.environ.get("VA_WRONG_GROUP_TOKEN", "")
        if not token:
            self.skipTest("VA_WRONG_GROUP_TOKEN not configured")
        response = requests.get(
            f"{VA_APP_URL}/",
            headers={"Authorization": f"Bearer {token}"},
            timeout=30,
        )
        self.assertEqual(response.status_code, 403)

    def test_wrong_email_domain_expected_403(self):
        """User with an unapproved email domain → 403."""
        token = os.environ.get("VA_WRONG_EMAIL_TOKEN", "")
        if not token:
            self.skipTest("VA_WRONG_EMAIL_TOKEN not configured")
        response = requests.get(
            f"{VA_APP_URL}/",
            headers={"Authorization": f"Bearer {token}"},
            timeout=30,
        )
        self.assertEqual(response.status_code, 403)


if __name__ == "__main__":
    unittest.main()
