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
