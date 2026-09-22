# FOUNDATION-4 4D Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task after explicit execution approval. Steps use checkbox (`- [ ]`) syntax. 本轮仅编制计划；后续拟采用四Owner独立worktree，具体启动仍须用户授权，不自动派生实现任务。

**Goal:** 提供唯一快照/交换/任务/汇总归档服务，并尽早让正式作者产物进入真实白盒运行。

**Architecture:** 协议与字节、输入捕获、执行工程、进程任务、报告归档、只读视图分别在小模块中实现。白盒手动宿主和整段Replayer入口各自隔离，二者只消费同轮正式产物；只读状态视图不持有可写Session。

**Tech Stack:** Godot/GDScript、PowerShell、现有FOUNDATION公开接口；不增加第三方运行依赖。工程声明4.7特性，实际engine能力须在I0核验并绑定，不能把声明当运行验证。

**Spec:** [Design Spec](../specs/2026-09-22-foundation-authoring-editor-design.md)，SHA-256 `A4D9CD7CCFDE8E4FDB0EEA72746505B995361850E623BEF7952D49849EC9A13F`；[Tool Contracts](../specs/2026-09-22-foundation-authoring-tool-contracts.md)，SHA-256 `C31A03E807A2BF9268D32AA00FA18BCD93C77BAD4C53ED00A8D349FED8462A6B`。仅消费这两个已批准内容版本。

**Approval:** [独立批准记录](../../development-records/FOUNDATION_4_SPEC_APPROVAL_RECORD.md)。Spec旧front matter保持原字节，不再以其待审标记否认本次哈希批准。

**Date:** 2026-09-23 · **PLAN_DOCUMENTED** · **AWAITING_USER_REVIEW** · **IMPLEMENTATION_NOT_STARTED**。

## Global Constraints

- 唯一Reader/Baker/Codec、Kernel/Safety、Solver/Softlock/Intent/Trace与Session/Presenter/Replayer；不调用私有测试seam绕过正式验证，不产生第二算法。
- 4A定义作者/source_map；4D定义wire、快照/任务/报告及唯一状态视图；4C只编排质量；4B独占插件入口。跨Owner共享数据及已批准数值以[集成计划公共约束](2026-09-23-foundation-authoring-integration-plan.md)为单一计划登记，不复制出另一套协议。
- 两个World单位变换；玩法实例覆盖报错停链；六面不缺失/不重复；未知字段/版本失败。原始Transform交Reader，不提前量化。
- ANALYZE_CURRENT允许未保存但不签发整关PASS；ACCEPT_SAVED保存同轮闭包；失败不回退旧产物。完整验收固定UNFILTERED/FULL_GRAPH、零软锁、适用Intent、同一trace语义与GRAPHICAL MATCH。
- 取消立即撤销PASS资格；CANCELLING直到调用结束和自有资源释放确认；不强杀、不承诺有界回收。所有工具默认预算逐项沿合同§6，期限不等于硬终止。
- 源码/fixture入Git；生成日志、运行工程、导出和本任务可配置临时目录在E盘。无全局环境修改。tests-only double只能证明局部包装行为，真实链不得加载它。
- 本轮不创建实际.gd/.uid/.tscn/.tres/插件/测试；以下Create/Modify/Test均为将来实施任务。所有示例仅在Markdown内；全部Godot验收 **NOT_RUN**。
- 禁止写main、旧P-01及既有FOUNDATION生产模块；禁止写`E:/Study/方块娘项目/若叶睦/model/art_pilot_01`、`E:/Study/方块娘项目/若叶睦/photo`或运行Blender。白盒不等待美术，不引入旧像素尺寸约束。
- 不commit/push/merge/PR、不创建开发worktree。计划批准、执行方式授权、共同基线已提交是执行前置；任务REVIEW完成只形成可审阅差异，不自动提交。

## Review Focus

- 数值跨wire使原本非法Transform变合法 → D1近阈值前后Reader判定一致。
- 主场景旧实例与独立World未保存值冲突 → D5读取独立源、覆盖明确失败。
- worker父进程消失、同步调用长期不返回 → D4保持正在清理，不声称有界退出。
- 阶段全绿但最终manifest写失败 → D6撤销最终PASS且保留技术证据。
- 只读状态浏览污染Runtime或复用旧节点 → D7隔离、失败清除本次图层。

