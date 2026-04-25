import Foundation
import GhostTileCore

final class ConfigWatcher {
    private var directoryMonitor: DispatchSourceFileSystemObject?
    private var fileMonitor: DispatchSourceFileSystemObject?

    private let onDirectoryChange: () -> Void
    private let onFileChange: () -> Void

    init(
        onDirectoryChange: @escaping () -> Void,
        onFileChange: @escaping () -> Void
    ) {
        self.onDirectoryChange = onDirectoryChange
        self.onFileChange = onFileChange
    }

    deinit {
        cancel()
    }

    func start() {
        try? FileManager.default.createDirectory(
            atPath: Config.configDir,
            withIntermediateDirectories: true
        )
        watchConfigDirectory()
        refreshConfigFileMonitor()
    }

    func cancel() {
        directoryMonitor?.cancel()
        fileMonitor?.cancel()
        directoryMonitor = nil
        fileMonitor = nil
    }

    func refreshConfigFileMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil

        guard FileManager.default.fileExists(atPath: Config.configPath) else { return }

        let fileFD = open(Config.configPath, O_EVTONLY)
        guard fileFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileFD,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Log.info("Config file changed on disk, refreshing")
            self?.onFileChange()
            self?.refreshConfigFileMonitor()
        }
        source.setCancelHandler { close(fileFD) }
        source.resume()
        fileMonitor = source
    }

    private func watchConfigDirectory() {
        directoryMonitor?.cancel()

        let directoryFD = open(Config.configDir, O_EVTONLY)
        guard directoryFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFD,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Log.info("Config directory changed on disk, updating watcher")
            self?.refreshConfigFileMonitor()
            self?.onDirectoryChange()
        }
        source.setCancelHandler { close(directoryFD) }
        source.resume()
        directoryMonitor = source
    }
}
