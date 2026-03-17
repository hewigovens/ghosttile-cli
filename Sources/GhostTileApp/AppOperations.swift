import GhostTileCore

enum HideAppOperationResult {
    case hidden
    case requiresSudo(command: String)
}

enum AppOperations {
    static func hideApp(
        bundleId: String,
        name: String,
        appPath: String,
        binaryPath: String,
        cliPath: String
    ) throws -> HideAppOperationResult {
        Log.info("Hiding app: \(name) (\(bundleId))")

        if AppManager.isAppleFirstParty(appPath) {
            Log.info("Blocked: \(name) is Apple first-party")
            throw GhostTileError("\(name) is an Apple system app and cannot be hidden.")
        }

        let info = AppInfo(
            bundleId: bundleId,
            name: name,
            appPath: appPath,
            binaryPath: binaryPath
        )

        if try AppManager.needsSudo(info) {
            Log.info("Blocked: \(name) needs manual step via CLI")
            return .requiresSudo(command: "sudo \(cliPath) manage \(bundleId)")
        }

        if try AppManager.needsPreparation(info) {
            try AppManager.prepare(info)
        }

        try AppManager.quit(bundleId)
        try AppManager.launchHidden(info)
        try Config.addHidden(
            bundleId,
            app: HiddenApp(
                name: name,
                appPath: appPath,
                binaryPath: binaryPath,
                prepared: true
            )
        )

        return .hidden
    }

    static func launchManagedVisible(
        bundleId: String,
        name: String,
        appPath: String,
        binaryPath: String
    ) throws {
        let info = AppInfo(
            bundleId: bundleId,
            name: name,
            appPath: appPath,
            binaryPath: binaryPath
        )
        try AppManager.launchManagedVisible(info)
    }

    static func removeApp(
        bundleId: String,
        appPath: String,
        binaryPath: String,
        wasRunning: Bool
    ) throws {
        if wasRunning {
            try AppManager.quit(bundleId)
        }

        try AppManager.restoreBinary(bundleId, binaryPath: binaryPath, appPath: appPath)
        try Config.removeHidden(bundleId)

        if wasRunning {
            try AppManager.launchNormal(appPath)
        }
    }
}
