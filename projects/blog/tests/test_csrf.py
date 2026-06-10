"""CSRF protection: state-changing POSTs need a valid session token."""
import re

import pytest

from app import create_app


@pytest.fixture
def csrf_client(tmp_path):
    """A client for an app with CSRF protection left ON (other tests disable it)."""
    app = create_app(
        {
            "TESTING": True,
            "DATABASE": str(tmp_path / "csrf.sqlite"),
            "SECRET_KEY": "test-secret",
        }
    )
    return app.test_client()


def _extract_token(html):
    match = re.search(r'name="csrf_token" value="([^"]+)"', html)
    assert match, "no CSRF token found in the form"
    return match.group(1)


def test_post_without_token_is_rejected(csrf_client):
    response = csrf_client.post("/signup", data={"username": "alice"})
    assert response.status_code == 400
    assert b"CSRF" in response.data


def test_post_with_token_is_accepted(csrf_client):
    page = csrf_client.get("/signup")
    token = _extract_token(page.get_data(as_text=True))
    response = csrf_client.post(
        "/signup",
        data={
            "csrf_token": token,
            "username": "alice",
            "email": "alice@example.com",
            "password": "password123",
        },
    )
    assert response.status_code == 302  # success → redirect to login
