"""Validate sign-up input before it touches the database."""
import re

USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,30}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
MIN_PASSWORD_LENGTH = 8


def validate_signup(username, email, password):
    """Return a list of human-readable problems (empty when valid)."""
    errors = []
    if not USERNAME_RE.fullmatch(username):
        errors.append("Username must be 3-30 letters, digits, or underscores.")
    if not EMAIL_RE.fullmatch(email):
        errors.append("Please enter a valid email address.")
    if len(password) < MIN_PASSWORD_LENGTH:
        errors.append(f"Password must be at least {MIN_PASSWORD_LENGTH} characters.")
    return errors
