import pytest

from deskpanel_agent.mouse_edge import PhoneLayout, Rect

MAIN = Rect(0, 0, 1920, 1080)
# Phone under the left third of the screen, at roughly its physical size (half scale).
UNDER = Rect(150, 1080, 512, 230.5)


def layout(phone=UNDER, displays=(MAIN,), resistance=0):
    return PhoneLayout(list(displays), phone, 1024, 461, resistance=resistance)


def test_crosses_only_where_the_phone_touches():
    e = layout()
    assert not e.should_cross(1000, 1079, 0, 10)          # bottom edge, but past the phone
    assert not e.should_cross(0, 600, -10, 0)              # left edge: nothing there
    assert e.should_cross(406, 1079, 0, 10)                # straight down into the phone
    assert e.px == pytest.approx((406 - 150) / .5) and e.py < 2


def test_resistance_needs_a_push():
    e = layout(resistance=24)
    assert not e.should_cross(406, 1079, 0, 10)
    assert not e.should_cross(406, 1079, 0, 10)
    assert e.should_cross(406, 1079, 0, 10)


def test_push_resets_away_from_the_edge():
    e = layout(resistance=24)
    assert not e.should_cross(406, 1079, 0, 20)
    assert not e.should_cross(406, 900, 0, 5)
    assert not e.should_cross(406, 1079, 0, 20)


def test_movement_is_continuous_and_comes_back_where_it_went_in():
    e = layout()
    e.should_cross(406, 1079, 0, 10)
    kind, nx, ny = e.move(10, 50)                          # 50 pt down = 100 phone px
    assert kind == "move" and ny == pytest.approx(e.py / 461)
    kind, x, y = e.move(0, -200)                           # back up, out of the phone's top
    assert kind == "leave" and x == pytest.approx(416) and y == pytest.approx(930.5, abs=1)  # continuous


def test_moving_off_a_free_side_of_the_phone_just_stops():
    e = layout()
    e.should_cross(406, 1079, 0, 10)
    assert e.move(-5000, 0)[0] == "move" and e.px == 0     # left of the phone: no display there
    assert e.move(0, 5000)[0] == "move" and e.py == 460


def test_second_monitor_and_side_placement():
    right = Rect(1920, 0, 2560, 1440)
    phone = Rect(4480, 900, 512, 230.5)                    # right of the second monitor
    e = layout(phone, (MAIN, right))
    assert not e.should_cross(1919, 1000, 10, 0)           # main → second monitor, not the phone
    assert e.should_cross(4479, 1000, 10, 0)
    assert e.move(-10, 0)[0] == "leave"


def test_return_point_for_esc_is_on_the_touching_display():
    e = layout()
    e.should_cross(406, 1079, 0, 10)
    e.move(0, 100)
    x, y = e.return_point()
    assert MAIN.contains(x, y) and y == 1077
