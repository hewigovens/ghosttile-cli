import Darwin
import Foundation

enum AppManagementPermissionStatusReader {
    private static let frameworkPath = "/System/Library/PrivateFrameworks/TCC.framework/TCC"
    private static let preflightSymbolName = "TCCAccessPreflight"
    private static let appManagementServiceSymbolName = "kTCCServiceSystemPolicyAppBundles"
    private static let preflightGranted: Int32 = 0

    private typealias TCCAccessPreflightFunction = @convention(c) (
        CFString,
        CFDictionary?
    ) -> Int32

    static func currentProcessIsAllowed() -> Bool? {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else { return nil }
        defer { dlclose(handle) }

        guard let preflightSymbol = dlsym(handle, preflightSymbolName),
              let serviceSymbol = dlsym(handle, appManagementServiceSymbolName)
        else {
            return nil
        }

        let preflight = unsafeBitCast(
            preflightSymbol,
            to: TCCAccessPreflightFunction.self
        )
        let service = serviceSymbol.assumingMemoryBound(to: CFString.self).pointee
        return isAllowed(preflightResult: preflight(service, nil))
    }

    static func isAllowed(preflightResult: Int32) -> Bool {
        preflightResult == preflightGranted
    }
}
