# Playable Puzzle P-01 Implementation Plan

**Goal:** 在已验证的连续滚动、世界与四视角连接上完成独立 P-01 关卡和实际双输入通关。
**Architecture:** 继承既有 Connectivity 配置两世界地图和单门边；Movement 发出落定信号并支持世界占格检查。公共输入适配与生产资源表现由关卡装配，不新增全局管理器。
**Tech Stack:** Godot 4.7.2 / GDScript / PowerShell，Windows Forward+ D3D12。
**Spec:** docs/design/p01-another-world.md；用户附件 491fb26a-ab81-4a88-bbb6-bd66a1a37988。

## Constraints

- 已核验 feat/playable-puzzle-p01，初始 git status 空。用户指定直接在本 feature branch 工作，不 commit/push/merge。
- 不更改 production、tests/visual、Perspective fixture 或旧 P01。旧回归 Tileset 保存样板的副作用由既有 runner 字节恢复。
- F5 主场景只改到新关卡；没有 P02、菜单、存档、音频或 Sprite 重制。

## 1. 关卡规则与公共移动接口

- [x] 新增 tests/gameplay/test_p01_state.gd，先通过 ResourceLoader.exists 检查缺失关卡模块，记录失败；随后检查 Surface 断路、Inner 桥、8 种 world/view link 配置、momentary Plate、过门落定顺序、Exit、Reset 和无 softlock。
- [x] 修改 prototype/perspective/connectivity.gd 添加默认 can_stand(cell,world)，技术原型全节点两个世界可站。
- [x] 修改 prototype/perspective/grid_movement.gd 添加 committed 信号；roll/shift 落定后发出、先于 try_held。shift 开始调用 graph.can_stand(cell,1-world)，拒绝时只更新反馈。
- [x] 新增 game/levels/mutsumi/p01_state.gd 继承 Connectivity。接口 bind(mover)、reset_level()、can_stand(cell,world)、neighbor(cell,direction,view)、settle()，使用现有 phase 完成锁定。
- [x] 用真实 Movement 调用 press/release/tick，断言过门半途 door_open=true、cell仍为Plate，落定后 door_open=false、cell在另一端；assert exit 完成和 Reset。

## 2. 公共输入与资源表现装配

- [x] 新增 tests/gameplay/test_p01_runtime.gd，真实加载新场景、Input.parse_input_event 完成 keyboard/drag 两条路线，比较最终 gameplay snapshot；先记录新场景缺失失败。
- [x] 新增 game/player/grid_input.gd，复用 mover.press/release/shift、view.request_rotate_left/right、begin/preview/end_drag；沿用 phase/view.busy 仲裁、焦点丢失清键，R/F3 发信号给场景。
- [x] 新增 game/player/sprite_presentation.gd，读取生产 SpriteFrames；按 view-relative direction 和 mover.fraction 播放原生帧，不从动画驱动逻辑。
- [x] 新增 game/levels/mutsumi/p01_another_world.tscn/.gd 与 p01_board.gd。scene 装配状态/输入/最小 HUD；board 实例化已验收 Floor、Plate、Door、Exit，整数缩放、Y-sort、门横向镜像匹配通行轴。
- [x] 新增 p01_hints.gd 实现三个本关提示一次性生命周期及淡出；F3 默认关闭；complete 与 Reset 必须覆盖全部本地状态。
- [x] 修改 project.godot 的 run/main_scene 为新场景，保留其余设置。

## 3. 验证与交付

- [x] Headless 状态测试和真实窗口 runtime 测试，失败先定位并保留红灯证据；测试键盘/拖动两次通关、锁、过桥切换拒绝、Reset 中断、四视角和最小窗口可见性。
- [x] 使用 Windows computer-use 正常键盘/鼠标，F3 关闭完整通关 A/B，无传送/Inspector/开发快捷键；截图保存独立 evidence/p01_*。
- [x] 运行 tests/gameplay/run_validation.ps1 -EvidenceName p01_regression_01 -IncludeRegressions；验证原 66/54/172 与旧 P01、Sprite/Tileset/Mechanism。
- [x] 请求独立只读代码审查，处理真实问题，复验受影响测试；比较 git diff 确认所有保护资源未变。
- [x] 新增 docs/development-records/PLAYABLE_PUZZLE_PROTOTYPE_01_REPORT.md，列真实文件、控制/解法、自动/手动证据、玩家体验观察、未测首次用时、美术债务与最终状态。保留未提交变更并停止。
