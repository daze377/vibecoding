"""Open the SQLite database and create tables (task-11.md section 6)."""
import sqlite3

import click
from flask import current_app, g
from flask.cli import with_appcontext

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT UNIQUE NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS posts (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  author_id  INTEGER NOT NULL REFERENCES users (id),
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS comments (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id    INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  user_id    INTEGER NOT NULL REFERENCES users (id),
  body       TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reactions (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  post_id INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users (id),
  kind    TEXT NOT NULL CHECK (kind IN ('like', 'dislike')),
  UNIQUE (post_id, user_id)
);
"""


def get_db():
    """Return the request-scoped database connection, opening it if needed."""
    if "db" not in g:
        g.db = sqlite3.connect(current_app.config["DATABASE"])
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


def close_db(_exception=None):
    """Close the connection at the end of the request, if one was opened."""
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Create all tables (idempotent — safe to run more than once)."""
    get_db().executescript(SCHEMA)


@click.command("init-db")
@with_appcontext
def init_db_command():
    """CLI: flask --app app init-db"""
    init_db()
    click.echo("Initialized the database.")


def init_app(app):
    """Hook the database into the app's lifecycle."""
    app.teardown_appcontext(close_db)
    app.cli.add_command(init_db_command)
