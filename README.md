# StreamGather

StreamGather 是一款适用于 Apple 芯片 Mac 的网页音视频下载客户端。粘贴网页链接后，可以下载视频或独立音轨，在窗口里查看进度、取消下载或打开成品目录。客户端使用 Swift 和 AppKit 编写，通过 yt-dlp 解析网页，再用 FFmpeg 合并分开的画面与音轨。

## 开始使用

需要 Apple 芯片和 macOS 14 或更高版本。

1. 克隆仓库，或在 GitHub 的 **Code → Download ZIP** 下载并解压整个项目。
2. 双击项目中的 **StreamGather.app**。请将应用、`yt-dlp` 和 `tools/` 放在同一目录。
3. 粘贴网页链接，选择 **视频** 或 **仅音频**，点击 **开始下载**。仅音频模式需要网站提供独立音轨。
4. 下载完成后点击 **打开文件夹**。成品默认保存在项目的 `Download/` 中，也可以在界面里改为项目内的其他文件夹。

## YouTube 登录

默认使用访客模式。遇到要求登录或确认年龄的视频时，先在浏览器中用自己的账号确认可以播放，再在客户端的 **YouTube 登录** 菜单中选择同一个浏览器。下载时 yt-dlp 会在本机读取浏览器 Cookie。macOS 可能提示授权钥匙串访问。可下载的清晰度和格式取决于网站、账号权限以及 yt-dlp 的解析能力。

## 项目文件

| 路径 | 用途 |
| --- | --- |
| `StreamGather.app/` | 编译好的 macOS 客户端 |
| `src/main.swift` | 客户端源码 |
| `yt-dlp` | 网页媒体解析与下载工具 |
| `tools/` | FFmpeg、ffprobe 和随附的上游说明 |

如需卸载，先移走要保留的下载文件，然后退出客户端并删除项目目录。

## 第三方组件

网页解析使用 [yt-dlp](https://github.com/yt-dlp/yt-dlp)。媒体合并和探测使用 [FFmpeg](https://ffmpeg.org/)，项目随附的 macOS ARM64 工具取自 [ffmpeg-static 发布页](https://github.com/eugeneware/ffmpeg-static/releases/tag/b6.1.1)。相关许可见 [yt-dlp 发布说明](https://github.com/yt-dlp/yt-dlp#licensing) 和 [FFmpeg 许可说明](tools/FFmpeg-LICENSE)。
