"""Create the Flask app and register routes (task-11.md section 5)."""
import os

from flask import Flask

import db
from auth import bp as auth_bp
from comments import bp as comments_bp
from csrf import init_csrf
from posts import bp as posts_bp
from reactions import bp as reactions_bp
from search import bp as search_bp


def create_app(test_config=None):
    """Application factory: configure the app, database, and blueprints."""
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_mapping(
        # Set SECRET_KEY in the environment for any public deployment.
        SECRET_KEY=os.environ.get("SECRET_KEY", "dev"),
        DATABASE=os.path.join(app.instance_path, "blog.sqlite"),
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        # Set COOKIE_SECURE=1 when serving over HTTPS (e.g. the Cloudflare tunnel).
        SESSION_COOKIE_SECURE=os.environ.get("COOKIE_SECURE") == "1",
    )
    if test_config is not None:
        app.config.from_mapping(test_config)

    os.makedirs(app.instance_path, exist_ok=True)

    db.init_app(app)
    with app.app_context():
        db.init_db()

    init_csrf(app)
    app.register_blueprint(auth_bp)
    app.register_blueprint(posts_bp)
    app.register_blueprint(comments_bp)
    app.register_blueprint(reactions_bp)
    app.register_blueprint(search_bp)

    @app.template_filter("day")
    def day_filter(timestamp):
        """Show only the date part of a 'YYYY-MM-DD HH:MM:SS' timestamp."""
        return (timestamp or "")[:10]

    @app.after_request
    def set_security_headers(response):
        """Baseline browser protections for every response."""
        response.headers.setdefault("Content-Security-Policy", "default-src 'self'")
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        return response

    return app
