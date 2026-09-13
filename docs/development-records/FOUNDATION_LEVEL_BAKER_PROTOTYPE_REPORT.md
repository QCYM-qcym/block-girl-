# FOUNDATION-2C — Level Baker Prototype

FOUNDATION_LEVEL_BAKER_PASS

FOUNDATION_LEVEL_BAKER_PROTOTYPE_PASS

CONTRACT_MISMATCH: NONE

工作区：E:/godot/worktrees/block-girl-foundation-baker

分支：feat/foundation-level-baker

基线 HEAD：b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5

依据：正式 FOUNDATION Spec、FOUNDATION-0 core §3.1/6，以及第二波冻结合同 §16–19；执行本 Work 的已授权 implementation plan。公共合同没有修改。

## Authoring schema

最小场景为 tools/foundation/level/minimal_authoring.tscn。这是明确的 2C 私有作者输入格式，不增加 LevelDefinition 字段。

| 作者输入 | 读取规则 |
|---|---|
| 根 Node3D 的 foundation_authoring | 保存除 content_hash 外的 18 字段模板；cubes、faces、celestial.slots 必须为空，由明确节点生成。 |
| 根的直接子容器 Cubes / Slots | 必须使用 identity transform，禁止 top_level。 |
| Cubes 的直接 Node3D 子节点 | foundation_cube 保存稳定 cube_id、layer、group_id、occludes_light、tags；位置和 Basis 转成 center2 与离散 orientation。 |
| foundation_faces | 六面均需明确配置 face、walkable、shift_exit_blocked、shift_entry_blocked、mechanism_ids；调用正式 Geometry.make_face_nodes 生成身份，再应用作者属性。 |
| Slots 的直接 Node3D 子节点 | slot_id: StringName 加 Shared Space 中的作者位置，转换为整数 position2。 |
| World / Group / Spawn / Exit / Mechanism | 使用模板中的正式数据字段；不从显示节点、名字或相邻关系推断规则。 |
| Camera 等视觉节点 | 容器外节点不参与定义；试图把 Node 放入规则元数据则拒绝。 |

根的刚体平移/旋转只表示场景放置。identity 容器下局部坐标等价于根逆变换后的坐标，脱离 SceneTree 读取也一致。Cube 坐标保持 World/Group 未旋转绑定坐标，不重复应用 initial_orientation。

位置采用 L=1、q=2p、最近整数且恰半值远离零的正式导入规则；误差须 ≤ 1e-6，Cube center2 每分量须偶数。先检查 int32 范围，再构造 Vector3i。Cube Basis 三列使用正式 Math.from_columns 转成 cube24 编号；偏离离散基、缩放、剪切、镜像和非有限值拒绝。FaceAnchor 不进入作者输入或输出缓存，由正式 Spatial 在消费定义时推导。

## 极小 fixture 与 LevelDefinition 输出

| 内容 | 实际值 |
|---|---|
| Surface | floor、exit；center2 分别为 (0,0,0)、(2,0,0)。 |
| Inner | inner_floor、group_cube；center2 分别为 (0,0,0)、(10,0,0)。 |
| Walkable | floor/TOP、exit/TOP、inner_floor/TOP；四个 Cube 共 24 条正式 Face 配置。 |
| Spawn / Exit | Surface floor/TOP，orientation=0；目标 exit/TOP。 |
| Celestial | a=(0,10,0)、b=(0,12,0)，slot_order=[a,b]，wrap=false，双向明确边。 |
| RotatableGroup | Inner 的 island，包含 group_cube，pivot2=(10,0,0)，合法状态 [0,22]，两条往返边。 |
| 最小机制 | floor/TOP 的 USE toggle_sky，MOVE_CELESTIAL / TOGGLE_BETWEEN，单一 default 状态。 |

输出仍为 schema_version=1 的 19 字段 LevelDefinition：schema_version、contract_version、orientation_version、rule_version、level_id、content_hash、cell_size、worlds、cubes、faces、groups、celestial、mechanisms、face_transitions、shift_compatibilities、spawn、goal、flag_definitions、build_info。没有 Node、Basis、浮点位置、手写 Anchor、运行时状态或视觉节点。纯 Reader/Baker 结果拥有深拷贝数据，不修改作者模板和 options。

