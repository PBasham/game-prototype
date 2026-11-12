extends GutTest

const RegistryScript := preload("res://src/core/registry.gd")
const FIXTURES := "res://tests/fixtures/data"

var reg: Node


func before_each() -> void:
	reg = RegistryScript.new()
	reg.quiet = true
	reg.load_all(FIXTURES)


func after_each() -> void:
	reg.free()


func test_loads_categories_from_folders() -> void:
	assert_true(reg.get_categories().has(&"test_things"))


func test_loads_nested_files() -> void:
	assert_eq(reg.count(&"test_things"), 2)
	assert_true(reg.has_def(&"test_things", &"thing_b"))


func test_get_def_returns_definition() -> void:
	var a: GameData = reg.get_def(&"test_things", &"thing_a")
	assert_not_null(a)
	assert_eq(a.display_name, "Thing A")


func test_unknown_ids_and_categories_return_null() -> void:
	assert_null(reg.get_def(&"test_things", &"nope"))
	assert_null(reg.get_def(&"no_category", &"thing_a"))


func test_duplicate_id_is_rejected() -> void:
	var dup := GameData.new()
	dup.id = &"thing_a"
	dup.display_name = "Duplicate"
	assert_false(reg.register(&"test_things", dup))
	assert_eq(reg.get_def(&"test_things", &"thing_a").display_name, "Thing A")


func test_empty_id_is_rejected() -> void:
	var bad := GameData.new()
	assert_false(reg.register(&"test_things", bad))


func test_missing_root_loads_nothing() -> void:
	reg.load_all("res://does_not_exist")
	assert_eq(reg.get_categories().size(), 0)
