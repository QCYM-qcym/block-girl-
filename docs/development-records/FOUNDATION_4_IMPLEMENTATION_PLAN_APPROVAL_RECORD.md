# FOUNDATION-4 Implementation Plan Approval Record

状态：**PLANS_APPROVED**；**IMPLEMENTATION: NOT_STARTED**。
批准日期：2026-09-23（Asia/Shanghai）；实际记录时间：2026-09-23T02:12:52.536594+08:00。

用户明确批准下列五份实施计划，以及它们引用的已批准Design Spec / Tool Contracts。写入本记录前已将当前字节SHA-256与上一轮交付的verification.json及Spec批准值逐一核对；批准对象没有发生变化。

| 批准文档 | SHA-256 |
|---|---|
| [2026-09-22-foundation-authoring-editor-design.md](../superpowers/specs/2026-09-22-foundation-authoring-editor-design.md) | `A4D9CD7CCFDE8E4FDB0EEA72746505B995361850E623BEF7952D49849EC9A13F` |
| [2026-09-22-foundation-authoring-tool-contracts.md](../superpowers/specs/2026-09-22-foundation-authoring-tool-contracts.md) | `C31A03E807A2BF9268D32AA00FA18BCD93C77BAD4C53ED00A8D349FED8462A6B` |
| [2026-09-23-foundation-authoring-data-plan.md](../superpowers/plans/2026-09-23-foundation-authoring-data-plan.md) | `DEB5F052F3DE84DB80450FCFA84ABFDC6FE3C3535B41F838163A999E8B2E402A` |
| [2026-09-23-foundation-authoring-integration-plan.md](../superpowers/plans/2026-09-23-foundation-authoring-integration-plan.md) | `179D1F2D416B59E3C890C6026D28F57F28F84E1EBE67F233666B4E98F7BD99FF` |
| [2026-09-23-foundation-authoring-quality-plan.md](../superpowers/plans/2026-09-23-foundation-authoring-quality-plan.md) | `87BDDD1FF7A691AD19E0FF5804FD011EC3CA7C57F73689D1BBF83BB7E07CEA98` |
| [2026-09-23-foundation-authoring-runtime-plan.md](../superpowers/plans/2026-09-23-foundation-authoring-runtime-plan.md) | `5E8293D9ECF5580F48669875FB0324511218C423C582FB888A5CF14BF445315D` |
| [2026-09-23-foundation-editor-tools-plan.md](../superpowers/plans/2026-09-23-foundation-editor-tools-plan.md) | `6A14B88D39BAD48B1003DEA011D34AFE30B8E0673B1B4AE87E7A84388132F1AD` |

## 执行方式与本轮授权

- 执行方式：**FOUR_PARALLEL_WORKTREES**。
- 集成策略：**SEPARATE_INTEGRATION_WORKTREE**，等待真实模块提交后再创建；本轮不得创建Integration工作树。
- 本轮仅执行IMPLEMENTATION BASELINE PREPARATION：独立批准记录、精确文档提交、推送origin/docs/foundation-4-authoring-design、确认远端同一commit、从该commit创建四个Feature工作树并检查清洁状态、执行已列正式基线回归。
- 不开始4A/4B/4C/4D生产实现，不新增测试实现，不修改main或旧生产代码，不合并main/Core，不rebase/squash/force push，不创建PR或删除其它工作树。
- 基线真实回归失败时标记BASELINE_REGRESSION_BLOCKED，保留首次结果，停止进入生产实现。历史timer/polish观察项按现有策略记录，不反复重跑筛选绿色。

## 批准记录关系

两份Spec和五份Plan原字节保持不变。其历史front matter中的待审标记由本页绑定hash的用户批准补充，不把文档旧状态当成再次审批理由。[Spec批准记录](FOUNDATION_4_SPEC_APPROVAL_RECORD.md)继续有效；Spec获批、计划获批、基线准备与生产实现是不同阶段。

## 共同基线与四工作树

提交前父HEAD为`bfcc6c004db232ca2f4ea4d409c98bda0dc6d165`，设计分支`docs/foundation-4-authoring-design`。本地Core `821bce29fc94dbed42fafbe3f4a720b4715d4aa3`相对父HEAD仅有README变化，正式生产源码一致；本轮不合并Core或main。共同基线是首次包含本记录及全部批准文档的完整commit，提交后从Git读取完整SHA并记录到E盘本地准备报告和最终回复，不在本commit正文构造自引用hash。

| Owner | 分支 | 工作树 |
|---|---|---|
| 4A | feat/foundation-authoring-data | E:/godot/worktrees/block-girl-foundation-authoring-data |
| 4B | feat/foundation-editor-tools | E:/godot/worktrees/block-girl-foundation-editor-tools |
| 4C | feat/foundation-authoring-quality | E:/godot/worktrees/block-girl-foundation-authoring-quality |
| 4D | feat/foundation-authoring-runtime | E:/godot/worktrees/block-girl-foundation-authoring-runtime |

四者只能从同一已提交且成功推送的Implementation Baseline Commit创建。创建后要求HEAD与共同基线相同、merge-base相同、git status为空。创建工作树不等于开始实现；后续由用户向四个Work分别发执行提示词。

本轮本地证据根：`E:/godot/foundation-4-baseline-preparation-2026-09-23/`；正式旧测试证据沿各自wrapper在E盘的既有目录。证据、运行产物、README临时图片、美术及其它用户文件均不纳入提交。