实际产物：`.godot/foundation-2c/level_baker_final/project/artifacts/minimal.level.json`。

实际最小场景 content_hash：

```text
9fd3905c2c35847e0cadbcaad9df95ef909017ea2f442d63e9c5e99e27ddc3e6
```

## Canonical 与 determinism

Codec 输出 UTF-8 JSON，无 BOM、末尾 LF 或结构空白。字段按 Unicode 码点排序；ID 为文本、枚举为符号、坐标为三整数数组。记录按正式身份排序，引用集合排序；slot_order、rotation_steps、Orientation/intent/delta 等有语义数组保留声明顺序。重复项拒绝，不排序去重。

content_hash 是排除 content_hash/build_info 后规范规则 JSON 的 SHA-256，不是完整产物文件摘要。独立规则 golden 为 1,892 字节，SHA-256 为 6983ed5f5e812c1bd10d0604aefb1b9661f0f93264536499b319d4bfeacbfc2b。编码器独立于正式 StateKey 的私有算法；StateKey 只在消费验证中调用公共入口。

解码器精确解析整数，拒绝小数/指数表示、int64 越界、重复字段、未知字段、非法 Unicode、错误版本及伪造 hash，恢复 StringName/Vector3i/int。同场景重复 Bake、重新加载、改显示名、重排兄弟节点均验证输出相同；记录集合重排不变，逻辑变化改变 hash，build_info 变化不改变规则身份。

## Validator 边界

公共 bake(authoring, options) 始终绑定真实 2B StaticValidator。流程为 DATA shape → 真实 hash → canonical encode/decode → StaticValidator。内部占位 hash 只用于前置 shape 检查，不能作为成功产物。

options 仅接受两个正整数预算 max_configurations / max_checks，没有 skip_validation 或成功替身。只有 VALID 且 issues=[] 返回完整 level；INVALID、INCOMPLETE、非法 Validator 返回值或任意前置失败均返回 level=null。已进入真实验证时保留 validation 和原 issues/details；之前的失败 validation=null。

缺失身份引用由正式 DATA 前置拒绝；不可行走目标、位于 Cube 内的 Slot 源、超出最小机制 profile、预算不足进一步由真实 StaticValidator 拒绝。没有复制 Validator、安全查询、Spatial 或 Orientation 实现。

2B 尚未合并时，验收 wrapper 把真正 2B 的 safety_queries、static_validator、validation_types 及 UID 只读复制到本 Work 的 ignored 临时 Godot 项目。source_manifest.json 记录源路径、逐文件 SHA-256、源/副本相等和 2B HEAD。HEAD 是工作树基线；实际未提交实现以逐文件 hash 为准。缺少真实依赖时 wrapper 明确失败，不能报完整 PASS。

最终真实 Validator：status=VALID (0)、issues=[]、configurations_checked=4、checks_performed=156。记录的 2B HEAD 为 b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5，source_copy_equal=true。

tests/foundation/level/validator_double.gd 只提供 INVALID / INCOMPLETE / malformed 失败结果，通过私有管线测试传播；不提供 VALID，不进入公共 bake 的成功路径。

## CLI 与文件副作用

CLI 只接受显式 --scene=res://... 和 --output=res://... 或 E 盘绝对路径。纯 Baker 不访问文件系统；CLI 负责加载/释放场景，完整成功后创建输出父目录，写入并核对临时 UTF-8 字节。

正式发布使用 Windows System.IO.File.Move 的不可替换语义，即便目标在预检查后出现也失败。通过隐藏 PowerShell EncodedCommand 调用，路径以 UTF-8/base64 传递，避免路径参与命令解释；失败清理自身临时文件。此 CLI 的发布适配限定 Windows/E 盘，与本次工作环境和冻结输出约束一致。

已有输出不覆盖；坏参数、缺失场景、非法输出路径、真实 Validator 拒绝均 exit=1，不创建最终产物。发布 helper 还直接验证目标已存在时，目标与候选文件字节都保留。

