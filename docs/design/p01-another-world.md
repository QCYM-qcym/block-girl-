# P-01《另一个世界》

本轮在 feat/playable-puzzle-p01 工作区实施，不 commit/push。目标是首次玩家约 2–5 分钟理解 Move · Shift · Rotate · Solve；熟悉解法后允许几十秒完成，不靠等待拖长。实际新玩家用时尚待用户试玩验证。

## 路线与教学

逻辑网格 (x,z)，全部同高。A：Surface 出生 (0,5)，向北唯一道路到 (0,2)。B：只有 Inner 有 (0,1) 桥；两世界共有 (0,0) 到 (3,0) 中间平台。C：(3,0) 向东连接最终平台入口 (9,0)，真实间隔保留；仅 Inner + EAST 启用。D：两世界共有 (9,0)..(13,0)，Surface 的 (11,0) 是 momentary Plate，门位于 (11.5,0) 格间边界，(13,0) 是自动完成 Exit。Inner 的同一门边界保持封闭，避免绕过教学。

连接沿用技术原型的分平台 2D 重构：EAST 时最终平台显示偏移 (-5,0)，两 Anchor 中点重合，中心相距正常一格。不是单一刚性 3D 相机的投影证明。其它 View 都无连接；节点不因旋转消失。第一断路不存在任何跨越 edge，所以无法用旋转代替世界切换。

正常界面默认隐藏 F3。初始仅 WASD；首次移动淡出。到第一断路仅 Space；首次成功 Shift 后不重复。到中间平台才 Q / E + 鼠标左右拖动；首次在此成功 Rotate 后淡出。Reset 恢复三个提示生命周期。最终 Inner 上显示锁定机关轮廓与明确 Surface/Inner 世界标签，让玩家自行尝试 Space。

## 状态顺序

同一 Movement 保存 GridPosition、24 态 CubeOrientation、World。Shift 保留姿态和 View，目标不存在地面则拒绝并短暂显示原因。移动先检查 graph edge，完整滚动落定后提交 cell + orientation，再发出 committed；关卡同步 Plate/Door/Exit 后，Movement 才尝试下一次 held input。Plate 只在 Surface 当前格占用时压下；从 Plate 穿越门边的滚动期间仍保持 OPEN，落定才 CLOSED。离开 Plate 向其它方向同样释放；无 latch、无动画驱动逻辑。

完成时锁住 Move/Shift/Rotate，轻淡化并显示「P-01《另一个世界》 / 关卡完成 / R 再次游玩」。Reset 可取消任意过渡并清除 held input、门、Plate、Exit、完成与提示。逐状态搜索检查可达节点均能继续抵达出口；不能用 Reset 掩盖关卡死路。

## 复用与边界

复用 prototype/perspective 的 Movement、Orientation、PerspectiveController、Anchor、Link、Connectivity；关卡图继承 Connectivity，仅覆盖地图/世界占格/门边策略。添加小型共享 GridInput 与 SpritePresentation 适配，未来关卡可直接用。复用 production 的角色 SpriteFrames、地板 atlas、Plate/Door/Exit 场景；不改生产资源、不改 tests/visual 或 Perspective Test。旧 prototype/puzzle_01.tscn 归类为 early gameplay draft / regression fixture，完整保留。主场景改为 game/levels/mutsumi/p01_another_world.tscn。

正式角色现已使用 v2_orientation 的 Mutsumi / Mortis atlas：24 态持久物理姿态、单物理面五官和真实翻滚均已通过上一阶段验收，不再使用旧的落格重置脸表现。门源图只有一个投影通行轴，另一屏幕轴采用水平镜像，保持格间位置与深度排序；光照镜像属于已有资产方向不足的表现限制。仅复用 Floor，不增加新环境图。无 Moving Platform、Rotator、六面谜题、其它角色、存档/菜单/章节框架。

## Polish Foundation

game/polish 提供本关局部音频、世界与连接反馈、教程键位图和完成演出。12 个 TEMP SFX 覆盖 Roll、Land、双向 Shift、Rotate、Link On/Off、Plate、Door Open/Close、Exit Ready、Complete；两个 TEMP 环境循环在世界间淡化。Master / SFX / Ambience 分层，M 静音。所有声音观察状态，失败或关闭不影响门和连接。

Shift 局部像素溶解约 0.4 秒：保留原有 0.25 秒状态提交与输入锁，提交后 0.15 秒重现尾段允许恢复输入。旋转保持原有 Q/E 与鼠标节奏，添加轻微边缘和连接端点反馈。F4 可关闭主要局部 FX 验证解耦。

三个原情境提示改为小型像素键帽与鼠标水平拖动图标。成功使用后淡出，R 恢复。Exit 完成后原逻辑立即锁定玩家，出口激活、环境音降低，短暂停顿后压暗并淡入 P-01 /《另一个世界》/ 完成 / R，演出约 1.8 秒。地图、机关规则、通关路线完全不变。

TUTORIAL_FIRST_USER_VALIDATION_REQUIRED：当前验收者知道解法；提示可见和路线可解不代表首次玩家一定理解，2–5 分钟首次体验仍需用户试玩。
