import GhostTileCore

enum AppOperations {
    static func hideApp(
        _ app: AppInfo,
        cliPath: String,
        forcePrepare: Bool = false,
        options: PrepareOptions = .init()
    ) throws -> HideAppOperationResult {
        Log.info("Hiding app: \(app.name) (\(app.bundleId))")

        if AppManager.isAppleFirstParty(app.appPath) {
            throw GhostTileError("\(app.name) is an Apple system app and cannot be hidden.")
        }

        if let blocked = try compatibilityGate(app, options: options) {
            return blocked
        }

        if try AppManager.needsSudo(app, forcePrepare: forcePrepare) {
            return sudoCommand(for: app, cliPath: cliPath, forcePrepare: forcePrepare, options: options)
        }

        if try forcePrepare || AppManager.needsPreparation(app) {
            try AppManager.prepare(app, cliPath: cliPath, options: options)
        }

        try AppManager.quit(app.bundleId)
        try AppManager.launchHidden(app)
        try Config.addHidden(app)

        return .hidden
    }

    /// nil = good to proceed; non-nil = a confirmation the caller must surface; throws if unsupported.
    private static func compatibilityGate(
        _ app: AppInfo,
        options: PrepareOptions
    ) throws -> HideAppOperationResult? {
        switch try AppManager.assessCompatibility(app) {
        case .compatible:
            return nil
        case let .unsupported(reason):
            throw GhostTileError(reason)
        case let .requiresUnsandbox(reason):
            return options.unsandbox ? nil : .requiresUnsandboxConfirmation(reason: reason)
        case let .warnings(warnings):
            return options.acceptWarnings ? nil : .requiresWarningConfirmation(warnings)
        }
    }

    private static func sudoCommand(
        for app: AppInfo,
        cliPath: String,
        forcePrepare: Bool,
        options: PrepareOptions
    ) -> HideAppOperationResult {
        // Pass the path, not the bundle ID: the CLI resolver can't find a non-running app by ID.
        var arguments = ["manage", app.appPath]
        if forcePrepare { arguments.append("--force-prepare") }
        if options.acceptWarnings { arguments.append("--accept-warnings") }
        if options.unsandbox { arguments.append("--unsandbox") }
        return .requiresSudo(command: ShellCommand.format(
            executable: cliPath,
            arguments: arguments,
            requiresSudo: true
        ))
    }

    static func removeApp(_ app: AppInfo, wasRunning: Bool) throws {
        guard GhosthidePatch.isApplied(to: app.binaryPath) else {
            AppManager.discardInjection(app.bundleId, appPath: app.appPath)
            try Config.removeHidden(app.bundleId)
            return
        }

        if wasRunning {
            try AppManager.quit(app.bundleId)
        }

        try AppManager.restoreBinary(
            app.bundleId,
            binaryPath: app.binaryPath,
            appPath: app.appPath
        )
        try Config.removeHidden(app.bundleId)

        if wasRunning {
            try AppManager.launchNormal(app.appPath)
        }
    }
}
