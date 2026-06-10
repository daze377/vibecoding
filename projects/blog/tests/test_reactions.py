"""Task 6: like/dislike a post — one reaction per user, counts update."""
from tests.test_posts import make_post, login_second_user


def react(client, kind, post_id=1):
    return client.post(f"/api/post/{post_id}/react", json={"kind": kind})


def setup_post(client, auth):
    auth.signup()
    auth.login()
    make_post(client)


def test_react_requires_login(client, auth):
    setup_post(client, auth)
    auth.logout()
    assert react(client, "like").status_code == 401


def test_like_updates_counts(client, auth):
    setup_post(client, auth)
    response = react(client, "like")
    assert response.status_code == 200
    data = response.get_json()
    assert data["reaction"] == "like"
    assert data["counts"] == {"like": 1, "dislike": 0}


def test_switching_reaction_keeps_one_per_user(client, auth):
    setup_post(client, auth)
    react(client, "like")
    data = react(client, "dislike").get_json()  # change of heart
    assert data["counts"] == {"like": 0, "dislike": 1}


def test_same_reaction_again_removes_it(client, auth):
    setup_post(client, auth)
    react(client, "like")
    data = react(client, "like").get_json()  # toggle off
    assert data["reaction"] is None
    assert data["counts"] == {"like": 0, "dislike": 0}


def test_two_users_can_both_like(client, auth):
    setup_post(client, auth)
    react(client, "like")
    auth.logout()

    login_second_user(auth)
    data = react(client, "like").get_json()
    assert data["counts"] == {"like": 2, "dislike": 0}


def test_invalid_kind_is_rejected(client, auth):
    setup_post(client, auth)
    assert react(client, "love").status_code == 400


def test_react_on_missing_post_is_404(client, auth):
    auth.signup()
    auth.login()
    assert react(client, "like", post_id=999).status_code == 404


def test_counts_shown_on_post_page(client, auth):
    setup_post(client, auth)
    react(client, "like")
    page = client.get("/post/1").get_data(as_text=True)
    assert 'data-count="like"' in page
    assert ">1</span>" in page
