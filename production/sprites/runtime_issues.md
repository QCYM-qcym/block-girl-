# Runtime issues — recorded before production PNG changes

## MAJOR R-001 — 翻滚中间帧丢失可见表面，体积收缩

Status: CONFIRMED, not yet fixed at initial recording.

Godot 4.7.2 Steam / Forward Plus / D3D12 / NVIDIA GeForce RTX 5060 Ti 已实际播放全部动画。第一轮 PNG 与 GPU 帧缓冲在 1x–4x 共 1,723,680 个采样像素完全一致，RGB 最大差值 0，因此问题来自生产 PNG，而不是导入、过滤或偏移。

运行证据：`E:/godot/若叶睦/方块少女-若叶睦/tests/visual/evidence/run_01/roll_right_f2.png`；其余对应截图、engine_runtime_report.json、pixel_runtime_analysis.json 均在同目录。

明显缺口帧（零基行列）：(2,3)、(3,2)、(4,2)、(5,3)，两皮肤相同。这些帧每格只有 153 个不透明像素，轮廓凸包内部缺失 10 像素；静止帧为 205 个不透明像素且无缺口。其他相邻翻滚帧也受同一可见面判断影响。

Root cause: 上轮确定性重投影的屏幕投影为 X=7.5(x−z)，Y=3(x+z)−9y，因此实际观察方向应与 (1,2/3,1) 平行。生成器却以 (1,2,1) 做面剔除和前后排序；在 36°/54° 等姿态误剔除了应可见的面。导入设置、FPS 和 offset 无法修复 PNG 中已缺失的像素。

拟议最小修复：只将面剔除/深度排序中的观察方向改为 (1,2/3,1)，沿用现有贴图、色板、投影、角度、网格、基线与时序；只替换两张 PNG 的翻滚行 2–5。要求其他行逐像素不变，并重新执行真实 Godot 运行验收。

修改前文件已保存到 `E:/godot/若叶睦/sprite_production_work/runtime_validation/before_png_fix/`：

- mutsumi_cube_sheet.png，SHA256 c7b7fd84e1411a8be8109dc8cab26b50a597bdc7e4ec2f55db6db1809c5547e6。
- mortis_cube_sheet.png，SHA256 bea21ec0e5d9cc712c1a86dce0add18c303fedecf7998bf1d2adc175eac110d4。
- prepare_sprites.cjs，修改前生成器，仅作审计。

## INFO R-002 — 项目默认过滤与角色显式过滤不同

项目默认过滤原值 1；角色节点显式 TEXTURE_FILTER_NEAREST。运行截图已证明角色没有模糊或 bleeding。将保留项目全局设置，仅在测试和角色节点使用 Nearest，避免扩大本轮范围。

## MINOR R-003 — 互动和完成的反馈在 1x 下很克制

运行可区分，但 16px 角色只靠少量面部/边缘像素反馈，1x 下较轻微；未出现错误播放。这符合既定安静风格，不在本轮无依据重画表情。建议正式交互阶段再结合音效/状态提示判断，不添加游戏 UI。


## 修复后结果（2026-09-12）

R-001：RESOLVED。采用与投影匹配的 (1,2/3,1) 做面剔除和排序；每皮肤仅 12 个翻滚格发生改变，其他格像素完全不变。原问题凸包内缺失 10 像素，修复后所有翻滚格缺失均为 0。已执行 Godot reimport 和 run_02 真正图形运行；1x–4x 渲染比对通过，锚点和双向切换保持一致。R-002 为项目默认 Linear 的 INFO，角色节点显式 Nearest；R-003 保留为非阻塞 MINOR。
