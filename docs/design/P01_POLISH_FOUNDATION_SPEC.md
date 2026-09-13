# P-01 Polish Foundation

用户附件a2e50d62已明确授权本阶段全部范围；保持当前feat/playable-puzzle-p01与未提交成果，不commit/push/merge/remote/reset/restore/clean。

## 基线与取舍

已读取P01、两轮角色姿态报告、Perspective、Sprite、Tileset、Mechanism报告与关卡设计、Hints、GridInput、Movement/View、现有Player Presenter。现有音频/WAV/OGG/Shader为空。复用正式178帧双皮肤、32×16地面、Plate/Door/Exit动画、现有0.32秒roll、0.25秒Shift状态锁、0.4秒90°View snap及60px鼠标阈值。状态图和13步解法不变。

不用全局AudioManager，不引入外部音频；程序化生成TEMP基础音色，标TEMPORARY，原始配方与来源许可在项目内。PNG图标只用于小键位图；FX用整数像素几何与一个可关闭的简单CanvasItem dissolve shader，不重制角色和环境。

## FILES_TO_CREATE

- game/polish/p01_audio.gd：每cue固定单声部播放器、两条ambient循环、Master/SFX/Ambience路由、M静音，cue信号供诊断。
- game/polish/p01_feedback.gd：局部像素dissolve/碎片、落地影响应、Link端点高光、rotation边缘反馈、稀疏环境像素。
- game/polish/p01_polish.gd：观察已提交状态/新roll，向Audio与FX发cue；F4只切主要FX；不写游戏逻辑。
- game/polish/p01_tutorial_view.gd：读取现有Hints生命周期，渲染低权重小键位图，自然淡入淡出。
- game/polish/p01_completion_view.gd：完成时立即可见但渐入，1.8秒克制演出，R始终可重置。
- game/polish/pixel_dissolve.gdshader：确定性原生像素coverage，可降至0关闭，不模糊RGB。
- default_bus_layout.tres；production/audio/p01/TEMP_*.wav及manifest.json；production/ui/p01/tutorial_keys.png。
- tests/gameplay/build_p01_polish_assets.py、test_p01_polish.gd、test_p01_polish_pixels.gd、运行证据。
- docs/audio/AUDIO_ASSET_MANIFEST.md、SOUND_DIRECTION.md；docs/art/POLISH_DIRECTION.md；最终报告和计划。

## FILES_TO_MODIFY

- game/levels/mutsumi/p01_another_world.gd：仅装配上述模块、教程/完成组件、刷新与Reset接线。
- docs/design/p01-another-world.md：同步当前正式角色基线与实际audio/FX/tutorial/completion，不改谜题。

## 声音与事件

PLAYER=roll/land；WORLD=双向shift、rotate、link on/off；MECHANISM=plate/door open/close/exit ready；UI=complete；AMBIENCE=两世界循环。每cue固定一个AudioStreamPlayer、max_polyphony=1，roll短于移动周期，落地很轻。类别与SFX总线保留headroom，持续移动不累积节点/voice。只有已成功接受的Shift或View commit播放声音，拒绝动作不泄露答案。Link只轻短音，不弹文字。

Audio和FX观察mover/view/graph；Door和Link状态从不等待音效/Shader。音频不可用或FX关闭仍完整通关。Master静音是本游戏总线，M方便验收与试玩；无混音UI。

## 视觉节奏

Shift覆盖约0.4秒：既有0.25秒phase锁定期间旧世界像素渐疏，commit后新世界在约0.15秒淡入。commit仍来自Movement；淡入尾段允许输入恢复，不把Shader变成额外状态锁。最大局部溶解保留少量轮廓，避免全屏强闪。换肤后cell、orientation、view保持。

View保留原easing/preview/rebound与阈值，附加边缘几何跟随及commit短音。Link成立时两anchor端点同步出现1px短高光、轻呼吸；断开快速淡去。Plate原2px下降和Door即时动画保持，补短音与稀疏高光；Exit现有locked/ready/complete外观不重做。

环境仅约12个低对比稀疏像素，Surface偏灰绿、Inner冷灰紫，小范围缓慢运动，不覆盖主路径信息。角色不缩放变形，落地只短影响应。

教程仍只三项：初始WASD小键帽，第一断路Space，连接教学点Q/E加水平拖动图；成功后淡出，Reset重现，不记录全局存档。完成时原逻辑立即锁定，Exit启动，环境声降低；短暂停顿后画面轻淡化，标题/完成/R在1.8秒内显现。

## 验收与边界

先红后绿：新增模块缺失、事件/输入锁边界、Reset、教程、音频失败/FX关闭仍通关。真实Godot运行A键盘、B鼠标、Master静音、无FX；独立像素验证1x–4x角色/地面清晰与dissolve开关。采集AudioEffectCapture实际混音，验证非零PCM、峰值、固定voice数量；声音是否令人舒服另由用户试听确认，不用数值冒充主观听感。

系统键鼠关闭F3至少两条完整通关，再静音路线；记录8项体验观察。实施者已知解法，因此 First-time User Test=REQUIRED，TUTORIAL_FIRST_USER_VALIDATION_REQUIRED。原Sprite/Tileset/Mechanism/Perspective/Cube/OrientationSprite/P01全部回归。只有真实Runtime与回归均通过才PASS；随后停止，不开下一阶段。
