# FOUNDATION-4 4B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task after explicit execution approval. Steps use checkbox (`- [ ]`) syntax. 本轮仅编制计划；后续拟采用四Owner独立worktree，具体启动仍须用户授权，不自动派生实现任务。

**Goal:** 让作者通过唯一插件编辑真实4A数据，调用4D服务并准确查看正式结果。

**Architecture:** 插件装配4A数据操作与4D单一服务；UI不保留另一可写地图模型。Inspector和视口共用FaceSelection，UndoRedo应用4A预检proposal；状态视图只由4D创建/释放。

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

- EditorInterface当前标签不是对象所属文档 → B2依据document_root选UndoRedo历史。
- 原生复制/Editable Children覆盖绕过工具操作 → B2/B3诊断拒绝，不静默修号或忽略覆盖。
- 报告旧数组下标选择到新对象 → B3复核authoring_id/currentness，不按旧索引猜。
- 插件卸载时D仍CANCELLING → B4注销UI后保留D清理服务，重新启用只接回一份。
- SOURCE/PREVIEW/RUNTIME被同一个绿色标签混淆 → B4三种来源标签和截图/操作验证。

## 禁止范围

不写foundation/authoring生产文件、4C质量、4D预览/任务/wire/汇总器、旧FOUNDATION和P-01。`project.godot`启用列表仅Integration I3修改，4B只创建plugin.cfg/plugin.gd。共同测试wrapper与case_manifest归Integration I0；4B提供精确case路径请求登记。MOC不由4B改。

## 精确文件所有权

下列路径相对实施worktree根；同名`.gd.uid`逐项归同Owner，实施导入后纳入正式源依赖。未列文件不得顺手修改。表内tests/路径同时是本任务的Test文件；Create表示未来创建，后续任务对同Owner已创建文件的扩展仍由该Owner维护。

