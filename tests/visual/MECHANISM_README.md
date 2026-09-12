# Mechanism runtime validation

打开 `res://tests/visual/mechanism_runtime_test.tscn`，F6。D 显示表里两侧全部机关；1 压力板进入测试；2 门打开；3 平台带角色移动；4 旋转 A→B；5 出口可用与进入测试。自动测试覆盖更多状态和返回行为。

自动复验：`run_mechanism_validation.ps1 -Auto -EvidenceName new_run`，实际打开图形窗口，结果在 `tests/visual/mechanism_evidence/new_run/`。首轮错误和最终修复轮均保留。图片来自 RenderingServer.frame_post_draw 之后的真实 Viewport GPU 图像。文本标签仅用于验收台，不是游戏 UI 资源。

逐像素复验工具：`E:/godot/若叶睦/mechanism_production_work/analyze_runtime.cjs`，传入 EvidenceName；使用本机 Node / Sharp。引擎断言、像素分析和实际画面观察共同构成验收。

可直接拖入场景的资源（同文件夹另有 Inner 版本）：

- `res://production/mechanisms/pressure_plate/PressurePlate.tscn`：Area2D 进入/离开；set_active(bool)。
- `res://production/mechanisms/door/Door.tscn`：set_open(bool)，打开结束后中央碰撞解除，柱脚保持阻挡。
- `res://production/mechanisms/moving_platform/MovingPlatform.tscn`：move_to(local_integer_destination,seconds)；translated(delta) 和 arrived(position) 信号。
- `res://production/mechanisms/rotator/RotatingPlatform.tscn`：rotate_to(0 or 1)；orientation_changed 在提交时发送。
- `res://production/mechanisms/exit/ExitGoal.tscn`：set_ready(bool)，进入 ready 区域产生 activated，complete_goal() 完成并发送 completed。

后续谜题逻辑应调用上述机关专属方法。共享 visual helper 用于内部动画，不是碰撞/通行状态 API。Surface/Inner 通过相应预设场景选择；world 属性是资源身份标记，不是完整换世界功能。

碰撞 layer 1=门阻挡、layer 2=平台支持范围、layer 4=验收角色。Area2D mask=4。平台支持面位于二维俯视投影平面，正式高度/重力/载客系统留给后续 Prototype。本轮测试角色通过 translated 信号接收相同整数位移；角色携带代码只在测试场景。

32×16 格中心定位、64×96 固定帧、pivot=(32,48)、Nearest 等规则见 MECHANISM_SPEC.md。门本批为 NE/SW 通行的一种朝向，不对 Sprite 任意旋转。旋转台 A/B 为几何重新投影；过渡期间禁止承载并禁用支持碰撞，端态开放。短暂的视觉扫掠可能超出端态格边约 1 个局部单位；没有扩大端态 logical footprint。

未设置新的 main scene、全局参考分辨率或控制器。World Switch Device 为 NOT_INCLUDED。
