extends Button

func _ready() -> void:
	SettingManager.locale_changed.connect(_refresh_text)
	_refresh_text()

func _refresh_text():
	text = tr("BTN_BACK")


func _on_pressed() -> void:
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/home_page.tscn")
