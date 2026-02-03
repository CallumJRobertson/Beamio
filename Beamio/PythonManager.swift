import Foundation
import PythonKit

struct ApkItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: String

    var isPreferred: Bool {
        name.localizedCaseInsensitiveContains("ARM")
    }
}

final class PythonManager: ObservableObject {
    static let shared = PythonManager()

    @Published var connectionStatus: String = "Disconnected"
    @Published var logLines: [String] = []

    private var worker: PythonObject?
    private var isInitialized = false
    private let workerQueue = DispatchQueue(label: "com.beamio.python.worker", qos: .userInitiated)

    private init() {}

    func initializeIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true

        if let pythonLibraryPath = pythonLibraryPath() {
            PythonLibrary.useLibrary(at: pythonLibraryPath)
        } else {
            connectionStatus = "Python unavailable"
            log("Python.framework not found in app bundle. Skipping initialization.")
            return
        }

        let sys = Python.import("sys")
        if let resourcePath = Bundle.main.resourcePath {
            sys.path.append(resourcePath)
            sys.path.append("\(resourcePath)/site-packages")
        }

        worker = Python.import("BeamioWorker")
        log("Python environment initialized.")
    }

    private func pythonLibraryPath() -> String? {
        let candidates = [
            Bundle.main.privateFrameworksPath,
            Bundle.main.frameworksPath
        ]
        .compactMap { $0 }
        .map { "\($0)/Python.framework/Python" }

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    func connect(ipAddress: String, keyStoragePath: String, completion: ((String) -> Void)? = nil) {
        initializeIfNeeded()
        connectionStatus = "Connecting..."
        log("Connecting to \(ipAddress)...")

        let worker = worker
        workerQueue.async { [weak self] in
            guard let self else { return }
            let resultObject = worker?.connect(ipAddress, keyStoragePath)
            let result = resultObject.flatMap { String($0) } ?? "Connection failed"

            DispatchQueue.main.async {
                self.connectionStatus = result
                self.log(result)
                completion?(result)
            }
        }
    }

    func scanURL(_ url: String, completion: @escaping ([ApkItem]) -> Void) {
        initializeIfNeeded()
        log("Scanning \(url)...")
        let worker = worker
        workerQueue.async { [weak self] in
            guard let self else { return }
            var items: [ApkItem] = []

            if let results = worker?.scan_url(url) {
                for item in results {
                    let name = String(item["name"]) ?? "Unknown"
                    let link = String(item["url"]) ?? ""
                    items.append(ApkItem(name: name, url: link))
                }
            }

            DispatchQueue.main.async {
                if items.isEmpty {
                    self.log("No APKs found.")
                } else {
                    self.log("Found \(items.count) APK(s).")
                }
                completion(items)
            }
        }
    }

    func installApk(from url: String) {
        initializeIfNeeded()
        log("Starting install from \(url)...")
        let worker = worker
        workerQueue.async { [weak self] in
            guard let self else { return }

            guard let stream = worker?.install_apk(url) else {
                DispatchQueue.main.async {
                    self.log("Install failed to start.")
                }
                return
            }

            for update in stream {
                let message = String(update) ?? ""
                if !message.isEmpty {
                    DispatchQueue.main.async {
                        self.log(message)
                    }
                }
            }
        }
    }

    private func log(_ message: String) {
        let entry = "[\(timestamp())] \(message)"
        if Thread.isMainThread {
            logLines.append(entry)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.logLines.append(entry)
            }
        }
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
