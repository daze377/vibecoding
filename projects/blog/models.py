"""Read and write users, posts, comments, and reactions (task-11.md section 6).

Every function returns plain dicts (copies), never live database rows,
so callers can't accidentally mutate shared state.
"""
from db import get_db

POST_COLUMNS = (
    "p.id, p.title, p.body, p.created_at, p.updated_at, "
    "p.author_id, u.username AS author"
)


# --- posts -----------------------------------------------------------------

def list_posts():
    """Return all posts, newest first, with author usernames."""
    rows = get_db().execute(
        f"SELECT {POST_COLUMNS}"
        "  FROM posts AS p JOIN users AS u ON u.id = p.author_id"
        " ORDER BY p.created_at DESC, p.id DESC"
    ).fetchall()
    return [dict(row) for row in rows]
