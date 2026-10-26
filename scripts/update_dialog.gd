extends CanvasLayer

signal confirmed_launch
signal cancelled

@onready var panel: Panel = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var status: Label = $Panel/VBox/Status
@onready var progress: ProgressBar = $Panel/VBox/ProgressBar
@onready var buttons: HBoxContainer = $Panel/VBox/Buttons
@onready var launch_btn: Button = $Panel/VBox/Buttons/LaunchButton
@onready var later_btn: Button = $Panel/VBox/Buttons/LaterButton

func _ready() -> void:
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if launch_btn:
		launch_btn.pressed.connect(_on_launch_pressed)
	if later_btn:
		later_btn.pressed.connect(_on_later_pressed)
	_hide_buttons()
	progress.value = 0.0
	progress.visible = true


func show_progress(text: String) -> void:
	visible = true
	_set_localized(title, "ĐANG CẬP NHẬT")
	_set_localized(status, text)
	progress.visible = true
	progress.value = 0.0
	if launch_btn:
		launch_btn.visible = false
	if later_btn:
		_set_localized(later_btn, "HỦY TẢI")
		later_btn.visible = true
	if buttons:
		buttons.visible = true


func set_progress(pct: float, text: String = "", show_percentage: bool = true) -> void:
	if pct < 0.0:
		pct = 0.0
	if pct > 100.0:
		pct = 100.0
	progress.value = pct
	progress.show_percentage = show_percentage
	if text != "":
		_set_localized(status, text)


func show_ready_to_launch(message: String = "") -> void:
	visible = true
	_set_localized(title, "CẬP NHẬT HOÀN TẤT")
	var ready_message := message
	if ready_message.is_empty():
		ready_message = "Bản cập nhật đã sẵn sàng.\nBạn có muốn khởi động game ngay bây giờ không?"
	_set_localized(status, ready_message)
	progress.visible = false
	if later_btn:
		_set_localized(later_btn, "ĐỂ SAU")
	_show_buttons()


func show_download_error(message: String) -> void:
	visible = true
	_set_localized(title, "KHÔNG THỂ TẢI BẢN CẬP NHẬT")
	_set_localized(status, message)
	progress.visible = false
	if launch_btn:
		launch_btn.visible = false
	if later_btn:
		_set_localized(later_btn, "ĐÓNG")
		later_btn.visible = true
	if buttons:
		buttons.visible = true


func _show_buttons() -> void:
	if buttons:
		buttons.visible = true
	if launch_btn:
		launch_btn.visible = true
		launch_btn.grab_focus()
	if later_btn:
		later_btn.visible = true


func _hide_buttons() -> void:
	if buttons:
		buttons.visible = false
	if launch_btn:
		launch_btn.visible = false
	if later_btn:
		later_btn.visible = false


func _set_localized(control: Control, source_text: String) -> void:
	var locale := get_node_or_null("/root/Locale")
	if locale:
		locale.localize_control(control, source_text)
	else:
		control.set("text", source_text)


func _on_launch_pressed() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	confirmed_launch.emit()


func _on_later_pressed() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	cancelled.emit()
	queue_free()
