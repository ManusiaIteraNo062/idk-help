extends Node
## Attach this to your main scene's root Node (replaces battle_demo.gd).
##
## Whole-game flow:
##
##   Lobby <-> Mission Board / Admin's Workshop / Training
##
##   Mission picked:
##     fade out -> title card -> fade in -> PRE-BATTLE dialogue
##     -> fade out -> battle (fade in) -> fade out
##     -> POST-BATTLE dialogue (victory or defeat)
##     -> win only: reward popup (Shangri-La Fragments, saved)
##     -> fade out -> Lobby
##
## Winning marks the mission cleared (unlocking the next one), pays
## fragments (full on first clear, REPLAY_REWARD_RATIO on replays) and saves.
## Every battle attempt starts fresh: party at full HP, new enemies, new
## item stock. Equipped weapons are baked into the party's stats.

signal _battle_finished

const REPLAY_REWARD_RATIO := 0.4

var _state: GameState
var _missions: Array[Mission] = []
var _busy: bool = false # blocks input while a transition/sequence runs

var _lobby: LobbyScreen
var _board: MissionBoard
var _workshop: WorkshopScreen
var _dialogue: DialogueBox
var _rewards: RewardPopup
var _fader: ScreenFader

var _battle_root: Node
var _battle_won: bool = false
var _battle_done: bool = false

func _ready() -> void:
	_state = GameState.load_or_new()
	_missions = MissionLibrary.build_all()

	_lobby = LobbyScreen.new()
	_lobby.missions_pressed.connect(func(): _switch_to(_board))
	_lobby.workshop_pressed.connect(func(): _switch_to(_workshop))
	_lobby.training_pressed.connect(_on_training_pressed)
	add_child(_lobby)

	_board = MissionBoard.new()
	_board.missions = _missions
	_board.mission_selected.connect(_on_mission_selected)
	_board.back_pressed.connect(func(): _switch_to(_lobby))
	add_child(_board)

	_workshop = WorkshopScreen.new()
	_workshop.changed.connect(func(): _state.save())
	_workshop.back_pressed.connect(func(): _switch_to(_lobby))
	add_child(_workshop)

	# Dialogue + rewards share a CanvasLayer so they always draw above the
	# menus and the battle.
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_dialogue = DialogueBox.new()
	layer.add_child(_dialogue)
	_rewards = RewardPopup.new()
	layer.add_child(_rewards)

	_fader = ScreenFader.new()
	add_child(_fader)

	_show_only(_lobby)
	await _play_lobby_story()

# ---------------------------------------------------------------- screens

func _show_only(screen) -> void:
	for s in [_lobby, _board, _workshop]:
		s.visible = false
	screen.refresh(_state)
	screen.visible = true
	screen.focus_first()

func _switch_to(screen) -> void:
	if _busy:
		return
	_busy = true
	await _fader.fade_out(0.25)
	_show_only(screen)
	await _fader.fade_in(0.25)
	_busy = false

func _play_lobby_story() -> void:
	var lines := MissionLibrary.lobby_visit_lines(_state)
	if lines.is_empty():
		return
	_busy = true
	await _dialogue.play(lines)
	_state.seen_lobby_intro = true
	_state.save()
	_busy = false

func _on_training_pressed() -> void:
	if _busy:
		return
	_busy = true
	# Placeholder until Training mode exists.
	await _dialogue.play([DialogueLine.make("", "Training mode isn't built yet.")])
	_busy = false

# ---------------------------------------------------------------- missions

func _on_mission_selected(mission: Mission) -> void:
	if _busy:
		return
	_busy = true

	# 1) Into the story: black -> title card -> reveal under the dialogue.
	await _fader.fade_out(0.4)
	for s in [_lobby, _board, _workshop]:
		s.visible = false
	var sub_parts: PackedStringArray = []
	if mission.chapter_label != "":
		sub_parts.append(mission.chapter_label)
	if mission.location != "":
		sub_parts.append(mission.location)
	await _fader.title_card(mission.title, "  -  ".join(sub_parts), 1.8)

	# 2) Pre-battle cutscene (fade-in runs while the dialogue starts).
	_fader.fade_in(0.5)
	await _dialogue.play(mission.intro_lines)

	# 3) Battle (builds under black, reveals, ends with a fade to black).
	await _fader.fade_out(0.4)
	var won := await _run_battle(mission)

	# 4) Post-battle cutscene, then rewards on a win.
	_fader.fade_in(0.5)
	if won:
		await _dialogue.play(mission.victory_lines)
		await _give_rewards(mission)
	else:
		await _dialogue.play(mission.defeat_lines)

	# 5) Back to the lobby.
	await _fader.fade_out(0.4)
	_show_only(_lobby)
	await _fader.fade_in(0.4)
	_busy = false

func _give_rewards(mission: Mission) -> void:
	var first_clear := not _state.is_cleared(mission.id)
	var amount := mission.fragment_reward
	if not first_clear:
		amount = maxi(1, int(ceil(mission.fragment_reward * REPLAY_REWARD_RATIO)))
	_state.mark_cleared(mission.id)
	_state.add_fragments(amount)
	_state.save()
	await _rewards.show_rewards(mission.title, amount, first_clear, _state.fragments)

## Builds a fresh battle under the black screen, reveals it, waits for the
## result, fades out, tears it down. Returns true if the player won.
func _run_battle(mission: Mission) -> bool:
	_battle_root = Node.new()
	_battle_root.name = "Battle"
	add_child(_battle_root)

	_battle_won = false
	_battle_done = false

	var bm := BattleManager.new()
	bm.name = "BattleManager"
	bm.player_team = UnitFactory.make_player_team(_state)

	var enemies: Array[BattleUnit] = []
	enemies.assign(mission.build_enemies.call())
	bm.enemy_team = enemies

	_give_starting_items(bm)

	bm.battle_ended.connect(func(player_won: bool):
		_battle_won = player_won
		_battle_done = true
		_battle_finished.emit()
	)

	# Same order as the old demo: manager, then units (so they're in the
	# tree and have their HP set), then UI (which starts the battle), then
	# the stage visuals.
	_battle_root.add_child(bm)
	for unit in bm.player_team + bm.enemy_team:
		_battle_root.add_child(unit)

	var ui := BattleUI.new()
	ui.battle_manager = bm
	_battle_root.add_child(ui)

	var stage := BattleStage.new()
	stage.battle_manager = bm
	stage.position = Vector2(600, 220)
	_battle_root.add_child(stage)

	await _fader.fade_in(0.4)
	if not _battle_done: # (it could, in theory, already be over)
		await _battle_finished
	# Let the player read the last log lines ("Victory!" / "defeated...").
	await get_tree().create_timer(1.8).timeout
	await _fader.fade_out(0.5)

	_battle_root.queue_free()
	_battle_root = null
	return _battle_won

func _give_starting_items(bm: BattleManager) -> void:
	var potion := Item.new()
	potion.item_name = "Potion"
	potion.heal_amount = 40
	potion.description = "Restores 40 HP."
	bm.add_item(potion, 3)

	var phoenix_down := Item.new()
	phoenix_down.item_name = "Phoenix Down"
	phoenix_down.heal_amount = 0
	phoenix_down.revive = true
	phoenix_down.description = "Revives a fallen ally at 50% HP."
	bm.add_item(phoenix_down, 1)
