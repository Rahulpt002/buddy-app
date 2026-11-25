"""shared/fixtures/*.json are generated from the mock provider and parsed by BOTH test
suites (pytest here, flutter test in /app), so the two sides can't drift apart.
Regenerate with:  .venv/bin/python -m tests.gen_fixtures"""
import json
from pathlib import Path

import pytest

from deskpanel_agent.protocol import TOPIC_MODELS

FIXTURES = Path(__file__).resolve().parents[2] / "shared" / "fixtures"


@pytest.mark.parametrize("topic", sorted(TOPIC_MODELS))
def test_fixture_matches_model(topic):
    path = FIXTURES / f"{topic}.json"
    assert path.exists(), f"missing {path}; run python -m tests.gen_fixtures"
    data = json.loads(path.read_text())
    TOPIC_MODELS[topic].model_validate(data)
