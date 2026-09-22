# FOUNDATION-4 4A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task after explicit execution approval. Steps use checkbox (`- [ ]`) syntax. 本轮仅编制计划；后续拟采用四Owner独立worktree，具体启动仍须用户授权，不自动派生实现任务。

**Goal:** 形成真实作者声明→正式Reader/Baker的唯一适配，交付身份、资源编辑、Intent绑定与来源映射。

**Architecture:** 新作者脚本只保存声明；document_projector和payload_assembler消除SceneTree/Resource引用后交authoring_adapter。正式Reader独占量化及六面生成，Baker独占正式验证；源编辑proposal交4B应用，wire与摘要交4D。

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

- 同一外部Resource路径出现两个不同缓冲版本 → A1冲突拒绝，不挑一份。
- 新World源已修改而主场景旧实例未刷新 → A1拒绝玩法覆盖，D5优先源投影。
- 无效Transform接近量化阈值 → A2原样传递，正式Reader决定接受/拒绝。
- 专用副本嵌套别名和Redo新ID变化 → A3保留内部别名、复用预分配身份。
- 绑定失败后残留上轮Intent/level → A4返回null并保留同轮标识。

## 范围与禁止修改

仅维护下表新文件。禁止修改foundation/level、contracts、rules、spatial、validation、solver、quality、runtime、parity和prototype旧fixture；禁止写addons插件、4D wire/任务、project.godot、共享wrapper及MOC。4A返回工具值诊断，不能执行第二份空间验证、排序哈希或质量判定。

## 精确文件所有权

下列路径相对实施worktree根；同名`.gd.uid`逐项归同Owner，实施导入后纳入正式源依赖。未列文件不得顺手修改。表内tests/路径同时是本任务的Test文件；Create表示未来创建，后续任务对同Owner已创建文件的扩展仍由该Owner维护。

