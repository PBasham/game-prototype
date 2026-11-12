extends Node
## Autoload "EventBus": global signals for events that cross system boundaries.
##
## Use a direct signal when the listener can hold a reference to the emitter
## (a HUD bar listening to the player's Health component). Use the EventBus when it
## can't (the music system reacting to a boss being summoned anywhere in the world).
## New signals get added here phase by phase, each with a one-line comment.

## Game.state changed. Values are Game.State.
@warning_ignore("unused_signal")
signal game_state_changed(new_state: int, old_state: int)

## A world finished loading / generating and is ready to play.
@warning_ignore("unused_signal")
signal world_loaded

## The current world was unloaded (back to menu, quit).
@warning_ignore("unused_signal")
signal world_unloaded

## Short text for on-screen debug toasts.
@warning_ignore("unused_signal")
signal debug_message(text: String)
