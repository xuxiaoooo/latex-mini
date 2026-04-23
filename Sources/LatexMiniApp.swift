import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import WebKit

@main
struct LatexMiniApp: App {
    @StateObject private var renderer = FormulaRenderer()
    @StateObject private var windowController = WindowController()

    var body: some Scene {
        WindowGroup {
            ContentView(renderer: renderer)
                .frame(
                    minWidth: WindowMetrics.minimumContentSize.width,
                    minHeight: WindowMetrics.minimumContentSize.height
                )
                .background(
                    WindowAccessor { window in
                        windowController.attach(window)
                    }
                )
        }
        .defaultSize(
            width: WindowMetrics.minimumContentSize.width,
            height: WindowMetrics.minimumContentSize.height
        )
    }
}

struct ContentView: View {
    @ObservedObject var renderer: FormulaRenderer

    private var hasInput: Bool {
        renderer.currentSource() != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            inputPane
            previewPane
            statusBar
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            renderer.showPlaceholder()
            renderer.scheduleRender()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LaTeX 公式工具")
                    .font(.subheadline.weight(.semibold))

                Text("自动实时编译")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("导出 SVG") {
                Task {
                    await renderer.exportSVG()
                }
            }
            .disabled(!hasInput)

            Button("复制 SVG") {
                Task {
                    await renderer.copySVG()
                }
            }
            .disabled(!hasInput)

            Button("复制 MathML") {
                Task {
                    await renderer.copyMathML()
                }
            }
            .disabled(!hasInput)
        }
        .controlSize(.mini)
    }

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LaTeX 输入")
                .font(.subheadline.weight(.medium))

            TextEditor(text: $renderer.latexSource)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 82, maxHeight: 94)
                .background(panelFill)
                .overlay(panelStroke)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onChange(of: renderer.latexSource) {
                    renderer.scheduleRender()
                }
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("预览")
                .font(.subheadline.weight(.medium))

            PreviewWebView(webView: renderer.webView)
                .background(panelFill)
                .overlay(panelStroke)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, minHeight: 178, maxHeight: 188)
    }

    private var statusBar: some View {
        HStack {
            Text(renderer.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("输入后自动更新")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var panelFill: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
    }

    private var panelStroke: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
    }
}

struct PreviewWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
    }
}

enum WindowMetrics {
    static let minimumContentSize = CGSize(width: 448, height: 420)
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

@MainActor
final class WindowController: NSObject, ObservableObject {
    @Published private(set) var isPinned = false

    private weak var window: NSWindow?
    private weak var pinButton: NSButton?
    private var accessoryController: NSTitlebarAccessoryViewController?
    private var didApplyInitialSize = false

    func attach(_ window: NSWindow) {
        self.window = window
        configureWindow(window)
        installPinAccessoryIfNeeded(on: window)
        syncPinnedState()
    }

    func togglePinned() {
        guard let window else {
            return
        }

        let nextPinnedState = !isPinned
        window.level = nextPinnedState ? .floating : .normal
        isPinned = nextPinnedState
        updatePinButton()
    }

    private func configureWindow(_ window: NSWindow) {
        let contentSize = NSSize(
            width: WindowMetrics.minimumContentSize.width,
            height: WindowMetrics.minimumContentSize.height
        )

        window.contentMinSize = contentSize

        if !didApplyInitialSize {
            window.setContentSize(contentSize)
            didApplyInitialSize = true
        }
    }

    private func installPinAccessoryIfNeeded(on window: NSWindow) {
        guard accessoryController == nil else {
            return
        }

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 34, height: 28))
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 28))
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = #selector(handlePinButtonPress)
        button.title = ""
        button.imagePosition = .imageOnly
        button.isBordered = true
        container.addSubview(button)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = container
        window.addTitlebarAccessoryViewController(accessory)

        pinButton = button
        accessoryController = accessory
        updatePinButton()
    }

    @objc
    private func handlePinButtonPress() {
        togglePinned()
    }

    private func syncPinnedState() {
        isPinned = window?.level == .floating
        updatePinButton()
    }

    private func updatePinButton() {
        let symbolName = isPinned ? "pin.fill" : "pin"
        pinButton?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: isPinned ? "取消置顶" : "置顶"
        )
        pinButton?.contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
        pinButton?.toolTip = isPinned ? "取消置顶" : "置顶显示"
    }
}

struct FormulaConversion: Sendable {
    let latex: String
    let svg: String
    let mathML: String
}

struct NodeRuntime: Sendable {
    let nodeURL: URL
    let scriptURL: URL
}

struct RendererEnvelope: Codable {
    let ok: Bool
    let svg: String?
    let mathml: String?
    let error: String?
}

@MainActor
final class FormulaRenderer: ObservableObject {
    @Published var latexSource = #"E = mc^2"#
    @Published private(set) var statusMessage = "就绪"

    let webView: WKWebView