## TDD 与最终验收

RED 证据在 .godot/foundation-2c/：codec-red、reader-red、baker-red 记录缺失实现；reader-id-red 与 reader-newline-red 记录正式工厂前置 ID 检查回归。CLI 的 task4-red-missing-cli / task4_red_unicode_source / task4_red_publication_race 目录记录缺失 CLI、警告扫描和发布 helper 回归。审查发现的 ID 前置条件、top_level 绕过、发布覆盖竞态、Validator 拒绝 fixture 问题均修复并复验。

执行目录为本 Work。最终验收命令：

```powershell
& './tests/foundation/level/run_validation.ps1' -EvidenceName level_baker_final
& './tests/foundation/run_validation.ps1' -EvidenceName level_baker_foundation_regression_final
```

wrapper 为未合并的真实 2B 构造隔离依赖项目；直接在缺少 foundation/validation 的本工作树调用 Baker 不能替代这个集成入口。项目副本、日志、产物均位于本 Work 的 ignored .godot 下，不写入其它 Work。

| 最终阶段 | 结果 |
|---|---|
| Codec 套件 | 75 checks，exit=0，PASS。 |
| Reader / Baker 套件 | 65 checks，exit=0，真实 Validator VALID。 |
| 发布 helper | exit=0，PASS，拒绝替换目标且保留候选文件。 |
| CLI 实际文件生成 | exit=0，FOUNDATION_LEVEL_BAKE_PASS。 |
| 实际产物 decode → Validator → StateKey | 70 checks（原 65 加 5 项文件验证），exit=0。 |
| 五项 CLI 负向场景 | 已有输出、缺失场景、相对输出、未知参数、真实 Validator 拒绝；全部按预期 exit=1。 |
| 第一波六套回归 | Orientation 77,965；DATA 733；StateKey 546；Spatial 1,533；Celestial 132；Integration 105，全部 PASS。 |

新套件证据：`.godot/foundation-2c/level_baker_final/` 下 results.json、source_manifest.json 及各阶段 stdout/stderr。成功阶段 stderr 为空；负向阶段只出现预期 FOUNDATION_LEVEL_BAKE_ERROR。wrapper 使用隐藏进程、每进程 60 秒超时、准确退出码、明确 PASS 和 ERROR / FAIL 扫描。

第一波回归证据：`.godot/foundation-1-validation/level_baker_foundation_regression_final/`。

## 文件与 git diff

| 文件 | 职责 |
|---|---|
| foundation/level/authoring_reader.gd | 明确作者 schema、量化、正式 Face 工厂。 |
| foundation/level/level_baker.gd | 纯数据编排与真实 Validator gate。 |
| foundation/level/level_codec.gd | canonical JSON、真实 hash、精确解码。 |
| tools/foundation/level/bake_level.gd | 显式路径 CLI 和无覆盖文件发布。 |
| tools/foundation/level/minimal_authoring.tscn | 双世界各两个 Cube 的极小 fixture。 |
| tests/foundation/level/baker_fixture.gd | Codec 作者/定义 fixture。 |
| tests/foundation/level/validator_double.gd | 仅失败传播测试 double。 |
| tests/foundation/level/test_level_codec.gd | Codec TDD 与独立 golden。 |
| tests/foundation/level/test_level_baker.gd | Reader/Baker、真实 Validator 和产物验证。 |
| tests/foundation/level/run_validation.ps1 | 隔离真实依赖、CLI 正负验收、来源证据。 |
| 本报告与本 Work plan | 交付说明与执行状态。 |

全部新 .gd 对应 UID 一并交付。完整包含未跟踪文件的 git diff 保存为 `.godot/foundation-2c/level_baker_final/work-c.diff`，统计为相邻 work-c.stat.txt。最终范围为 19 个新增文件及 1 个本 Work plan 修改。

没有修改公共合同、第一波实现、2B 原文件、主工作区、project.godot 或其它 Work 的文件。没有 Editor Plugin、Kernel、Runtime gameplay、Solver、P-02 或美术工作。未 commit/push/merge；保留当前分支和 worktree。