## 禁止范围

不改4A字段转换/Intent绑定、4C分析器、4B插件或project.godot；不改旧Kernel/Geometry/Math/Reader/Baker/Codec/Solver/Replayer/Presenter，不调用私有注入seam。唯一测试wrapper归Integration；D不再写第二wrapper。新执行工程project.godot是每run生成配置，不是修改仓库入口。

## 精确文件所有权

下列路径相对实施worktree根；同名`.gd.uid`逐项归同Owner，实施导入后纳入正式源依赖。未列文件不得顺手修改。表内tests/路径同时是本任务的Test文件；Create表示未来创建，后续任务对同Owner已创建文件的扩展仍由该Owner维护。

| 操作 | 文件 | 责任 / 创建任务 |
|---|---|---|
| Create | `tools/foundation/authoring_acceptance/run_records.gd` | 4D-1：唯一共享身份、ExecutionPolicy默认值和StageRecord工厂 |
| Create | `tools/foundation/authoring_acceptance/run_records.gd.uid` | 4D-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/tool_wire.gd` | 4D-1：唯一foundationtoolwire.v1编码/恢复/摘要 |
| Create | `tools/foundation/authoring_acceptance/tool_wire.gd.uid` | 4D-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/wire_schemas.gd` | 4D-1：封闭记录注册表，作者字段描述只引用4A |
| Create | `tools/foundation/authoring_acceptance/wire_schemas.gd.uid` | 4D-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/boundary_control.gd` | 4D-1：正式调用边界停止接口，非wire对象 |
| Create | `tools/foundation/authoring_acceptance/boundary_control.gd.uid` | 4D-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/snapshot_capture.gd` | 4D-2：保存源捕获，D5扩展当前缓冲；唯一捕获服务 |
| Create | `tools/foundation/authoring_acceptance/snapshot_capture.gd.uid` | 4D-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/execution_project.gd` | 4D-2：版本/依赖/UID清单与受控工程物化 |
| Create | `tools/foundation/authoring_acceptance/execution_project.gd.uid` | 4D-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/execution_dependencies.json` | 4D-2：允许的静态/动态生产依赖和受控宿主路径 |
| Create | `tools/foundation/authoring_acceptance/canonical_loader.gd` | 4D-3：同轮正式Codec装载；失败清空候选 |
| Create | `tools/foundation/authoring_acceptance/canonical_loader.gd.uid` | 4D-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/whitebox_host.gd` | 4D-3：通用手动运行宿主，只请求正式Session动作 |
| Create | `tools/foundation/authoring_acceptance/whitebox_host.gd.uid` | 4D-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/whitebox_host.tscn` | 4D-3：白盒相机/显示容器；不固定地图 |
| Create | `tools/foundation/authoring_acceptance/whitebox_entry.gd` | 4D-3：从本run产物启动手动宿主的SceneTree入口 |
| Create | `tools/foundation/authoring_acceptance/whitebox_entry.gd.uid` | 4D-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/task_service.gd` | 4D-4：编辑器实例唯一任务槽，保持清理生命周期 |
| Create | `tools/foundation/authoring_acceptance/task_service.gd.uid` | 4D-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/process_transport.gd` | 4D-4：create_process/文件IPC/身份及sequence，合作取消 |
| Create | `tools/foundation/authoring_acceptance/process_transport.gd.uid` | 4D-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/worker_entry.gd` | 4D-4：headless受控工程正式适配/质量入口 |
| Create | `tools/foundation/authoring_acceptance/worker_entry.gd.uid` | 4D-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/graphical_entry.gd` | 4D-4：同轮trace+canonical整段GRAPHICAL宿主 |
| Create | `tools/foundation/authoring_acceptance/graphical_entry.gd.uid` | 4D-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/report_aggregator.gd` | 4D-6：唯一验收汇总，不重写native结果 |
| Create | `tools/foundation/authoring_acceptance/report_aggregator.gd.uid` | 4D-6：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/archive_store.gd` | 4D-6：附件/最后manifest发布、读取及独立导出 |
| Create | `tools/foundation/authoring_acceptance/archive_store.gd.uid` | 4D-6：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/report_currentness.gd` | 4D-6：CURRENT/STALE/UNKNOWN与编辑代次 |
| Create | `tools/foundation/authoring_acceptance/report_currentness.gd.uid` | 4D-6：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_acceptance/state_view.gd` | 4D-7：唯一只读Shared Space状态视图及释放 |
| Create | `tools/foundation/authoring_acceptance/state_view.gd.uid` | 4D-7：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_tool_wire.gd` | 4D-1：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_tool_wire.gd.uid` | 4D-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_saved_snapshot.gd` | 4D-2：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_saved_snapshot.gd.uid` | 4D-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_whitebox_host.gd` | 4D-3：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_whitebox_host.gd.uid` | 4D-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_task_lifecycle.gd` | 4D-4：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_task_lifecycle.gd.uid` | 4D-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/owned_worker_fixture.gd` | 4D-4：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/owned_worker_fixture.gd.uid` | 4D-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_current_snapshot.gd` | 4D-5：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_current_snapshot.gd.uid` | 4D-5：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_reports_archive.gd` | 4D-6：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_reports_archive.gd.uid` | 4D-6：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/file_store_double.gd` | 4D-6：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/file_store_double.gd.uid` | 4D-6：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_acceptance/test_state_view.gd` | 4D-7：本Owner行为测试/明示故障注入，非产品规则 |
| Create | `tests/foundation/authoring_acceptance/test_state_view.gd.uid` | 4D-7：对应脚本持久UID，只在所属任务受控导入生成 |

D5在D2创建的snapshot_capture.gd内扩展同一服务，不新增第二捕获实现；该共享文件始终4D一人维护。D6产品归档与Integration测试证据wrapper不是两套验收汇总：wrapper只检测测试运行，产品verdict唯一归report_aggregator。

## 公开接口（新建，Dictionary形状见公共记录表及批准合同）

| 模块 / 完整签名 | 输出 / 失败责任 |
|---|---|
| run_records.gd `default_execution_policy(entry_kind:String)->Dictionary` | ExecutionPolicy精确默认表；unknown entry拒绝，失败返回空Dictionary且调用方必须诊断；不可静默选另一入口 |
| run_records.gd `make_identity(editor_id:String,generation:int,level_ref:Dictionary,snapshot:Dictionary,policy_digest:String,execution_digest:String,versions:Dictionary)->Dictionary` | RunIdentity；capture为新运行分配UUID，本方法沿用snapshot.identity中的run_id/snapshot_id/source_fingerprint，不再生成另一UUID；版本/摘要齐全才可用于start |
| tool_wire.gd `encode_wire(kind:String,value:Variant)->Dictionary`、`decode_wire(kind:String,bytes:PackedByteArray)->Dictionary` | Result.value分别PackedByteArray/精确值；坏schema/大小/数值失败null |
| tool_wire.gd `digest(kind:String,value:Variant)->Dictionary` | Result.value小写SHA-256 String；只hash自己的canonical wire，Level content_hash仍正式Codec |
| boundary_control.gd `stop_requested()->bool`、`reason()->String`、`checkpoint(stage_id:String)->bool` | 构造绑定run/IPC，check返回false停止下一正式调用；不保证打断当前调用 |
| snapshot_capture.gd `capture(request:Dictionary,editor_context:Dictionary)->Dictionary` | Result.value=SnapshotRef；ANALYZE_CURRENT读取上下文，ACCEPT_SAVED执行保存核对；失败释放捕获锁，run保留诊断不启动worker |
| snapshot_capture.gd `capture_saved(request:Dictionary,project_root:String)->Dictionary` | 同一capture实现的无Editor入口，明确只消费已保存源；不是当前缓冲分析替代物 |
| execution_project.gd `materialize(snapshot_ref:Dictionary,source_root:String)->Dictionary` | Result.value=`{project_root:String,execution_digest:String,manifest:ArtifactRef}`；缺依赖/UID版本停链；不从活动项目补缺 |
| canonical_loader.gd `load_artifact(snapshot_ref:Dictionary,canonical_ref:Dictionary)->Dictionary` | Result.value正式level；先摘要/身份后Codec.decode；失败无可用旧level |
| whitebox_host.gd `load_artifact(snapshot_ref:Dictionary,canonical_ref:Dictionary)->Dictionary` | `{ok:bool,issues:Array[Dictionary]}`；正式Session.load_level成功才loaded；保存所用hash |
| whitebox_host.gd `submit_action(action:Dictionary)->Dictionary`、`reset_run()->void`、`loaded_hash()->String` | 原Session返回、正式Reset；hash只读。动作不在host重新判断合法性；旧回调不能重复commit |
| task_service.gd static `get_or_create(editor_root:Node,editor_instance_id:String)->Node` | 编辑器根唯一自有服务；插件卸载不直接销毁未清理服务 |
| task_service.gd `bind_editor_context(provider:RefCounted)->Dictionary`、`unbind_editor_context(provider:RefCounted)->void` | provider实现B1的describe/current_generation/set_capture_lock；绑定Result.value=null。身份错误/第二活provider拒绝；卸载先cancel再解绑，D清理继续且不再访问旧活源 |
| task_service.gd `start(request:Dictionary)->Dictionary`、`cancel(identity:Dictionary)->Dictionary`、`status(identity:Dictionary)->Dictionary` | Result.value=`{identity:RunIdentity,lifecycle:String,stage_id:String,release_confirmed:bool}`；BUSY不排队；cancel幂等。信号`status_changed(status:Dictionary)`、`result_ready(report_ref:Dictionary)` |
| process_transport.gd `launch(identity:Dictionary,project:Dictionary,entry:String)->Dictionary`、`send_cancel(identity:Dictionary)->Dictionary`、`poll(identity:Dictionary)->Dictionary` | entry仅枚举HEADLESS/GRAPHICAL/MANUAL；Result.value为owned过程记录或消息数组；无任意脚本命令。进程记录`{identity:RunIdentity,pid:int,hello_verified:bool,exited:bool}`仅服务内部 |
| task_service.gd `replay_run(identity:Dictionary,canonical_ref:Dictionary,trace_ref:Dictionary,options:Dictionary)->Dictionary` | async，始终返回GRAPHICAL_REPLAY StageRecord；native_result为实际正式ReplayerResult或未运行时null，actual_budget保留正式options和内部固定静态预算；使用同一槽，不中途恢复，不吞取消 |
| report_aggregator.gd `summarize(run_evidence:Dictionary)->Dictionary` | Report候选；只接受绑定证据，ANALYZE_CURRENT恒UNDETERMINED，安全未知不得PASS |
| archive_store.gd `publish(run_evidence:Dictionary)->Dictionary`、`read_archive(manifest_path:String)->Dictionary`、`export_archive(verified_manifest:Dictionary,destination:String)->Dictionary` | Result.value为report/manifest引用或读档内容；export返回ExportResult；首次发布失败completion=ERROR；已发布报告不可变 |
| report_currentness.gd `compare(report:Dictionary,current_identity:Dictionary,edit_generation:int)->String` | CURRENT/STALE/UNKNOWN；未知/缺依赖非CURRENT；Undo不恢复PASS |
| state_view.gd `inspect_state(request:Dictionary)->Dictionary`、`release_view(view_id:String)->void` | Result.value=ViewHandle；失败清理本次节点；幂等释放；没有Session返回/注入接口 |

额外编排输入RunEvidence=`{identity:RunIdentity,entry_kind:String,snapshot_ref:SnapshotRef,stages:Array[StageRecord],evidence:Array[Dictionary],intent_empty:bool,cancelled:bool,tool_errors:Array[ToolIssue]}`；evidence条目精确沿批准合同§7.2；同一个identity验证覆盖level/intent/trace的实际摘要。保存的旧报告不能重新被summarize当作本轮新native_result。4A source_map和authoring schema由D读取其描述或真实返回，D不能重新写一份作者转换。

## wire与任务实现约束

严格按批准§5.2：数组标签树、无JSON数字/Object、int64十进制、f64按位、Vector3i域、Basis列向量/Transform原位；canonical UTF-8不做Unicode归一化。字典按键编码排序并拒绝解码后String/StringName碰撞；重复键不能覆盖。读取大小→ready→摘要→字节语法→类型/schema→正式校验。D1计划计数约定：envelope不计入值树深度，payload根计1，每个带类型子值+1，dict键/值和array元素为孩子；到64可接受、65拒绝。此为计划级可测试细化，仍沿批准上限64。

脚本依赖闭包先列现有foundation生产脚本和必要4A/4C/4D，静态res://与源码明确动态路径均登记；例如Replayer动态依赖solution_trace.gd、Session动态Safety必须包括。不能直接复制整个仓库以覆盖漏项。A/quality缺失时标DEPENDENCY_PENDING；首条只Bake/手动运行的policy不列质量阶段，不要求提前加载C。正式全验收时C必需。工程和tool digest核验后才能启动。UID只在受控工程内对应清单资源，作者UID只做来源定位。

合作式取消：cancel闩锁先落盘并撤销发布资格，当前公开调用允许自然返回；退出确认、文件关闭、回调断开、预览清理齐备才开放槽。父1秒续租、30秒失效在下一可检查边界生效；300000ms阶段期限只停链，不能推断进程必然释放。崩溃/超时/取消分别记，所有native_result有实际返回才保存。协议sequence/完整RunIdentity/摘要全核验，迟到/重发不覆盖新任务。

## 小步任务

### 4D-1 — 唯一wire、身份与批准默认值

**Files:** `tools/foundation/authoring_acceptance/run_records.gd`, `tools/foundation/authoring_acceptance/tool_wire.gd`, `tools/foundation/authoring_acceptance/wire_schemas.gd`, `tools/foundation/authoring_acceptance/boundary_control.gd`, `tests/foundation/authoring_acceptance/test_tool_wire.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 批准合同§5.2/§6及公共精确预算表；旧Codec和正式shape接口

