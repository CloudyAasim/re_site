# ReSite - Seat Reservation Management System

> ⚠️ **Note**: This project is a final coursework for educational purposes only. No further maintenance will be provided.

A modern seat reservation and management system built with Godot Engine.

**Backend Repository**: [seat_reservation_schoolwork](https://github.com/HiryKun/seat_reservation_schoolwork)

## Features

- 🎫 Seat reservation and management
- 🗺️ Visual seat map
- 👤 User account system
- 🌐 Multi-language support (Chinese/English)
- 📱 Cross-platform support (Windows, Linux, Android, Web)
- ⚙️ Flexible configuration management

## Tech Stack

- **Engine**: Godot 4.7
- **Language**: GDScript
- **Renderer**: Mobile Renderer

## Project Structure

```
re-seat/
├── inner_layer/              # Core logic layer
│   ├── autoload/            # Autoload scripts (config, data, settings)
│   └── locales/             # Localization files
├── ui_layer/                # UI layer
│   ├── scenes/              # Scene files
│   │   ├── components/      # Common components
│   │   ├── page/            # Pages
│   │   └── main_ui/         # Main interface
│   ├── scripts/             # UI scripts
│   ├── themes/              # Theme resources
│   └── shaders/             # Shaders
├── network_layer/           # Network layer
├── assets/                  # Asset files
│   ├── fonts/               # Fonts
│   ├── icons/               # Icons
│   └── photo/               # Images
└── project.godot            # Project configuration
```

## Development Requirements

- Godot Engine 4.7

## Quick Start

Open the project with Godot Engine:
   - Launch Godot Engine
   - Click the "Import" button
   - Select the `project.godot` file in the project root directory

Run the project:
   - Press F5 or click the run button in the Godot editor

## Export Build

The project supports multi-platform export:

- **Windows**: Export as `.exe` executable
- **Linux**: Export as `.zip` archive
- **Android**: Export as `.apk` file
- **Web**: Export as HTML5 application

## License

This project is open-sourced under the MIT License. See the [LICENSE](LICENSE) file for details.

### Third-Party Dependencies

| Name | License | Description |
|------|---------|-------------|
| [Godot Engine](https://godotengine.org) | MIT | Game engine |
| [Source Han Sans](https://github.com/adobe-fonts/source-han-sans) | SIL OFL 1.1 | Source Han Sans font |
| [Noto Color Emoji](https://github.com/googlefonts/noto-emoji) | SIL OFL 1.1 | Noto Color Emoji font |

---

# ReSite - 座位预订管理系统

> ⚠️ **注意**：本项目仅为期末课程作业，仅供学习参考使用，不进行后续维护。

一个使用 Godot Engine 开发的现代化座位预订和管理系统。

**配套后端**：[seat_reservation_schoolwork](https://github.com/HiryKun/seat_reservation_schoolwork)

## 功能特性

- 🎫 座位预订和管理
- 🗺️ 可视化座位地图
- 👤 用户账户系统
- 🌐 多语言支持（中文/英文）
- 📱 跨平台支持（Windows、Linux、Android、Web）
- ⚙️ 灵活的配置管理

## 技术栈

- **引擎**: Godot 4.7
- **语言**: GDScript
- **渲染**: Mobile Renderer

## 项目结构

```
re-seat/
├── inner_layer/              # 核心逻辑层
│   ├── autoload/            # 自动加载脚本（配置、数据、设置）
│   └── locales/             # 多语言文件
├── ui_layer/                # UI 界面层
│   ├── scenes/              # 场景文件
│   │   ├── components/      # 通用组件
│   │   ├── page/            # 页面
│   │   └── main_ui/         # 主界面
│   ├── scripts/             # UI 脚本
│   ├── themes/              # 主题资源
│   └── shaders/             # 着色器
├── network_layer/           # 网络层
├── assets/                  # 资源文件
│   ├── fonts/               # 字体
│   ├── icons/               # 图标
│   └── photo/               # 图片
└── project.godot            # 项目配置
```

## 开发环境要求

- Godot Engine 4.7

## 快速开始

使用 Godot Engine 打开项目：
   - 启动 Godot Engine
   - 点击 "Import" 按钮
   - 选择项目根目录下的 `project.godot` 文件

运行项目：
   - 在 Godot 编辑器中按 F5 或点击运行按钮

## 导出构建

项目支持多平台导出：

- **Windows**: 导出为 `.exe` 可执行文件
- **Linux**: 导出为 `.zip` 压缩包
- **Android**: 导出为 `.apk` 文件
- **Web**: 导出为 HTML5 应用

## 许可证

本项目基于 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。

### 第三方依赖

| 名称 | 许可证 | 说明 |
|------|--------|------|
| [Godot Engine](https://godotengine.org) | MIT | 游戏引擎 |
| [Source Han Sans](https://github.com/adobe-fonts/source-han-sans) | SIL OFL 1.1 | 思源黑体字体 |
| [Noto Color Emoji](https://github.com/googlefonts/noto-emoji) | SIL OFL 1.1 | 彩色 Emoji 字体 |
