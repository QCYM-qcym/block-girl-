# 方块少女 · 若叶睦 / Mortis Sprite 生产清单

日期：2026-09-12。目标：Godot 4.x（现有工程声明 4.7）。仅交付角色 Sprite 与预览、资源说明。

## 状态与验证边界

**SPRITE_RUNTIME_ACCEPTANCE_PASS — 2026-09-12。** 已在 Godot 4.7.2 Steam / Forward Plus / D3D12 / NVIDIA GeForce RTX 5060 Ti 实际导入、运行并播放两套动画。两张生产 PNG 保持 GODOT_READY，运行证据与完整结论见 [runtime_validation_report.md](runtime_validation_report.md)。

本轮运行发现并修复 R-001：翻滚投影的可见面剔除方向不匹配，部分中间帧缺面。先记录问题与原图备份，再只修正两张 PNG 的翻滚行 2–5；其他行逐像素不变。没有更换角色设计、色板、帧序、FPS 或锚点。修改前文件与 SHA256 见 runtime_validation.json。

两次真实运行分别保留在工程 tests/visual/evidence/run_01、run_02；最终 run_02 的 1x–4x 共 1,723,680 个渲染像素与 PNG 完全相同。双向切换交接差异 0，阴影稳定。未开展正式玩法、关卡或 Tileset 工作。HTML 预览只作辅助，运行结论依据 Godot 本身。

**未解决 BLOCKER：0；未解决 MAJOR：0；MINOR：1**（1x 互动/完成反馈较轻微，保留现有风格）。

## 输出文件

| 文件 | 用途 / 状态 |
|---|---|
| `mutsumi_cube_sheet.png` | Surface 生产贴图；GODOT_READY |
| `mortis_cube_sheet.png` | Inner 生产贴图；GODOT_READY |
| `mutsumi_cube_preview.png` | 6 倍最近邻放大、带标签与格线；VIEW_ONLY |
| `mortis_cube_preview.png` | 6 倍最近邻放大、带标签与格线；VIEW_ONLY |
| `sprite_palette_reference.png` | 两套基础色板；REFERENCE_ONLY |
| `mutsumi_sprite_frames.tres` | 预配置 12 个动画的 SpriteFrames；Godot 4.7.2 运行通过 |
| `mortis_sprite_frames.tres` | 同上，Mortis |
| `mutsumi_sprite_example.tscn` | 单角色 Body / Shadow 节点示例；Godot 实际加载通过 |
| `mortis_sprite_example.tscn` | 同上，Mortis |
| `sprite_animation_preview.html` | 自包含双角色对照预览、暂停/逐帧/倍率/背景切换；VIEW_ONLY |
| `animation_layout.json` | 机器可读布局、色板、帧序、FPS、循环、锚点 |
| `validation_report.json` | 132 格逐帧边界、像素哈希和自动验收结果 |
| `source_inventory.md` | 实际读取的全部 11 张源图、尺寸、用途、状态、处理建议 |
| `generation_notes/mutsumi_imagegen_prompt.txt` | 内置 imagegen 的 Surface 原稿提示词 |
| `generation_notes/mortis_imagegen_prompt.txt` | 内置 imagegen 的 Inner 原稿提示词 |
| `asset_manifest.md` | 本文档 |
| `runtime_validation_report.md` | 本轮真实运行验收报告 |
| `runtime_validation.json` | 运行结论、环境、PNG 修改前后 SHA256 |
| `runtime_issues.md` | 修改前问题记录与修复结果 |

## 两张 Sheet 的共同规格

```yaml
frame_size: [24, 24]
sheet_size: [144, 264]
columns: 6
rows: 11
frame_index: row * 6 + column
region: [column * 24, row * 24, 24, 24]
cell_origin: top_left
anchor_in_cell: [12, 21]
last_body_pixel_row: 20
rest_body_bbox_inclusive: [4, 5, 19, 20]
rest_body_size: [16, 16]
alpha_values: [0, 255]
filter: nearest
loop_roll: false
```