| 操作 | 文件 | 责任 / 创建任务 |
|---|---|---|
| Create | `foundation/authoring/authoring_schema.gd` | 4A-1：封闭作者schema、字段类型、版本和profile检查 |
| Create | `foundation/authoring/authoring_schema.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/level_authoring_root.gd` | 4A-1：关卡/Spawn/Exit/Celestial与两World装配引用 |
| Create | `foundation/authoring/level_authoring_root.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/world_authoring_root.gd` | 4A-1：世界声明与单位变换约束 |
| Create | `foundation/authoring/world_authoring_root.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/cube_authoring_node.gd` | 4A-1：稳定Cube身份与原始Transform、六面资源 |
| Create | `foundation/authoring/cube_authoring_node.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/slot_authoring_node.gd` | 4A-1：Slot身份和原始位置 |
| Create | `foundation/authoring/slot_authoring_node.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/group_authoring_node.gd` | 4A-1：唯一cube_ids成员写入及正式组配置 |
| Create | `foundation/authoring/group_authoring_node.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/mechanism_authoring_node.gd` | 4A-1：实例身份/host_face/触发与目标绑定 |
| Create | `foundation/authoring/mechanism_authoring_node.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/transition_authoring_node.gd` | 4A-1：显式FaceTransition作者声明 |
| Create | `foundation/authoring/transition_authoring_node.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/face_authoring_resource.gd` | 4A-1：六面内嵌可变资源 |
| Create | `foundation/authoring/face_authoring_resource.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/mechanism_config.gd` | 4A-1：白名单可复用机制语义参数 |
| Create | `foundation/authoring/mechanism_config.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/intent_authoring_resource.gd` | 4A-1：独立版本作者Intent，不保存level_hash |
| Create | `foundation/authoring/intent_authoring_resource.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/milestone_authoring_resource.gd` | 4A-1：required/predicate/有序里程碑 |
| Create | `foundation/authoring/milestone_authoring_resource.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/bypass_authoring_resource.gd` | 4A-1：bypass_id与disabled_mechanics |
| Create | `foundation/authoring/bypass_authoring_resource.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/document_projector.gd` | 4A-1：编辑根或冻结SceneState只读投影 |
| Create | `foundation/authoring/document_projector.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/payload_assembler.gd` | 4A-1：文档闭包与资源别名表装配 |
| Create | `foundation/authoring/payload_assembler.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/authoring_adapter.gd` | 4A-2：唯一临时旧profile→正式Reader/Baker |
| Create | `foundation/authoring/authoring_adapter.gd.uid` | 4A-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/source_map.gd` | 4A-2：作者/Reader/canonical位置映射 |
| Create | `foundation/authoring/source_map.gd.uid` | 4A-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/id_registry.gd` | 4A-3：正式ID校验/候选分配和作者UUID |
| Create | `foundation/authoring/id_registry.gd.uid` | 4A-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/edit_operations.gd` | 4A-3：复制/删除/专用化预检与proposal，不提交UndoRedo |
| Create | `foundation/authoring/edit_operations.gd.uid` | 4A-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `foundation/authoring/intent_binder.gd` | 4A-4：唯一同轮保义Intent绑定 |
| Create | `foundation/authoring/intent_binder.gd.uid` | 4A-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring/authoring_fixtures.gd` | 4A-1：本Owner测试支持或行为用例 |
| Create | `tests/foundation/authoring/authoring_fixtures.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring/test_authoring_documents.gd` | 4A-1：本Owner测试支持或行为用例 |
| Create | `tests/foundation/authoring/test_authoring_documents.gd.uid` | 4A-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring/test_authoring_bake.gd` | 4A-2：本Owner测试支持或行为用例 |
| Create | `tests/foundation/authoring/test_authoring_bake.gd.uid` | 4A-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring/test_authoring_edits.gd` | 4A-3：本Owner测试支持或行为用例 |
| Create | `tests/foundation/authoring/test_authoring_edits.gd.uid` | 4A-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring/test_intent_binding.gd` | 4A-4：本Owner测试支持或行为用例 |
| Create | `tests/foundation/authoring/test_intent_binding.gd.uid` | 4A-4：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring/fixtures/minimal/level.tscn` | 4A-1：独立作者文档保存/加载fixture |
| Create | `tests/foundation/authoring/fixtures/minimal/surface.tscn` | 4A-1：独立作者文档保存/加载fixture |
| Create | `tests/foundation/authoring/fixtures/minimal/inner.tscn` | 4A-1：独立作者文档保存/加载fixture |
| Create | `tests/foundation/authoring/fixtures/minimal/intent.tres` | 4A-1：独立作者文档保存/加载fixture |

## 公开接口与封闭作者数据（均需新建）

方法均static，除Resource/Node声明类；所有Result按集成计划定义。入口只支持白名单节点/资源，未知脚本/继承覆盖拒绝，不实例化任意作者脚本。内存投影与磁盘投影采用同一字段表。

