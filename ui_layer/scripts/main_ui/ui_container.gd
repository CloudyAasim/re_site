extends Control

var ui_container: Control = self

var current_page: Node = null

func _ready():
	# 监听全局切换信号
	UISignal.switch_page_requested.connect(_on_switch_page_requested)
	
	# 游戏开始时加载主页
	_on_switch_page_requested("res://ui_layer/scenes/page/login_page.tscn")

# 核心切换函数
func _on_switch_page_requested(page_path: String):
	if current_page:
		current_page.queue_free()
	var page_scene = load(page_path)
	if page_scene:
		current_page = page_scene.instantiate()
		ui_container.add_child(current_page)
