import platform

import pytest

from deskpanel_agent.collectors.mac_temp import MacTemps, mean_die_temp


def test_mean_uses_only_plausible_die_sensors():
    r = [("PMU tdie1", 57.3), ("PMU tdie2", 53.9), ("PMU2 tdie1", 47.5), ("PMU tdev1", 41.0),
         ("PMU tdie9", -1.6), ("gas gauge battery", 29.0), ("PMU tdie3", None)]
    assert mean_die_temp(r) == pytest.approx((57.3 + 53.9 + 47.5) / 3, abs=.05)
    assert mean_die_temp([("NAND CH0 temp", 39.0)]) is None


@pytest.mark.skipif(platform.system() != "Darwin" or platform.machine() != "arm64", reason="Apple Silicon only")
def test_reads_a_real_temperature_on_apple_silicon():
    t = MacTemps().cpu_c()
    assert t is None or 10 < t < 120
