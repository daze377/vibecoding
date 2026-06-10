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


def get_post(post_id):
    """Return one post (with author username) as a dict, or None."""
    row = get_db().execute(
        f"SELECT {POST_COLUMNS}"
        "  FROM posts AS p JOIN users AS u ON u.id = p.author_id"
        " WHERE p.id = ?",
        (post_id,),
    ).fetchone()
    return dict(row) if row else None


def create_post(author_id, title, body):
    """Insert a new post and return its id."""
    db = get_db()
    cursor = db.execute(
        "INSERT INTO posts (author_id, title, body) VALUES (?, ?, ?)",
        (author_id, title, body),
    )
    db.commit()
    return cursor.lastrowid


def update_post(post_id, title, body):
    """Replace a post's title and body, stamping updated_at."""
    db = get_db()
    db.execute(
        "UPDATE posts SET title = ?, body = ?, updated_at = CURRENT_TIMESTAMP"
        " WHERE id = ?",
        (title, body, post_id),
    )
    db.commit()


def delete_post(post_id):
    """Delete a post (its comments and reactions cascade away too)."""
    db = get_db()
    db.execute("DELETE FROM posts WHERE id = ?", (post_id,))
    db.commit()


# --- search ------------------------------------------------------------------

def search_posts(query):
    """Return posts whose title or body contains the words, newest first."""
    escaped = (
        query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    )
    pattern = f"%{escaped}%"
    rows = get_db().execute(
        f"SELECT {POST_COLUMNS}"
        "  FROM posts AS p JOIN users AS u ON u.id = p.author_id"
        " WHERE p.title LIKE ? ESCAPE '\\' OR p.body LIKE ? ESCAPE '\\'"
        " ORDER BY p.created_at DESC, p.id DESC",
        (pattern, pattern),
    ).fetchall()
    return [dict(row) for row in rows]


# --- comments ----------------------------------------------------------------

def add_comment(post_id, user_id, body):
    """Insert a comment and return it (with the author's username)."""
    db = get_db()
    cursor = db.execute(
        "INSERT INTO comments (post_id, user_id, body) VALUES (?, ?, ?)",
        (post_id, user_id, body),
    )
    db.commit()
    return get_comment(cursor.lastrowid)


def get_comment(comment_id):
    """Return one comment as a dict, or None."""
    row = get_db().execute(
        "SELECT c.id, c.post_id, c.body, c.created_at, u.username AS author"
        "  FROM comments AS c JOIN users AS u ON u.id = c.user_id"
        " WHERE c.id = ?",
        (comment_id,),
    ).fetchone()
    return dict(row) if row else None


def list_comments(post_id):
    """Return a post's comments, oldest first, with author usernames."""
    rows = get_db().execute(
        "SELECT c.id, c.body, c.created_at, u.username AS author"
        "  FROM comments AS c JOIN users AS u ON u.id = c.user_id"
        " WHERE c.post_id = ?"
        " ORDER BY c.created_at ASC, c.id ASC",
        (post_id,),
    ).fetchall()
    return [dict(row) for row in rows]


# --- reactions ---------------------------------------------------------------

def get_reaction(post_id, user_id):
    """Return this user's reaction to a post: 'like', 'dislike', or None."""
    row = get_db().execute(
        "SELECT kind FROM reactions WHERE post_id = ? AND user_id = ?",
        (post_id, user_id),
    ).fetchone()
    return row["kind"] if row else None


def set_reaction(post_id, user_id, kind):
    """Set a user's reaction (one per post).

    Picking the same kind again removes it (a toggle). Returns the
    resulting reaction: 'like', 'dislike', or None.
    """
    db = get_db()
    if get_reaction(post_id, user_id) == kind:
        db.execute(
            "DELETE FROM reactions WHERE post_id = ? AND user_id = ?",
            (post_id, user_id),
        )
        db.commit()
        return None
    db.execute(
        "INSERT INTO reactions (post_id, user_id, kind) VALUES (?, ?, ?)"
        " ON CONFLICT (post_id, user_id) DO UPDATE SET kind = excluded.kind",
        (post_id, user_id, kind),
    )
    db.commit()
    return kind


def count_reactions(post_id):
    """Return {'like': n, 'dislike': n} for a post."""
    rows = get_db().execute(
        "SELECT kind, COUNT(*) AS total FROM reactions"
        " WHERE post_id = ? GROUP BY kind",
        (post_id,),
    ).fetchall()
    counts = {"like": 0, "dislike": 0}
    for row in rows:
        counts[row["kind"]] = row["total"]
    return counts
