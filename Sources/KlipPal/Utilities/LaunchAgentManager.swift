import Foundation

/// Manages the ~/Library/LaunchAgents plist for background launch at login.
final class LaunchAgentManager {
    static let label = "com.klippal.app"

    let plistDestination: URL
    private let templateProvider: () -> String?
    private let executableURL: URL
    private let shell: (String, [String]) -> Int32

    /// Production initializer — resolves paths from the running binary.
    convenience init() {
        let plistDest = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(LaunchAgentManager.label).plist")

        let execURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0])

        let templateProvider: () -> String? = {
            let candidate = execURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(LaunchAgentManager.label).plist")
            return FileManager.default.fileExists(atPath: candidate.path) ? candidate.path : nil
        }

        self.init(
            plistDestination: plistDest,
            executableURL: execURL,
            templateProvider: templateProvider,
            shell: LaunchAgentManager.runProcess
        )
    }

    init(
        plistDestination: URL,
        executableURL: URL,
        templateProvider: @escaping () -> String?,
        shell: @escaping (String, [String]) -> Int32 = LaunchAgentManager.runProcess
    ) {
        self.plistDestination = plistDestination
        self.executableURL = executableURL
        self.templateProvider = templateProvider
        self.shell = shell
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistDestination.path)
    }

    func install() throws {
        guard let templatePath = templateProvider(),
              let template = try? String(contentsOfFile: templatePath) else {
            throw LaunchAgentError.templateNotFound
        }

        let plistContent = template.replacingOccurrences(
            of: "KLIPPAL_BINARY_PATH",
            with: executableURL.path
        )

        let dir = plistDestination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try plistContent.write(to: plistDestination, atomically: true, encoding: .utf8)

        let exitCode = shell("/bin/launchctl", ["load", plistDestination.path])
        if exitCode != 0 {
            throw LaunchAgentError.launchctlFailed(exitCode)
        }
    }

    func uninstall() throws {
        guard isInstalled else { return }
        _ = shell("/bin/launchctl", ["unload", plistDestination.path])
        try FileManager.default.removeItem(at: plistDestination)
    }

    @discardableResult
    static func runProcess(_ executable: String, _ arguments: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus
    }
}

enum LaunchAgentError: Error, LocalizedError, Equatable {
    case templateNotFound
    case launchctlFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .templateNotFound:
            return "LaunchAgent plist template not found next to the KlipPal binary"
        case .launchctlFailed(let code):
            return "launchctl exited with code \(code)"
        }
    }
}
