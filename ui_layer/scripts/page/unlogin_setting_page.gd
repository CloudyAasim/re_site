extends Node

@export var initial_focus_control: Control
@export var back_login_page_button: Button

func _ready() -> void:
	UiNavigator.focus_control(initial_focus_control)
	SettingManager.locale_changed.connect(_on_locale_changed)
	_on_locale_changed()

func _on_locale_changed():
	back_login_page_button.text = tr("BTN_BACK")

# ⭐⭐ 新增：监听全局返回键输入 ⭐⭐
func _unhandled_input(event: InputEvent):
	# ui_cancel 对应键盘的 Escape 键和安卓的返回键
	if event.is_action_pressed("ui_cancel"):
		UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/home_page.tscn")


func _on_back_login_page_button_pressed() -> void:
	UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/login_page.tscn")