**Interfaces — produces:** tool_wire/run_records/wire_schemas/BoundaryControl；D_PROTOCOL交付

- [ ] **RED：** int64两端、StringName≠String、Vector3i边界、负零、非有限拒绝、Transform近Reader阈值、非法UTF-8/重复键/未知字段/深度64与65、128MiB边界；默认值逐项断言。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-1 -Mode Unit -EvidenceName 4d_4d-1_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var policy := RunRecords.default_execution_policy("ACCEPT_SAVED")
var encoded := Wire.encode_wire("policy", policy)
check(encoded.ok, "closed policy without an A implementation dependency")
var decoded := Wire.decode_wire("policy", encoded.value)
check(decoded.ok and decoded.value == policy, "exact policy round trip")
check(policy.search_budget.max_runtime_ms == 30000 and policy.replay_options.step_timeout_ms == 5000, "approved defaults")
check(policy.stage_deadline_ms == 300000 and policy.max_wire_bytes == 134217728, "approved limits")
```

- [ ] **GREEN：** 封闭生产schema随record_kind分派，authoring/source_map引用A1描述，未到A1先测试policy/manifest等D自有schema。数值边界先覆盖本文件内部值编码/解析单元，不在生产record_kind增加测试类型；完整作者Transform及StringName往返在A_SCHEMA接入后补齐。逐字节重编码一致才能接受，精确位值恢复后调用正式校验。D1用已批准默认构造ExecutionPolicy和身份；BoundaryControl不扩展旧算法API。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 整数测试放合法int64字段如manifest.byte_length之外需限制值时用wire内部数值测试，不把不合法record冒称成功输入；最终Real作者/Intent/Trace往返还需D2/I2；没有第二codec改变Level hash。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4D-2 — 已保存快照与受控工程

**Files:** `tools/foundation/authoring_acceptance/snapshot_capture.gd`, `tools/foundation/authoring_acceptance/execution_project.gd`, `tools/foundation/authoring_acceptance/execution_dependencies.json`, `tests/foundation/authoring_acceptance/test_saved_snapshot.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** A_SCHEMA/A_BAKE、D_PROTOCOL；明确源项目和LevelRef

