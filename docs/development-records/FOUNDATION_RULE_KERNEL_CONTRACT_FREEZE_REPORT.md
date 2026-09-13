# FOUNDATION-2.0 — Puzzle Rule Kernel Contract Freeze Report

Design: **FROZEN DESIGN**；Implementation: **NOT IMPLEMENTED**；Review: **AWAITING USER REVIEW**。

**FOUNDATION_RULE_KERNEL_CONTRACT_FREEZE_PASS** — 仅文档冻结验收通过。

## 1. Branch / HEAD / 开始门禁

- 项目：`E:/godot/若叶睦/方块少女-若叶睦`。
- 分支：`feat/foundation-core`。
- 开始HEAD：`f04f00989be427049c78faf6a739253470412b3f`，正好等于FOUNDATION-1通过基线；开始working tree clean。
- 本轮只新增文档；不暂存、不commit/push/merge，不修改代码、场景、资产或project.godot。

## 2. 读取依据与接口审计

已读取架构Spec（含§15、§23、§33）、core contracts、0.1 reconciliation与FOUNDATION-1集成报告，并核对十个第一波production脚本及tests/foundation/integration的实际fixture/调用链。

| 实际发现 | 冻结处理 |
|---|---|
| PuzzleActionKind=0..7，局部组名LOCAL_GROUP_ROTATE | 不采用需求中的近义ROTATE_LOCAL_GROUP作为新枚举 |
| Spatial snapshot/anchor/cube返回ok/value/issues，Mapping四态 | Kernel先检查包装，只将成功裸值送Lighting |
| compose/reframe/quarter_turn真实存在 | roll/承载/Shift共用Math，不复制24表 |
| DATA严格19定义字段、六状态字段；StateKey拒未知字段 | 执行context/ticket/result独立，不改状态schema或key格式 |
| MechanismDefinition七字段，没有flag target/value、没有状态转换表 | 首版flags只读、mechanism_states单值域；动态flag/多状态机关明确延期，禁止任意字典扩展 |
| FaceTransition没有任意pivot/轨道控制点 | 首版同Cube明确三段运输profile；跨Cube任意通道先扩合同 |
| 第一波spatial_validation不做PlayerSafety或扫掠 | 新Safety唯一归2B，供Static Validator与2A共用；明确2A真实联调新增这项冻结接口依赖 |

执行合同新增版本标记 `foundation.execution.v1`，不改变已有 `foundation.contract.v1.1` API或Level数据版本。旧Spec保留原文，新Spec提供第二波执行细化，不把历史未实现说明改写为本轮实施事实。

## 3. 实际新增文档

游戏仓库仅新增下列6个Markdown：

1. [Kernel Contracts Spec](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md)
2. [2A Rule Kernel Plan](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/plans/2026-09-13-foundation-rule-kernel.md)
3. [2B Static Validator Plan](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/plans/2026-09-13-foundation-static-validator.md)
4. [2C Level Baker Plan](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/plans/2026-09-13-foundation-level-baker-prototype.md)
5. [2D Runtime Plan](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/plans/2026-09-13-foundation-runtime-prototype.md)
6. [本报告](E:/godot/若叶睦/方块少女-若叶睦/docs/development-records/FOUNDATION_RULE_KERNEL_CONTRACT_FREEZE_REPORT.md)

所有plan为未执行复选框；包含exact files、ownership、精确接口/依赖、TDD顺序及示例、正反测试、禁止路径、验收命令与独立PASS token。不存在已生成的Kernel/Safety/Baker/Runtime脚手架。

## 4. Kernel、Result与动作语义

唯一主入口：`Kernel.evaluate_action(level,state,action,context) -> PuzzleTransitionResult`。这是只读推导，同时回答合法性与下一态；不另写一套can/apply规则。`Kernel.complete_global(level,state,context)`完成已经接受的单事务，仍返回完整下一态。

Result八字段：`status, previous_state, next_state, action, changed, rejection_code, issues, global_kind`。APPLIED=0 / REJECTED=1 / ERROR=2；失败next_state=null。APPLIED只意味着计算成功，调用者在动作边界才一次替换整个状态。所有输入/输出集合深复制。

| 动作 | 冻结语义 |
|---|---|
| MOVE | face_axis已离散；当前Frame共面邻接；roll更新pose，不自动跨边换面 |
| SHIFT_WORLD | 无人为target字段；正式Mapping唯一后权限/安全与完整Frame姿态变换 |
| ROTATE_SURFACE / ROTATE_INNER | 目标写在action种类；允许delta/端态/安全，承载玩家跟随 |
| USE_FACE_TRANSITION | transition_id明确同世界路径与flags；三段运输，不回正 |
| TRIGGER_MECHANISM | 本Face USE授权，调用定义单效果；ENTER仅由进入事件内部授权 |
| LOCAL_GROUP_ROTATE | group_id/delta/mechanism_id，有向边与pivot；Shared delta=W×delta×W逆 |
| MOVE_CELESTIAL | 正式SET/NEXT/PREVIOUS/TOGGLE请求；唯一共享slot_id |