| 文件 / 新接口完整签名 | value或专用返回 / 失败 |
|---|---|
| document_projector.gd `project_document(source:Variant, document_context:Dictionary)->Dictionary` | source仅受支持Node3D、冻结SceneState或白名单语义Resource；Result.value=AuthoringDocument；unknown/override/type失败value=null；Resource文档root_transform=IDENTITY，无伪造空间节点 |
| payload_assembler.gd `assemble_payload(documents:Array[Dictionary], level_ref:Dictionary)->Dictionary` | Result.value=AuthoringPayload；相同资源身份异值RESOURCE_VERSION_CONFLICT，重复/缺失文档失败 |
| authoring_schema.gd `validate_authoring(payload:Dictionary)->Dictionary` | `{ok:bool,issues:Array[ToolIssue]}`；只作者形状/ID/引用/层级，不提前判Safety |
| authoring_adapter.gd `bake_authoring(payload:Dictionary,bake_options:Dictionary,snapshot_identity:Dictionary)->Dictionary` | `{ok:bool,level:Dictionary或null,issues:Array[Dictionary],validation:Dictionary或null,source_map:Dictionary}`；原Reader/Baker issues保留；失败level=null；临时树每个出口释放 |
| source_map.gd `locate(map:Dictionary,issue:Dictionary,phase:String)->Dictionary` | Result.value=Array[SourceMap.Entry]；无法唯一匹配返回空数组并附明确未定位诊断；不猜最近对象 |
| id_registry.gd `allocate(entity_kind:String,existing_ids:Array[StringName])->Dictionary` | Result.value=`{authoring_id:String,entity_id:StringName}`；词法沿旧合同，不与旧ID冲突 |
| edit_operations.gd `prepare_edit(operation:String,object_ref:Dictionary,context:Dictionary)->Dictionary` | Result.value=EditProposal；仅COPY/DELETE/MAKE_UNIQUE；无源副作用；失败不产生部分新对象 |
| intent_binder.gd `bind_intent(authoring_intent:Dictionary,successful_bake:Dictionary,snapshot_identity:Dictionary)->Dictionary` | `{ok:bool,bound_intent:Dictionary或null,source_intent_digest:String或null,issues:Array[ToolIssue]}`；来源校验失败null；source_intent_digest从4D给定身份回传，不自行编码/hash |

AuthoringDocument=`{authoring_version:String,document_uri:String,document_authoring_id:String,kind:String,root_transform:Transform3D,records:Array[Dictionary],resources:Array[Dictionary],dependencies:Array[String],override_paths:Array[String]}`；kind=LEVEL/WORLD/INTENT/CONFIG。每个records条目=`{kind:String,authoring_id:String,node_path:String,label:String,fields:Dictionary}`。fields按批准Tool Contracts §3该kind的完整字段白名单；空间字段原始Transform3D，面引用为`{cube_id:StringName,face:int}`。默认新建值由显式创建工厂给出，加载缺字段不能偷偷补值。

AuthoringPayload=`{authoring_version:String,level_ref:LevelRef,documents:Array[AuthoringDocument],resource_table:Array[Dictionary]}`。资源条目=`{authoring_id:String,kind:String,document_uri:String,resource_uid:String或null,fields:Dictionary}`；字段资源引用统一值`{resource_ref:String}`指向authoring_id，不遗留Object地址。资源kind只允许FACE/MECHANISM_CONFIG/INTENT/MILESTONE/BYPASS；字段恰按批准§3.2/§4，语义循环失败。原始场景存Resource引用，投影才展开此表；这是作者字段映射，不是第二wire。

DocumentContext=`{document_uri:String,document_authoring_id:String,origin:String,allowed_script_digests:Dictionary,instance_role:String或null}`；origin=EDITOR_BUFFER/SAVED。LevelRef等共享类型由D1值合同定义，但A1/A2不能preload4D服务；用显式Dictionary输入避免循环依赖。

EditProposal=`{operation:String,document_uri:String,target_authoring_id:String,created_objects:Array[Object],assigned_ids:Array[Dictionary],before:Array[Dictionary],after:Array[Dictionary],hierarchy_changes:Array[Dictionary],retained_targets:Array[StringName],reference_impacts:Array[Dictionary],requires_confirmation:bool}`，**仅编辑器进程内**，禁止wire；before/after变更项=`{object:Object,property:StringName,value:Variant}`；hierarchy_changes条目=`{action:String,node:Node,parent:Node,index:int,owner:Node或null}`，action仅ADD/REMOVE，同属一个document_uri，按顺序应用、逆序撤销，不携带任意Callable。object_ref=`{object:Object,authoring_id:String,document_uri:String}`；context=`{document_root:Node,documents:Array[AuthoringDocument],existing_ids:Dictionary}`。4A负责未采纳proposal释放created_objects的`discard_proposal(proposal:Dictionary)->void`，4B采纳后把生命周期交UndoRedo的do/undo引用。删除只准备移除/恢复，不在预检中free源对象；external dangling refs不改写。