**Interfaces — produces:** capture_saved/capture/materialize、不可变input.ready；D_SAVED交付

- [ ] **RED：** 封包中改变一个依赖、缺UID、缺动态模块、engine hash不符必须停链；同源两run source_fingerprint相同（定位/来源也相同），run_id不同；后台移走活动源后仍只用包。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-2 -Mode Real -EvidenceName 4d_4d-2_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var captured := Capture.capture_saved(request, project_root)
check(captured.ok, "saved closure captured")
var sealed := captured.value
check(sealed.identity.source_fingerprint == repeat_capture.value.identity.source_fingerprint, "stable source digest")
check(sealed.identity.run_id != repeat_capture.value.identity.run_id, "unique execution identity")
check(not capture_after_external_change.ok, "CAPTURE_CHANGED is not disk fallback")
check(worker_read_paths.all(func(p): return p.begins_with(sealed.root_path)), "worker uses controlled package")
```

- [ ] **GREEN：** 先冻结源文件字节，用A投影及闭包装配，摘要命名附件，前后检查文件hash/身份。execution/project保持res路径，仅白名单代码/配置；正式Reader/Baker由4A调用。快照manifest字段、两种来源和稳定source-manifest投影按批准合同，排除run路径。capture_saved只承诺磁盘，UI完整入口需D5保存核对后调用。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** input.ready前不启动；非E根明确要求E运行位置；复制受控执行依赖只作每run输入物化，不是跨Owner源码Git集成。A未交付不能mock后标真实capture通过。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4D-3 — 正式产物加载与通用白盒手动宿主

**Files:** `tools/foundation/authoring_acceptance/canonical_loader.gd`, `tools/foundation/authoring_acceptance/whitebox_host.gd`, `tools/foundation/authoring_acceptance/whitebox_host.tscn`, `tools/foundation/authoring_acceptance/whitebox_entry.gd`, `tests/foundation/authoring_acceptance/test_whitebox_host.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** D_SAVED与A_BAKE；正式Codec.decode、Session/Presenter/InputMapper；不依赖完整Dock或C

