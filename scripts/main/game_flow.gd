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

## Where the save lives. Tests point this at a temp file; leave it alone otherwise.
var save_path: String = GameState.SAVE_PATH

var _tutorial: TutorialBox
var _title: TitleScreen
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
	_state = GameState.load_or_new(save_path)
	_missions = MissionLibrary.build_all()

	_title = TitleScreen.new()
	_title.total_missions = _missions.size()
	_title.continue_pressed.connect(_on_continue)
	_title.new_game_pressed.connect(_on_new_game)
	_title.quit_pressed.connect(func(): get_tree().quit())
	add_child(_title)

	_lobby = LobbyScreen.new()
	_lobby.title_pressed.connect(func(): _switch_to(_title))
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
	_tutorial = TutorialBox.new()
	layer.add_child(_tutorial)

	_fader = ScreenFader.new()
	add_child(_fader)

	_show_only(_title)

# ---------------------------------------------------------------- screens

func _show_only(screen) -> void:
	for s in [_title, _lobby, _board, _workshop]:
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

## Title > Continue: straight to the lobby with the saved progress.
func _on_continue() -> void:
	if _busy:
		return
	_state = GameState.load_or_new(save_path)
	await _switch_to(_lobby)
	await _play_lobby_story()

## Title > New Game (already confirmed): wipe the save, start from zero, and
## go straight into the first mission. Afterwards the lobby plays its intro.
func _on_new_game() -> void:
	if _busy or _missions.is_empty():
		return
	GameState.delete_save(save_path)
	_state = GameState.load_or_new(save_path) # fresh defaults, no file
	_state.save()
	await _on_mission_selected(_missions[0])
	await _play_lobby_story()

func _play_lobby_story() -> void:
	var lines := MissionLibrary.lobby_visit_lines(_state)
	if lines.is_empty():
		return
	_busy = true
	await _dialogue.play(lines)
	_state.seen_lobby_intro = true
	_state.save()
	_busy = false

## Training: the normal battle screen against two dummies, with the energy bar
## always full. No story, no rewards, and items used are not spent.
func _on_training_pressed() -> void:
	if _busy:
		return
	_busy = true
	await _fader.fade_out(0.4)
	for s in [_title, _lobby, _board, _workshop]:
		s.visible = false
	await _run_battle(_make_training_mission(), true)
	_show_only(_lobby)
	await _fader.fade_in(0.4)
	_busy = false

## Two Training Dummies (data/enemies/training_dummy.tres) in one wave.
func _make_training_mission() -> Mission:
	var dummy: EnemyType = load("res://data/enemies/training_dummy.tres")
	var wave := EnemyWave.new()
	wave.enemies.append(dummy)
	wave.enemies.append(dummy)
	var m := Mission.new()
	m.id = &"training"
	m.title = "Training"
	m.waves.append(wave)
	return m

# ---------------------------------------------------------------- missions

func _on_mission_selected(mission: Mission) -> void:
	if _busy:
		return
	_busy = true

	# 1) Into the story: black -> title card -> reveal under the dialogue.
	await _fader.fade_out(0.4)
	for s in [_title, _lobby, _board, _workshop]:
		s.visible = false
	var sub_parts: PackedStringArray = []
	if mission.chapter_label != "":
		sub_parts.append(mission.chapter_label)
	if mission.location != "":
		sub_parts.append(mission.location)
	await _fader.title_card(mission.title, "  -  ".join(sub_parts), 1.8, mission.title_background)

	# 2) Pre-battle cutscene (fade-in runs while the dialogue starts).
	_fader.fade_in(0.5)
	await _dialogue.play(mission.intro_lines)

	# 3) Battle (builds under black, reveals, ends with a fade to black).
	await _fader.fade_out(0.4)
	var won := true # story-only missions (no waves) skip the battle
	if mission.wave_count() > 0:
		won = await _run_battle(mission)

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
	if not first_clear and amount > 0:
		amount = maxi(1, int(ceil(mission.fragment_reward * REPLAY_REWARD_RATIO)))
	_state.mark_cleared(mission.id)
	_state.add_fragments(amount)
	_state.save()
	if amount <= 0:
		return # story-only mission: nothing to show
	await _rewards.show_rewards(mission.title, amount, first_clear, _state.fragments)

## Builds a fresh battle under the black screen, reveals it, waits for the
## result, fades out, tears it down. Returns true if the player won.
func _run_battle(mission: Mission, training: bool = false) -> bool:
	_battle_root = Node.new()
	_battle_root.name = "Battle"
	add_child(_battle_root)

	_battle_won = false
	_battle_done = false

	var bm := BattleManager.new()
	bm.name = "BattleManager"
	bm.training = training
	bm.player_team = UnitFactory.make_player_team(_state, mission.party_ids)

	var enemies: Array[BattleUnit] = []
	enemies.assign(mission.build_wave(0))
	bm.enemy_team = enemies
	bm.wave_count = mission.wave_count()
	bm.wave_factory = func(i: int): return mission.build_wave(i)

	_load_inventory(bm)

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
	var show_tutorial := not training and not mission.tutorial_pages.is_empty()
	ui.autostart = not show_tutorial # a tutorial shows first, then begin()
	_battle_root.add_child(ui)

	var stage := BattleStage.new()
	stage.battle_manager = bm
	_battle_root.add_child(stage)

	await _fader.fade_in(0.4)
	if show_tutorial:
		await _tutorial.play(mission.tutorial_pages)
		ui.begin()
	if not _battle_done: # (it could, in theory, already be over)
		await _battle_finished
	# Let the player read the last log lines ("Victory!" / "defeated...").
	await get_tree().create_timer(1.8).timeout
	await _fader.fade_out(0.5)

	if _battle_won and not training:
		_save_inventory(bm)
	_battle_root.queue_free()
	_battle_root = null
	return _battle_won

## Items crafted in the workshop go into the battle.
func _load_inventory(bm: BattleManager) -> void:
	for item in ItemLibrary.all():
		var n := _state.item_count(item.id)
		if n > 0:
			bm.add_item(item, n)

## After a WIN, whatever was used stays used. After a loss nothing is spent,
## so the player can retry with the same supplies.
func _save_inventory(bm: BattleManager) -> void:
	for item in ItemLibrary.all():
		_state.inventory[item.id] = clampi(int(bm.party_inventory.get(item, 0)), 0, ItemLibrary.MAX_STACK)
	_state.save()
