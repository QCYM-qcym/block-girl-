# P-01 sound direction

本阶段只有基础声音，没有正式 BGM。14 个 WAV 全部由项目内确定性配方生成，标记 TEMPORARY；来源、作者、CC0-1.0 与再分发信息见 AUDIO_ASSET_MANIFEST.md。没有下载外部音乐或采样。

共同语言：短、柔和、留白。Roll 0.15 秒、Land 0.10 秒，低于每格 0.32 秒；每种 cue 只有一个 max_polyphony=1 的本地播放器。连续按键在真实落格时触发 Land，并在下一次合法 Roll 开始时触发 Roll；撞墙不重复播放。12 个 SFX 通道有固定上限。

Surface：soft / natural / restrained，轻空气与较亮的短泛音。Inner：cold / reversed / spatial，相关 motif 的反向冷尾音与空旷低频，不使用尖叫、惊吓、低频冲击或恐怖底床。两条 8 秒环境循环使用周期频率和首尾连续的配方，世界变化时约 0.4 秒交叉淡化。

层级：Master 0 dB；SFX -6 dB；Ambience -12 dB。本地类别增益 PLAYER -12、MECHANISM -10、WORLD -12、UI -8、AMBIENCE -10 dB。Link On/Off 另降低 8 dB，且 Link Off 素材比 On 更弱。素材自身保留峰值余量。完成后环境层再降低 14 dB，Reset 恢复。M 只控制本场运行的 Master 静音，不改系统音量。

声音只观察移动、世界、视角、连接和机关状态；不通过播放结束信号控制任何机关。缺少某条音频时跳过该 cue。关闭音频后逻辑仍继续。

未来可为各角色设计独立 sound motif；若叶睦候选 guitar string / harmonic。本轮不引入版权音乐，也不制作正式角色主题曲。连续滚动的主观耐听性、Inner 空间感与最终音量需要用户本人听音反馈；PCM 与 Runtime 检查只能证明触发、输出、叠音上限与峰值。