**Interfaces — produces:** canonical_loader、WhiteboxHost、whitebox_entry；D_HOST交付供I1

- [ ] **RED：** 损坏canonical、错snapshot、Bake失败后保留旧host均拒绝；加载哈希精确，真实MOVE/旋转/Shift/Goal/Reset；晚到动画回调不重复提交。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-3 -Mode Graphical -EvidenceName 4d_4d-3_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var loaded := host.load_artifact(snapshot_ref, canonical_ref)
check(loaded.ok and host.loaded_hash() == baked.level.content_hash, "real artifact installed")
var result := host.submit_action(action)
check(result == host.session.last_result, "formal session owns transition")
# 等待Presenter自然finished与Session.committed信号，不能用固定sleep强制完成。
host.reset_run()
check(StateKey.build(baked.level, host.session.state).key == initial_key, "formal Reset")
```

- [ ] **GREEN：** 新host不继承固定runtime_fixture，不在_ready里烘焙另一关；canonical_loader先核本轮摘要/输入，再正式Codec.decode和Session.load_level。输入使用正式input_mapper.gd::map_move(frame:Dictionary,camera_basis:Basis,screen_direction:Vector2)->Dictionary、map_rotation(intent:int,camera_basis:Basis,world:Dictionary)->Dictionary，SHIFT/USE构造正式Action。Session.transition_started提供is_global及token，Presenter自然完成后按该标志调用finish_local/finish_global，绝不单凭global_kind推测MOVE+ENTER提交路径。Reset清自有Tween/预览后Session.reset。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** host.session仅测试读取状态，不向外提供写入入口；对白盒使用正式cell_size，不固定美术比例。手动宿主独立测试入口暂不宣称产品完整Acceptance；后续插件通过D4单槽启动。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

D3入口参数在whitebox_entry.gd明确创建：`--run-dir=<E盘run绝对目录>`；读取该run的input.ready和已完成Bake阶段记录中的canonical ArtifactRef，拒绝任意直接Level Dictionary或缺失阶段产物。未来手动复验命令（入口尚未创建，本轮NOT_RUN）：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path $executionProject --script res://tools/foundation/authoring_acceptance/whitebox_entry.gd -- --run-dir=$runDirectory
```

