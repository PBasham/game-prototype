extends GutTest

const TMP := "user://test_save_header.tmp"


func after_each() -> void:
	DirAccess.remove_absolute(TMP)


func _write(callable: Callable) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	callable.call(f)
	f.close()


func _read() -> Dictionary:
	var f := FileAccess.open(TMP, FileAccess.READ)
	var result := SaveHeader.read(f)
	f.close()
	return result


func test_round_trip() -> void:
	_write(func(f: FileAccess) -> void: SaveHeader.write(f, SaveHeader.KIND_WORLD))
	var h := _read()
	assert_true(h.ok, h.error)
	assert_eq(h.kind, SaveHeader.KIND_WORLD)
	assert_eq(h.version, SaveHeader.FORMAT_VERSION)


func test_rejects_bad_magic() -> void:
	_write(func(f: FileAccess) -> void: f.store_buffer("NOPE1234".to_ascii_buffer()))
	var h := _read()
	assert_false(h.ok)
	assert_string_contains(h.error, "magic")


func test_rejects_newer_version() -> void:
	_write(func(f: FileAccess) -> void: SaveHeader.write(f, SaveHeader.KIND_CHARACTER, SaveHeader.FORMAT_VERSION + 1))
	var h := _read()
	assert_false(h.ok)
	assert_string_contains(h.error, "newer")


func test_rejects_truncated_file() -> void:
	_write(func(f: FileAccess) -> void: f.store_8(1))
	assert_false(_read().ok)
