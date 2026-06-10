"""List, show, create, edit, and delete posts."""
from flask import Blueprint, render_template

import models

bp = Blueprint("posts", __name__)


@bp.get("/")
def index():
    """Home page: every post, newest first."""
    return render_template("index.html", posts=models.list_posts())
