# FOUNDATION-4 正式 Spec 批准记录

记录日期：2026-09-23（Asia/Shanghai）。精确记录时间在末尾追加。

状态：**SPEC_APPROVED_FOR_PLANNING**。计划状态：**AWAITING_USER_REVIEW**。实施状态：**IMPLEMENTATION_NOT_STARTED**。

## 批准对象与内容身份

用户在当前任务明确回复：“我批准你上一条消息明确标识的两份2026-09-23修订版正式文档及所列G1–G6细则。”写入本记录前，实际文件SHA-256与用户指定值逐一一致：

| 文档（相对仓库根） | 被批准 SHA-256 |
|---|---|
| [docs/superpowers/specs/2026-09-22-foundation-authoring-editor-design.md](../superpowers/specs/2026-09-22-foundation-authoring-editor-design.md) | A4D9CD7CCFDE8E4FDB0EEA72746505B995361850E623BEF7952D49849EC9A13F |
| [docs/superpowers/specs/2026-09-22-foundation-authoring-tool-contracts.md](../superpowers/specs/2026-09-22-foundation-authoring-tool-contracts.md) | C31A03E807A2BF9268D32AA00FA18BCD93C77BAD4C53ED00A8D349FED8462A6B |

这两个文件的原字节保持不变，保留其中审阅时的front matter；它们历史上的HELD_FOR_REVIEW/AWAITING USER REVIEW由本次**绑定上述哈希**的明确批准记录补充，不再据旧标记重复要求批准。内容变化必须另行核对，不能把本批准套用到另一版本。

## 授权范围

- G1：独立World源编辑优先；不支持的玩法实例覆盖报错停链；未保存内容一致捕获，失败不回退旧磁盘值。
- G2：4D唯一带类型数组编码、精确数值、摘要范围及校验顺序；不跨进程恢复可信完整图。
- G3：六个内嵌Face Resource、引用单一来源、专用副本内部别名/外部目标和所属文档撤销边界。
- G4：唯一只读Shared Space视图，与消费正式产物、经Kernel/Session执行的通用白盒运行宿主分开。
- G5：合作式取消立即撤销通过发布资格；调用结束和资源释放确认前保持正在取消；无即时强杀或有界回收承诺。包含被批准Tool Contracts §6的全部默认预算、期限、租约和资源限额，计划原样列出并区分固定项/可配置项。
- G6：E盘执行源项目`.godot/foundation-authoring/runs/<run_id>/`缓存；默认永久交付`E:/godot/foundation-authoring-deliveries/<level_id>/<run_id>/`；首次发布失败与已有报告后续导出失败采用不同语义。

本轮仅授权记录批准、编制四Owner计划及集成计划、文档一致性/所有权检查、必要Obsidian摘要。Spec批准不等于实施计划获批。

不授权生产代码、实际测试脚本/场景、实现任务启动、新开发worktree、Blender/美术改动、main/P-01/旧FOUNDATION生产修改，以及commit/push/merge/PR。未来实施必须另获计划和执行授权；未跟踪文档不是共同已提交基线。

## 本轮基线与交付索引

设计工作树：`E:/godot/worktrees/block-girl-foundation-authoring-design`；分支`docs/foundation-4-authoring-design`；HEAD `bfcc6c004db232ca2f4ea4d409c98bda0dc6d165`。本地Core `821bce29fc94dbed42fafbe3f4a720b4715d4aa3`仅多README变更；本轮未切分支、回退或提交。

- [4A计划](../superpowers/plans/2026-09-23-foundation-authoring-data-plan.md)
- [4B计划](../superpowers/plans/2026-09-23-foundation-editor-tools-plan.md)
- [4C计划](../superpowers/plans/2026-09-23-foundation-authoring-quality-plan.md)
- [4D计划](../superpowers/plans/2026-09-23-foundation-authoring-runtime-plan.md)
- [集成计划及公共约束](../superpowers/plans/2026-09-23-foundation-authoring-integration-plan.md)

本轮文件校验和差异证据存于`E:/godot/foundation-4-planning-2026-09-23/`；它不是游戏运行验收证据。

实际记录时间：2026-09-23T01:37:19.1000710+08:00

## 五计划编制与文档自检记录

实际记录时间：2026-09-23T02:07:20.110985+08:00（Asia/Shanghai）。本节记录编制和文档检查，不构成用户批准五份实施计划。

状态：**FOUNDATION_4_IMPLEMENTATION_PLAN_REVIEW_READY**；**IMPLEMENTATION: NOT_STARTED**。五份计划各自保持PLAN_DOCUMENTED / AWAITING_USER_REVIEW / IMPLEMENTATION_NOT_STARTED。

本轮自检采用writing-plans并按verification-before-completion核验证据。实际执行的是只读Git/源接口/命令参数检查，以及E盘`document_audit.py`文档核验；没有执行计划中的Godot、插件、生产测试或实现任务。

| 检查 | 结果 |
|---|---|
| 两份批准Spec SHA-256 | 与本页顶部批准值一致，原字节不变 |
| 原有设计工作树文件 | 2,521个文件逐文件hash不变，含原工作笔记/审阅报告 |
| 五计划覆盖 | 4A、4B、4C、4D、Integration共23项任务，有精确文件、输入/输出、RED/GREEN/REVIEW、依赖和停止条件 |
| 文件所有权 | 181个唯一计划路径：4A 54、4B 32、4C 14、4D 54、Integration 27；0跨Owner重叠 |
| 现有文件的未来修改 | 只列Integration维护project.godot插件启用；其余180项为未来Create/Test；本轮均未执行 |
| 公共约束 | §6的20行值逐项对照；来源/阶段/固定与可配置、期限非回收保证均明确 |
| 命令和链接 | 12个旧PowerShell入口已查存在及EvidenceName参数；其它参数按现有源码核对；20处计划文档链接有效；新wrapper明确I0创建 |
| 真实验收状态 | 全部NOT_RUN；替身只允许明确Unit；缺依赖收口为DEPENDENCY_PENDING |
| 本轮Git变化 | 只新增本批准记录及五计划，共6个未跟踪Markdown；既有4个未跟踪文档不变；无tracked/staged diff |
| 主工作树及worktree | main原7个未跟踪import保留；branch/HEAD、worktree列表不变；未创建开发worktree |
| Obsidian | 仅在2026-09-22-FOUNDATION-4作者工具设计归并.md追加摘要，原字节为完整前缀；其余文件和MOC不变 |

自审修正了阶段下标假定、Editor测试上下文、取消返回包装、结构编辑撤销记录及服务上下文绑定；首链明确修改非Goal中间面，I2机制源提前交付，避免依赖I3后建fixture。I2先产真实质量/回放StageRecord，I3才消费D6最终报告，不倒置汇总依赖。

五计划精确文件哈希、实际校验时间和检查细节保存在`E:/godot/foundation-4-planning-2026-09-23/verification.json`，最后再核对一次；该证据目录不属于游戏产物。计划级新增接口/文件拆分、I0入口、依赖交接、Editor和图形验收安排仍待用户审阅；实际BASE/Owner SHA只在后续获得Git及实施授权后登记，不编造提交。

授权在此停止：未写生产代码/实际游戏测试脚本或场景，未启动4A–4D，未运行Blender，未动main/P-01/既有FOUNDATION生产代码，未commit/push/merge/PR。下一步等待用户审阅计划并授权实施，不重问已绑定批准的两个Spec版本。
