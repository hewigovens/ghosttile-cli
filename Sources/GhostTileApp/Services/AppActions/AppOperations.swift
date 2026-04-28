import GhostTileCore

enum AppOperations {
    static func hideApp(_ app: AppInfo, cliPath: String) throws -> HideAppOperationResult {
        Log.info("Hiding app: \(app.name) (\(app.bundleId))")

        if AppManager.isAppleFirstParty(app.appPath) {
            throw GhostTileError("\(app.name) is an Apple system app and cannot be hidden.")
        }

        if try AppManager.needsSudo(app) {
            return .requiresSudo(command: ShellCommand.format(
                executable: cliPath,
                arguments: ["manage", app.bundleId],
                requiresSudo: true
            ))
        }

        if try AppManager.needsPreparation(app) {
            try AppManager.prepare(app, cliPath: cliPath)
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