作者类字段、类型映射详见批准合同§3，不新增游戏字段。Level根以导出Dictionary保存spawn/goal/celestial配置及显式World/Intent关联；world/cube/slot/group/mechanism/transition各为独立Node3D数据类，Face和五类语义资源为Resource。六面可使用`Array[Resource]`导出并逐元素封闭类型检查，避免类依赖加载顺序导致跨脚本循环；不放宽六面恰6条要求。

测试支持（A1创建、仅tests）：`authoring_fixtures.gd::documents(case_name:String)->Array[Dictionary]`、`payload(case_name:String)->Dictionary`、`identity()->Dictionary`、`options()->Dictionary`。case限minimal/missing_face/duplicate_face/duplicate_id/shared_alias/resource_conflict/off_lattice/unsupported_override；identity给独立测试身份，options固定4096/100000。Real保存加载测试使用本Owner四个源文件经project_document，不能用此值fixture替代I1作者链。

## 消费的已有正式API

`AuthoringReader.read_scene(root:Node3D)->Dictionary`返回ok/authoring/issues；`LevelBaker.bake(authoring:Dictionary,options:Dictionary)->Dictionary`返回ok/level/issues/validation；`LevelCodec.encode(level:Dictionary)->Dictionary`、`compute_content_hash(level:Dictionary)->Dictionary`由正式模块独占；`SurfaceGeometry.face_id(cube_id:StringName,face:int)->StringName`仅用于引用解析，六面及坐标仍Reader生成。`IntentValidation.validate(level:Dictionary,intent:Dictionary)->Dictionary`用于A4测试及4C正式流程；4A不改该模块。

适配核心边界（A2实现，示意内部变量均本次创建）：

```gdscript
var root := Node3D.new()
# 按批准字段建立直接Cubes/Slots，填18字段template；不得挂活动SceneTree。
var read_result := Reader.read_scene(root)
root.free() # 失败同样释放；构造失败出口也释放。
if not read_result.ok:
    return {"ok":false,"level":null,"issues":read_result.issues,"validation":null,"source_map":map}
var baked := Baker.bake(read_result.authoring, bake_options)
return {"ok":baked.ok,"level":baked.level,"issues":baked.issues,"validation":baked.validation,"source_map":map}
```

### 4A-1 — 作者组件、投影与保存加载

**Files:** `foundation/authoring/authoring_schema.gd`, `foundation/authoring/level_authoring_root.gd`, `foundation/authoring/world_authoring_root.gd`, `foundation/authoring/cube_authoring_node.gd`, `foundation/authoring/slot_authoring_node.gd`, `foundation/authoring/group_authoring_node.gd`, `foundation/authoring/mechanism_authoring_node.gd`, `foundation/authoring/transition_authoring_node.gd`, `foundation/authoring/face_authoring_resource.gd`, `foundation/authoring/mechanism_config.gd`, `foundation/authoring/intent_authoring_resource.gd`, `foundation/authoring/milestone_authoring_resource.gd`, `foundation/authoring/bypass_authoring_resource.gd`, `foundation/authoring/document_projector.gd`, `foundation/authoring/payload_assembler.gd`, `tests/foundation/authoring/authoring_fixtures.gd`, `tests/foundation/authoring/test_authoring_documents.gd`, `tests/foundation/authoring/fixtures/minimal/level.tscn`, `tests/foundation/authoring/fixtures/minimal/surface.tscn`, `tests/foundation/authoring/fixtures/minimal/inner.tscn`, `tests/foundation/authoring/fixtures/minimal/intent.tres`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 批准Tool Contracts §3/§3.2；正式类型/FaceDirection；无D生产依赖

**Interfaces — produces:** 上表project_document/assemble_payload/validate_authoring、五Resource和七节点类、测试fixture工厂

