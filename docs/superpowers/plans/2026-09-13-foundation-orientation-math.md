# FOUNDATION Orientation Math Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax. 本文仅计划，FOUNDATION-0 不执行。

**Goal:** 提供唯一、版本固定、无浮点累积的 cube24.v1 离散旋转数学。

**Architecture:** 纯 RefCounted 静态函数，列向量主动变换；不依赖 contracts/spatial/celestial 的代码。24 个 ID 及六轴增量按合同固化，已有 prototype CubeOrientation 只读参考。

**Tech Stack:** Godot 4.7.2 GDScript，Vector3i，headless SceneTree 测试。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md` §7/33；`docs/superpowers/specs/2026-09-13-foundation-core-contracts.md` §2–4/9 为唯一公共接口。

## Global Constraints

- 游戏仓库：`E:/godot/若叶睦/方块少女-若叶睦`；contract_version=foundation.contract.v1，orientation_version=cube24.v1。
- 只写 `foundation/orientation/discrete_orientation.gd`、其 UID、`tests/foundation/orientation/test_orientation.gd`、其 UID、本计划进度和 `docs/development-records/FOUNDATION_ORIENTATION_MATH_REPORT.md`。
- 禁改 contracts/spatial/celestial、公共 Spec、game/、prototype/、production/、project.godot、其它测试；不抽取/重写旧 CubeOrientation，不注册 class_name。
- 不做 InputMapper、地图、Kernel、Solver、Blender、P-02；不自动 commit/push/merge/rebase。证据在 E 盘专属目录。

## 接口与依赖

`discrete_orientation.gd` 输出合同 §9 MATH 全部签名：is_valid、columns、from_columns、compose、inverse、apply、quarter_turn、reframe。is_valid 返回 bool；columns 返回 Array[Vector3i]；apply 返回 Vector3i；其余返回 int。非法 from_columns=-1；其它数学操作的 id/axis/sign 为严格已验证前置条件，绝不取模修正。RotationAxis 只定义在此文件，调用者持久化 rotation_delta，不能序列化 axis。

读取无前置模块，输出供 SPATIAL 使用。DATA 仅检查 ID 范围，不复制数学表。

### Task 1：固定编号与基础旋转

**Files:** 新建上述脚本与 `tests/foundation/orientation/test_orientation.gd`。

- [ ] 先建测试入口。缺文件检查采用运行时 load，使缺实现是明确测试失败而不是编译挂起：

```gdscript
extends SceneTree
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func _initialize() -> void:
	var path="res://foundation/orientation/discrete_orientation.gd"
	if not FileAccess.file_exists(path):
		printerr("FAIL: orientation implementation missing"); quit(1); return
	var math=load(path)
	check(math.columns(0)==[Vector3i.RIGHT,Vector3i.UP,Vector3i(0,0,1)],"identity golden columns")
	check(math.apply(2,Vector3i.UP)==Vector3i(0,0,1),"X+ sends Y to Z")
	check(math.from_columns(Vector3i.RIGHT,Vector3i.UP,Vector3i(0,0,-1))==-1,"reject reflection")
	print("ORIENTATION ",failures); quit(0 if failures.is_empty() else 1)
```

- [ ] 用下方验收命令运行，保存 RED，确认 missing implementation，非资源导入故障。
- [ ] 实现合同24行表、is_valid、columns、from_columns、apply；测试固定六增量2/3/22/18/9/12及全部24唯一正交右手基。拒绝重复轴、零轴、反射和越界 ID；columns 返回新数组，修改结果不能污染表。
- [ ] 增加全部24×24组合闭合、全部24逆、六增量四次回原态、非交换实例；实现 compose/inverse 与六张24项查表。独立 golden 例：compose(2,22) 与 compose(22,2) 不同；apply(compose(a,b),v)=apply(a,apply(b,v))。
- [ ] 运行 GREEN，所有失败输出必须为空；重构只允许在本模块内部。

### Task 2：Frame 重定向与姿态增量

**Files:** 仅上述脚本与本测试。

- [ ] 先添加不使用实现自产期望值的 golden tests：

```gdscript
check(math.reframe(3,2,0)==1,"TOP to BOTTOM")
check(math.reframe(3,17,0)==19,"opposite normal with different tangents")
check(math.reframe(3,3,9)==9,"same full frame keeps pose")
```

- [ ] 运行 RED 后实现唯一关系：`compose(compose(target_frame,inverse(source_frame)),pose)`；不检查 Shift 光照/权限、不加入“回正”特例。
- [ ] 枚举24个 source、target、pose，验证结果合法且逆向 Frame 重定向恢复 pose；同时覆盖 compose 三元结合律和不修改输入。
- [ ] 按验收命令运行 GREEN，记录 check 数、版本、错误输出。对接 SPATIAL 时只能修自己实现；发现合同矛盾停止该接口接线并报告，不能修改共享 Spec。

## 验收命令

在仓库执行；RED/最终运行使用不同日志文件名，不覆盖旧失败证据。测试入口须失败 quit(1)、通过 quit(0)，不能只打印 PASS。

```powershell
$foundationEvidence='E:/godot/若叶睦/foundation-0-evidence/orientation'
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationResult=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/若叶睦/方块少女-若叶睦" --script res://tests/foundation/orientation/test_orientation.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$foundationEvidence/final.stdout.log" -RedirectStandardError "$foundationEvidence/final.stderr.log"
if ($foundationResult.ExitCode -ne 0 -or (Get-Content "$foundationEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Orientation failed' }
git diff --check
```

完成输出 FOUNDATION_ORIENTATION_MATH_PASS 与报告；只证明数学模块，不启动其它工作或声称 FOUNDATION Runtime 已通过。
