#include "voxel_step.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void initialize_voxel_native(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(VoxelStep);
}

static void uninitialize_voxel_native(ModuleInitializationLevel level) {}

extern "C" {
GDExtensionBool GDE_EXPORT voxel_native_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		const GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
	init_obj.register_initializer(initialize_voxel_native);
	init_obj.register_terminator(uninitialize_voxel_native);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
