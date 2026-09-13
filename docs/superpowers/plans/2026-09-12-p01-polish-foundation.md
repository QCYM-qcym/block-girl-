# P-01 Polish Foundation Implementation Plan

**Goal:** 不改变谜题与真实姿态，补齐P01声音、像素反馈、教程与完成体验。
**Architecture:** 五个局部表现组件观察既有状态；一个小型cue播放器、一个dissolve shader，无全局框架。
**Tech Stack:** Godot4.7.2，Node2D/CanvasItem/AudioStreamPlayer，程序化PCM WAV、透明PNG小图标。
**Spec:** docs/design/P01_POLISH_FOUNDATION_SPEC.md（含确切FILES_TO_CREATE/MODIFY）。用户明确授权当前阶段，在当前分支执行，不提交。

- [x] 读取基线、盘点资源、确认分支/dirty tree、保存精确快照、制定规格。
- [ ] 添加test_p01_polish.gd并运行得到缺失Polish的RED；生成带许可证记录的TEMP WAV及小图标，验证无剪切和循环边界。
- [ ] 实现Audio固定cue与bus；实现World/Link/落地/ambient反馈及可关闭shader；连接既有已提交状态。
- [ ] 实现三阶段小键位教程和1.8秒完成组件，在P01根脚本只做装配；Reset清除视觉计时。
- [ ] 真实图形测试四条路线与输入锁/事件/混音capture；1x–4x像素测试；修复发现的问题并保留失败证据。
- [ ] 关闭F3，系统键鼠Q/E、鼠标、Master静音完整通关；记录首次玩家验证仍需用户。
- [ ] 回归Sprite/Tileset/Mechanism/Perspective/Orientation/X/P01，独立只读审查并解决重要问题。
- [ ] 同步设计与音画方向/manifest，完整性比对，输出P01_POLISH_FOUNDATION_REPORT及提交建议，停止。
