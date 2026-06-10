"""Find posts by words in the title or body (task-11.md section 7)."""
from flask import Blueprint, render_template, request

import models

bp = Blueprint("search", __name__)

MAX_QUERY_LENGTH = 100


@bp.get("/search")
def results():
    """Show posts matching ?q=, newest first."""
    query = request.args.get("q", "").strip()[:MAX_QUERY_LENGTH]
    posts = models.search_posts(query) if query else []
    return render_template("search.html", query=query, posts=posts)
