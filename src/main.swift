import AppKit

func label(_ value: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSTextField {
    let field = NSTextField(labelWithString: value)
    field.font = .systemFont(ofSize: size, weight: weight)
    return field
}

func row(_ views: [NSView], spacing: CGFloat = 10) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = spacing
    return stack
}

func group(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = spacing
    for view in views { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    return stack
}

final class Downloader: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let root = Bundle.main.bundleURL.deletingLastPathComponent()
    lazy var folder = root.appendingPathComponent("Download", isDirectory: true)
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 610, height: 488),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    let link = NSTextField()
    let mode = NSSegmentedControl(labels: ["视频", "仅音频"], trackingMode: .selectOne, target: nil, action: nil)
    let youtubeLogin = NSPopUpButton(frame: .zero, pullsDown: false)
    let location = label("", 13)
    let status = label("等待下载", 13, .medium)
    let progress = NSProgressIndicator()
    let start = NSButton(title: "开始下载", target: nil, action: nil)
    let choose = NSButton(title: "更改…", target: nil, action: nil)
    let reveal = NSButton(title: "打开文件夹", target: nil, action: nil)
    var running: Process?
    var canceled = false
    var quitting = false
    var lastError = ""
    var savedPath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "StreamGather"
        window.delegate = self
        installMenu()
        let icon = NSImageView(image: NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)!)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 38, weight: .medium)
        icon.contentTintColor = .systemBlue
        let heading = row([icon, label("StreamGather", 28, .bold), NSView()], spacing: 12)

        link.placeholderString = "粘贴视频或音频的网页链接"
        link.controlSize = .large
        link.font = .systemFont(ofSize: 15)
        link.lineBreakMode = .byTruncatingMiddle
        link.setAccessibilityLabel("网页链接")
        link.target = self
        link.action = #selector(submitLink)
        let paste = NSButton(title: "粘贴", target: self, action: #selector(pasteLink))
        paste.controlSize = .large
        let input = row([link, paste])
        link.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mode.selectedSegment = 0
        mode.setWidth(76, forSegment: 0)
        mode.setWidth(76, forSegment: 1)
        let type = row([label("下载内容", 13, .semibold), mode, NSView()], spacing: 16)
        youtubeLogin.addItem(withTitle: "访客模式")
        for (name, browser) in [("Google Chrome", "chrome"), ("Safari", "safari"), ("Firefox", "firefox"),
                                ("Microsoft Edge", "edge"), ("Brave", "brave")] {
            youtubeLogin.addItem(withTitle: name)
            youtubeLogin.lastItem?.representedObject = browser
        }
        youtubeLogin.setAccessibilityLabel("YouTube 登录")
        youtubeLogin.toolTip = "选择浏览器后，yt-dlp 将在本机读取该浏览器的 Cookie，用于 YouTube 下载。"
        let loginRow = row([label("YouTube 登录", 13, .semibold), youtubeLogin, NSView()], spacing: 16)
        location.lineBreakMode = .byTruncatingMiddle
        location.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateFolder()
        choose.target = self
        choose.action = #selector(selectFolder)
        let folderIcon = NSImageView(image: NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!)
        folderIcon.contentTintColor = .secondaryLabelColor
        let pathRow = row([folderIcon, location, NSView(), choose])
        let divider = NSBox()
        divider.boxType = .separator
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 100
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        reveal.target = self
        reveal.action = #selector(openFolder)
        reveal.bezelStyle = .inline
        reveal.isHidden = true
        let activity = row([status, NSView(), reveal])
        start.target = self
        start.action = #selector(startOrCancel)
        start.controlSize = .large
        start.bezelStyle = .rounded
        start.bezelColor = .systemBlue
        let controls = group([
            heading, group([label("网页链接", 13, .semibold), input], spacing: 7),
            type, loginRow, group([label("保存位置", 13, .semibold), pathRow], spacing: 4),
            divider, group([activity, progress], spacing: 7), start
        ], spacing: 20)
        let content = window.contentView!
        controls.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            controls.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            controls.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)
        ])
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: 610, height: controls.fittingSize.height + 52))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(link)
        NSApp.activate(ignoringOtherApps: true)
    }

    func installMenu() {
        let bar = NSMenu()
        for (title, items) in [("StreamGather", [("退出StreamGather", "terminate:", "q")]),
                            ("编辑", [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("拷贝", "copy:", "c"),
                                     ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")])] {
            let item = NSMenuItem()
            bar.addItem(item)
            let menu = NSMenu(title: title)
            item.submenu = menu
            for (name, action, key) in items {
                menu.addItem(withTitle: name, action: NSSelectorFromString(action), keyEquivalent: key)
            }
        }
        NSApp.mainMenu = bar
    }

    func updateFolder() {
        location.stringValue = (folder.path as NSString).abbreviatingWithTildeInPath
        location.toolTip = folder.path
    }

    @objc func pasteLink() {
        guard running == nil else { return }
        if let url = NSPasteboard.general.string(forType: .string) { link.stringValue = url }
    }

    @objc func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        panel.message = "请选择 StreamGather 项目内的保存文件夹。"
        panel.prompt = "选择文件夹"
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url {
                guard self.isProjectFolder(url) else {
                    self.showStatus("保存位置须在 StreamGather 项目内。", error: true)
                    return
                }
                self.folder = url
                self.updateFolder()
                self.reveal.isHidden = true
            }
        }
    }

    func isProjectFolder(_ url: URL) -> Bool {
        let project = root.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return url.standardizedFileURL.resolvingSymlinksInPath().pathComponents.starts(with: project)
    }

    @objc func openFolder() { NSWorkspace.shared.open(folder) }
    @objc func submitLink() { if running == nil { startOrCancel() } }

    func showStatus(_ text: String, error: Bool = false) {
        status.stringValue = text
        status.toolTip = text
        status.textColor = error ? .systemRed : .secondaryLabelColor
    }

    func setBusy(_ busy: Bool) {
        link.isEnabled = !busy
        choose.isEnabled = !busy
        mode.isEnabled = !busy
        youtubeLogin.isEnabled = !busy
        start.isEnabled = true
        start.title = busy ? "取消下载" : "开始下载"
    }

    @objc func startOrCancel() {
        if let task = running {
            canceled = true
            start.isEnabled = false
            showStatus("正在取消…")
            if task.isRunning { task.interrupt() }
            return
        }
        let value = link.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URLComponents(string: value), ["https", "http"].contains(url.scheme?.lowercased()),
              let host = url.host, !host.isEmpty, !value.contains(where: { $0.isWhitespace }) else {
            showStatus("请输入完整的 http 或 https 网页链接。", error: true)
            window.makeFirstResponder(link)
            return
        }
        let tool = root.appendingPathComponent("yt-dlp")
        guard FileManager.default.isExecutableFile(atPath: tool.path) else {
            showStatus("找不到 yt-dlp。请将客户端和 yt-dlp 放在同一个文件夹。", error: true)
            return
        }
        let task = Process()
        task.executableURL = tool
        let tools = root.appendingPathComponent("tools", isDirectory: true)
        guard ["ffmpeg", "ffprobe"].allSatisfy({ FileManager.default.isExecutableFile(atPath: tools.appendingPathComponent($0).path) }) else {
            showStatus("项目 tools 文件夹中缺少 FFmpeg 或 ffprobe。", error: true)
            return
        }
        let work = root.appendingPathComponent(".work", isDirectory: true)
        let parts = work.appendingPathComponent("parts", isDirectory: true)
        guard [folder, work, parts].allSatisfy(isProjectFolder) else {
            showStatus("保存位置和临时目录须在 StreamGather 项目内。", error: true)
            return
        }
        let format = mode.selectedSegment == 1 ? "bestaudio/best[vcodec=none]" : "bestvideo*+bestaudio/best"
        let domain = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let isThisVidVideo = mode.selectedSegment == 0 && (domain == "thisvid.com" || domain.hasSuffix(".thisvid.com"))
        // ThisVid supplies a quality rank for HQ even when its height is missing.
        let sortOrder = isThisVidVideo ? "quality,res,vcodec:h264" : "res,vcodec:h264"
        let qualitySuffix = isThisVidVideo ? " [%(format_id).32B]" : ""
        let filename = "%(title).120B [%(id).60B]" + qualitySuffix + ".%(ext)s"
        task.currentDirectoryURL = root
        var environment = ProcessInfo.processInfo.environment
        environment["TMPDIR"] = work.path
        task.environment = environment
        task.arguments = ["--ignore-config", "--no-cache-dir", "--no-plugin-dirs", "--no-playlist", "--no-simulate",
                          "--ffmpeg-location", tools.path, "-S", sortOrder,
                          "--newline", "--progress", "--progress-template", "download:PROGRESS %(progress._percent_str)s",
                          "--progress-template", "postprocess:POST %(progress.postprocessor)s",
                          "--print", "after_move:FILE %(filepath)s", "-f", format,
                          "-P", "home:" + folder.path, "-P", "temp:" + parts.path,
                          "-o", filename, "--", value]
        let youtubeHost = domain == "youtu.be" || domain == "youtube.com" || domain.hasSuffix(".youtube.com")
        if youtubeHost, url.scheme?.lowercased() == "https",
           let browser = youtubeLogin.selectedItem?.representedObject as? String {
            task.arguments?.insert(contentsOf: ["--cookies-from-browser", browser], at: 0)
        }
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.standardInput = FileHandle.nullDevice
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: parts, withIntermediateDirectories: true)
            try task.run()
        } catch {
            showStatus("无法开始下载：" + error.localizedDescription, error: true)
            return
        }
        running = task
        canceled = false
        savedPath = nil
        lastError = ""
        setBusy(true)
        reveal.isHidden = true
        progress.doubleValue = 0
        progress.isIndeterminate = true
        progress.startAnimation(nil)
        showStatus("正在解析网页…")
        DispatchQueue.global(qos: .utility).async {
            var buffer = Data()
            let handle = pipe.fileHandleForReading
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let end = buffer.firstIndex(of: 10) {
                    let line = String(decoding: buffer[..<end], as: UTF8.self)
                    buffer.removeSubrange(...end)
                    DispatchQueue.main.async { self.consume(line) }
                }
            }
            if !buffer.isEmpty {
                let line = String(decoding: buffer, as: UTF8.self)
                DispatchQueue.main.async { self.consume(line) }
            }
            task.waitUntilExit()
            DispatchQueue.main.async { self.finish(task.terminationStatus) }
        }
    }

    func consume(_ line: String) {
        if canceled { return }
        if line.hasPrefix("PROGRESS ") {
            let percent = line.dropFirst(9).trimmingCharacters(in: .whitespacesAndNewlines)
            if let number = Double(percent.replacingOccurrences(of: "%", with: "")) {
                progress.isIndeterminate = false
                progress.doubleValue = number
                showStatus("正在下载  " + percent)
            } else { showStatus("正在下载…") }
        } else if line.hasPrefix("POST "), line.contains("Merger") {
            progress.isIndeterminate = true
            progress.startAnimation(nil)
            showStatus("正在合并画面和声音…")
        } else if line.hasPrefix("FILE ") {
            savedPath = String(line.dropFirst(5))
        } else if line.hasPrefix("ERROR:") {
            lastError = String(line.dropFirst(6))
        }
    }

    func finish(_ code: Int32) {
        running = nil
        setBusy(false)
        progress.stopAnimation(nil)
        progress.isIndeterminate = false
        progress.doubleValue = 0
        if canceled { showStatus("已取消下载") }
        else if code == 0, let path = savedPath, FileManager.default.fileExists(atPath: path) {
            progress.doubleValue = 100
            showStatus("已保存 · " + (path as NSString).lastPathComponent)
            reveal.isHidden = false
        } else if lastError.contains("[youtube]"), lastError.localizedCaseInsensitiveContains("confirm your age") {
            let help = youtubeLogin.indexOfSelectedItem == 0
                ? "此视频需要年龄验证。请在浏览器中确认能播放，再从「YouTube 登录」选择该浏览器。"
                : "YouTube 仍要求年龄验证。请确认所选浏览器的账号能播放这条视频。"
            showStatus(help, error: true)
        } else if lastError.contains("Requested format is not available") {
            showStatus(mode.selectedSegment == 1 ? "网页未提供可直接下载的独立音轨。" : "没有找到可用的视频和音频组合。", error: true)
        } else {
            showStatus(lastError.isEmpty ? "下载失败，请检查网址和网络后重试。" : "下载失败：" + lastError, error: true)
        }
        if quitting { NSApp.reply(toApplicationShouldTerminate: true) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let task = running else { return .terminateNow }
        quitting = true
        canceled = true
        if task.isRunning { task.interrupt() }
        return .terminateLater
    }
}

let app = NSApplication.shared
let delegate = Downloader()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
