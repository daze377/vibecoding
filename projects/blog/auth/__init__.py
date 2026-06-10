"""Sign up, log in, log out, and session helpers (task-11.md section 7)."""
import functools
import sqlite3

from flask import (
    Blueprint, flash, g, jsonify, redirect, render_template, request,
    session, url_for,
)
from werkzeug.security import check_password_hash, generate_password_hash

import models
from auth.validation import validate_signup

bp = Blueprint("auth", __name__)


@bp.before_app_request
def load_logged_in_user():
    """Make the logged-in user available as ``g.user`` on every request."""
    user_id = session.get("user_id")
    g.user = models.get_user_by_id(user_id) if user_id else None


def login_required(view):
    """Send guests to the log-in page (JSON 401 for API calls)."""

    @functools.wraps(view)
    def wrapped_view(**kwargs):
        if g.user is not None:
            return view(**kwargs)
        if request.path.startswith("/api/"):
            return jsonify({"ok": False, "error": "Please log in first."}), 401
        return redirect(url_for("auth.login", next=request.path))

    return wrapped_view


@bp.route("/signup", methods=("GET", "POST"))
def signup():
    """Create an account; the password is stored only as a hash."""
    if request.method == "GET":
        return render_template("signup.html")

    username = request.form.get("username", "").strip()
    email = request.form.get("email", "").strip().lower()
    password = request.form.get("password", "")

    errors = validate_signup(username, email, password)
    if not errors and models.get_user_by_username(username):
        errors.append("That username is already taken.")
    if not errors and models.get_user_by_email(email):
        errors.append("That email is already registered.")
    if errors:
        for message in errors:
            flash(message, "error")
        return render_template("signup.html"), 400

    try:
        models.create_user(username, email, generate_password_hash(password))
    except sqlite3.IntegrityError:
        # Two signups raced past the checks above — the UNIQUE constraint wins.
        flash("That username or email is already taken.", "error")
        return render_template("signup.html"), 400
    flash("Account created — please log in.", "success")
    return redirect(url_for("auth.login"))


@bp.route("/login", methods=("GET", "POST"))
def login():
    """Start a session for a user with the right password."""
    if request.method == "GET":
        return render_template("login.html")

    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")
    user = models.get_user_by_username(username)

    if user is None or not check_password_hash(user["password_hash"], password):
        flash("Wrong username or password.", "error")
        return render_template("login.html"), 400

    session.clear()
    session["user_id"] = user["id"]
    flash(f"Welcome back, {user['username']}!", "success")
    return redirect(_safe_next_url())


@bp.post("/logout")
def logout():
    """End the session."""
    session.clear()
    flash("You have been logged out.", "success")
    return redirect(url_for("posts.index"))


def _safe_next_url():
    """Only follow same-site relative ?next= targets (no open redirects).

    Backslashes are rejected too: browsers treat ``/\\evil.com`` like
    ``//evil.com``, which would leave the site.
    """
    next_url = request.args.get("next", "")
    is_local_path = (
        next_url.startswith("/")
        and not next_url.startswith("//")
        and "\\" not in next_url
    )
    return next_url if is_local_path else url_for("posts.index")
