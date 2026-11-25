import pytest


@pytest.fixture(autouse=True)
def _isolated_home(tmp_path, monkeypatch):
    """Never touch the real ~/.deskpanel during tests."""
    monkeypatch.setenv("DESKPANEL_HOME", str(tmp_path / "deskpanel"))
