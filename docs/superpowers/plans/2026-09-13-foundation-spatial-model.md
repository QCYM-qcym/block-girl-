# FOUNDATION Spatial Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax. 本文仅计划，FOUNDATION-0 不执行。

**Goal:** 从离散 Cube/World/Group 变换生成六面 Shared Space 快照，并校验单个稳定构型。

**Architecture:** 无 SceneTree 的 surface_geometry 与 spatial_validation；FaceAnchor 由整数几何派生。只做数据快照，绝不实现 Shared Space Mapping Solver 或路径搜索。

**Tech Stack:** Godot 4.7.2 GDScript、Vector3i、Dictionary、headless 测试。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md` §5/6/11/18/33；`docs/superpowers/specs/2026-09-13-foundation-core-contracts.md` §3/4/5/9/10。

## Global Constraints

- 根路径 `E:/godot/若叶睦/方块少女-若叶睦`；foundation.contract.v1 / cube24.v1；L=1，所有 position2/center2/pivot2 是半格整数。
- 只写 `foundation/spatial/surface_geometry.gd`、`spatial_validation.gd`、相应 UID、`tests/foundation/spatial/test_spatial.gd`、UID、本计划进度和 `docs/development-records/FOUNDATION_SPATIAL_MODEL_REPORT.md`。
- contracts/orientation/celestial、公共 Spec、game/、prototype/、production/、project.godot、其它测试全部只读；不新建邻模块假脚本。
- 不做 Mapping/Lighting Solver、BFS、全构型枚举、扫掠证明、输入或 Runtime、Blender、P-02；不自动 commit/push/merge/rebase。

## 接口与依赖

消费 MATH `apply(id,vector)`, `compose(a,b)` 和 DATA foundation_types 枚举；消费合同中的 CubeCell、DiscreteTransform、LevelDefinition、PuzzleState 值记录。输出合同 §9 SPATIAL 完整签名：face_frame、face_id、resolve_cube、resolve_anchor、snapshot、validate_snapshot。snapshot 输出 cubes/anchors 排序数组，不能返回 Godot Node 或把玩家位置写回输入。

DATA/MATH 未落地时先写独立的六面 golden fixture 和接口失败测试；实际 preload 接线/集成测试必须等真实模块到位，不向公共路径塞 stub。CELESTIAL 可以先按本合同写固定 ResolvedCube fixture，不必等待本实现。

### Task 1：六面基与整数层级变换

**Files:** surface_geometry 与本测试。

- [ ] 创建 SceneTree 测试入口：缺实现打印 FAIL 并 quit(1)，检查失败累积到 Array[String]，最终失败 quit(1)。先写 golden tests，运行下方命令保存 RED：

```gdscript
var spatial=load("res://foundation/spatial/surface_geometry.gd")
var frame=spatial.face_frame(4)
check(frame.u==Vector3i.RIGHT and frame.v==Vector3i(0,0,-1) and frame.normal==Vector3i.UP,"TOP frame")
check(spatial.face_id(&"tile_a",4)==&"tile_a/TOP","immutable local face identity")
var cube={"cube_id":&"tile_a","layer":0,"center2":Vector3i(2,0,0),"orientation":0,"group_id":&"","occludes_light":true,"tags":[]}
var identity={"rotation":0,"pivot2":Vector3i.ZERO}
var resolved=spatial.resolve_cube(cube,identity,identity)
check(spatial.resolve_anchor(resolved,4).position2==Vector3i(2,1,0),"half-grid TOP anchor")
```

- [ ] 实现合同六面表，返回新 Dictionary；实现 W×G×C 和 pivot2 公式，不用 Transform3D 插值/epsilon。所有面 ID 保留 Cube 本地名称。
- [ ] 添加非交换层级 golden：cube.center2=(2,0,0)、Group delta=22/Y+、pivot2=(0,0,0)、World=2/X+，最终中心=(0,2,0)；交换层级所得中心不同，必须拒绝“顺序无所谓”的实现。
- [ ] 添加奇 pivot2=(1,0,0)、Y+ 后 center2=(1,0,-1) 的非法格点 fixture；resolve 返回确定整数，validate_snapshot 才报告 OFF_LATTICE，不偷偷四舍五入。
- [ ] 运行 GREEN；覆盖六 Face、24 orientation，所有 Frame 正交且 u×v=n；输出数值必须与独立 golden 一致。

### Task 2：快照与初态结构校验

**Files:** 新建 spatial_validation，并扩充本测试。

- [ ] RED fixtures：同层同中心两个 Cube→SAME_WORLD_CUBE_OVERLAP；异层同中心→无该错误；同层中心差(2,0,0)只共面，内部相对 walkable 面→SEALED_WALKABLE_FACE；外侧 Face 不误报。移动/Shift 候选不属于本模块。
- [ ] 实现 snapshot，按 level Cube IDs 与 state World/Group orientation 解析；所有输入先通过 DATA shape。处理数据派生副本，不修改 LevelDefinition/PuzzleState。validate_snapshot 检查中心偶数、锚公式、唯一 Face ID、Frame 合法、同层体积重叠和内部 walkable 面。
- [ ] 接入真实 MATH/DATA fixture：World/Group 旋转后中心和法线变化而 face_id 不变；重算两次相同；交换输入数组次序不改排序后的快照；深比较原输入未变。
- [ ] GREEN 后写报告，明确仅单稳定构型，不含全状态枚举、Shift mapping、安全扫掠或 LEVEL_VALID。

## 验收命令

```powershell
$foundationEvidence='E:/godot/若叶睦/foundation-0-evidence/spatial'
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationResult=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/若叶睦/方块少女-若叶睦" --script res://tests/foundation/spatial/test_spatial.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$foundationEvidence/final.stdout.log" -RedirectStandardError "$foundationEvidence/final.stderr.log"
if ($foundationResult.ExitCode -ne 0 -or (Get-Content "$foundationEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Spatial failed' }
git diff --check
```

RED 与最终日志分别保存。真实依赖集成未跑则不能报告 FOUNDATION_SPATIAL_MODEL_PASS；通过后停止，只交付模块报告。
