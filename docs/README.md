# Float Kitchen · AI 后厨

一个独立的原生 macOS 悬浮应用，把本地 AI 客户端的活动变成微缩餐馆的演出。独立安装、独立运行。

## 打开

```sh
zsh scripts/build-kitchen.sh
open 'build/Float Kitchen.app'
```

首次启动为明确标注的「看场好戏」演示模式。点「真实活动」后，自动只读监听 `~/.codex/sessions` 与 `~/.claude/projects` 中最近更新的会话记录。三个厨师从左至右分别代表 Codex、Claude 和自定义事件。点击厨师或下面的客户端按钮选择要查看的状态。

右上角可切换置顶、迷你模式或隐藏。菜单栏的平底锅可找回窗口、重置位置、切换模式、打开小票或退出。窗口可以拖动；位置会保存。不自动开机启动。

## 活动与小票

八种独立姿势（道具已绘在各自姿势里）：读文件捧食谱、搜索提采购袋、执行任务翻锅、测试掀盖看火候、等待确认指铃、失败端糊锅、完成后端盘、闲置喝咖啡。每个工位牌直接显示实际活动、工具名或受限的文件信息。闲置两分钟后转为小憩。事件采用实际源时间，不把旧日志伪装成当前任务。多个同客户端会话聚合到一个厨师；不展示单会话的准确进度百分比。

「订单小票」可展开最近六步活动，文本可选择和复制。显示客户端、发生时间、工具名及受限的文件名或命令类别。自动日志来源不保留对话正文、私有推理、工具输出、完整路径和命令参数。不会发送网络请求。未知日志类型忽略；客户端升级改变格式时可能需要适配。某些通用脚本调用只能显示“运行脚本/工具”，无法判断脚本里每个操作。自动日志只在最近事件发生后反映状态；等待审批仅在来源显式提供该事件时可识别。

## 自定义客户端

可通过「接入事件」打开本地事件目录，或连接另一个持续追加的 JSONL 文件。无需开放端口、API Key 或修改客户端设置。

```sh
python3 scripts/kitchen-event.py reading --client Local --tool read_file
python3 scripts/kitchen-event.py cooking --client Local --label '正在构建小厨房'
python3 scripts/kitchen-event.py served --client Local
```

默认文件：`~/Library/Application Support/FloatKitchen/events.jsonl`，仅在本机追加。

```json
{"id":"unique-event-id","timestamp":"2026-11-09T08:00:00Z","client":"Local","event":"cooking","tool":"build","label":"正在构建小厨房"}
```

`event` 支持 `idle`、`reading`、`searching`、`cooking`、`testing`、`waiting`、`failed`、`served`。`client` 为 `Codex`、`Claude` 或 `Local`。`label` 是客户端主动提供的小票说明，最多90字符；请只传希望在小票中展示的文本。无时间戳时采用文件修改时间；建议每条事件包含时间戳。

## 性能设计

原生 AppKit + Core Animation；厨房为专用 layer-hosting 视图，八格角色先各自裁成独立缓存 CGImage，避免精灵图串格。工位牌由独立的静态 AppKit 兄弟视图绘制，两行分别按实际字体测量后单行省略，图标与文字通过共享基线和 cap-height 对齐。姿势切换淡入淡出360ms、收势280ms；其他未变化的客户端继续原有动画。连续动画在合成器中运行，没有逐帧 Swift 绘制计时器。窗口隐藏、被遮挡或休眠时停止连续动画，遵循系统「减弱动态效果」。演示可暂停；真实日志每2秒在后台增量读取，每20秒发现一次源文件。每个来源单次最多512KiB，每个客户端最多4个近期文件；截断、轮换、半行写入都有处理，队列和历史有上限。未改动的来源不会重复解析。

## 检查

```sh
swift run KitchenCoreChecks
'build/Float Kitchen.app/Contents/MacOS/FloatKitchen' --self-check --exit-after-check
'build/Float Kitchen.app/Contents/MacOS/FloatKitchen' --integration-check --exit-after-check
open 'build/Float Kitchen.app' --args --performance-report "$PWD/build/kitchen-performance.json"
open 'build/Float Kitchen.app' --args --preview-dir "$PWD/build/kitchen-preview"
```

性能采样为8秒进程 CPU、峰值RSS和主线程显示回调间隔。显示回调频率不是GPU实际呈现率，不能据此承诺所有机器都无丢帧。UI走查截图来自真实AppKit视图。

「看懂后厨」入口提供八种动作的说明及逐项演示；[动作说明书](动作说明书.md) 也随应用打包。

素材通过内置 image_gen 工具生成。运行时场景仅打包 `kitchen.png` 与 `chef-states.png`；`chefs.png` 保留在源目录，供构建应用图标使用。各素材的精确提示词保存在同目录，并嵌入 PNG 元数据。废弃的 `activity-props-prompt.txt` 仅保留为创作记录，不再使用单独叠加的前景道具。生产源素材位于 `Sources/FloatKitchen/Assets`，不依赖外部图片地址或运行时下载。应用仅本地临时签名，未做 Apple 公证或跨机器系统版本兼容性验收。

本应用的独立产品和视觉规范见 [PRODUCT.md](PRODUCT.md)、[DESIGN.md](DESIGN.md)，实际验收与性能样本见 [PERFORMANCE.md](PERFORMANCE.md)。
