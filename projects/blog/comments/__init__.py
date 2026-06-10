"""Add comments through a small JSON API (task-11.md section 7)."""
from flask import Blueprint, g, jsonify, request

import models
from auth import login_required

bp = Blueprint("comments", __name__, url_prefix="/api")

MAX_COMMENT_LENGTH = 2_000


@bp.post("/post/<int:post_id>/comment")
@login_required
def add(post_id):
    """Save a comment for the logged-in user and return it as JSON."""
    if models.get_post(post_id) is None:
        return jsonify({"ok": False, "error": "Post not found."}), 404

    payload = request.get_json(silent=True) or {}
    raw_body = payload.get("body", "")
    if not isinstance(raw_body, str):
        return jsonify({"ok": False, "error": "Comment must be text."}), 400
    body = raw_body.strip()
    if not body:
        return jsonify({"ok": False, "error": "Comment cannot be empty."}), 400
    if len(body) > MAX_COMMENT_LENGTH:
        return jsonify(
            {"ok": False,
             "error": f"Comment must be at most {MAX_COMMENT_LENGTH} characters."}
        ), 400

    comment = models.add_comment(post_id, g.user["id"], body)
    return jsonify({"ok": True, "comment": comment}), 201
