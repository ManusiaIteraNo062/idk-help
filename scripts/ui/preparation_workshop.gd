extends Control
class_name PreparationWorkshop
## Workshop > Preparation: craft consumable items to carry into missions.
## Grouped by category (each with its flavor text); price differs per item.
## You can carry at most ItemLibrary.MAX_STACK of each. Items used in a won
## mission stay used; after a loss nothing is spent.

signal back_pressed
signal changed

var _state: GameState
var _focus_row: int = 0
var _fragments_label: Label
var _list: VBoxContainer
var _admin_label: Label
var _back_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := WorkshopStyle.build_frame(880)
	center.add_child(frame["root"])
	var col: VBoxContainer = frame["content"]
	col.add_theme_constant_override("separation", 7)

	col.add_child(WorkshopStyle.title_label("ITEM", 24))

	_fragments_label = Label.new()
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fragments_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_admin_label = Label.new()
	_admin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_label.custom_minimum_size = Vector2(0, 26)
	_admin_label.modulate = Roster.ADMIN_COLOR.lightened(0.4)
	col.add_child(_admin_label)

	_back_btn = Button.new()
	_back_btn.text = "Back"
	_back_btn.custom_minimum_size = Vector2(0, 42)
	WorkshopStyle.style_button(_back_btn)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)

func refresh(state: GameState) -> void:
	_state = state
	_admin_label.text = ""
	_focus_row = 0
	_rebuild()

func focus_first() -> void:
	var rows := _list.get_children()
	var start := clampi(_focus_row, 0, maxi(0, rows.size() - 1))
	var order: Array[int] = []
	for i in range(start, rows.size()):
		order.append(i)
	for i in range(start - 1, -1, -1):
		order.append(i)
	for i in order:
		for b in _buttons_in(rows[i]):
			if not b.disabled:
				b.grab_focus()
				return
	_back_btn.grab_focus()

func _buttons_in(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		else:
			out.append_array(_buttons_in(c))
	return out

func _rebuild() -> void:
	if _state == null:
		return
	_fragments_label.text = "Shangri-La Fragments: %d" % _state.fragments
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for category in ItemLibrary.categories():
		var head := VBoxContainer.new()
		head.add_theme_constant_override("separation", 0)
		var title := Label.new()
		title.text = category.to_upper()
		title.add_theme_font_override("font", WorkshopStyle.title_font())
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", WorkshopStyle.TEAL_EDGE)
		head.add_child(title)
		var flavor := Label.new()
		flavor.text = ItemLibrary.CATEGORY_FLAVOR[category]
		flavor.modulate = Color(1, 1, 1, 0.65)
		flavor.add_theme_font_size_override("font_size", 13)
		head.add_child(flavor)
		_list.add_child(head)
		for item in ItemLibrary.in_category(category):
			_item_row(item)

func _item_row(item: Item) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", WorkshopStyle.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var info := Label.new()
	info.text = "%s   (%d Frag)\n%s\nDimiliki: %d / %d" % [
		item.item_name, item.cost, item.description, _state.item_count(item.id), ItemLibrary.MAX_STACK
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(560, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 52)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	WorkshopStyle.style_button(btn)
	var full := not _state.can_carry_more(item.id)
	btn.text = "Full" if full else "Craft (%d)" % item.cost
	btn.disabled = full or not _state.can_afford(item.cost)
	var index := _list.get_child_count()
	btn.pressed.connect(func():
		_focus_row = index
		_on_craft(item)
	)
	row.add_child(btn)
	_list.add_child(card)

func _on_craft(item: Item) -> void:
	if _state.buy_item(item):
		_admin_label.text = "Admin: %s siap dibawa. (%d)" % [item.item_name, _state.item_count(item.id)]
		changed.emit()
	_rebuild()
	focus_first.call_deferred()
