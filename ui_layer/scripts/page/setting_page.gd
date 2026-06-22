extends Node

@export var initial_focus_control: Control

func _ready() -> void:
	UiNavigator.focus_control(initial_focus_control)

# ⭐⭐ 新增：监听全局返回键输入 ⭐⭐
func _unhandled_input(event: InputEvent):
	# ui_cancel 对应键盘的 Escape 键和安卓的返回键
	if event.is_action_pressed("ui_cancel"):
		UISignal.switch_page_requested.emit("res://ui_layer/scenes/page/home_page.tscn")
