"""Lightweight session-based CSRF protection for every state-changing request.

Forms send the token in a hidden ``csrf_token`` field; the JSON API sends it
in an ``X-CSRF-Token`` header (read from the meta tag in base.html).
"""
import secrets

from flask import abort, jsonify, request, session

TOKEN_KEY = "_csrf_token"
HEADER_NAME = "X-CSRF-Token"
FIELD_NAME = "csrf_token"
PROTECTED_METHODS = ("POST", "PUT", "PATCH", "DELETE")


def generate_csrf_token():
    """Return the session's CSRF token, creating one on first use."""
    if TOKEN_KEY not in session:
        session[TOKEN_KEY] = secrets.token_hex(32)
    return session[TOKEN_KEY]


def _request_token():
    """Read the token the client sent (form field first, then header)."""
    return request.form.get(FIELD_NAME) or request.headers.get(HEADER_NAME)


def init_csrf(app):
    """Reject any protected request whose token doesn't match the session."""

    @app.before_request
    def protect():
        if request.method not in PROTECTED_METHODS:
            return None
        if app.config.get("CSRF_DISABLED"):  # only ever set by tests
            return None
        expected = session.get(TOKEN_KEY)
        provided = _request_token()
        if not expected or not provided or not secrets.compare_digest(expected, provided):
            if request.path.startswith("/api/"):
                return jsonify({"ok": False, "error": "Invalid or missing CSRF token."}), 400
            abort(400, description="Invalid or missing CSRF token.")
        return None

    app.jinja_env.globals["csrf_token"] = generate_csrf_token