## 5. ShiftPermission、Busy与原子事务

Shift必须先真实collect→resolve，NONE正常拒绝、UNIQUE继续、AMBIGUOUS错误、ERROR保留底层。UNIQUE后source exit、target entry、Surface源SHADOW、目标安全按固定次序检查；Inner→Surface不要求SHADOW。SAME保持Shared姿态；OPPOSITE使用正式reframe，3→2/pose0=1、3→17/pose0=19。

busy context不进PuzzleState或StateKey；仅保存global_transition_state、ticket、已执行local_moves。Runtime另持id/generation。MOVING/TRANSITION拒绝一切新global，无queue/deferred；仅允许Kernel证明可交换且联合扫掠安全的MOVE。complete_global从最新player重建完整下一态，不覆盖启动旧位置；Reset取消旧ticket/callback。

MOVE+ENTER单全局效果作为一次原子复合动作，在本地roll落定完整提交，不能开延迟global ticket。纯global/USE可走延迟提交。首版busy拒绝进入ENTER或进入/离开goal，防止表现时间窗产生不同轨迹。

## 6. Rejection Codes / Derived / Goal

沿用Types.ValidationCode原名原值：NO_SHIFT_MAPPING1400、SHIFT_REQUIRES_SHADOW1403、SHIFT_EXIT_BLOCKED1404、SHIFT_ENTRY_BLOCKED1405、GLOBAL_TRANSITION_BUSY1500、UNAUTHORIZED_MECHANISM1503、MOVE_NOT_COMMUTATIVE1504、SLOT_STEP_UNAVAILABLE1301。AMBIGUOUS1401与1105均ERROR而非正常拒绝。

新拒绝枚举仅在2A rules/rule_types定义MOVE_BLOCKED2000、ROTATION_NOT_ALLOWED2001、ROTATION_STATE_INVALID2002、FACE_TRANSITION_NOT_AVAILABLE2003，不重复定义已有码，不放入旧ValidationIssue.code。Result.status与issue.severity职责不同。

DerivedStateResolver统一编排真实snapshot/mapping/light；Connectivity归2A、纯Safety归2B。缓存不进StateKey；busy许可缓存若仅按StateKey会漏context，明确禁止。Goal.is_goal返回`{ok,is_goal,issues}`，仅回答Face与required_flags，不触发状态变化。

## 7. 第二波所有权与实际依赖

| Work | 唯一写入范围 | 实施后最终token |
|---|---|---|
| 2A | foundation/rules、tests/foundation/rules、专属plan/report | FOUNDATION_RULE_KERNEL_PASS |
| 2B | foundation/validation、tests/foundation/validation、专属plan/report | FOUNDATION_STATIC_VALIDATOR_PASS |
| 2C | foundation/level、tests/foundation/level、tools/foundation/level、专属plan/report | FOUNDATION_LEVEL_BAKER_PROTOTYPE_PASS |
| 2D | foundation/runtime、tests/foundation/runtime、prototype/foundation/runtime、专属plan/report | FOUNDATION_RUNTIME_PROTOTYPE_PASS |

各计划列出精确文件及对应.uid归属；公共Spec与第一波Owner只读。依赖图见Spec §19：2B Safety→2A真实规则；2B完整Validator→2C真实Bake；2A→2D真实Runtime。2A/2B都基于FOUNDATION-1，但第一波没有PlayerSafety，因此不能省略这项新增真实链接依赖。2A/2C/2D可先用本tests目录内double并行，不复制邻Owner生产文件；最终PASS必须真实接口，不允许默认成功fallback。

## 8. Obsidian同步

根目录 `E:/obsdian/青澄的水泥房/方块娘/若叶睦`；按用户本轮指定目录新增6页，另向既有MOC追加导航，旧正文保持：

- [核心机制/PuzzleRuleKernel与原子状态变换.md](E:/obsdian/青澄的水泥房/方块娘/若叶睦/核心机制/PuzzleRuleKernel与原子状态变换.md)
- [核心机制/ShiftPermission与跨世界事务.md](E:/obsdian/青澄的水泥房/方块娘/若叶睦/核心机制/ShiftPermission与跨世界事务.md)
- [核心机制/全局状态迁移与Busy规则.md](E:/obsdian/青澄的水泥房/方块娘/若叶睦/核心机制/全局状态迁移与Busy规则.md)
- [测试与验证/Action拒绝与Level错误的区别.md](E:/obsdian/青澄的水泥房/方块娘/若叶睦/测试与验证/Action拒绝与Level错误的区别.md)
- [可复用方法论/Runtime与Solver共享规则核心.md](E:/obsdian/青澄的水泥房/方块娘/若叶睦/可复用方法论/Runtime与Solver共享规则核心.md)
- [开发日志/2026-09-13-FOUNDATION-2.0规则核心合同冻结.md](E:/obsdian/青澄的水泥房/方块娘/若叶睦/开发日志/2026-09-13-FOUNDATION-2.0规则核心合同冻结.md)
- 追加 `00-索引/00-MOC-核心玩法架构.md`；旧3337字节前缀逐字节保持，原SHA-256=`566909C463A18FA91818389067148A01771AB3AC94446C40763BD1CEA0127527`，仅追加797字节。