`$executionProject`和`$runDirectory`必须从D2实际SnapshotRef/materialize输出读取，不能手填另一fixture路径。4D-3的Graphical测试会记录二者；最终由I1给出用户可重复入口。

### 4D-4 — 独立宿主、单槽、合作取消与真实回放

**Files:** `tools/foundation/authoring_acceptance/task_service.gd`, `tools/foundation/authoring_acceptance/process_transport.gd`, `tools/foundation/authoring_acceptance/worker_entry.gd`, `tools/foundation/authoring_acceptance/graphical_entry.gd`, `tests/foundation/authoring_acceptance/test_task_lifecycle.gd`, `tests/foundation/authoring_acceptance/owned_worker_fixture.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** D_PROTOCOL/D_SAVED/D_HOST；C_QUALITY可在后续接入但未就绪阶段不得执行；正式Replayer.replay

**Interfaces — produces:** task_service/process_transport/worker_entry/graphical_entry；D_JOBS交付

- [ ] **RED：** owned_worker_fixture在正式调用边界间阻塞可控信号：取消后不能启动第二任务，返回边界后才清理；sequence重复/错run/迟到结果拒绝；插件卸载仍等待。真实Replayer不提供cancel，测试必须允许自然整段返回。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-4 -Mode Unit -EvidenceName 4d_4d-4_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var started := service.start(request)
var stopped := service.cancel(started.value.identity)
check(stopped.value.lifecycle == "CANCELLING", "cancel acknowledgement is not stop confirmation")
check(not service.start(request).ok, "slot held until release")
check(not service.status(started.value.identity).value.release_confirmed, "resources still owned")
# tests-only worker收到释放信号并实际退出；再轮询父服务。
var released_status := service.status(started.value.identity)
check(released_status.ok and released_status.value.lifecycle == "CANCELLED" and released_status.value.release_confirmed, "observed release")
```

