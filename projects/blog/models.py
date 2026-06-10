"""Read and write users, posts, comments, and reactions (task-11.md section 6).

Every function returns plain dicts (copies), never live database rows,
so callers can't accidentally mutate shared state.
"""
from db import get_db

POST_COLUMNS = (
    "p.id, p.title, p.body, p.created_at, p.updated_at, "
    "p.author_id, u.username AS author"
)


# --- users -----------------------------------------------------------------

def create_user(username, email, password_hash):
    """Insert a new user and return their id."""
    db = get_db()
    cursor = db.execute(
        "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
        (username, email, password_hash),
    )
    db.commit()
    return cursor.lastrowid


def get_user_by_id(user_id):
    """Return one user as a dict, or None."""
    row = get_db().execute(
        "SELECT * FROM users WHERE id = ?", (user_id,)
    ).fetchone()
    return dict(row) if row else None


def get_user_by_username(username):
    """Return one user as a dict, or None."""
    row = get_db().execute(
        "SELECT * FROM users WHERE username = ?", (username,)
    ).fetchone()
    return dict(row) if row else None


def get_user_by_email(email):
    """Return one user as a dict, or None."""
    row = get_db().execute(
        "SELECT * FROM users WHERE email = ?", (email,)
    ).fetchone()
    return dict(row) if row else None


# --- posts -----------------------------------------------------------------

def list_posts():
    """Return all posts, newest first, with author usernames."""
    rows = get_db().execute(
        f"SELECT {POST_COLUMNS}"
        "  FROM posts AS p JOIN users AS u ON u.id = p.author_id"
        " ORDER BY p.created_at DESC, p.id DESC"
    ).fetchall()
    return [dict(row) for row in rows]