    private var pendingRenderTask: Task<Void, Never>?
    private var cachedConversion: FormulaConversion?

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
    }

    func currentSource() -> String? {
        let trimmed = latexSource.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : latexSource
    }

    func showPlaceholder() {
        loadPreviewBody("<div class=\"placeholder\">公式会在这里自动预览</div>")
    }

    func scheduleRender() {
        pendingRenderTask?.cancel()
        pendingRenderTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(for: .milliseconds(220))
            await self.renderPreview()
        }
    }

    func exportSVG() async {
        guard let source = currentSource() else {
            statusMessage = "没有可导出的内容"
            return
        }

        do {
            let conversion = try await conversion(for: source)
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.nameFieldStringValue = "formula.svg"
            savePanel.allowedContentTypes = [.svg]

            if savePanel.runModal() == .OK, let url = savePanel.url {
                try conversion.svg.write(to: url, atomically: true, encoding: .utf8)
                statusMessage = "已导出 SVG"
            }
        } catch {
            statusMessage = "导出 SVG 失败: \(error.localizedDescription)"
        }
    }

    func copySVG() async {
        guard let source = currentSource() else {
            statusMessage = "没有可复制的内容"
            return
        }

        do {
            let conversion = try await conversion(for: source)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(conversion.svg, forType: .string)
            statusMessage = "SVG 已复制到剪贴板"
        } catch {
            statusMessage = "复制 SVG 失败: \(error.localizedDescription)"
        }
    }

    func copyMathML() async {
        guard let source = currentSource() else {
            statusMessage = "没有可复制的内容"
            return
        }

        do {
            let conversion = try await conversion(for: source)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(conversion.mathML, forType: .string)
            statusMessage = "MathML 已复制到剪贴板"
        } catch {
            statusMessage = "复制 MathML 失败: \(error.localizedDescription)"
        }
    }

    private func renderPreview() async {
        guard let source = currentSource() else {
            cachedConversion = nil
            showPlaceholder()
            statusMessage = "就绪"
            return
        }

        statusMessage = "正在自动编译…"

        do {
            let conversion = try await conversion(for: source)
            guard !Task.isCancelled else {
                return
            }

            loadPreviewBody(conversion.svg)
            statusMessage = "已自动更新"
        } catch {
            guard !Task.isCancelled else {
                return
            }

            loadPreviewBody("<pre class=\"error\">\(Self.escapeHTML(error.localizedDescription))</pre>")
            statusMessage = "编译失败: \(error.localizedDescription)"
        }
    }

    private func conversion(for source: String) async throws -> FormulaConversion {
        if let cachedConversion, cachedConversion.latex == source {
            return cachedConversion
        }

        let runtime = try resolveRuntime()
        let conversion = try await Task.detached(priority: .userInitiated) {
            try Self.runRenderer(runtime: runtime, latex: source)
        }.value

        cachedConversion = conversion
        return conversion
    }

    private func resolveRuntime() throws -> NodeRuntime {
        guard let scriptURL = Bundle.main.url(forResource: "render", withExtension: "js", subdirectory: "Renderer") else {
            throw RendererError.missingRendererScript
        }

        for candidate in nodeCandidates() where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return NodeRuntime(nodeURL: candidate, scriptURL: scriptURL)
        }

        throw RendererError.missingNodeBinary
    }

    private func nodeCandidates() -> [URL] {
        var candidates: [URL] = []

        if let pinned = Bundle.main.url(forResource: "node-path", withExtension: "txt", subdirectory: "Renderer"),
           let path = try? String(contentsOf: pinned, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            candidates.append(URL(fileURLWithPath: path))
        }

        let fixedPaths = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ]
        candidates.append(contentsOf: fixedPaths.map(URL.init(fileURLWithPath:)))

        let nvmRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nvm/versions/node", isDirectory: true)

        if let versions = try? FileManager.default.contentsOfDirectory(
            at: nvmRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
            candidates.append(contentsOf: versions.map { $0.appendingPathComponent("bin/node") })
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }

    private func loadPreviewBody(_ body: String) {
        webView.loadHTMLString(Self.previewHTML(body: body), baseURL: nil)
    }

    private static func previewHTML(body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              color-scheme: light;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }

            html, body {
              height: 100%;
              margin: 0;
              background: #ffffff;
            }

            body {
              box-sizing: border-box;
              min-height: 100vh;
              display: grid;
              place-items: center;
              padding: 12px;
              overflow: auto;
              background:
                radial-gradient(circle at top left, rgba(14, 116, 144, 0.08), transparent 28%),
                linear-gradient(180deg, #ffffff 0%, #f4f8fb 100%);
            }

            .placeholder {
              color: #64748b;
              font-size: 13px;
            }

            .error {
              width: 100%;
              white-space: pre-wrap;
              word-break: break-word;
              color: #b91c1c;
              font: 12px/1.5 SFMono-Regular, ui-monospace, monospace;
              margin: 0;
            }

            svg {
              max-width: 100%;
              max-height: calc(100vh - 24px);
              height: auto;
            }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    nonisolated private static func runRenderer(runtime: NodeRuntime, latex: String) throws -> FormulaConversion {
        let process = Process()
        process.executableURL = runtime.nodeURL
        process.arguments = [runtime.scriptURL.path]
        process.currentDirectoryURL = runtime.scriptURL.deletingLastPathComponent()

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let payload = try JSONEncoder().encode(["latex": latex])
        inputPipe.fileHandleForWriting.write(payload)
        inputPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        let stdout = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderr = try errorPipe.fileHandleForReading.readToEnd() ?? Data()

        if process.terminationStatus != 0 {
            let message = String(data: stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw RendererError.renderCommandFailed(message ?? "Node 进程退出码 \(process.terminationStatus)")
        }

        let envelope = try JSONDecoder().decode(RendererEnvelope.self, from: stdout)

        guard envelope.ok,
              let svg = envelope.svg,
              let mathml = envelope.mathml else {
            throw RendererError.renderCommandFailed(envelope.error ?? "渲染器没有返回完整结果")
        }

        return FormulaConversion(latex: latex, svg: svg, mathML: mathml)
    }
}

enum RendererError: LocalizedError {
    case missingRendererScript
    case missingNodeBinary
    case renderCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRendererScript:
            return "缺少渲染脚本"
        case .missingNodeBinary:
            return "没有找到可用的 Node.js，可在常见安装路径里补装"
        case .renderCommandFailed(let message):
            return message
        }
    }
}
