import GhostTileCore

enum HideAppOperationResult {
    case hidden
    case requiresSudo(command: String)
}

enum AppOperations {
    static func hideApp(_ app: AppInfo, cliPath: String) throws -> HideAppOperationResult {
        Log.info("Hiding app: \(app.name) (\(app.bundleId))")

        if AppManager.isAppleFirstParty(app.appPath) {
            throw GhostTileError("\(app.name) is an Apple system app and cannot be hidden.")
        }

        if try AppManager.needsSudo(app) {
            return .requiresSudo(command: "sudo \(cliPath) manage \(app.bundleId)")
        }

        if try AppManager.needsPreparation(app) {
            try AppManager.prepare(app)
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
