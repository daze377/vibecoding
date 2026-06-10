"""Task 5: logged-in users can comment; comments appear on the post page."""
from tests.test_posts import make_post


def comment(client, post_id=1, body="Nice post!"):
    return client.post(f"/api/post/{post_id}/comment", json={"body": body})


def test_comment_requires_login(client, auth):
    auth.signup()
    auth.login()
    make_post(client)
    auth.logout()

    response = comment(client)
    assert response.status_code == 401
    assert response.get_json()["ok"] is False


def test_logged_in_user_can_comment(client, auth):
    auth.signup()
    auth.login()
    make_post(client)

    response = comment(client, body="First!")
    assert response.status_code == 201
    data = response.get_json()
    assert data["ok"] is True
    assert data["comment"]["body"] == "First!"
    assert data["comment"]["author"] == "alice"

    page = client.get("/post/1")
    assert b"First!" in page.data
    assert b"Comments (1)" in page.data


def test_empty_comment_is_rejected(client, auth):
    auth.signup()
    auth.login()
    make_post(client)

    response = comment(client, body="   ")
    assert response.status_code == 400
    assert b"Comments (0)" in client.get("/post/1").data  # nothing was saved


def test_comment_on_missing_post_is_404(client, auth):
    auth.signup()
    auth.login()
    assert comment(client, post_id=999).status_code == 404


def test_guests_can_read_comments(client, auth):
    auth.signup()
    auth.login()
    make_post(client)
    comment(client, body="Readable by everyone")
    auth.logout()

    page = client.get("/post/1")
    assert b"Readable by everyone" in page.data
    assert b"Log in" in page.data  # guests see a log-in prompt, not the form
