"""Shared pytest fixtures: a fresh app + throwaway database for every test."""
import pytest

from app import create_app


@pytest.fixture
def app(tmp_path):
    """A new app instance wired to a temporary SQLite file."""
    return create_app(
        {
            "TESTING": True,
            "DATABASE": str(tmp_path / "test.sqlite"),
            "SECRET_KEY": "test-secret",
            "CSRF_DISABLED": True,
        }
    )


@pytest.fixture
def client(app):
    """A test client that makes requests without running a real server."""
    return app.test_client()


class AuthActions:
    """Drive the sign-up / log-in / log-out forms from tests."""

    def __init__(self, client):
        self._client = client

    def signup(self, username="alice", email="alice@example.com",
               password="password123"):
        return self._client.post(
            "/signup",
            data={"username": username, "email": email, "password": password},
        )

    def login(self, username="alice", password="password123"):
        return self._client.post(
            "/login", data={"username": username, "password": password}
        )

    def logout(self):
        return self._client.post("/logout")


@pytest.fixture
def auth(client):
    return AuthActions(client)
