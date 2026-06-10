"""Task 2: sign up, log in, log out — passwords hashed, sessions work."""
import models


def test_signup_page_renders(client):
    assert client.get("/signup").status_code == 200


def test_signup_then_login(auth):
    assert auth.signup().status_code == 302  # redirects to the login page
    assert auth.login().status_code == 302   # redirects home


def test_signup_rejects_bad_input(auth):
    assert auth.signup(username="ab").status_code == 400        # too short
    assert auth.signup(email="not-an-email").status_code == 400
    assert auth.signup(password="short").status_code == 400


def test_signup_rejects_duplicates(auth):
    auth.signup()
    response = auth.signup()  # same username + email again
    assert response.status_code == 400
    assert b"already" in response.data


def test_password_is_stored_hashed(app, auth):
    auth.signup(password="password123")
    with app.app_context():
        user = models.get_user_by_username("alice")
    assert "password123" not in user["password_hash"]


def test_login_wrong_password(auth):
    auth.signup()
    response = auth.login(password="wrong-password")
    assert response.status_code == 400
    assert b"Wrong username or password" in response.data


def test_login_unknown_user(auth):
    assert auth.login(username="ghost").status_code == 400


def test_logged_in_user_shown_in_nav(client, auth):
    auth.signup()
    auth.login()
    response = client.get("/")
    assert b"alice" in response.data
    assert b"Log out" in response.data


def test_logout_ends_session(client, auth):
    auth.signup()
    auth.login()
    auth.logout()
    response = client.get("/")
    assert b"Log in" in response.data
    assert b"Log out" not in response.data