| 操作 | 文件 | 责任 / 创建任务 |
|---|---|---|
| Create | `addons/block_girl_level_tools/plugin.cfg` | 4B-1：唯一产品EditorPlugin注册 |
| Create | `addons/block_girl_level_tools/plugin.gd` | 4B-1：唯一入口，服务连接和卸载 |
| Create | `addons/block_girl_level_tools/plugin.gd.uid` | 4B-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/editor_context.gd` | 4B-1：文档根/资源/变化代次只读端口，不捕获封包 |
| Create | `addons/block_girl_level_tools/editor_context.gd.uid` | 4B-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/level_dock.gd` | 4B-1：最小上下文及服务调用，再扩展报告UI |
| Create | `addons/block_girl_level_tools/level_dock.gd.uid` | 4B-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/face_inspector.gd` | 4B-2：Inspector六面与机制字段编辑 |
| Create | `addons/block_girl_level_tools/face_inspector.gd.uid` | 4B-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/face_gizmo.gd` | 4B-2：视口命中同一局部面、基础标记/关系线 |
| Create | `addons/block_girl_level_tools/face_gizmo.gd.uid` | 4B-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/edit_transaction.gd` | 4B-2：所属文档UndoRedo应用A proposal |
| Create | `addons/block_girl_level_tools/edit_transaction.gd.uid` | 4B-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/diagnostic_selection.gd` | 4B-3：问题定位、过期/失配拒绝当前高亮 |
| Create | `addons/block_girl_level_tools/diagnostic_selection.gd.uid` | 4B-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/report_panel.gd` | 4B-3：正式结果显示，绝不重判verdict |
| Create | `addons/block_girl_level_tools/report_panel.gd.uid` | 4B-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `addons/block_girl_level_tools/state_view_host.gd` | 4B-4：只装配D视图句柄与选择/相机 |
| Create | `addons/block_girl_level_tools/state_view_host.gd.uid` | 4B-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/editor/test_editor_ports.gd` | 4B-1：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/test_editor_ports.gd.uid` | 4B-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/editor/service_double.gd` | 4B-1：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/service_double.gd.uid` | 4B-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/editor/plugin.cfg` | 4B-1：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/editor_test_driver.gd` | 4B-1：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/editor_test_driver.gd.uid` | 4B-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/editor/test_face_editing.gd` | 4B-2：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/test_face_editing.gd.uid` | 4B-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/editor/test_diagnostics.gd` | 4B-3：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/test_diagnostics.gd.uid` | 4B-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/editor/test_plugin_lifecycle.gd` | 4B-4：测试专用；QA插件与产品插件严格分开 |
| Create | `tests/foundation/editor/test_plugin_lifecycle.gd.uid` | 4B-4：对应脚本持久UID，只在所属任务受控导入生成 |

## 新接口、编辑与查看边界

| 文件 / 公开签名 | 输入输出及失败 |
|---|---|
| editor_context.gd `describe(level_ref:Dictionary)->Dictionary` | Result.value=EditorContext；缺文档/歧义失败。只提供活引用，限4D捕获主线程使用，不做后台遍历 |
| editor_context.gd `current_generation()->int`、`set_capture_lock(locked:bool)->void` | 记录相关源修改代次及限制本插件源编辑；不声称锁住外部磁盘/原生编辑器所有操作 |
| face_inspector.gd / face_gizmo.gd `select_face(selection:Dictionary)->void` | FaceSelection=`{document_uri:String,cube_authoring_id:String,face:int}`；两个入口发同一`face_selected(selection:Dictionary)`信号，不改变源 |
| edit_transaction.gd `apply_proposal(proposal:Dictionary,undo_manager:EditorUndoRedoManager)->Dictionary` | Result.value=`{action_name:String,document_uri:String}`；需要确认而未确认不得调用；失败弃置A新对象且源不变 |
| diagnostic_selection.gd `select_issue(issue:Dictionary,source_map:Dictionary,currentness:String)->Dictionary` | 调A.locate；Result.value为实际匹配的FaceSelection或对象定位数组；STALE/UNKNOWN不覆盖当前源高亮 |
| report_panel.gd `show_report(report:Dictionary,currentness:String,integrity:String)->void` | 展示4D值；不计算PASS、不把COMPLETE当PASS，损坏报告显示读取错误 |
| state_view_host.gd `attach_view(handle:Dictionary)->void`、`detach_view()->void` | handle为D ViewHandle；D服务负责释放，B只移除容器关联；不写Geometry/Session |
| plugin.gd `_enter_tree()->void`、`_exit_tree()->void` | Godot入口：装配一份Dock/Inspector/Gizmo和D服务引用；卸载断开本插件信号并请求D取消，不free未清理D进程服务 |

EditorContext=`{editor_instance_id:String,level_ref:Dictionary,open_roots:Array[Node],semantic_resources:Array[Resource],generation:int,document_contexts:Array[Dictionary]}`，DocumentContext沿A1。Node/Resource引用只在本进程短时捕获用，不进wire；D捕获完毕不得保留活引用。changed信号对应相关作者编辑/Resource.changed/UndoRedo/外部依赖通知；无法判断完整性交D标UNKNOWN，不自行签CURRENT。

源修改：字段、创建/复制/删除、绑定、组成员、专用化进入所属文档UndoRedo，并增加generation；查看：选面、相机、显隐、过滤、报告/步骤浏览只改UI；运行：start/cancel/replay/export调用D，不放入UndoRedo。Level内出现不支持玩法覆盖时展示UNSUPPORTED_AUTHORING_OVERRIDE并阻止启动，不能投影时忽略掉继续分析。

新测试QA入口：`tests/foundation/editor/plugin.cfg`仅在I0隔离Editor测试工程启用，脚本editor_test_driver.gd extends EditorPlugin，`run_case(case_id:String)->Dictionary`；测试case脚本公开`run(editor_plugin:EditorPlugin,tools_plugin:EditorPlugin)->Dictionary`返回TestSuite结果。它读取命令行case，待Editor完成初始化后执行，写实际证据并退出测试工程。生产plugin.cfg绝不引用QA。`service_double.gd`只实现D的start/cancel/status/inspect/release窄接口并记录调用，Unit模式才装配；Real Editor/最终交付拒绝它。

消费接口：4A.prepare_edit/locate/project_document按A计划完整签名；4D.get_or_create(editor_root:Node,editor_instance_id:String)->Node、bind_editor_context/unbind_editor_context、start/cancel/status、inspect_state/release_view按D计划。editor_context.gd extends RefCounted，实现provider；B启动时绑定，卸载先取消后解绑。B1单元可先使用service_double，但真正插件服务接入依赖A_SCHEMA/D_PROTOCOL/D_JOBS的已集成提交。

最小事务实现边界（B2）：

```gdscript
undo_manager.create_action("Edit authoring", UndoRedo.MERGE_DISABLE, document_root, false, true)
# proposal.before/after逐项add_undo_property/add_do_property；新对象加do/undo引用。
# hierarchy_changes按ADD/REMOVE登记add_child/remove_child、move_child及owner恢复；Undo逆序。
undo_manager.commit_action()
# 不在这里保存文件、运行求解或写report.verdict。
```

### 4B-1 — 唯一插件入口、文档端口和最小Dock

**Files:** `addons/block_girl_level_tools/plugin.cfg`, `addons/block_girl_level_tools/plugin.gd`, `addons/block_girl_level_tools/editor_context.gd`, `addons/block_girl_level_tools/level_dock.gd`, `tests/foundation/editor/test_editor_ports.gd`, `tests/foundation/editor/service_double.gd`, `tests/foundation/editor/plugin.cfg`, `tests/foundation/editor/editor_test_driver.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** I_HARNESS；A_SCHEMA和D_PROTOCOL（Unit可用明示service_double）

