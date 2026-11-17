extends Node
## Autoload "Game": top-level game state and the session's network role.
##
## Multiplayer rule (see docs/architecture.md): the game is host-authoritative.
## Anything that changes shared state (tiles, dropped items, entities, chests, bosses)
## is applied only where is_authority() is true. In single-player the local game is
## the host, so is_authority() is always true and nothing changes for solo play.
## Systems request changes through their service API; they never mutate shared state
## directly from input code.

enum State { BOOT, MAIN_MENU, LOADING, PLAYING, PAUSED }

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const WORLD_SCENE := "res://scenes/world/world.tscn"

var state: State = State.BOOT
## The world to load or being played. Set by start_world(); read by World._ready().
var world_info: WorldInfo


## Loads a world (new or saved) and switches to the world scene.
func start_world(info: WorldInfo) -> void:
	world_info = info
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)


## Back to the main menu. The World saves itself as it leaves the tree.
func quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	EventBus.game_state_changed.emit(new_state, old)


func state_name() -> String:
	return State.keys()[state]


## True when this peer may change shared game state. Offline / single-player: always true.
func is_authority() -> bool:
	return multiplayer.is_server()


## True when running a networked session (host or client), false for solo play.
func is_networked() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
