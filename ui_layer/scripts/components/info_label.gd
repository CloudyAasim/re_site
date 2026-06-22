extends Label

func _ready() -> void:
	# --- 1. 你自己应用的许可证声明（代码 MIT + 字体 SIL OFL） ---
	var app_license := "This application's source code is licensed under the MIT License.\n" \
	+ "Copyright (c) 2026 CloudyAasim\n" \
	+ "\n" \
	+ "Included fonts:\n" \
	+ "- Source Han Sans\n" \
	+ "  Copyright © 2014–2021 Adobe, Google\n" \
	+ "  Licensed under the SIL Open Font License, Version 1.1\n" \
	+ "- Noto Color Emoji\n" \
	+ "  Copyright © Google\n" \
	+ "  Licensed under the SIL Open Font License, Version 1.1"

	# --- 2. 动态获取 Godot 引擎自身的版权信息 ---
	var copyright_info: Array = Engine.get_copyright_info()
	var engine_text := ""

	for item in copyright_info:
		if item.has("name") and item["name"] == "Godot Engine":
			engine_text += item["name"] + "\n"
			if item.has("parts"):
				for part in item["parts"]:
					var license_name = part.get("license", "MIT")
					if license_name == "Expat":
						license_name = "MIT License"
					engine_text += "License: " + license_name + "\n"
					if part.has("copyright"):
						for line in part["copyright"]:
							engine_text += "Copyright (c) " + line + "\n"
			break

	# --- 3. 合并并去除末尾多余换行 ---
	var full_text = app_license + "\n\n" + engine_text
	text = full_text.strip_edges()