**Interfaces — produces:** 上述EditorContext、唯一plugin入口、QA driver，Dock仅必需源选择/运行状态

- [ ] **RED：** 插件启停两次只有一份Dock/Inspector/Gizmo及信号连接；当前Level与独立World缓冲准确登记；未到真实服务时显示DEPENDENCY_PENDING而不是可运行假按钮。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4B -Case 4B-1 -Mode Unit -EvidenceName 4b_4b-1_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
# Unit用service_double，仅证明UI调用；真实Editor用例运行同一插件生命周期。
check(dock_count == 1 and inspector_count == 1, "one plugin entry")
check(context.open_roots.has(open_world_root), "independent World source present")
check(fake_service.calls.size() == 1, "one explicit click starts once")
check(fake_service.calls[0].request.entry_kind == "ANALYZE_CURRENT", "entry remains explicit")
```

- [ ] **GREEN：** 注册唯一plugin.cfg，文档端口枚举相关根及资源，按A schema校验身份；UI先只显示依赖、分析/验收入口和任务状态。保存仅列相关清单，不调用save_all_scenes；在QA隔离工程测试，不改main或主工程入口。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 运行一次真实Editor模式复验无重复连接；Unit成功只交UI局部证据，A/D未到位不宣告编辑器集成完成。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4B-2 — 六面选择、机制Inspector和文档撤销

**Files:** `addons/block_girl_level_tools/face_inspector.gd`, `addons/block_girl_level_tools/face_gizmo.gd`, `addons/block_girl_level_tools/edit_transaction.gd`, `tests/foundation/editor/test_face_editing.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** A_EDIT的prepare_edit/discard_proposal、正式几何仅作显示；EditorUndoRedoManager

**Interfaces — produces:** 两个选面入口、字段变更和proposal事务；基础World/Slot/Spawn/Exit/组pivot/关系线标记

- [ ] **RED：** 两个入口选择同一Cube局部Face；编辑Inner文档时即使Level标签打开也进入Inner历史；COPY/DELETE/MAKE_UNIQUE可撤销；删除默认取消，确认后保留dangling refs；Redo不生成新ID。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4B -Case 4B-2 -Mode Editor -EvidenceName 4b_4b-2_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
check(viewport_selection == inspector_selection, "same local face identity")
var previous_id: String = copied.authoring_id
undo_manager.get_history_undo_redo(history_id).undo()
undo_manager.get_history_undo_redo(history_id).redo()
check(copied.authoring_id == previous_id, "redo reuses identity")
check(target_binding == original_target_binding, "copy does not remap target")
```

- [ ] **GREEN：** 视口命中只解出Cube本地face，不根据旋转后世界normal重命名；调用A预检和所属文档UndoRedo。配置关系线标未验证，逻辑光照/连接只消费正式派生结果。共享配置先明示影响，专用化用A白名单。一次拖动一次action。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 所有临时操作副本有UndoRedo持有或清理责任；不添加永久六面Node；非离散Transform显示正式错误，不自动吸附；字段没有双写来源。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4B-3 — 正式诊断、来源定位和报告展示

**Files:** `addons/block_girl_level_tools/diagnostic_selection.gd`, `addons/block_girl_level_tools/report_panel.gd`, `tests/foundation/editor/test_diagnostics.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** A.source_map.locate；D.currentness/report/integrity；正式不同issue形状

