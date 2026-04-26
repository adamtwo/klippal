import XCTest
@testable import KlipPal

final class LaunchAgentManagerTests: XCTestCase {

    private var tempDir: URL!
    private var plistDest: URL!
    private var templateFile: URL!
    private var fakeBinary: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAgentTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        plistDest = tempDir.appendingPathComponent("com.klippal.app.plist")
        templateFile = tempDir.appendingPathComponent("template.plist")
        fakeBinary = tempDir.appendingPathComponent("KlipPal")

        // Write a minimal plist template
        try plistTemplate.write(to: templateFile, atomically: true, encoding: .utf8)

        // Create a fake executable
        try "#!/bin/sh\n".write(to: fakeBinary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fakeBinary.path
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - isInstalled

    func testIsInstalledReturnsFalseWhenPlistAbsent() {
        let manager = makeManager()
        XCTAssertFalse(manager.isInstalled)
    }

    func testIsInstalledReturnsTrueAfterInstall() throws {
        let manager = makeManager()
        try manager.install()
        XCTAssertTrue(manager.isInstalled)
    }

    // MARK: - install

    func testInstallWritesPlistWithCorrectBinaryPath() throws {
        let manager = makeManager()
        try manager.install()

        let contents = try String(contentsOf: plistDest)
        XCTAssertTrue(contents.contains(fakeBinary.path), "Plist should contain the binary path")
        XCTAssertFalse(contents.contains("KLIPPAL_BINARY_PATH"), "Placeholder should be replaced")
    }

    func testInstallWritesRunAtLoadTrueWhenEnabled() throws {
        let manager = makeManager()
        try manager.install(runAtLoad: true)

        let contents = try String(contentsOf: plistDest)
        XCTAssertTrue(contents.contains("<true/>"), "RunAtLoad should be true when preference is enabled")
        XCTAssertFalse(contents.contains("KLIPPAL_RUN_AT_LOAD"), "Placeholder should be replaced")
    }

    func testInstallWritesRunAtLoadFalseWhenDisabled() throws {
        let manager = makeManager()
        try manager.install(runAtLoad: false)

        let contents = try String(contentsOf: plistDest)
        XCTAssertTrue(contents.contains("<false/>"), "RunAtLoad should be false when preference is disabled")
        XCTAssertFalse(contents.contains("KLIPPAL_RUN_AT_LOAD"), "Placeholder should be replaced")
    }

    func testInstallCreatesMissingLaunchAgentsDirectory() throws {
        // Use a destination inside a not-yet-created subdirectory
        let nestedDest = tempDir
            .appendingPathComponent("LaunchAgents/nested")
            .appendingPathComponent("com.klippal.app.plist")
        let manager = makeManager(plistDest: nestedDest)

        try manager.install()

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedDest.path))
    }

    func testInstallThrowsWhenTemplateNotFound() {
        let manager = LaunchAgentManager(
            plistDestination: plistDest,
            executableURL: fakeBinary,
            templateProvider: { nil },
            shell: { _, _ in 0 }
        )
        XCTAssertThrowsError(try manager.install()) { error in
            XCTAssertEqual(error as? LaunchAgentError, .templateNotFound)
        }
    }

    func testInstallDoesNotCallLaunchctl() throws {
        var shellCallCount = 0
        let manager = makeManager(shell: { _, _ in
            shellCallCount += 1
            return 0
        })

        try manager.install()

        XCTAssertEqual(shellCallCount, 0, "install() must not call launchctl — starting the agent immediately would spawn a duplicate if the app is already running")
    }

    // MARK: - uninstall

    func testUninstallRemovesPlist() throws {
        let manager = makeManager()
        try manager.install()
        try manager.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: plistDest.path))
    }

    func testUninstallCallsLaunchctlRemove() throws {
        var capturedExe: String = ""
        var capturedArgs: [String] = []
        let manager = makeManager(shell: { exe, args in
            capturedExe = exe
            capturedArgs = args
            return 0
        })

        try manager.install()
        try manager.uninstall()

        XCTAssertTrue(capturedExe.hasSuffix("launchctl"))
        XCTAssertEqual(capturedArgs, ["remove", LaunchAgentManager.label])
    }

    func testUninstallIsNoOpWhenNotInstalled() {
        let manager = makeManager()
        XCTAssertNoThrow(try manager.uninstall())
    }

    func testIsInstalledFalseAfterUninstall() throws {
        let manager = makeManager()
        try manager.install()
        try manager.uninstall()
        XCTAssertFalse(manager.isInstalled)
    }

    // MARK: - Duplicate-launch regression

    // install() must NOT call launchctl load. If it did, launchd would start a second
    // instance immediately whenever the user toggles the preference while the app is running.
    // The plist is written to ~/Library/LaunchAgents so launchd picks it up at next login.

    func testInstallCalledTwiceNeverCallsLaunchctlLoad() throws {
        var loadCallCount = 0
        let manager = makeManager(shell: { _, args in
            if args.first == "load" { loadCallCount += 1 }
            return 0
        })

        try manager.install()
        try manager.install()

        XCTAssertEqual(loadCallCount, 0, "install() must never call launchctl load to avoid spawning a duplicate instance")
    }

    func testUninstallBeforeReinstallOnlyCallsRemoveOnce() throws {
        var commands: [String] = []
        let manager = makeManager(shell: { _, args in
            if let verb = args.first { commands.append(verb) }
            return 0
        })

        try manager.install()
        try manager.uninstall()
        try manager.install()

        XCTAssertEqual(commands, ["remove"], "Only uninstall() should touch launchctl, with a single remove call")
    }

    func testUninstallBeforeInstallNeverLeavesStaleLoadedAgent() throws {
        var commands: [String] = []
        let manager = makeManager(shell: { _, args in
            if let verb = args.first { commands.append(verb) }
            return 0
        })

        try manager.install()
        try manager.uninstall()
        try manager.install()

        XCTAssertFalse(commands.contains("load"), "install() must never call launchctl load")
        XCTAssertEqual(commands.filter { $0 == "remove" }.count, 1, "uninstall() calls remove exactly once")
    }

    // MARK: - Helpers

    private func makeManager(
        plistDest: URL? = nil,
        shell: @escaping (String, [String]) -> Int32 = { _, _ in 0 }
    ) -> LaunchAgentManager {
        LaunchAgentManager(
            plistDestination: plistDest ?? self.plistDest,
            executableURL: fakeBinary,
            templateProvider: { self.templateFile.path },
            shell: shell
        )
    }

    private let plistTemplate = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.klippal.app</string>
        <key>ProgramArguments</key>
        <array>
            <string>KLIPPAL_BINARY_PATH</string>
        </array>
        <key>RunAtLoad</key>
        KLIPPAL_RUN_AT_LOAD
    </dict>
    </plist>
    """
}