- [ ] **RED：** 写恰六面保存重开、同身份保持、缺面/重复面/重复CubeID、实例覆盖、共享别名和资源版本冲突用例。先让缺面/覆盖通过以观察用例失败，再实现拒绝；未创建入口的首次加载失败不计行为验证。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4A -Case 4A-1 -Mode Real -EvidenceName 4a_4a-1_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
const F = preload("res://tests/foundation/authoring/authoring_fixtures.gd")
const Schema = preload("res://foundation/authoring/authoring_schema.gd")
check(Schema.validate_authoring(F.payload("minimal")).ok, "explicit six faces")
check(not Schema.validate_authoring(F.payload("missing_face")).ok, "missing is not defaulted")
check(not Schema.validate_authoring(F.payload("unsupported_override")).ok, "override stops authoring")
check(not Schema.validate_authoring(F.payload("duplicate_id")).ok, "no silent identity repair")
```

- [ ] **GREEN：** 以精确schema表读取export字段；源投影只读，World根/组织容器identity及顶层归属检查；比对SceneState与编辑根保存重开后的值、UUID和资源别名。资源循环/多个版本拒绝，六面可变资源不得跨Cube共享。A_SCHEMA交付包含支持的script digest名单生成输入，wire仍不归4A。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 使用新场景真实ResourceSaver/PackedScene保存重开；未保存捕获能力留D5，但Source投影须可消费当前根；不读取美术目录。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4A-2 — 唯一正式Bake与source map

**Files:** `foundation/authoring/authoring_adapter.gd`, `foundation/authoring/source_map.gd`, `tests/foundation/authoring/test_authoring_bake.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** A_SCHEMA；正式Reader/Baker/Codec及Geometry.face_id

**Interfaces — produces:** bake_authoring、SourceMap生成及locate；A_BAKE交付

- [ ] **RED：** 同一payload两次Bake应canonical相同；树重排/显示名变化只改来源不改level_hash；off-lattice坐标必须返回Reader原错误且level=null；成功后失败不可回填上次level。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4A -Case 4A-2 -Mode Real -EvidenceName 4a_4a-2_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
const F = preload("res://tests/foundation/authoring/authoring_fixtures.gd")
const Adapter = preload("res://foundation/authoring/authoring_adapter.gd")
const Codec = preload("res://foundation/level/level_codec.gd")
var one := Adapter.bake_authoring(F.payload("minimal"), F.options(), F.identity())
var two := Adapter.bake_authoring(F.payload("minimal"), F.options(), F.identity())
check(one.ok and two.ok and Codec.encode(one.level).text == Codec.encode(two.level).text, "deterministic formal Bake")
var invalid := Adapter.bake_authoring(F.payload("off_lattice"), F.options(), F.identity())
check(not invalid.ok and invalid.level == null, "Reader rejects original transform")
```

- [ ] **GREEN：** 只展开Cubes/Slots与18字段template；group_id由组成员生成，face.mechanism_ids由host_face生成；正式face引用调用Geometry.face_id。临时树不入SceneTree，保留Reader路径到authoring_id映射，成功canonical排序后按实体ID建立canonical_path，早期失败只有reader_path。验证每次临时对象释放。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 4A代码不出现自写坐标round/离散姿态推导或内容hash；safety未完成不成功；Reader早期entity_ids空和AnalysisIssue不同结构都有准确未定位/定位断言。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4A-3 — 身份操作和专用化proposal

**Files:** `foundation/authoring/id_registry.gd`, `foundation/authoring/edit_operations.gd`, `tests/foundation/authoring/test_authoring_edits.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** A_SCHEMA；同关整套声明及4B未来UndoRedo应用边界

**Interfaces — produces:** allocate、prepare_edit、discard_proposal；A_EDIT数据部分

