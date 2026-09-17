# 1.1.0fix 后台驱动优化候选版

基于 Yoroin/GlobalRefresh-PiP，commit 8004d96。原作者 CaiWanFeng，维护者 Yoroin；保留原项目署名和 NOTICE。

## 修改
- 无悬浮窗启动意图、活动会话或转场时，进入后台停止主高刷驱动。
- 悬浮窗启动、停止、启动失败及会话状态变化时重新判断驱动需求；0.1pt隐藏及侧边吸附不作为停止条件。
- 已有主驱动复用，不在前后台切换时销毁再创建。
- 切换到其他引擎时显式停止原驱动。
- 高刷开关名称改为“高刷请求120Hz（影响悬浮窗）”，澄清其实际影响范围。

## 边界与验证
保留原120Hz请求范围、VideoCall/PlayerLayer及保活机制。不是全局120帧保证，不包含测量其他App帧率的功能。
已做差异/空白检查，并审阅启动、停止和失败路径。当前Linux环境没有Xcode或iPhone，尚未完成iOS编译、实机帧率或耗电验证。正常持续运行隐藏PiP时仍保持高刷请求，此修改主要减少无会话后台运行及驱动重建，不承诺运行中明显省电。

## 构建未签名IPA
把源码放入自己的GitHub仓库，Actions中手动运行 Build unsigned optimized IPA。成功后下载 GlobalRefresh-optimized-unsigned 工件，解压得到IPA，使用原有证书签名安装。
构建依赖提供足够新iOS SDK的macOS/Xcode runner；如果默认runner SDK不支持源码中的接口，需要换用相应Xcode环境。此工作流未在本环境运行。
也可在Mac用Xcode打开 pip_swift/pip_swift.xcworkspace，选择pip_swift scheme构建。

## 实机回归
1. 默认VideoCall启动→吸附→0.1pt隐藏→切换其他App：会话应继续存活。
2. 停止PiP后切到后台；打开调试日志时应看到 background without a PiP session 的驱动停止记录。
3. 重新启动、其他PiP挤掉、启动失败后重试、切换PlayerLayer：检查恢复和停止均正常。
4. 相同亮度、温度、内容、时长下与原版比较。若中断或流畅度退化，恢复原版；日志记录不是其他App达到120帧的证据。