- [ ] **GREEN：** 文件IPC一写者单调sequence，先附件后消息，HELLO验证engine/module/identity；OS.create_process只启动受控entry且只观察自有PID，不kill。清理Node独立于B控件，父租约按批准值；退出不能仅信EXIT消息，须进程退出和资源清理。GRAPHICAL从同canonical/trace经正式验证、Spawn绑定后实例Replayer await；返回取消后不能发布PASS。手动宿主也占同一重槽。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** fixture只验协议；另用4C真实同步调用和原Replayer完成Real/Graphical测试，记录取消延迟但不以短耗时推导有界回收。未确认退出保持槽，不接管美术进程。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4D-5 — 未保存一致捕获与保存核对

**Files:** `tools/foundation/authoring_acceptance/snapshot_capture.gd`, `tests/foundation/authoring_acceptance/test_current_snapshot.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** A_SCHEMA、D2同一捕获实现、B1 EditorContext；真实Editor API能力

**Interfaces — produces:** ANALYZE_CURRENT与ACCEPT_SAVED完整入口，无第二快照格式

- [ ] **RED：** 主场景旧实例、独立World未保存、共享Intent未保存、资源同路径不同版本、未保存新文档、玩法实例覆盖及捕获期间外部变更分别测试；saved入口不得静默保存无关文档。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-5 -Mode Editor -EvidenceName 4d_4d-5_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var analyzed := Capture.capture(analyze_request, editor_context)
check(analyzed.ok and analyzed.value.input_mode == "ANALYZE_CURRENT", "captures current buffers")
check(projected_current_world_value == edited_world_value, "not stale Level instance")
check(not Capture.capture(saved_request, editor_context).ok, "SAVE_REQUIRED until explicit save")
check(not unsupported_override_result.ok, "override is an error, never ignored")
check(unrelated_scene_bytes == original_unrelated_bytes, "no save_all_scenes")
```

- [ ] **GREEN：** 使用B提供相关open roots做同步主线程A投影，不await跨活对象复制；关联资源闭包和覆盖来源明确。前后重新核对generation/投影/磁盘，冲突释放锁且不启动。新未保存文档用editor URI可分析，完整验收必须路径持久化/保存确定；无法证明一致即SAVE_REQUIRED/UNKNOWN，不伪造dirty API。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 必须真实独立World编辑测试，不能只用内存double证明Editor捕获；断开后台活引用；捕获后源再编辑只令当前性过期，原快照继续。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4D-6 — 唯一汇总、当前性、归档与导出

