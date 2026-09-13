# FOUNDATION Orientation Math Report

- 日期：2026-09-13
- 结果：`FOUNDATION_ORIENTATION_MATH_PASS`
- Work：A / DiscreteOrientation 数学核心
- Worktree：`E:/godot/worktrees/block-girl-foundation-orientation`
- 分支：`feat/foundation-orientation-math`
- 基线 HEAD：`4643062e83a962000d14f0e1dbfbece6e310d4ed`
- 合同：`foundation.contract.v1`；姿态：`cube24.v1`
- 引擎：`Godot Engine v4.7.2.stable.steam.ed1daf0bf`
- 当前验收：FOUNDATION-1A 补充覆盖后 **77,965 项数学检查 + 66 项旧纯逻辑回归，全部通过**。下文 Work A 日志保留初次实现历史。

## 交付与边界

实现纯 `RefCounted` 静态数学模块；未注册 `class_name`，无其它 FOUNDATION 模块依赖。合同 §9 的八个签名全部提供：`is_valid`、`columns`、`from_columns`、`compose`、`inverse`、`apply`、`quarter_turn`、`reframe`。

24 个列基严格固定为合同 §4 的 ID；六张 24 项表表示旧姿态左乘 X±、Y±、Z±。组合按列向量主动变换、右侧先执行。`columns` 每次返回新的类型化数组，外部修改不会污染表。`from_columns` 精确匹配，非法基返回 -1；其它运算使用断言表达合同的严格已验证前置条件，不取模、不回退 identity。调用方必须先验证 ID/axis/sign；这不是 DATA 错误记录接口。

`reframe(source,target,pose)=compose(compose(target,inverse(source)),pose)`，不加入光照、Shift 权限或回正逻辑。相同法线但不同切向仍按此数学公式计算；业务上的 SAME_NORMAL 处理属于后续调用层。

仅新增数学脚本/UID、专用测试/UID、本报告，更新本 Work 计划进度。公共合同、其它模块和工作树均未修改；未 commit/push/merge/rebase。未发现 `CONTRACT_MISMATCH`。本结果只证明数学模块，不代表 SPATIAL、DATA、CELESTIAL 联合验收或 FOUNDATION Runtime 可玩。

## 验证

