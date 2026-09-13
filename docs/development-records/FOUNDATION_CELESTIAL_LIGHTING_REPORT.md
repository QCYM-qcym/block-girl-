# FOUNDATION-1C — CELESTIAL & LOGICAL LIGHTING

**FOUNDATION_CELESTIAL_LIGHTING_PASS**

2026-09-13；Worktree `E:/godot/worktrees/block-girl-foundation-celestial`；分支 `feat/foundation-celestial-lighting`；Git 基线 `4643062e83a962000d14f0e1dbfbece6e310d4ed`。

本轮重读正式 FOUNDATION Spec、冻结公共合同和 Work C 计划，在已有实现上补充 19 项验收，完整 **132 项检查通过，退出码 0，stderr 为空**。生产脚本与本轮开始时一致。未修改主工作区、公共合同或其它 Work 模块；未 commit/push/merge。

## 文件与接口

| 文件 | 交付内容 |
|---|---|
| `foundation/celestial/celestial_rules.gd` | `resolve_slot_request(definition,current_slot_id,operation,target_slot_id,alternate_slot_id) -> Dictionary` |
| `foundation/celestial/logical_lighting.gd` | `query(anchor,slot,cubes: Array[Dictionary]) -> Dictionary`，承担 LogicalLightSolver 职责 |
| `tests/foundation/celestial/test_celestial.gd` | 独立 headless 单元测试、共享 Slot/光照组合测试和真实依赖集成 |
| 上述三个脚本的 `.uid` | Godot 脚本 UID |
| `docs/superpowers/plans/2026-09-13-foundation-celestial-lighting.md` | 本 Work 实施进度 |
| 本报告 | 模型、算法、验证、状态迁移合同与边界 |

只使用公共合同中的 Dictionary 值记录与 DATA 枚举，不另建 CelestialState/CelestialSlot 类或 LogicalLightSolver 公共别名。

## Slot 模型

- 每关提供 `CelestialDefinition={slots,slot_order,wrap,initial_slot_id,edges}`。
- `CelestialSlot={slot_id:StringName,position2:Vector3i}`，位置是 Shared Space 半格整数；数量和 ID 不固定。
- 唯一已提交 `CelestialState={slot_id:StringName}`。Surface Sun 与 Inner Moon 消费同一记录，名称和动画只属于表现层。
- SET 指定目标；NEXT/PREVIOUS 按关卡顺序及 wrap 行走；TOGGLE 使用两个不同合法端点。所有改变必须存在有向 edge。
- 设置当前 Slot 成功且 `changed=false`。非法请求返回确定 issues、`changed=false`、空 `next_slot_id`，不修改输入。
- 解析结果是下一稳定 Slot 的候选，不自行提交状态，也不保存未提交请求。

## 遮挡算法与 FaceNormal

只在 `FaceAnchor.position2` 采一个点；没有面面积比例或 PARTIAL。`anchor.frame.normal` 是已转换至 Shared Space 的有符号单位轴，与 `u/v` 构成右手正交基，`u×v=normal`。

本地方向约定：FRONT=+Z、BACK=-Z、LEFT=-X、RIGHT=+X、TOP=+Y、BOTTOM=-Y。逻辑 FRONT 是 +Z，不能使用 Godot 的 FORWARD=-Z 替代。旋转后的法线由 SPATIAL 解析，不在光照模块复制空间模型。

入射条件为 `normal · (source-anchor) > 0`；背向或切向为 SHADOW。逻辑射线从 Celestial 源点 `t=0` 指向 FaceAnchor `t=1`，只取开区间 `(0,1)`。

同世界、`occludes_light=true` 的 Cube 使用 `center2±(1,1,1)` 闭 AABB。逐轴以有理区间求交，平行轴单独判断；其它 Cube 擦边算阻挡，接收 Cube 仅在终点接触不遮挡。最近命中从光源起算，同精确 t 按 Cube ID 排序，输入顺序不影响结果。

光源与 Anchor 重合、位于同世界遮挡 Cube 闭包内或边界时返回 LIGHT_SOURCE_INVALID。跨世界 Cube 不遮挡；透明 Cube 不遮挡。坐标按分量提升到 int64，每个有理交叉乘法先检查溢出，超范围返回 ARITHMETIC_OVERFLOW，不使用浮点容差、PhysicsServer、视觉 RayCast 或渲染阴影。

成功结果只有 LIT/SHADOW，原因是 FRONT_CLEAR / BACK_OR_TANGENT / OCCLUDED。失败时 `ok=false,light_state=null,reason=INVALID`，不是第三种光照状态。

## 状态迁移合同与执行边界

遵循正式 Spec §15/33、公共合同 §6/7/9，以及本 Work 计划的明确职责分配：

| 阶段 | 唯一已提交 Slot | 合同要求 |
|---|---|---|
| Stable / IDLE | A | 纯解析请求，合法且 changed=true 时产生 B 候选；无变化不启动事务 |
| MOVING | 仍为 A | 已接受唯一事务的目标为 B；第二次全局 mutation 返回 GLOBAL_TRANSITION_BUSY，立即丢弃，不 queue、不 deferred-trigger、不补触发 |
| Stable / IDLE | B | 在合法离散边界提交 B，按最新稳定快照重算光照；不发布中间 Slot |

