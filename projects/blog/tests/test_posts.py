"""Tasks 3+4: posts CRUD with author-only rules, home list, detail page."""


def make_post(client, title="Hello world", body="My very first post."):
    """Create a post through the real form and return the response."""
    return client.post("/new", data={"title": title, "body": body})


def login_second_user(auth):
    """Sign up and log in a different user (bob)."""
    auth.signup(username="bob", email="bob@example.com")
    auth.login(username="bob")


def test_new_post_requires_login(client):
    response = client.get("/new")
    assert response.status_code == 302
    assert "/login" in response.headers["Location"]


def test_create_post_shows_on_home_and_detail(client, auth):
    auth.signup()
    auth.login()
    response = make_post(client)
    assert response.status_code == 302  # redirects to the new post

    home = client.get("/")
    assert b"Hello world" in home.data

    detail = client.get(response.headers["Location"])
    assert detail.status_code == 200
    assert b"My very first post." in detail.data
    assert b"alice" in detail.data


def test_create_post_rejects_empty_title(client, auth):
    auth.signup()
    auth.login()
    assert make_post(client, title="   ").status_code == 400
    assert make_post(client, body="   ").status_code == 400


def test_create_post_rejects_over_length_input(client, auth):
    auth.signup()
    auth.login()
    assert make_post(client, title="x" * 201).status_code == 400
    assert make_post(client, body="x" * 20_001).status_code == 400


def test_home_lists_newest_first(client, auth):
    auth.signup()
    auth.login()
    make_post(client, title="Older post")
    make_post(client, title="Newer post")
    html = client.get("/").get_data(as_text=True)
    assert html.index("Newer post") < html.index("Older post")


def test_home_shows_preview_not_full_body(client, auth):
    auth.signup()
    auth.login()
    long_body = "word " * 100  # ~500 characters
    make_post(client, title="Long story", body=long_body)
    html = client.get("/").get_data(as_text=True)
    assert "..." in html              # truncated preview
    assert long_body not in html      # full body only on the detail page


def test_author_can_edit_own_post(client, auth):
    auth.signup()
    auth.login()
    make_post(client)
    response = client.post(
        "/edit/1", data={"title": "Hello edited", "body": "Updated body."}
    )
    assert response.status_code == 302
    detail = client.get("/post/1")
    assert b"Hello edited" in detail.data
    assert b"edited" in detail.data  # the "edited <date>" marker


def test_other_user_cannot_edit(client, auth):
    auth.signup()
    auth.login()
    make_post(client)
    auth.logout()

    login_second_user(auth)
    assert client.get("/edit/1").status_code == 403
    response = client.post("/edit/1", data={"title": "Hacked", "body": "x"})
    assert response.status_code == 403


def test_author_can_delete_own_post(client, auth):
    auth.signup()
    auth.login()
    make_post(client)
    response = client.post("/delete/1")
    assert response.status_code == 302
    assert client.get("/post/1").status_code == 404
    assert b"Hello world" not in client.get("/").data


def test_other_user_cannot_delete(client, auth):
    auth.signup()
    auth.login()
    make_post(client)
    auth.logout()

    login_second_user(auth)
    assert client.post("/delete/1").status_code == 403


def test_missing_post_returns_404(client):
    assert client.get("/post/999").status_code == 404