**Interfaces — produces:** select_issue与show_report，不提供verdict汇总函数

- [ ] **RED：** Reader早期空entity_ids、canonical重排、AnalysisIssue.upstream、QualityFinding.subject_ids分别定位；改名保持作者ID但旧映射过期；missing/duplicate定位失败不选最近Cube。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4B -Case 4B-3 -Mode Editor -EvidenceName 4b_4b-3_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
check(old_report_currentness == "STALE", "editing invalidates pass")
check(current_green_visible == false, "historical PASS is not current")
check(unlocated_selection.is_empty(), "ambiguous mapping selects nothing")
check(rendered_scope.contains("SINGLE_TRACE"), "milestones keep scope")
check(empty_scope_label == "验收通过 · 未声明设计约束", "qualified empty intent")
```

- [ ] **GREEN：** 展示原status/budget/issues及4D verdict/currentness，不重判安全/可解性；按类型提取实体和source map定位，无法匹配显示整关问题；未知/损坏归档不显示可信当前绿灯。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 展示四维：生命周期、原模块结论、验收汇总、当前性；源选择仅在身份复核成功时执行；局部分析始终非整关验收。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4B-4 — 唯一视图装配与运行中卸载

**Files:** `addons/block_girl_level_tools/state_view_host.gd`, `tests/foundation/editor/test_plugin_lifecycle.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** D_JOBS、D7只读视图、D3/D4白盒与Replayer；同轮身份

**Interfaces — produces:** attach/detach，步骤自由浏览及真实整段入口；B_EDITOR交付

- [ ] **RED：** 切步骤只改PREVIEW，不改作者/Session；真实运行显示RUNTIME；取消/卸载UI后D仍CANCELLING，重新启用连接同一服务；旧run迟到不得覆盖新Level。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4B -Case 4B-4 -Mode Editor -EvidenceName 4b_4b-4_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
check(author_bytes_after == author_bytes_before, "inspection is readonly")
check(preview_label == "解法预期状态", "not measured runtime")
check(runtime_session_state == runtime_state_before_inspection, "no state injection")
check(service_before.get_instance_id() == service_after.get_instance_id(), "reconnect same cleanup owner")
check(status.ok and status.value.lifecycle == "CANCELLING" and not next_start.ok, "release not yet confirmed")
```

- [ ] **GREEN：** B只把D ViewHandle挂入UI容器、切相机与步骤参数。真实回放从Spawn整段，按钮共用D重任务槽；插件卸载取消并释放自己的显示订阅，D资源由D确认释放。完成真实Editor和Graphical用例后才能交B_EDITOR。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 无第二个preview计算器/任务管理器；SOURCE/PREVIEW/RUNTIME清楚标识；未完成Replayer不能显示MATCH。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

## 验收、依赖及停止

所有新命令当前NOT_RUN。4B-1的Unit命令后，必须以`-Mode Editor`和新EvidenceName运行真实QA；4B-2/3/4默认真实Editor。图形窗口与美术渲染协调，无法运行即NOT_RUN，不用合成截图替代操作。插件最终接真实A/D，源保存/重开由I3复验。

完成条件：唯一入口、两个选面入口一致、单文档UndoRedo、诊断/过期显示、状态只读及卸载重接均有实测；无生产service_double。缺A_EDIT/D_JOBS/D_FULL则相关用例DEPENDENCY_PENDING，不能签全流程PASS；越界修改需求先交Owner/Integration评审，禁止本Owner接管共享文件。
