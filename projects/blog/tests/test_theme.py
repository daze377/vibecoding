"""Task 8: a light/dark toggle exists and its script + styles are served."""


def test_every_page_has_a_theme_toggle(client):
    response = client.get("/")
    assert b'id="theme-toggle"' in response.data
    assert b"theme.js" in response.data


def test_theme_script_is_served_and_persists_choice(client):
    response = client.get("/static/theme.js")
    assert response.status_code == 200
    assert b"localStorage" in response.data  # the choice is remembered


def test_styles_define_a_dark_theme(client):
    response = client.get("/static/style.css")
    assert response.status_code == 200
    assert b'[data-theme="dark"]' in response.data
