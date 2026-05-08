import GhostTileCore

enum AppOperations {
    static func hideApp(
        _ app: AppInfo,
        cliPath: String,
        acceptWarnings: Bool = false
    ) throws -> HideAppOperationResult {
        Log.info("Hiding app: \(app.name) (\(app.bundleId))")

        if AppManager.isAppleFirstParty(app.appPath) {
            throw GhostTileError("\(app.name) is an Apple system app and cannot be hidden.")
        }

        switch try AppManager.assessCompatibility(app) {
        case .compatible:
            break
        case let .unsupported(reason):
            throw GhostTileError(reason)
        case let .warnings(warnings):
            if !acceptWarnings {
                return .requiresWarningConfirmation(warnings)
            }
        }

        if try AppManager.needsSudo(app) {
            var arguments = ["manage", app.bundleId]
            if acceptWarnings { arguments.append("--accept-warnings") }
            return .requiresSudo(command: ShellCommand.format(
                executable: cliPath,
                arguments: arguments,
                requiresSudo: true
            ))
        }

        if try AppManager.needsPreparation(app) {
            try AppManager.prepare(app, cliPath: cliPath, acceptWarnings: acceptWarnings)
        }

        try AppManager.quit(app.bundleId)
        try AppManager.launchHidden(app)
        try Config.addHidden(app)

        return .hidden
    }

    static func removeApp(_ app: AppInfo, wasRunning: Bool) throws {
        if wasRunning {
            try AppManager.quit(app.bundleId)
        }

        try AppManager.restoreBinary(app.bundleId, binaryPath: app.binaryPath, appPath: app.appPath)
        try Config.removeHidden(app.bundleId)

        if wasRunning {
            try AppManager.launchNormal(app.appPath)
        }
    }
}
