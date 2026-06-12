"""Shared fixtures: a fresh sample PDF per test."""
import pytest

from samples.make_sample import make_sample


@pytest.fixture
def sample_pdf(tmp_path):
    return make_sample(str(tmp_path / "sample.pdf"))
