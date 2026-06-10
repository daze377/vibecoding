"""Like / dislike posts through a small JSON API (task-11.md section 7)."""
from flask import Blueprint, g, jsonify, request

import models
from auth import login_required

bp = Blueprint("reactions", __name__, url_prefix="/api")

ALLOWED_KINDS = ("like", "dislike")


@bp.post("/post/<int:post_id>/react")
@login_required
def react(post_id):
    """Toggle/switch the user's reaction and return the new counts."""
    if models.get_post(post_id) is None:
        return jsonify({"ok": False, "error": "Post not found."}), 404

    payload = request.get_json(silent=True) or {}
    kind = payload.get("kind")
    if kind not in ALLOWED_KINDS:
        return jsonify(
            {"ok": False, "error": "Reaction must be 'like' or 'dislike'."}
        ), 400

    reaction = models.set_reaction(post_id, g.user["id"], kind)
    return jsonify(
        {"ok": True, "reaction": reaction, "counts": models.count_reactions(post_id)}
    )
