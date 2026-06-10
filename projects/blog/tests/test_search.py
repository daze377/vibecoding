"""Task 7: search finds posts by words in the title or body."""
from tests.test_posts import make_post


def setup_posts(client, auth):
    auth.signup()
    auth.login()
    make_post(client, title="Flask tips", body="Blueprints keep code tidy.")
    make_post(client, title="Cooking pasta", body="Boil water, add salt.")


def test_search_matches_title(client, auth):
    setup_posts(client, auth)
    response = client.get("/search?q=flask")  # case-insensitive
    assert response.status_code == 200
    assert b"Flask tips" in response.data
    assert b"Cooking pasta" not in response.data


def test_search_matches_body(client, auth):
    setup_posts(client, auth)
    response = client.get("/search?q=salt")
    assert b"Cooking pasta" in response.data
    assert b"Flask tips" not in response.data


def test_search_with_no_matches(client, auth):
    setup_posts(client, auth)
    response = client.get("/search?q=quantum")
    assert response.status_code == 200
    assert b"No posts match" in response.data


def test_empty_query_prompts_for_words(client, auth):
    setup_posts(client, auth)
    response = client.get("/search?q=")
    assert response.status_code == 200
    assert b"Type something" in response.data


def test_like_wildcards_are_not_special(client, auth):
    setup_posts(client, auth)
    response = client.get("/search?q=%25")  # a literal '%' query
    assert b"Flask tips" not in response.data
    assert b"Cooking pasta" not in response.data
