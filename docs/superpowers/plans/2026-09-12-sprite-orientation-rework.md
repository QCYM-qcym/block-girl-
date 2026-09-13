# Cube Sprite Orientation Rework Implementation Plan

**Goal:** 将正式双皮肤像素图集接入现有姿态驱动表现，不改变已验收逻辑。
**Architecture:** 固定单面纹理→离线2D像素投影/去重→24态规范相机lookup→现有mover/view驱动正式Presenter。
**Spec:** docs/design/CUBE_SPRITE_PRESENTATION_SPEC.md；用户a7f2b155附件已明确授权整个阶段，沿用当前分支、不commit。

- [x] 读取原报告/资源与代码、确认分支、保存本轮baseline，写正式规格。
- [x] 生成两皮肤正面原稿并清理到固定像素色板；建立稳定图集与验证，先红后绿。
- [x] 稳定192映射通过后生成3帧中间roll及相机过渡，RGBA去重并输出manifest/预览/生产资源。
- [x] 新增game/player/orientation_sprite_presenter.gd及独立sprite test场景；保留X原实现，P01只换引用。
- [x] Godot真实图形测试、系统键鼠目检、≥10秒等待与≥5格hold、Debug parity及P01完整回归。
- [x] 完成只读审查、完整性比对与最终报告，状态取决于正式Sprite验收，停止等待试玩。

