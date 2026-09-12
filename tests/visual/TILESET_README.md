# Tileset asset validation

在 Godot 打开 `res://tests/visual/tileset_runtime_test.tscn`，F6 运行；不是项目主场景。D：并排样板；1–4：像素倍率；F：五块地面；W：墙角；T：楼梯连接；O：墙后遮挡。

`tileset_paired_sample.tscn` 是已保存的编辑器样板，包含 Surface / Inner 各五个真正 TileMapLayer（Ground、Structures、ElevatedBridge、ElevatedWall、Decorations）和已验收角色。可选中 TileMapLayer 查看 atlas、custom data 和基本碰撞。样板没有关卡或机制逻辑。

自动运行：`run_tileset_validation.ps1 -Auto -EvidenceName new_run`。会实际打开图形窗口，完成所有原生 Tile 的 1×–4× 采样、拼接、七种角色摆位和基本物理点查询，保存真实 GPU 截图及 engine_runtime_report.json。输出目录有 .gdignore，不作为游戏资源导入。

完整像素分析工具：`E:/godot/若叶睦/tileset_production_work/analyze_runtime.cjs`，参数是 EvidenceName。需要本机已配置的 Node / Sharp 路径。最终已验证证据见 `tileset_evidence/run_03/`；该工具的 PASS 与引擎检查、实机目检共同构成验收，单独生成 PNG 不算运行验收。

生产规则见 `res://production/tilesets/TILESET_SPEC.md`。标准 TileSet `DIAMOND_DOWN` 的原始首格中心为 (16,8)，样板层 position=(-16,-8) 归一化到父节点原点。脚点使用 `layer.position + layer.map_to_local(cell) - Vector2(0,elevation)`。Sprite offset 保持 (0,-9)。同高度前后使用 Y-sort；高处落脚面使用指定上层 stratum，未实现自动高度控制器。

所有 PNG Lossless、无 mipmap。CanvasItem 必须显式 Nearest；项目默认 Linear 保持不变。表里 Tile 同逻辑同通行，未来世界差异道路应改变 logical tile ID，而非暗改同 ID 碰撞。