坐标、行、列、帧号全部从 0 开始。透明空白不裁剪。两种状态每一对应格的 Alpha 蒙版完全相同；翻滚时轮廓变化是姿态变化，但都在 24×24 内、底边 y=20。静止、互动、切换、完成共用静止轮廓。

每套基础色板 12 色，切换过程会使用对方色板；每张完整 Sheet 实际共 25 个不透明 RGB 颜色（两套基础色板 + 共用阴影 `#263138`），外加透明。无渐变、无半透明像素、无模糊或抗锯齿。色板参考 PNG 展示两套基础 12 色；共用阴影另记在这里和 JSON 中。

## 动画表（两套完全一致）

| animation name | 行 | 使用列（播放顺序） | Sheet 索引 | 建议 FPS | Loop | 时长 / 说明 |
|---|---:|---|---|---:|---|---|
| `idle` | 0 | 0 | 0 | 1 | 是 | 静止；本行其余列为重复补位 |
| `subtle_idle` | 1 | 0,1,2,3,4,5 | 6–11 | 8 | 是 | duration 权重为 18,1,1,1,1,10；总计 4 秒，避免频繁眨眼 |
| `roll_left` | 2 | 0,1,2,3,4,5 | 12–17 | 18 | 否 | 约 0.333 秒；绕 Z 轴向 −X 翻滚 |
| `roll_right` | 3 | 0,1,2,3,4,5 | 18–23 | 18 | 否 | 约 0.333 秒；绕 Z 轴向 +X 翻滚 |
| `roll_forward` | 4 | 0,1,2,3,4,5 | 24–29 | 18 | 否 | 约 0.333 秒；绕 X 轴向 +Z 翻滚 |
| `roll_backward` | 5 | 0,1,2,3,4,5 | 30–35 | 18 | 否 | 约 0.333 秒；绕 X 轴向 −Z 翻滚 |
| `interaction` | 6 | 0,1,2,3,4,5 | 36–41 | 10 | 否 | 0.6 秒；微弱下缘高光/眼睑变化；无压力板图形 |
| `world_switch_start` | 7 | 0,1,2 | 42,43,44 | 12 | 否 | 0.25 秒；本状态到过渡色；其余列为补位 |
| `world_switch_midpoint` | 8 | 0,1,2 | 48,49,50 | 12 | 否 | 0.25 秒；过渡到目标状态静止帧；其余列为补位 |
| `puzzle_complete` | 9 | 0,1,2,3,4,5 | 54–59 | 10 | 否 | 0.6 秒；克制高光与眼睑变化后归静止 |
| `shadow` | 10 | 0 | 60 | 1 | 是 | 14×5 硬边菱形阴影；本行其余列重复 |
| `world_switch` | 7+8 | (7,0),(7,1),(7,2),(8,0),(8,1),(8,2) | 42,43,44,48,49,50 | 12 | 否 | SpriteFrames 额外提供的合并动画；0.5 秒 |

四方向采用与源图接近的俯视正交投影：+X 显示为右下，−X 为左上，+Z 为左下，−Z 为右上。它们是棋盘坐标方向，不是四个纯屏幕水平/垂直方向；若项目键位使用屏幕方向，应在输入映射层匹配动画名。实际移动一格由游戏逻辑控制，Sheet 只提供原地翻滚，不含位移。

翻滚帧阶段为 0°、18°、36°、54°、72°、落定；落定帧恢复标准面部朝向。这个有意的纹理复位满足“不记录六面朝向”的玩法规格。两状态共用几何和时序，差异来自表面颜色、面部与轻微紫色标记。没有新增六面玩法或状态系统。

## Godot 导入和使用

