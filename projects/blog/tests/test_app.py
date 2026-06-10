"""Task 1: the app starts, serves the home page, and can init its database."""


def test_home_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_home_shows_empty_state(client):
    response = client.get("/")
    assert b"No posts yet" in response.data


def test_init_db_command_reports_success(app):
    result = app.test_cli_runner().invoke(args=["init-db"])
    assert "Initialized the database." in result.output
