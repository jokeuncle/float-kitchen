# 0.1.0 公开交付结果

2026-11-09，Float Kitchen 已作为独立项目发布；源码与官网变更均已推送远程。

- 产品与使用：https://harnessloom.com/float-kitchen/
- 公开源码：https://github.com/jokeuncle/float-kitchen
- DMG、ZIP、SHA256：https://github.com/jokeuncle/float-kitchen/releases/tag/v0.1.0
- 官网本次版本：0f12b6b5576be25c，214项公网检查通过；实际浏览器从产品页点击下载的DMG与发布hash一致。
- 原生97项核心回归、11项打包检查，独立解压及挂载DMG运行检查通过。八状态、展开/迷你、小票、说明书和长文案完成画面走查。
- 真实Codex已逐项核对读取、搜索、首次测试失败、修改、重测通过、本轮完成的状态和文字，见 [真实对账](REAL_CODEX_CHECK.md)。Claude未实跑。
- 官网延续原有Harnessloom风格；真实浏览器核对深浅主题、手机布局、八种动作与文字，没有观察到CSP错误、破图或文字溢出。

DMG：7,323,368字节，SHA-256 `2ac93205df15a323025a8798191abf60f4cdd06ab7721429ef1ebfbb84b05db5`。
ZIP：7,106,640字节，SHA-256 `d030cd3cbbfd11374ff949a40de06ad0a2936750c6dc7d151b1758561333c1df`。

这是macOS14+Apple Silicon预览版，采用本地签名，未经过Apple公证。性能样本只代表本机；主线程显示回调不等于GPU呈现率。客户端格式和动态脚本的识别边界见动作说明书。
