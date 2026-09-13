# CUBE_ORIENTATION_VISUAL_AUDIT

2026-09-12，feat/playable-puzzle-p01。先调查与真实复现，未改生产贴图。结论：**SPRITE_RESOURCE_INSUFFICIENT_FOR_TRUE_CUBE_ORIENTATION**。

## 数据流与十项回答

1. Input：game/player/grid_input.gd 调用既有 Movement.press；GridMovement 每格落定调用 orientation.roll(direction)，真实更新。复现的 NORTH 四步 FACE_ID 世界方向依次 SOUTH(+Z) → TOP(+Y) → NORTH(-Z) → BOTTOM(-Y) → SOUTH(+Z)。
2. Movement 整体绑定给 sprite_presentation.gd，因此 Orientation 对象可访问；但没有传入任何选图决策。
3. 旧 Presentation 不读 orientation；只遍历 view.world_direction 与 movement.direction，选择四个固定 roll 名称。
4. roll_left/right/forward/backward 每种只有固定 6 帧，与起始姿态无关。
5. roll 完成由逻辑 phase 回 idle；refresh 无条件选择 subtle_idle。不是 animation_finished 信号导致回正，但结果相同。
6. idle 仅一个默认正面；subtle_idle 是同一姿态的眨眼，没有不同物理面版本。
7. Mutsumi/Mortis 各一套同构的固定 idle。换世界替换 SpriteFrames，因此仍选固定正面。
8. Perspective 只影响方向对应的 roll 名称，idle 不按相机解释各物理面。
9. PNG 与 manifest 一致：每段 roll 首尾都画回朝镜头的同一张脸，缺少固定 FACE_ID 的持久身份。不能说四个 roll 就是 24 态支持。
10. 两张 144×264 sheet 是 6 列 × 11 行，包含动作/切换/阴影等，不包含 24 姿态和每态出发的滚动。当前素材不足。

## 真实复现

tests/gameplay/audit_cube_orientation_visual.gd 实例化实际 P01 sprite_presentation、Movement、InputAdapter，Windows / Forward+ / D3D12 实际运行，两世界各 W×4。截图时角色固定屏幕位置以隔离位移，游戏逻辑仍逐格移动。记录每次 cell、orientation、face direction、当前 animation/frame、选中纹理像素哈希。

evidence/cube_visual_audit_02/audit.json：两世界中间三步的逻辑方向改变，但 6/6 选中 idle 像素哈希与初始完全相同。预期失败输出：`FAIL: production Sprite presenter resets visible face after every roll`。10 张 GPU 截图保留，不能以旧 P01 gameplay PASS 覆盖此失败。首轮 cube_visual_audit 未等待输入队列分发，四次请求只结算两步；其证据保留但不用于四步结论，02 已修正并核对完整方向序列。

## 最小修复决策

采用用户允许的 A+B：复用已经验证的 prototype/perspective/cube_visual.gd 的 2D 面投影与遮挡，建立 CubeVisualPresenter，在固定 local +Z 面绘制清楚的 X。P01 切换到这个明确标注的临时技术表现，使实际试玩也遵守持续朝向；旧 Sprite 脚本和生产 PNG 原样留存作审计参考。

Presenter 只读取 Movement 的 CubeOrientation、direction/fraction、world 与 Perspective，不维护另一份可变 visual_orientation。视觉基矩阵是现有起始姿态乘当前滚动四分之一圈，落定后读取已提交姿态。World 只换两种测试色板，Perspective 只改观察变换。固定 FACE_ID=physical_face_front/local+Z，背面与底面不可见时不画 X。

不做正式 Sprite 生产或 3D 迁移，不改 P01 地图/谜题规则。最终应区分“临时表现修复通过”与“正式美术待重制”，使用 CUBE_ROLL_LOGIC_PASS_SPRITE_REWORK_REQUIRED。
