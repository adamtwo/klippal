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

    func testInstallCallsLaunchctlLoad() throws {
        var capturedArgs: [String] = []
        let manager = makeManager(shell: { _, args in
            capturedArgs = args
            return 0
        })

        try manager.install()

        XCTAssertEqual(capturedArgs.first, "load")
        XCTAssertEqual(capturedArgs.last, plistDest.path)
    }

    func testInstallThrowsWhenLaunchctlFails() {
        let manager = makeManager(shell: { _, _ in 1 })
        XCTAssertThrowsError(try manager.install()) { error in
            if case LaunchAgentError.launchctlFailed(let code) = error as! LaunchAgentError {
                XCTAssertEqual(code, 1)
            } else {
                XCTFail("Expected launchctlFailed error")
            }
        }
    }

    // MARK: - uninstall

    func testUninstallRemovesPlist() throws {
        let manager = makeManager()
        try manager.install()
        try manager.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: plistDest.path))
    }

    func testUninstallCallsLaunchctlUnload() throws {
        var capturedArgs: [String] = []
        var callCount = 0
        let manager = makeManager(shell: { _, args in
            callCount += 1
            if callCount == 2 { capturedArgs = args }  // second call is unload
            return 0
        })

        try manager.install()
        try manager.uninstall()

        XCTAssertEqual(capturedArgs.first, "unload")
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
        <true/>
    </dict>
    </plist>
    """
}
