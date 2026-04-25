extends Control
class_name UpgradeMenu

signal closed()

const PANEL_W := 660.0
const PANEL_H := 920.0
const CARD_H  := 160.0

var _wallet_label: Label
var _level_labels: Dictionary = {}
var _buy_buttons:  Dictionary = {}

func _ready() -> void:
	_build_ui()
	UpgradeManager.upgraded.connect(_on_upgraded)
	GameManager.money_changed.connect(_on_money_changed)

func _build_ui() -> void:
	var px := (720.0 - PANEL_W) / 2.0
	var py := (1280.0 - PANEL_H) / 2.0

	# Full-screen dimmer — blocks all touches behind the menu
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Panel background
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.13, 0.16)
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(px, py)
	add_child(panel)

	# Title
	var title := Label.new()
	title.text = "Upgrade Shop"
	title.size = Vector2(PANEL_W, 44)
	title.position = Vector2(px, py + 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)

	# Wallet display
	_wallet_label = Label.new()
	_wallet_label.size = Vector2(PANEL_W - 32, 30)
	_wallet_label.position = Vector2(px + 16, py + 56)
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label.add_theme_font_size_override("font_size", 17)
	_wallet_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_child(_wallet_label)

	# Upgrade cards
	var card_y := py + 96.0
	for type: int in UpgradeManager.Type.values():
		_build_card(type, px + 14, card_y, PANEL_W - 28)
		card_y += CARD_H + 8

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size = Vector2(180, 52)
	close_btn.position = Vector2(px + (PANEL_W - 180) / 2.0, py + PANEL_H - 68)
	close_btn.pressed.connect(_on_close_pressed)
	add_child(close_btn)

	_refresh_all()

func _build_card(type: int, x: float, y: float, w: float) -> void:
	var def := UpgradeManager.get_def(type)

	var bg := ColorRect.new()
	bg.color = Color(0.20, 0.22, 0.27)
	bg.size = Vector2(w, CARD_H)
	bg.position = Vector2(x, y)
	add_child(bg)

	# Upgrade name
	var name_lbl := Label.new()
	name_lbl.text = def.display_name
	name_lbl.position = Vector2(x + 12, y + 10)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(name_lbl)

	# Level indicator
	var lvl_lbl := Label.new()
	lvl_lbl.size = Vector2(120, 26)
	lvl_lbl.position = Vector2(x + w - 132, y + 10)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.add_theme_font_size_override("font_size", 14)
	lvl_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.45))
	add_child(lvl_lbl)
	_level_labels[type] = lvl_lbl

	# Description
	var desc := Label.new()
	desc.text = def.description
	desc.size = Vector2(w - 24, 56)
	desc.position = Vector2(x + 12, y + 40)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	add_child(desc)

	# Buy button
	var btn := Button.new()
	btn.size = Vector2(148, 44)
	btn.position = Vector2(x + w - 160, y + CARD_H - 54)
	btn.pressed.connect(_on_buy_pressed.bind(type))
	add_child(btn)
	_buy_buttons[type] = btn

func _refresh_all() -> void:
	_wallet_label.text = "Wallet:  $%.0f" % GameManager.money
	for type: int in UpgradeManager.Type.values():
		_refresh_card(type)

func _refresh_card(type: int) -> void:
	var def := UpgradeManager.get_def(type)
	var lvl := UpgradeManager.get_level(type)

	var lvl_lbl: Label = _level_labels.get(type)
	if lvl_lbl:
		lvl_lbl.text = "Lvl %d / %d" % [lvl, def.max_level]

	var btn: Button = _buy_buttons.get(type)
	if not btn:
		return

	if UpgradeManager.is_maxed(type):
		btn.text = "MAXED"
		btn.disabled = true
	else:
		btn.text = "$%d" % UpgradeManager.get_cost(type)
		btn.disabled = not UpgradeManager.can_afford(type)

func _on_buy_pressed(type: int) -> void:
	UpgradeManager.purchase(type)

func _on_upgraded(_type: int, _level: int) -> void:
	_refresh_all()

func _on_money_changed(_amount: float) -> void:
	_refresh_all()

func _on_close_pressed() -> void:
	closed.emit()