所有新页包含[[双链]]、标签、FROZEN DESIGN与NOT IMPLEMENTED。Obsidian不在游戏Git仓库，需独立保存；本轮未设置同步自动化。

## 9. 独立复审与修订

通过requesting-code-review技能派发一次只读合同审查，并复审修订。没有派发第二波开发Work。

1. 原同Cube中心纯90°轨迹会在中间穿透支撑，改为半格径向距离2→4→旋转→2的三段路径，明确运动安全正例/反例。
2. 两条串行路径安全不证明并发安全；增加共享validate_concurrent_motion，检查两进度组合体积。同层组外玩家roll不随Group旋转；另世界旋转退化为普通roll。
3. MOVE+ENTER若player先提交、Slot延迟会产生半态/重复MOVE，改为一次完整复合提交，不开ticket。
4. 相反输入分别按固定轴序打平局不一定互反；改为规范半平面代表量化后反向还原，保持原规则确定性。
5. RuleRecords只创建值记录，不反向调用Kernel；真实ticket授权在Kernel消费时核对，避免preload环。

这些是文档审查发现与设计修订，尚未通过运行测试验证。对应测试要求已写入2A/2B/2D计划。

## 10. 十四项自检与验证范围

| 自检项 | 结论 / 依据 |
|---|---|
| 1 Runtime与未来Solver同一个Kernel | 是，Spec §2/14/18 |
| 2 Action全部语义化 | 是，沿用原八种union；键鼠只在adapter |
| 3 UI/Input不进PuzzleState | 是，原六字段不变 |
| 4 Derived不进StateKey | 是，cache/context单独且需完整身份 |
| 5 Shift不复制Mapping/Lighting | 是，真实接口编排及错误短路 |
| 6 SAME/OPPOSITE遵循FOUNDATION-1 | 是，保持/完整reframe及两golden |
| 7 原子无半提交 | 是，失败null，完整下一态；复合ENTER政策明确 |
| 8 Rejection与Error分开 | 是，三态结果及独立拒绝域 |
| 9 Busy无queue/deferred | 是，local_moves是已执行历史 |
| 10 FaceTransition与Shift分开 | 是，显式同层通道与跨层几何映射 |
| 11 Group与World Rotate分开 | 是，授权/坐标/pivot/承载规则不同 |
| 12 唯一天体逻辑状态 | 是，单一slot_id；动画不入图 |
| 13 Solver未实现 | 是，未新增任何代码 |
| 14 四计划所有权不重叠 | 文档清单交叉检查，无共同可写文件 |

本轮验证仅文档与文件边界。Godot、旧P-01回归、新Kernel/Safety/Baker/Runtime测试均**未运行**；FOUNDATION-1的81,014项及Runtime通过为已有基线，不挪作本轮证明。

## 11. Git diff、合同状态与停止点

本轮实际文档/文件检查结果：

- DOCUMENT_BOUNDARY_CHECK_PASS：仅6个新Markdown，既有tracked差异0、暂存差异0，HEAD不变。
- PLAN_MANIFEST_CHECK_PASS：46个拟新增精确文件路径，无跨Work所有权重叠；57个步骤均未执行。对应.gd.uid由相同Owner创建，不另分给其它Work。
- SOURCE_INTERFACE_AUDIT_PASS：18个既有canonical枚举数值、25个真实static API名称核对一致；第二波production/tests目录均未创建。
- OBSIDIAN_CHECK_PASS：6个新笔记、20条双链全部唯一解析；既有MOC前3337字节SHA-256不变，仅追加导航。
- 六个新Markdown的代码围栏配对、文件链接、末尾空白、占位词检查通过；git diff --check通过。独立复审确认全部重要问题收敛，无新的实质合同冲突。
- 本轮终态HEAD仍为`f04f00989be427049c78faf6a739253470412b3f`。git diff --stat为空，因为6个新增文档均未跟踪、未暂存；这不表示没有交付文件。Obsidian另有6新增+1追加，不计入游戏Git。

CONTRACT_MISMATCH：在本Spec明确的首版profile内未发现既有ABI冲突。动态Flag、多状态机制、任意跨Cube轨道不属于已支持能力；如第二波需要这些能力，应先中央扩展合同，不得在Work内猜测实现。

第二波可启动性：本轮文档review后可以按四计划授权并行；真实PASS按依赖gate顺序取得。当前没有自动启动任何Work。对更宽目标架构的延期能力不宣称已解决；不修改P-01、不开始Solver/Editor/Blender/P-02。
