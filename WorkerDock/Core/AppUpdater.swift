import Foundation
import Sparkle

/// Wraps Sparkle. Updates are signed with the key whose public half is SUPublicEDKey in Info.plist and served
/// from the appcast at SUFeedURL. Debug builds and test runs don't check, so developing never nags.
@MainActor
final class AppUpdater {
    static let shared = AppUpdater()

    /// Debug builds can opt in with WORKERDOCK_UPDATER=1 to try the flow.
    let isEnabled: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["WORKERDOCK_DEMO"] != nil { return false }
        #if DEBUG
        return env["WORKERDOCK_UPDATER"] != nil
        #else
        return true
        #endif
    }()

    private var controller: SPUStandardUpdaterController?

    func start() {
        guard isEnabled, controller == nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    func checkForUpdates() { controller?.checkForUpdates(nil) }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }
}