全局锁同样适用于 TRANSITION。Reset 按公共合同取消会话事务并使旧回调失效。许可普通 MOVE 的安全/交换性证明不在本模块完成。

**本模块提供稳定请求/结果合同，不实现 Runtime/Scheduler/Kernel 的 busy 检查、提交时机、回调或动画。** 公共 §9 的两个接口没有会话状态参数；不能向 `resolve_slot_request` 私加 MOVING 参数或伪造调度器测试，然后宣称并发锁通过。上述规则是调用层必须履行的正式合同，忙时执行验收留给其 Owner。

## 测试覆盖

| 要求 | 证据 |
|---|---|
| SET/NEXT/PREVIOUS/TOGGLE | `_test_slots`：四操作、合法无变化、无效目标/当前值/端点 |
| 顺序/循环边界 | 无 wrap 越界、有 wrap 首尾、有向 edge 限制、关卡顺序变化 |
| Surface/Inner 共用 CelestialState | `_test_stable_slot_lighting`：单记录 A→B 同时更新两世界查询，查询不修改记录 |
| 朝向无遮挡、背向/切向 | 六轴正负方向黄金用例，FRONT_CLEAR / BACK_OR_TANGENT |
| 正前 Cube 遮挡、移开恢复、射线外不误判 | 稳定 blocker 从 `(0,4,0)` 到 `(4,4,0)`，SHADOW→LIT；旧快照仍可重现 |
| FaceAnchor 唯一采样、无 PARTIAL | 擦边黄金点 `(1,3,0)` 决定 Anchor 的 SHADOW，不按面面积计算；输出仅整数 0/1 |
| 同状态确定性 | 重复旧/新稳定快照，数组顺序变化、最近命中和精确平局 |
| Slot 改变后更新 | A→B→A 的 LIT→SHADOW→LIT；解析请求时原 committed A 不变 |
| 数学边界 | 开端点、闭包源点错误、平行轴、跨世界、透明 Cube、int32 极限与 int64 溢出 |
| 真实依赖 | DATA shape → records.initial_state → SPATIAL.snapshot/validate_snapshot → Lighting；Cube/World Z+、固定 Slot、黄金坐标与输入不变 |
| 错误边界 | 缺实现/依赖明确非零退出；无效字段/非字符串 key/引用/重复 ID 的确定错误，无脚本错误放行 |

最终分组：Slot 47、独立 Lighting 47、共享稳定状态与光照 19、真实依赖集成 19，总计 132。

原实现 TDD 的缺实现 RED、形状累积 RED、字段名缺陷 RED/GREEN 均已保存于上一轮证据目录 `E:/godot/若叶睦/foundation-0-evidence/celestial/`。本轮新增 19 项是对已有行为的补充验收，未重写生产算法；旧证据只读保留。独立审查确认新增用例及状态迁移职责解释无实质问题。

## 本轮运行证据

新的证据目录在主工作区之外：`E:/godot/foundation-evidence/celestial-1c/`。

- `final.stdout.log`：Godot `4.7.2.stable.steam.ed1daf0bf`；132 checks；failures=[]；FOUNDATION_CELESTIAL_LIGHTING_PASS。
- `final.stderr.log`：空；进程退出码 0。
- `verified-sources.json`：实际测试的 Work C 与真实 DATA/MATH/SPATIAL 副本 SHA-256；每份副本均核对与 Owner 原始文件一致。
- `before.json`：本轮开始时生产脚本、测试及公共 Spec 指纹。
- `work-c.diff`：相对 HEAD 的完整 Git patch，包含未跟踪脚本/测试/UID/报告，不修改 index。
- `work-c.stat.txt`：完整 patch 的文件统计。

四模块原文件仅作为只读来源；外部 `integration-project` 装入原样副本，不使用 double，不修补任何其它模块，也不需要先 merge。此结果仅对应 manifest 中的实际依赖版本，不代替其它 Work 的独立 PASS。

```powershell
$celestialEvidence='E:/godot/foundation-evidence/celestial-1c'
$celestialRun=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/foundation-evidence/celestial-1c/integration-project" --script res://tests/foundation/celestial/test_celestial.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$celestialEvidence/final.stdout.log" -RedirectStandardError "$celestialEvidence/final.stderr.log"
if ($celestialRun.ExitCode -ne 0 -or (Get-Content "$celestialEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Celestial failed' }
```

默认入口要求全部单元测试与真实集成通过才输出模块 PASS。局部参数 `--slots-only`、`--lighting-only`、`--unit-only` 不输出模块 PASS。

## CONTRACT_MISMATCH 与停止状态

**CONTRACT_MISMATCH：无。** CelestialState/Slot 及 LogicalLightSolver 职责均沿用冻结记录/接口；MOVING 串行要求作为已有调用合同说明，不擅自扩展本模块接口。

未实现 Shader、Sun/Moon 美术、Blender、PointLight3D、Shared Space Solver、Shift、BFS、Editor、P-02；未声明全构型 Lighting、忙时并发执行或可玩 FOUNDATION 通过。

保留本 Work 分支和未提交改动；公共合同/主工作区/其它 Work 模块保持只读。完成后停止，不自动 commit/push/merge。