**Files:** `tools/foundation/authoring_acceptance/report_aggregator.gd`, `tools/foundation/authoring_acceptance/archive_store.gd`, `tools/foundation/authoring_acceptance/report_currentness.gd`, `tests/foundation/authoring_acceptance/test_reports_archive.gd`, `tests/foundation/authoring_acceptance/file_store_double.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 真实C_QUALITY/Replay阶段；D身份/wire；批准合同§7/§9

**Interfaces — produces:** summarize/publish/read_archive/export_archive/compare；D_FULL报告部分

- [ ] **RED：** 全门槛、硬反例+不完整、错误/取消优先、安全未知、空Intent、局部分析、当前性Undo；故障注入每个写/close/hash/rename/manifest边界。先模拟最后manifest失败确认技术全绿也不能最终PASS。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-6 -Mode Unit -EvidenceName 4d_4d-6_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
check(run_evidence.entry_kind == "ANALYZE_CURRENT", "current-buffer case")
var candidate := Aggregator.summarize(run_evidence)
check(candidate.summary.verdict == "UNDETERMINED", "analysis cannot accept")
var publication := Store.publish(evidence_with_manifest_failure)
check(not publication.ok, "publication failure explicit")
check(failed_report.summary.completion == "ERROR" and failed_report.summary.verdict == "UNDETERMINED", "no final pass without manifest")
check(original_published_bytes == after_failed_export_bytes, "export cannot rewrite historical report")
```

- [ ] **GREEN：** report_aggregator唯一门槛，保留native_result；可信硬反例优先FAIL，缺证据UNDETERMINED；安全未知保留算法枚举但禁止PASS。archive_store附件close/重读验证、无覆盖rename、最后manifest，report不含自身/manifest哈希避免循环。取消可发布真实部分报告，发布完成不等于通过。currentness比较输入/版本/策略及编辑代次，Undo不恢复当前PASS。首次发布失败按批准规则，后续ExportResult独立。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** file_store_double只注入自有文件端口故障并明确记录；另运行真实E盘写入/坏包/无覆盖导出及I3完整链；不声称断电持久性或跨文件事务。graph_archive只读，不交Softlock。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4D-7 — 唯一只读Shared Space状态视图

**Files:** `tools/foundation/authoring_acceptance/state_view.gd`, `tests/foundation/authoring_acceptance/test_state_view.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 正式Geometry.snapshot/Math.columns/DerivedQueries、已验证canonical/state/完整StateKey；D服务生命周期

**Interfaces — produces:** inspect_state/release_view；D_FULL视图交付，B只装配

- [ ] **RED：** trace初态0/第N步/软锁状态显示匹配，非法state/key/损坏图返回错误且不留旧图层；浏览不改源字节/Session；显示同空间而非Presenter±2.4。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4D -Case 4D-7 -Mode Graphical -EvidenceName 4d_4d-7_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var view := StateView.inspect_state(request)
check(view.ok and view.value.state_key == request.state_key, "bound formal state")
check(view.value.origin == "TRACE_EXPECTED", "expected not measured")
check(authoring_digest_before == authoring_digest_after, "source untouched")
check(session_key_before == session_key_after, "Runtime not restored from preview")
StateView.release_view(view.value.view_id)
StateView.release_view(view.value.view_id) # 幂等且无孤立节点
```

- [ ] **GREEN：** state形状/StateKey及trace语义校验后，消费正式Geometry.snapshot的cube/frame派生值、Math columns和cell_size生成白盒；不复制WGC/光照/shift判断。失败清理本次节点；历史状态显式历史标签，D管root生命周期，B管相机/容器。真实Replayer仍原Presenter分层布局，不能用只读视图替换GRAPHICAL验收。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 不同cell_size和旋转构型与正式几何输出对照；SRC/Preview/Runtime三者各自隔离；不把graph.complete文件标志视为来源证明。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

## 验收与停止

各新命令当前NOT_RUN；4D-1/4/6的Unit覆盖协议/故障端口，后续须同Case以Real或Graphical/Editor模式运行真实用例（I0 manifest明确登记支持组合）。D2/D3先交I1可运行纵向链，不能等全部界面齐备才接运行；D5未保存分析仍是最终必需，不能删去。

现有对照（本轮NOT_RUN）：

```powershell
pwsh -NoProfile -File tests/foundation/runtime/run_validation.ps1 -EvidenceName f4d_runtime_01
pwsh -NoProfile -File tests/foundation/parity/run_validation.ps1 -EvidenceName f4d_parity_01
```

完成条件：D_PROTOCOL/D_SAVED/D_HOST/D_JOBS/D_FULL各交真实SHA及对应证据，所有最终回放/编辑/文件路径都使用真实依赖；取消迟到隔离、发布失败与当前性有实际用例。API能力缺失、实际字段冲突、未知依赖或无图形窗口分别DEPENDENCY_PENDING/CONTRACT_MISMATCH/NOT_RUN，不能用强杀、旧结果、私有测试seam或假的MATCH收口。