- [ ] **RED：** 一个机制COPY得到新自身ID但target_bindings不变；嵌套共享Resource专用化后副本内部同别名、与原件断开；DELETE预检列影响且不改源；取消proposal释放副本。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4A -Case 4A-3 -Mode Unit -EvidenceName 4a_4a-3_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
# 在test_authoring_edits.gd从minimal资源建立obj/ref/context，调用真实EditOperations。
var proposal := EditOperations.prepare_edit("MAKE_UNIQUE", object_ref, context)
check(proposal.ok, "known semantic whitelist")
var copies: Array = proposal.value.created_objects
check(copies[0] != original_resource, "outer resource is independent")
check(original_resource.get_instance_id() == original_id, "preflight leaves original")
check(proposal.value.retained_targets == original_targets, "external targets preserved")
EditOperations.discard_proposal(proposal.value)
```

- [ ] **GREEN：** 白名单显式字段复制、访问表保内部别名、循环拒绝、预分配authoring和正式身份。未知Resource拒绝且清理暂存对象；删除不静默解绑；proposal只描述本源文档，跨文件编辑拒绝。4B一次UndoRedo接管引用；不在A内调用EditorUndoRedoManager。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 补真实Resource对象复制测试，Unit仅缺Editor事务；Redo身份稳定最终由B2 Editor用例验；六面副本也不共享原可变对象。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4A-4 — Intent唯一绑定和来源定位

**Files:** `foundation/authoring/intent_binder.gd`, `tests/foundation/authoring/test_intent_binding.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 本轮成功A2结果＋SnapshotIdentity；正式IntentValidation用于对照

**Interfaces — produces:** bind_intent专用返回；A_EDIT完成交付

- [ ] **RED：** 有效空Intent恰八正式字段；仅optional非空不能当空；失配run/snapshot/hash、失败Bake、非法tag/缺必填字段均失败；AT_FACE走正式face_id，源Resource值不改。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4A -Case 4A-4 -Mode Real -EvidenceName 4a_4a-4_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var bound := Binder.bind_intent(author_intent, successful_bake, identity)
check(bound.ok and bound.bound_intent.size() == 8, "formal closed sidecar")
check(bound.bound_intent.level_hash == successful_bake.level.content_hash, "same Bake")
check(IntentValidation.validate(successful_bake.level, bound.bound_intent).ok, "real intent validation")
check(author_intent == before_author_intent, "never writes binding into author source")
check(not Binder.bind_intent(author_intent, failed_bake, identity).ok, "no previous level fallback")
```

- [ ] **GREEN：** Bake provenance由A2返回source_map.snapshot_id及source_fingerprint，bind交叉核对identity；自动字段只填正式version/hash/rule。标签集合先拒绝重复非法再升序，milestone保持顺序；digest回传D提供值。缺Intent允许独立Bake但完整流程由4C/4D记MISSING_INPUT，不自动创建空。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 约束逐项比较不增删；FACE_LIGHT仅玩家面语义；SourceMap及诊断不混入正式19/6字段；失败候选明确无效。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

## 验收与依赖收口

上述4个新命令当前NOT_RUN，I0 wrapper和A1–A4测试均有创建任务。已有对照回归：

```powershell
$authoringRoot=(Get-Location).Path
pwsh -NoProfile -File tests/foundation/level/run_validation.ps1 -EvidenceName f4a_baker_01 -ValidatorSourceRoot $authoringRoot
```

4A模块完成：真实保存/加载、正式Baker及source_map/绑定验证成功，临时树释放；A_SCHEMA/A_BAKE/A_EDIT交付真实SHA。单元编辑proposal通过不代表真实Editor UndoRedo通过，须B2；A2通过不代表白盒Runtime完成，须I1。缺A1、正式Validator或I_HARNESS标DEPENDENCY_PENDING，不用私有seam替代。公共合同变化/字段冲突停止受影响项，报告CONTRACT_MISMATCH；本计划禁止为了过测改旧合同。
