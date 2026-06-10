"""List, show, create, edit, and delete posts (task-11.md section 7)."""
from flask import Blueprint, abort, flash, g, redirect, render_template, request, url_for

import models
from auth import login_required

bp = Blueprint("posts", __name__)

MAX_TITLE_LENGTH = 200
MAX_BODY_LENGTH = 20_000


@bp.get("/")
def index():
    """Home page: every post, newest first."""
    return render_template("index.html", posts=models.list_posts())


@bp.get("/post/<int:post_id>")
def detail(post_id):
    """One full post with its comments and reaction counts."""
    post = _get_post_or_abort(post_id)
    my_reaction = (
        models.get_reaction(post_id, g.user["id"]) if g.user else None
    )
    return render_template(
        "post.html",
        post=post,
        comments=models.list_comments(post_id),
        counts=models.count_reactions(post_id),
        my_reaction=my_reaction,
    )


@bp.route("/new", methods=("GET", "POST"))
@login_required
def new():
    """Write a new post."""
    if request.method == "GET":
        return render_template("edit.html", post=None)

    title, body, errors = _read_post_form()
    if errors:
        _flash_errors(errors)
        return render_template("edit.html", post=None), 400

    post_id = models.create_post(g.user["id"], title, body)
    flash("Post published.", "success")
    return redirect(url_for("posts.detail", post_id=post_id))


@bp.route("/edit/<int:post_id>", methods=("GET", "POST"))
@login_required
def edit(post_id):
    """Edit an existing post — author only."""
    post = _get_post_or_abort(post_id, author_only=True)
    if request.method == "GET":
        return render_template("edit.html", post=post)

    title, body, errors = _read_post_form()
    if errors:
        _flash_errors(errors)
        return render_template("edit.html", post=post), 400

    models.update_post(post_id, title, body)
    flash("Post updated.", "success")
    return redirect(url_for("posts.detail", post_id=post_id))


@bp.post("/delete/<int:post_id>")
@login_required
def delete(post_id):
    """Delete a post — author only."""
    _get_post_or_abort(post_id, author_only=True)
    models.delete_post(post_id)
    flash("Post deleted.", "success")
    return redirect(url_for("posts.index"))


# --- helpers ---------------------------------------------------------------

def _get_post_or_abort(post_id, author_only=False):
    """Load a post or abort: 404 if missing, 403 if someone else's."""
    post = models.get_post(post_id)
    if post is None:
        abort(404)
    if author_only and (g.user is None or g.user["id"] != post["author_id"]):
        abort(403)
    return post


def _read_post_form():
    """Validate the new/edit form; returns (title, body, errors)."""
    title = request.form.get("title", "").strip()
    body = request.form.get("body", "").strip()
    errors = []
    if not title:
        errors.append("Title cannot be empty.")
    elif len(title) > MAX_TITLE_LENGTH:
        errors.append(f"Title must be at most {MAX_TITLE_LENGTH} characters.")
    if not body:
        errors.append("Body cannot be empty.")
    elif len(body) > MAX_BODY_LENGTH:
        errors.append(f"Body must be at most {MAX_BODY_LENGTH} characters.")
    return title, body, errors


def _flash_errors(errors):
    for message in errors:
        flash(message, "error")
