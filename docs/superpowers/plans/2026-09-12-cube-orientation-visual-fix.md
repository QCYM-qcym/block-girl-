# Cube Roll Orientation Visual Fix Plan

**Goal:** 修复每格回正，真实 2D 单面滚动在独立 fixture 和 P01 均可观察。
**Architecture:** 复用已验证 cube_visual 的面投影，新增薄 CubeVisualPresenter 和调试描述；Movement/CubeOrientation 是唯一状态源，不复制逻辑或迁移 3D。
**Spec:** docs/development-records/CUBE_ORIENTATION_VISUAL_AUDIT.md；用户附件 0669bc22-ac71-4ba2-b5a5-9b4251755628。

约束：既有未提交 P01 成果已备份；只在 feat/playable-puzzle-p01，不 commit/push，不改地图、TileSet 或机关。正式角色 PNG 不重做。

- [x] 运行真实旧 Presenter 复现：两世界 W×4，6/6 中间逻辑姿态仍选相同 idle，记录 JSON/截图并生成 audit。
- [x] 新增 tests/gameplay/test_cube_visual.gd，在缺失新 Presenter 时先失败；逐步覆盖24态、四View、四步循环、反向抵消、hold衔接、Shift保姿态、屏幕X可见性和5秒不回正。
- [x] prototype/perspective/cube_visual.gd 仅提取可覆盖的绘制标记函数，既有默认脸不变；新增 game/player/cube_visual_presenter.gd 复用投影/遮挡，固定local+Z绘X，动态导出起始/目标/当前渲染矩阵与debug_text。
- [x] 新增 tests/gameplay/cube_orientation_visual_test.tscn/.gd，简单地面，复用GridInput/Movement/Graph/View，按键WASD/QE/拖动/Space/F3/R，大幅单面标记和状态标签。
- [x] P01 board 只替换Player Presentation引用；P01 F3补充ID、世界方向、可见性、roll起止姿态；正常界面标明临时单面测试方块。
- [x] 真图形运行新套件，系统键鼠人工A-D；实际保持W验证E通过真实Input事件单次press连续动作，说明系统工具只支持tap。
- [x] 运行P01现有完整167项，原Perspective运行/bugfix与资产回归；比较本轮baseline保护地图/旧Sprite/Tileset/机关和谜题逻辑。
- [x] 独立只读审查；生成24态资源规格与 CUBE_ROLL_ORIENTATION_VISUAL_REPORT；正式Sprite=REWORK_REQUIRED，停止等待用户试玩。

