extends CanvasLayer

const CELL_SIZE := 48.0
const GRID_COLUMNS := 8
const GRID_ROWS := 8

var _root: Control
var _stash_grid: Control
var _drag_item: Panel
var _dragging := false
var _drag_offset := Vector2.ZERO
var _inventory_open := false
var _player: Node


func _ready() -> void:
	_build_ui()
	_root.visible = false
	_player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	var should_open := Input.is_action_pressed("inventory")
	if should_open != _inventory_open:
		_set_inventory_open(should_open)


func _set_inventory_open(value: bool) -> void:
	_inventory_open = value
	_root.visible = value

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if is_instance_valid(_player) and _player.has_method("set_input_locked"):
		_player.set_input_locked(value)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.025, 0.03, 0.035, 0.96)
	_root.add_child(backdrop)

	var title := Label.new()
	title.position = Vector2(28, 18)
	title.text = "GEAR"
	title.add_theme_font_size_override("font_size", 26)
	_root.add_child(title)

	var hint := Label.new()
	hint.position = Vector2(28, 52)
	hint.text = "Hold TAB to inspect inventory   •   Drag the test item in the stash"
	hint.modulate = Color(0.65, 0.68, 0.7)
	_root.add_child(hint)

	var body := HBoxContainer.new()
	body.position = Vector2(28, 92)
	body.size = Vector2(1224, 610)
	body.add_theme_constant_override("separation", 18)
	_root.add_child(body)

	var equipment := _make_section("EQUIPMENT", Vector2(290, 610))
	body.add_child(equipment)
	_add_slot(equipment, "HEADWEAR", Vector2(20, 62), Vector2(115, 105))
	_add_slot(equipment, "FACE COVER", Vector2(155, 62), Vector2(115, 105))
	_add_slot(equipment, "BODY ARMOR", Vector2(20, 188), Vector2(250, 120))
	_add_slot(equipment, "HOLSTER", Vector2(20, 330), Vector2(115, 170))
	_add_slot(equipment, "ON SLING", Vector2(155, 330), Vector2(115, 170))

	var carried := _make_section("CARRIED", Vector2(395, 610))
	body.add_child(carried)
	_add_slot(carried, "TACTICAL RIG", Vector2(20, 62), Vector2(355, 150))
	_add_slot(carried, "POCKETS", Vector2(20, 232), Vector2(355, 90))
	_add_slot(carried, "BACKPACK", Vector2(20, 342), Vector2(355, 220))

	var stash := _make_section("STASH", Vector2(500, 610))
	body.add_child(stash)

	_stash_grid = Control.new()
	_stash_grid.position = Vector2(20, 62)
	_stash_grid.size = Vector2(GRID_COLUMNS * CELL_SIZE, GRID_ROWS * CELL_SIZE)
	_stash_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	stash.add_child(_stash_grid)
	_build_grid_cells(_stash_grid)

	var stash_note := Label.new()
	stash_note.position = Vector2(20, 468)
	stash_note.text = "Prototype grid: 8 × 8"
	stash_note.modulate = Color(0.55, 0.58, 0.6)
	stash.add_child(stash_note)

	_drag_item = Panel.new()
	_drag_item.position = Vector2(CELL_SIZE, CELL_SIZE)
	_drag_item.size = Vector2(CELL_SIZE * 2.0, CELL_SIZE)
	_drag_item.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_item.gui_input.connect(_on_item_gui_input)
	_drag_item.add_theme_stylebox_override("panel", _style_box(Color(0.28, 0.38, 0.24), Color(0.62, 0.74, 0.45), 2))
	_stash_grid.add_child(_drag_item)

	var item_label := Label.new()
	item_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_label.text = "TEST RIFLE\n2 × 1"
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_item.add_child(item_label)


func _make_section(section_name: String, section_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = section_size
	panel.add_theme_stylebox_override("panel", _style_box(Color(0.055, 0.065, 0.072), Color(0.18, 0.2, 0.21), 1))

	var label := Label.new()
	label.position = Vector2(18, 16)
	label.text = section_name
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	return panel


func _add_slot(parent: Control, slot_name: String, slot_position: Vector2, slot_size: Vector2) -> void:
	var label := Label.new()
	label.position = slot_position + Vector2(0, -22)
	label.text = slot_name
	label.modulate = Color(0.72, 0.74, 0.75)
	parent.add_child(label)

	var slot := Panel.new()
	slot.position = slot_position
	slot.size = slot_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _style_box(Color(0.035, 0.04, 0.045), Color(0.16, 0.18, 0.19), 1))
	parent.add_child(slot)


func _build_grid_cells(grid: Control) -> void:
	for row in GRID_ROWS:
		for column in GRID_COLUMNS:
			var cell := Panel.new()
			cell.position = Vector2(column * CELL_SIZE, row * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.045, 0.05), Color(0.14, 0.15, 0.16), 1))
			grid.add_child(cell)


func _on_item_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position
			_drag_item.move_to_front()
		else:
			_dragging = false
			_snap_item_to_grid()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_item.position += event.relative
		_clamp_item_to_grid()
		accept_event()


func _snap_item_to_grid() -> void:
	var snapped := Vector2(
		round(_drag_item.position.x / CELL_SIZE) * CELL_SIZE,
		round(_drag_item.position.y / CELL_SIZE) * CELL_SIZE
	)
	_drag_item.position = snapped
	_clamp_item_to_grid()


func _clamp_item_to_grid() -> void:
	var max_x := _stash_grid.size.x - _drag_item.size.x
	var max_y := _stash_grid.size.y - _drag_item.size.y
	_drag_item.position.x = clamp(_drag_item.position.x, 0.0, max_x)
	_drag_item.position.y = clamp(_drag_item.position.y, 0.0, max_y)


func _style_box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
