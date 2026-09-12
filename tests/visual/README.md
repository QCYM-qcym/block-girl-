# Sprite runtime validation

在 Godot 打开 `sprite_runtime_test.tscn`，按 F6 运行当前场景。也可在 PowerShell 运行此目录的 `run_sprite_validation.ps1`。加 `-Auto` 会自动播放全部动画、保存 GPU 帧缓冲截图与运行 JSON，然后退出测试窗口。

测试局部采用 Nearest、整数位置及整数倍率；不会修改项目主场景或全局分辨率/过滤设置。角色资源复用 `res://production/sprites/`。测试不是正式角色控制器。

按键：1 idle、2 subtle_idle、3 roll_left、4 roll_right、5 roll_forward、6 roll_backward、7 interaction、8 puzzle_complete、Space world_switch、S 阴影显隐。每个按键均同时操作两个角色；1x–4x 和额外 8x 放大区同步。普通交互模式的 Space 仅播放颜色切换预览；自动模式额外验证切换后更换 SpriteFrames 的无缝接续。

`evidence/run_01` 是修复前实际运行；`evidence/run_02` 是修复后实际运行。每轮保留使用的 PNG/SpriteFrames 副本，避免后续资源更新后无法复查。截图来自 Godot Viewport 在 `RenderingServer.frame_post_draw` 后读取的真实 GPU 渲染，不是离线 Sprite 拼图。contact 图片是这些真实截图的裁切排列。

最终结论、问题修复及边界见同目录 `sprite_runtime_validation.md`。`.gdignore` 阻止证据图片再次作为游戏资产导入。