1. 将本目录作为整个文件夹复制到项目 `res://production/sprites/`。`.tres` 和 `.tscn` 内的路径以此为准；如改目录，需同步更改资源路径。
2. PNG 采用 Lossless、关闭 Mipmaps。Godot 4 的 `Texture Filter` 在 CanvasItem / Sprite 节点或项目默认项设置为 **Nearest**；不是旧版的 PNG Filter 导入开关。不要在导入时缩小贴图。建议整数显示倍率、整数像素位置。
3. AnimatedSprite2D 的 SpriteFrames 属性加载对应 `.tres`。资源含 12 个动画；Body 播放角色动画，Shadow 节点只播放 `shadow`，放在 Body 后面。阴影像素本身不透明，需要淡阴影时用 Shadow 的 `modulate.a`（示例为 0.35）。
4. 推荐 `centered = true`、`offset = Vector2(0, -9)`，使纹理点 (12,21) 对齐节点原点；两种状态相同。若 `centered = false`，则用 `offset = Vector2(-12, -21)`。不要逐帧改变 offset。
5. 使用 Sprite2D 时设 `hframes=6`、`vframes=11`，按上表全局帧号播放；或使用 24×24 的 region/AtlasTexture。不要让重复补位延长动画。
6. 碰撞和逻辑占格固定，不根据透明包围盒动态重建。默认建议逻辑占格 16×16；若需要与静止外接框一致的 RectangleShape2D，可用 size=(16,16)、相对锚点中心=(0,-8)。实际棋盘的菱形/网格变换由项目决定。本交付不建立或更改碰撞玩法。
7. 翻滚/互动/完成动画 `animation_finished` 后切回 `idle` 或 `subtle_idle`。位移一格时让父节点的移动与约 0.333 秒的翻滚匹配；不要旋转整个 Sprite2D 代替现有翻滚帧。
8. 切世界时在当前资源上完整播放 `world_switch`，结束后更换到目标角色的 SpriteFrames 并播放 `idle`；末帧像素与目标 `idle` 完全一致。若游戏必须在中点切资源，应自行安排两段的接续，不能盲目在目标资源重播同名动画，否则会切回原色。

## 来源与重制记录

实际读取清单见 `source_inventory.md`。主要参考：`Codex 图像 2026年9月11日 20_34_19.png`（双状态角色与皮肤）和 `Codex 图像 2026年9月11日 20_38_30.png`（Mortis 动作需求、切换、阴影）。辅助仅观察其他概念板里的角色区域。没有直接把原图角色裁下来冒充 24×24 成品。

制作方式：内置 imagegen 生成 Surface 动作工作稿，再以其为目标生成 Mortis 换色工作稿；用户明确同意以程序完成生产处理。移除烘焙背景，以生成稿的正面/侧面/顶面像素为表面来源，在统一立方体投影上重排四方向翻滚，限制色板、固定基线、整理轻微表情、独立阴影、离散切换色与固定网格。所有源图未修改。原始提示词在 `generation_notes/`。

生成原稿仅位于本机工作缓存，属于未交付 DRAFT：

- `C:\Users\QCYM\.codex\generated_images\01a0938a-3d20-7261-badc-8d74329e0d2a\exec-4e7ee545-f9d9-4563-8b52-ac5b9366545b.png`
- `C:\Users\QCYM\.codex\generated_images\01a0938a-3d20-7261-badc-8d74329e0d2a\exec-de5b69a9-09c2-4c47-ab6c-ec9dcc7add30.png`

## 验收结论

- 同画布 / 同体型 / 同占格 / 同透视 / 同像素密度：通过。
- 固定 24×24 单元格，全部 132 格无越界、无随机边距漂移，底边 y=20：通过。
- 真正透明 PNG，Alpha 仅 0/255、透明像素 RGB 为 0，无抗锯齿：通过。
- 两状态每一对应帧的轮廓完全一致：通过。
- 四个翻滚各包含 4 个中间姿态，首尾同静止；方向和共用投影：真实运行逐帧检查通过；正式移动玩法不在本轮范围。
- 表情、互动、完成不是全程同一张静态图：像素差异检查通过。
- 生产 Sheet 没有背景、网格、标签、文字；无四肢、武器、战斗元素：目视检查通过。
- SpriteFrames 区域、引用、实际加载和播放：Godot 4.7.2 运行通过；正式游戏联调不在本轮范围。

官方参考：[导入图片](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)、[AnimatedSprite2D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html)、[SpriteFrames](https://docs.godotengine.org/en/stable/classes/class_spriteframes.html)、[AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html)。
