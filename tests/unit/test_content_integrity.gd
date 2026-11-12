extends GutTest
## Checks every real content definition under res://data.
## Grows in value as content is added: a typo'd id or missing name fails CI.


func test_all_content_definitions_are_valid() -> void:
	var problems := PackedStringArray()
	for category in Registry.get_categories():
		for data in Registry.get_all(category):
			problems.append_array(data.validate())
	assert_eq(problems.size(), 0, "\n".join(problems))


func test_every_data_file_is_registered() -> void:
	var unregistered := PackedStringArray()
	for category in DirAccess.get_directories_at(Registry.DATA_ROOT):
		var files := Registry.list_resource_files(Registry.DATA_ROOT.path_join(category))
		if files.size() != Registry.count(StringName(category)):
			unregistered.append("%s: %d files, %d registered (duplicate id or not GameData?)" % [
				category, files.size(), Registry.count(StringName(category))])
	assert_eq(unregistered.size(), 0, "\n".join(unregistered))
