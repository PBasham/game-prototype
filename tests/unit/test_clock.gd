extends GutTest
## The day and night clock.


func test_day_night_and_twilight() -> void:
	var c := WorldClock.new()
	add_child_autofree(c)
	c.set_hour(12.0)
	assert_eq(c.daylight(), 1.0, "noon")
	assert_false(c.is_night())
	c.set_hour(0.0)
	assert_eq(c.daylight(), 0.0, "midnight")
	assert_true(c.is_night())
	c.set_hour(c.sunset_hour)
	assert_almost_eq(c.daylight(), 0.5, 0.01, "halfway through dusk")
	assert_gt(c.twilight(), 0.9, "warm light at sunset")
	var night := c.sun_light()
	c.set_hour(12.0)
	assert_gt(c.sun_light().g, night.g, "brighter by day")


func test_time_passes_and_days_count() -> void:
	var c := WorldClock.new()
	add_child_autofree(c)
	assert_almost_eq(c.hour(), c.start_hour, 0.001, "new worlds start in the morning")
	assert_eq(c.days(1.0), 24.0 * 60.0, "a day is 24 real minutes")
	watch_signals(c)
	c.advance(c.days(1.0))
	assert_eq(c.day, 2)
	assert_signal_emitted(c, "day_started")
	assert_almost_eq(c.hour(), c.start_hour, 0.01)


func test_clock_saves() -> void:
	var c := WorldClock.new()
	c.set_hour(21.25)
	c.day = 5
	var back := WorldClock.new()
	back.from_dict(c.to_dict())
	add_child_autofree(back)
	assert_eq(back.day, 5)
	assert_almost_eq(back.hour(), 21.25, 0.001, "a loaded clock keeps its time")
	assert_eq(back.label(), "Day 5, 21:15")
	c.free()