最终执行实际指定工作树，而非计划示例中的主仓库路径：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path 'E:/godot/worktrees/block-girl-foundation-orientation' --script res://tests/foundation/orientation/test_orientation.gd
git diff --check
```

实际运行通过 `Start-Process -WindowStyle Hidden -PassThru -Wait` 分别保存 stdout/stderr，并检查进程退出码与错误内容；对新增未跟踪文件另运行 `git diff --no-index --check`，未 stage 文件。

首次 Work A 结果：**73,107 checks，failures=[]，退出码 0，stderr 0 字节**；当前 FOUNDATION-1A 最终结果见下节。

- 固定 ID 顺序、24 个唯一正交右手基、精确反查；非法 ID 范围、216 组有符号单位轴组合、零轴/缩放/重复轴/反射拒绝。
- 整数向量应用；返回数组修改隔离。
- 六个固定增量 2/3/22/18/9/12、144 项左乘表；所有起始姿态的四次旋转复原。
- 576 组组合闭合、右侧先执行、24 个双侧逆与单位元。
- 独立非交换 golden：`compose(2,22)=10`，`compose(22,2)=20`。
- Frame golden：`reframe(3,2,0)=1`、`reframe(3,17,0)=19`、`reframe(3,3,9)=9`；相同法线不同切向示例。
- 全部 13,824 组 source/target/pose：合法性、反向复原、独立坐标投影验证、组合结合律及输入保持。

## RED / GREEN 证据

目录：`E:/godot/若叶睦/foundation-0-evidence/orientation/work-a-20260913-142557/`。各轮日志独立保存，未覆盖失败证据。

| 日志前缀 | 退出码 | 结果 |
|---|---|---|
| `red-missing` | 1 | 明确 implementation missing；不是资源导入故障 |
| `red-task1` | 1 | 扩充基础测试后，仍明确缺实现 |
| `green-task1` | 1 | 首次实现运行：测试中两条自写非交换 golden 的期望值写反 |
| `green-task1-corrected` | 0 | 按合同手算修正测试期望：3,982 checks，无失败 |
| `red-reframe` | 1 | 明确缺少 reframe 方法 |
| `green-reframe` | 0 | 实现唯一公式后：73,107 checks，无失败 |
| `uids` | 0 | 引擎 ResourceUID 生成两个独立 UID |
| `final` | 0 | 73,107 checks，无失败；stderr 为空 |

非交换 golden 修正依据：Y+ 的三列 `[-Z,+Y,+X]` 再经 X+ 得 `[+Y,+Z,+X]`，合同 ID=10；X+ 的三列 `[+X,+Z,-Y]` 再经 Y+ 得 `[-Z,+X,-Y]`，合同 ID=20。修正的是本 Work 新测试，未修改合同或旋转实现。

测试入口缺文件/缺方法时明确退出 1；完整测试失败也退出 1；全部通过才打印 PASS 并退出 0。

## 只读审查

独立审查已批准：核对实现与冻结合同、计划及 GREEN 日志，未发现具体正确性、合同或测试覆盖问题，无 `CONTRACT_MISMATCH`。审查未修改文件。最终文件范围及已跟踪/新增文件的空白检查通过。

## FOUNDATION-1A 补充验收

再次核对实际工作路径与分支，分别为本报告列出的 orientation worktree 和 `feat/foundation-orientation-math`。重读正式 Spec、模块计划、公共合同及 Core Contract Freeze 报告后，保留已有数学实现，仅补充本模块测试与报告；没有重新定义任何公共接口。

### 24 态编码和变换接口

`cube24.v1` 是固定字面量 24 行列基表，不在运行时遍历生成编号。right 按 `[+X,-X,+Y,-Y,+Z,-Z]` 排列，up 同序跳过平行轴，forward=right×up；6×4=24，identity 唯一为 ID 0。旧代码遍历仅用于测试可达性，不参与新 ID 编码。

- FaceDirection 的数学变换：对合同六面法线调用 `apply(rotation, normal)`。结果仍为六个方向之一且是双射；不重命名 Cube 本地 Face ID，不在 MATH 另建 DATA 所属枚举。
- SurfaceFrame 的数学变换：分别计算 `apply(rotation, frame.u/v/normal)`；`from_columns(u,v,normal)` 返回变换后的 Frame ID。测试使用合同六面 Dictionary fixture，没有实现 SPATIAL 的 `face_frame` 或派生 Anchor。
- CubeOrientation 的数学变换：`compose(delta, pose)`，增量左乘；`compose(a,b)=a×b`，先 b 后 a；`inverse(id)` 是列基矩阵转置所对应的合法 ID。
- OPPOSITE_NORMAL：完整目标 Frame × 源 Frame 逆，再左乘姿态；96 对合法反法线 Frame 均有定义，不从相反法线的叉积猜旋转轴。

### 当前检查和旧代码兼容性

| 检查组 | 检查数 | 范围 |
|---|---:|---|
| 原有数学与全枚举 | 73,107 | 固定表、非法基、闭包、逆、结合律、24³ reframe |
| Face / SurfaceFrame | 1,757 | 24×6 法线/Frame、单位正交右手性、反射/平行切向拒绝、identity 唯一、正负旋转互消 |
| OPPOSITE_NORMAL | 2,785 | 全部 96 对完整 U/V/N 映射、半圈性质、每对全部 24 种姿态 |
| 只读旧 CubeOrientation parity | 316 | 24 态双射、96 条四向 roll 边、144 次 X/Y/Z ±90°、物理 +Z 脸 |
| **本模块总计** | **77,965** | failures=[]，进程退出码 0，stderr 0 字节 |
| 既有 `test_perspective_logic.gd` | 66 | 原脚本未修改，24 态纯逻辑回归通过，退出码 0，stderr 0 字节 |

新旧数学列基及旋转方向兼容。旧 `key()` 是列向量字符串，新 ID 是版本固定整数，**不承诺旧字符串或遍历顺序与新 ID 的序列化兼容**；只读 parity 通过三列精确反查建立双射。P-01 Runtime、相机行为和存档均未迁移。旧脚本 SHA-256 保持 `9F81583C7C9FBADC92A4F4640EE502EF7A8E517D213CBB3A052CF7E447748DCE`；生产数学脚本此次保持 `D228A4230A6E8E2C72BDE07AF030E623BD3363FECAF17010621E54BB25B093F3`。

### 新增测试的检错证据

已有实现此前完成了 RED→GREEN。本次新增覆盖首先在已有实现上通过，再以证据目录中的独立故障副本证明测试能检错；没有把生产脚本临时改坏，也没有把补充测试冒称为首次实现前的 RED。

- `red-apply-identity`：故意令 apply 恒等返回输入，新增 Face/Frame 和 parity 检查捕获 83 个失败，退出码 1。
- `red-reframe-keeps-pose`：故意令 reframe 保持旧姿态，新增 OPPOSITE 检查捕获 2,304 个失败，退出码 1。
- 两次失败均是行为断言失败，stderr 为空，非脚本解析/资源导入错误。随后原工作树完整测试再次通过。

当前证据目录：`E:/godot/若叶睦/foundation-0-evidence/orientation/foundation-1a-20260913-143312/`。含 `green-extended`、两轮 `red-*`、`legacy-regression`、`final` 的独立 stdout/stderr，及包含未跟踪新文件的 `orientation-worktree.diff.txt` 和 `git-status.txt`。

独立只读复审批准新增 fixtures、Frame 与旧代码 parity 覆盖；无 `CONTRACT_MISMATCH`。未修改公共合同或其它模块，未 commit/push/merge。这里只交付 `FOUNDATION_ORIENTATION_MATH_PASS`。

### 修改文件 / Git diff

相对 HEAD 共 6 个文件（5 个新增、1 个修改）：

1. `foundation/orientation/discrete_orientation.gd`：新增数学核心。
2. `foundation/orientation/discrete_orientation.gd.uid`：新增 UID。
3. `tests/foundation/orientation/test_orientation.gd`：新增完整测试及只读 parity。
4. `tests/foundation/orientation/test_orientation.gd.uid`：新增 UID。
5. `docs/development-records/FOUNDATION_ORIENTATION_MATH_REPORT.md`：新增本报告。
6. `docs/superpowers/plans/2026-09-13-foundation-orientation-math.md`：更新本 Work 完成记录。

普通 `git diff` 仅显示已跟踪的计划变化；完整差异证据追加每个未跟踪文件相对空文件的 diff，未使用 stage/commit。`git diff --check`、新增文件空白检查及 6 文件允许范围检查均通过。
