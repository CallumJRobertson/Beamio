import Foundation
import Network
import Security

struct ApkItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: String

    var isPreferred: Bool {
        name.localizedCaseInsensitiveContains("ARM")
    }
}

enum ADBError: Error, LocalizedError {
    case invalidHost
    case connectionClosed
    case connectionTimeout
    case protocolError(String)
    case authenticationFailed
    case streamClosed
    case syncFailed(String)
    case invalidResponse
    case keyGenerationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Invalid host"
        case .connectionClosed:
            return "Connection closed"
        case .connectionTimeout:
            return "Connection timed out"
        case .protocolError(let message):
            return "Protocol error: \(message)"
        case .authenticationFailed:
            return "ADB authentication failed"
        case .streamClosed:
            return "ADB stream closed"
        case .syncFailed(let message):
            return "ADB sync failed: \(message)"
        case .invalidResponse:
            return "Invalid response"
        case .keyGenerationFailed(let message):
            return "Key generation failed: \(message)"
        }
    }
}

final class ADBManager: ObservableObject {
    static let shared = ADBManager()

    @Published var connectionStatus: String = "Disconnected"
    @Published var logLines: [String] = []

    private let maxLogLines = 800
    private let workerQueue = DispatchQueue(label: "com.beamio.adb.worker", qos: .userInitiated)
    private var client: ADBClient?

    private init() {}

    func connect(ipAddress: String, keyStoragePath: String, completion: ((String) -> Void)? = nil) {
        let targetIP = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let (host, port) = Self.parseHostPort(from: targetIP)
        connectionStatus = "Connecting..."
        log("Connecting to \(host):\(port)...")

        workerQueue.async { [weak self] in
            guard let self else { return }
            let client = ADBClient { [weak self] message in
                self?.log(message)
            }
            Task {
                let result: String
                do {
                    try await client.connect(host: host, port: port, keyStoragePath: keyStoragePath)
                    self.client = client
                    result = "Connected"
                } catch {
                    self.client = nil
                    result = "Connection failed"
                    self.log("\(result): \(error.localizedDescription)")
                    self.log("Error: \(String(reflecting: error))")
                }

                DispatchQueue.main.async {
                    self.connectionStatus = result
                    self.log(result)
                    completion?(result)
                }
            }
        }
    }

    func scanURL(_ url: String, completion: @escaping ([ApkItem]) -> Void) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        log("Scanning \(trimmed)...")

        guard let baseURL = URL(string: trimmed) else {
            log("Invalid URL.")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: baseURL) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.log("Scan failed: \(error.localizedDescription)")
                    completion([])
                }
                return
            }

            let html = String(data: data ?? Data(), encoding: .utf8) ?? ""
            let items = Self.parseApkLinks(from: html, baseURL: baseURL)

            DispatchQueue.main.async {
                if items.isEmpty {
                    self.log("No APKs found.")
                } else {
                    self.log("Found \(items.count) APK(s).")
                }
                completion(items)
            }
        }.resume()
    }

    func installApk(from url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        log("Starting install from \(trimmed)...")

        guard let downloadURL = URL(string: trimmed) else {
            log("Invalid APK URL.")
            return
        }
        guard let client else {
            log("No device connected.")
            return
        }

        URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempURL, _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.log("Download failed: \(error.localizedDescription)")
                }
                return
            }
            guard let tempURL else {
                DispatchQueue.main.async {
                    self.log("Download failed: missing file.")
                }
                return
            }

            let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("beamio_payload.apk")
            do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: targetURL)
            } catch {
                DispatchQueue.main.async {
                    self.log("Failed to prepare APK: \(error.localizedDescription)")
                }
                return
            }

            self.workerQueue.async {
                Task {
                    do {
                        try await client.installApk(at: targetURL) { [weak self] update in
                            DispatchQueue.main.async {
                                self?.log(update)
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.log("Install failed: \(error.localizedDescription)")
                            self.log("Error: \(String(reflecting: error))")
                        }
                    }
                }
            }
        }.resume()
    }

    func installApkFile(_ fileURL: URL) {
        log("Starting install from file \(fileURL.lastPathComponent)...")
        guard let client else {
            log("No device connected.")
            return
        }

        workerQueue.async {
            Task {
                let didAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent("beamio_payload.apk")
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: fileURL, to: targetURL)
                } catch {
                    DispatchQueue.main.async {
                        self.log("Failed to read APK file: \(error.localizedDescription)")
                        self.log("Error: \(String(reflecting: error))")
                    }
                    return
                }

                do {
                    try await client.installApk(at: targetURL) { [weak self] update in
                        DispatchQueue.main.async {
                            self?.log(update)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.log("Install failed: \(error.localizedDescription)")
                        self.log("Error: \(String(reflecting: error))")
                    }
                }
            }
        }
    }

    private static func parseApkLinks(from html: String, baseURL: URL) -> [ApkItem] {
        let pattern = "<a\\s+[^>]*href=[\"']([^\"']+\\.apk)[\"'][^>]*>(.*?)</a>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)

        var results: [ApkItem] = []
        var seen = Set<String>()

        if let regex {
            for match in regex.matches(in: html, options: [], range: nsRange) {
                guard let hrefRange = Range(match.range(at: 1), in: html) else { continue }
                let href = String(html[hrefRange])
                let name: String
                if let textRange = Range(match.range(at: 2), in: html) {
                    name = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    name = ""
                }

                let fullURL = URL(string: href, relativeTo: baseURL)?.absoluteString ?? href
                guard seen.insert(fullURL).inserted else { continue }

                let displayName = name.isEmpty
                    ? (URL(string: fullURL)?.lastPathComponent ?? "APK")
                    : name
                results.append(ApkItem(name: displayName, url: fullURL))
            }
        }

        return results
    }

    private static func parseHostPort(from input: String) -> (String, UInt16) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultPort: UInt16 = 5555

        if trimmed.hasPrefix("["),
           let closing = trimmed.firstIndex(of: "]"),
           closing < trimmed.endIndex,
           trimmed.index(after: closing) < trimmed.endIndex,
           trimmed[trimmed.index(after: closing)] == ":" {
            let host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closing])
            let portStart = trimmed.index(after: closing)
            let portString = String(trimmed[trimmed.index(after: portStart)...])
            if let port = UInt16(portString) {
                return (host, port)
            }
            return (host, defaultPort)
        }

        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2, let port = UInt16(parts[1]) {
            return (parts[0], port)
        }
        return (trimmed, defaultPort)
    }

    private func log(_ message: String) {
        let entry = "[\(timestamp())] \(message)"
        if Thread.isMainThread {
            appendLog(entry)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.appendLog(entry)
            }
        }
    }

    private func appendLog(_ entry: String) {
        logLines.append(entry)
        if logLines.count > maxLogLines {
            logLines.removeFirst(logLines.count - maxLogLines)
        }
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

private final class ADBClient {
    private let logger: ((String) -> Void)?
    private var connection: ADBConnection?
    private var nextLocalId: UInt32 = 1
    private var keyPair: ADBKeyPair?
    private var maxData: Int = 4096
    private var dataPacketCount: Int = 0
    private var okayPacketCount: Int = 0

    init(logger: ((String) -> Void)? = nil) {
        self.logger = logger
    }

    func connect(host: String, port: UInt16, keyStoragePath: String) async throws {
        guard !host.isEmpty else { throw ADBError.invalidHost }

        let connection = ADBConnection(host: host, port: port, logger: logger)
        try await connection.start()
        self.connection = connection

        let keyPair = try ADBKeyManager.loadOrCreateKeyPair(at: keyStoragePath)
        self.keyPair = keyPair

        let localMaxData: UInt32 = 4096
        try await sendPacket(.cnxn, arg0: 0x01000000, arg1: localMaxData, data: Data("host::".utf8))

        var sentSignature = false
        var sentPublicKey = false

        while true {
            let packet = try await readPacket()
            switch packet.command {
            case .cnxn:
                let remoteMax = Int(packet.arg1)
                maxData = max(256, remoteMax)
                trace("Negotiated max data size: \(maxData) bytes")
                return
            case .auth:
                if !sentSignature, packet.arg0 == 1 {
                    let signature = try ADBKeyManager.sign(token: packet.data, with: keyPair.privateKey)
                    try await sendPacket(.auth, arg0: 2, arg1: 0, data: signature)
                    sentSignature = true
                } else if !sentPublicKey {
                    let publicKeyData = Data((keyPair.publicKey + "\u{0}").utf8)
                    try await sendPacket(.auth, arg0: 3, arg1: 0, data: publicKeyData)
                    sentPublicKey = true
                } else {
                    throw ADBError.authenticationFailed
                }
            default:
                continue
            }
        }
    }

    func installApk(at localURL: URL, progress: (String) -> Void) async throws {
        progress("Uploading APK...")
        try await pushFile(localURL: localURL, remotePath: "/data/local/tmp/beamio_payload.apk", mode: 0o644)

        progress("Installing APK...")
        let output = try await runShell("pm install -r /data/local/tmp/beamio_payload.apk")
        progress(output.trimmingCharacters(in: .whitespacesAndNewlines))

        _ = try? await runShell("rm /data/local/tmp/beamio_payload.apk")
        progress("Install complete.")
    }

    private func runShell(_ command: String) async throws -> String {
        let stream = try await openStream(service: "shell:\(command)")
        let data = try await readStreamUntilClose(stream)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func pushFile(localURL: URL, remotePath: String, mode: Int) async throws {
        let stream = try await openStream(service: "sync:")
        var buffer = Data()
        var bufferOffset = 0

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? NSNumber)?.int64Value
        var sentBytes: Int64 = 0
        let progressStep: Int64
        if let fileSize, fileSize > 0 {
            progressStep = max(512 * 1024, fileSize / 20)
        } else {
            progressStep = 512 * 1024
        }
        var nextProgress = progressStep

        func availableBytes() -> Int {
            buffer.count - bufferOffset
        }

        func compactBufferIfNeeded() {
            guard bufferOffset > 0 else { return }
            if bufferOffset > 64 * 1024, bufferOffset > buffer.count / 2 {
                buffer = Data(buffer[bufferOffset...])
                bufferOffset = 0
            }
        }

        func fillBuffer(minBytes: Int) async throws {
            while availableBytes() < minBytes {
                let packet = try await readPacket()
                switch packet.command {
                case .wrte:
                    guard packet.arg0 == stream.remoteId, packet.arg1 == stream.localId else { continue }
                    buffer.append(packet.data)
                    try await sendPacket(.okay, arg0: stream.localId, arg1: stream.remoteId, data: Data())
                case .clse:
                    try await sendPacket(.clse, arg0: stream.localId, arg1: stream.remoteId, data: Data())
                    throw ADBError.streamClosed
                default:
                    continue
                }
            }
        }

        func readBytes(_ length: Int) async throws -> Data {
            try await fillBuffer(minBytes: length)
            let available = availableBytes()
            guard length <= available else {
                throw ADBError.protocolError("Buffer underflow (needed \(length), have \(available))")
            }
            let start = bufferOffset
            let end = bufferOffset + length
            let slice = buffer[start..<end]
            bufferOffset = end
            compactBufferIfNeeded()
            return Data(slice)
        }

        let modeString = String(format: "%#o", mode)
        trace("Sending file mode \(modeString) to \(remotePath)")
        let sendPath = "\(remotePath),\(modeString)"
        try await writeSyncCommand(stream: stream, id: "SEND", data: Data(sendPath.utf8), buffer: &buffer)

        let handle = try FileHandle(forReadingFrom: localURL)
        defer { try? handle.close() }

        let maxPayload = max(256, maxData)
        let maxChunk = maxPayload > 8 ? (maxPayload - 8) : 0
        guard maxChunk > 0 else {
            throw ADBError.protocolError("Invalid max payload size: \(maxPayload)")
        }

        while true {
            let chunk = try handle.read(upToCount: maxChunk) ?? Data()
            if chunk.isEmpty { break }
            try await writeSyncCommand(stream: stream, id: "DATA", data: chunk, buffer: &buffer)
            sentBytes += Int64(chunk.count)
            if sentBytes >= nextProgress {
                if let fileSize, fileSize > 0 {
                    let percent = Int((Double(sentBytes) / Double(fileSize)) * 100)
                    trace("Upload progress: \(percent)% (\(sentBytes)/\(fileSize) bytes)")
                } else {
                    trace("Upload progress: \(sentBytes) bytes")
                }
                nextProgress = sentBytes + progressStep
            }
        }

        let mtime = UInt32(Date().timeIntervalSince1970)
        try await writeSyncDone(stream: stream, mtime: mtime, buffer: &buffer)

        let responseId = try await readBytes(4)
        let responseIdString = String(data: responseId, encoding: .ascii) ?? ""
        let responseLengthData = try await readBytes(4)
        let responseLength = responseLengthData.readUInt32LE(at: 0)

        if responseIdString == "OKAY" {
            _ = responseLength
            return
        }

        if responseIdString == "FAIL" {
            let messageData = try await readBytes(Int(responseLength))
            let message = String(data: messageData, encoding: .utf8) ?? "Unknown error"
            throw ADBError.syncFailed(message)
        }

        throw ADBError.invalidResponse
    }

    private func openStream(service: String) async throws -> ADBStream {
        let localId = nextLocalId
        nextLocalId += 1

        var payload = Data(service.utf8)
        payload.append(0)

        try await sendPacket(.open, arg0: localId, arg1: 0, data: payload)

        while true {
            let packet = try await readPacket()
            switch packet.command {
            case .okay:
                if packet.arg1 == localId {
                    return ADBStream(localId: localId, remoteId: packet.arg0)
                }
            case .clse:
                throw ADBError.streamClosed
            default:
                continue
            }
        }
    }

    private func readStreamUntilClose(_ stream: ADBStream) async throws -> Data {
        var output = Data()

        while true {
            let packet = try await readPacket()
            switch packet.command {
            case .wrte:
                guard packet.arg0 == stream.remoteId, packet.arg1 == stream.localId else { continue }
                output.append(packet.data)
                try await sendPacket(.okay, arg0: stream.localId, arg1: stream.remoteId, data: Data())
            case .clse:
                if packet.arg0 == stream.remoteId, packet.arg1 == stream.localId {
                    try await sendPacket(.clse, arg0: stream.localId, arg1: stream.remoteId, data: Data())
                    return output
                }
            default:
                continue
            }
        }
    }

    private func writeSyncCommand(stream: ADBStream, id: String, data: Data, buffer: inout Data) async throws {
        var payload = Data(id.utf8)
        var length = UInt32(data.count).littleEndian
        payload.append(Data(bytes: &length, count: 4))
        payload.append(data)
        try await sendPacket(.wrte, arg0: stream.localId, arg1: stream.remoteId, data: payload)
        try await waitForOkay(stream: stream, buffer: &buffer)
    }

    private func writeSyncDone(stream: ADBStream, mtime: UInt32, buffer: inout Data) async throws {
        var payload = Data("DONE".utf8)
        var time = mtime.littleEndian
        payload.append(Data(bytes: &time, count: 4))
        try await sendPacket(.wrte, arg0: stream.localId, arg1: stream.remoteId, data: payload)
        try await waitForOkay(stream: stream, buffer: &buffer)
    }

    private func waitForOkay(stream: ADBStream, buffer: inout Data) async throws {
        while true {
            let packet = try await readPacket()
            switch packet.command {
            case .okay:
                if packet.arg0 == stream.remoteId, packet.arg1 == stream.localId {
                    return
                }
            case .wrte:
                guard packet.arg0 == stream.remoteId, packet.arg1 == stream.localId else { continue }
                buffer.append(packet.data)
                try await sendPacket(.okay, arg0: stream.localId, arg1: stream.remoteId, data: Data())
            case .clse:
                if packet.arg0 == stream.remoteId, packet.arg1 == stream.localId {
                    throw ADBError.streamClosed
                }
            default:
                continue
            }
        }
    }

    private func readPacket() async throws -> ADBPacket {
        guard let connection else { throw ADBError.connectionClosed }
        let header = try await connection.receiveExact(24)
        if header.count < 24 { throw ADBError.connectionClosed }

        let commandRaw = header.readUInt32LE(at: 0)
        let arg0 = header.readUInt32LE(at: 4)
        let arg1 = header.readUInt32LE(at: 8)
        let length = header.readUInt32LE(at: 12)
        let checksum = header.readUInt32LE(at: 16)
        let magic = header.readUInt32LE(at: 20)

        guard let command = ADBCommand(rawValue: commandRaw) else {
            throw ADBError.protocolError("Unknown command: \(commandRaw)")
        }

        if command.rawValue ^ 0xFFFFFFFF != magic {
            throw ADBError.protocolError("Invalid magic")
        }

        let data = length > 0 ? try await connection.receiveExact(Int(length)) : Data()
        _ = checksum
        tracePacket(direction: "RX", command: command, arg0: arg0, arg1: arg1, length: length, checksum: checksum, data: data)
        return ADBPacket(command: command, arg0: arg0, arg1: arg1, length: length, checksum: checksum, magic: magic, data: data)
    }

    private func sendPacket(_ command: ADBCommand, arg0: UInt32, arg1: UInt32, data: Data) async throws {
        guard let connection else { throw ADBError.connectionClosed }

        if command != .cnxn, data.count > maxData {
            throw ADBError.protocolError("Payload too large: \(data.count) > \(maxData)")
        }

        let checksum = data.reduce(UInt32(0)) { $0 + UInt32($1) }
        let magic = command.rawValue ^ 0xFFFFFFFF

        var payload = Data()
        payload.appendUInt32LE(command.rawValue)
        payload.appendUInt32LE(arg0)
        payload.appendUInt32LE(arg1)
        payload.appendUInt32LE(UInt32(data.count))
        payload.appendUInt32LE(checksum)
        payload.appendUInt32LE(magic)
        payload.append(data)

        tracePacket(direction: "TX", command: command, arg0: arg0, arg1: arg1, length: UInt32(data.count), checksum: checksum, data: data)
        try await connection.send(payload)
    }

    private func trace(_ message: String) {
        logger?("[ADB] \(message)")
    }

    private func tracePacket(direction: String, command: ADBCommand, arg0: UInt32, arg1: UInt32, length: UInt32, checksum: UInt32, data: Data) {
        if command == .okay {
            okayPacketCount += 1
            if okayPacketCount <= 5 || okayPacketCount % 50 == 0 {
                trace("\(direction) \(command.name) arg0=\(arg0) arg1=\(arg1) len=\(length)")
            }
            return
        }

        if command == .wrte, let syncId = syncCommandId(from: data) {
            if syncId == "DATA" {
                dataPacketCount += 1
                if dataPacketCount <= 3 || dataPacketCount % 100 == 0 {
                    trace("\(direction) \(command.name) id=DATA chunk=\(dataPacketCount) bytes=\(data.count)")
                }
                return
            }
            let payloadPreview = data.hexPreview(maxBytes: 64)
            trace("\(direction) \(command.name) id=\(syncId) arg0=\(arg0) arg1=\(arg1) len=\(length) checksum=\(checksum) data=\(payloadPreview)")
            return
        }

        let payloadPreview = data.hexPreview(maxBytes: 64)
        trace("\(direction) \(command.name) arg0=\(arg0) arg1=\(arg1) len=\(length) checksum=\(checksum) data=\(payloadPreview)")
    }

    private func syncCommandId(from data: Data) -> String? {
        guard data.count >= 4 else { return nil }
        let idData = data.prefix(4)
        return String(data: idData, encoding: .ascii)
    }
}

private struct ADBStream {
    let localId: UInt32
    let remoteId: UInt32
}

private enum ADBCommand: UInt32 {
    case cnxn = 0x4e584e43
    case auth = 0x48545541
    case open = 0x4e45504f
    case okay = 0x59414b4f
    case clse = 0x45534c43
    case wrte = 0x45545257

    var name: String {
        switch self {
        case .cnxn: return "CNXN"
        case .auth: return "AUTH"
        case .open: return "OPEN"
        case .okay: return "OKAY"
        case .clse: return "CLSE"
        case .wrte: return "WRTE"
        }
    }
}

private struct ADBPacket {
    let command: ADBCommand
    let arg0: UInt32
    let arg1: UInt32
    let length: UInt32
    let checksum: UInt32
    let magic: UInt32
    let data: Data
}

private final class ADBConnection {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.beamio.adb.connection")
    private let logger: ((String) -> Void)?

    init(host: String, port: UInt16, logger: ((String) -> Void)? = nil) {
        let endpoint = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(rawValue: port) ?? 5555
        self.connection = NWConnection(host: endpoint, port: port, using: .tcp)
        self.logger = logger
    }

    func start(timeout: TimeInterval = 8) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            var lastError: Error?
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                guard !didResume else { return }
                didResume = true
                self.connection.stateUpdateHandler = nil
                self.connection.cancel()
                continuation.resume(throwing: lastError ?? ADBError.connectionTimeout)
            }
            timer.resume()

            connection.stateUpdateHandler = { state in
                guard !didResume else { return }
                switch state {
                case .ready:
                    didResume = true
                    timer.cancel()
                    self.logger?("[ADB] Connection ready")
                    continuation.resume()
                case .failed(let error):
                    didResume = true
                    timer.cancel()
                    self.logger?("[ADB] Connection failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                case .waiting(let error):
                    lastError = error
                    self.logger?("[ADB] Connection waiting: \(error.localizedDescription)")
                case .cancelled:
                    didResume = true
                    timer.cancel()
                    self.logger?("[ADB] Connection cancelled")
                    continuation.resume(throwing: ADBError.connectionClosed)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receiveExact(_ length: Int) async throws -> Data {
        var data = Data()
        var remaining = length
        while remaining > 0 {
            let chunk = try await receive(minimum: 1, maximum: remaining)
            if chunk.isEmpty {
                throw ADBError.connectionClosed
            }
            data.append(chunk)
            remaining -= chunk.count
        }
        return data
    }

    private func receive(minimum: Int, maximum: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: minimum, maximumLength: maximum) { content, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if isComplete && (content == nil || content?.isEmpty == true) {
                    continuation.resume(throwing: ADBError.connectionClosed)
                    return
                }
                continuation.resume(returning: content ?? Data())
            }
        }
    }
}

private struct ADBKeyPair {
    let privateKey: SecKey
    let publicKey: String
}

private enum ADBKeyManager {
    static func loadOrCreateKeyPair(at path: String) throws -> ADBKeyPair {
        let keyURL = resolveKeyURL(path: path)
        let pubURL = keyURL.appendingPathExtension("pub")

        if FileManager.default.fileExists(atPath: keyURL.path),
           let data = try? Data(contentsOf: keyURL),
           let privateKey = createPrivateKey(from: data) {
            let publicKey = (try? String(contentsOf: pubURL, encoding: .utf8)) ?? createPublicKeyString(from: privateKey)
            return ADBKeyPair(privateKey: privateKey, publicKey: publicKey)
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let message = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw ADBError.keyGenerationFailed(message)
        }

        guard let privateData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            let message = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw ADBError.keyGenerationFailed(message)
        }

        try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try privateData.write(to: keyURL)

        let publicKeyString = createPublicKeyString(from: privateKey)
        try publicKeyString.write(to: pubURL, atomically: true, encoding: .utf8)

        return ADBKeyPair(privateKey: privateKey, publicKey: publicKeyString)
    }

    static func sign(token: Data, with privateKey: SecKey) throws -> Data {
        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA1
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw ADBError.authenticationFailed
        }
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, token as CFData, &error) as Data? else {
            let message = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw ADBError.keyGenerationFailed(message)
        }
        return signature
    }

    private static func resolveKeyURL(path: String) -> URL {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url.appendingPathComponent("adbkey")
        }
        if url.pathExtension.isEmpty {
            return url.appendingPathComponent("adbkey")
        }
        return url
    }

    private static func createPrivateKey(from data: Data) -> SecKey? {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048,
        ]

        return SecKeyCreateWithData(data as CFData, attributes as CFDictionary, nil)
    }

    private static func createPublicKeyString(from privateKey: SecKey) -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { return "" }
        var error: Unmanaged<CFError>?
        guard let publicData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else { return "" }

        guard let (modulus, exponent) = parseRSAPublicKey(publicData) else { return "" }

        let sshKey = buildSSHPublicKey(modulus: modulus, exponent: exponent)
        let base64Key = sshKey.base64EncodedString()
        return "ssh-rsa \(base64Key) beamio@ios"
    }

    private static func parseRSAPublicKey(_ data: Data) -> (Data, Data)? {
        if let pkcs1 = parseRSAPublicKeyPKCS1(data) {
            return pkcs1
        }
        if let embedded = extractPKCS1(fromSubjectPublicKeyInfo: data) {
            return parseRSAPublicKeyPKCS1(embedded)
        }
        return nil
    }

    private static func parseRSAPublicKeyPKCS1(_ data: Data) -> (Data, Data)? {
        var index = 0

        func readByte() -> UInt8? {
            guard index < data.count else { return nil }
            let byte = data[index]
            index += 1
            return byte
        }

        func readLength() -> Int? {
            guard let first = readByte() else { return nil }
            if first & 0x80 == 0 {
                return Int(first)
            }
            let byteCount = Int(first & 0x7F)
            var length = 0
            for _ in 0..<byteCount {
                guard let next = readByte() else { return nil }
                length = (length << 8) | Int(next)
            }
            return length
        }

        guard readByte() == 0x30, let _ = readLength() else { return nil }
        guard readByte() == 0x02, let modLen = readLength() else { return nil }
        guard index + modLen <= data.count else { return nil }
        let modulus = Data(data[index..<index + modLen])
        index += modLen

        guard readByte() == 0x02, let expLen = readLength() else { return nil }
        guard index + expLen <= data.count else { return nil }
        let exponent = Data(data[index..<index + expLen])

        return (modulus, exponent)
    }

    private static func extractPKCS1(fromSubjectPublicKeyInfo data: Data) -> Data? {
        var index = 0

        func readByte() -> UInt8? {
            guard index < data.count else { return nil }
            let byte = data[index]
            index += 1
            return byte
        }

        func readLength() -> Int? {
            guard let first = readByte() else { return nil }
            if first & 0x80 == 0 {
                return Int(first)
            }
            let byteCount = Int(first & 0x7F)
            var length = 0
            for _ in 0..<byteCount {
                guard let next = readByte() else { return nil }
                length = (length << 8) | Int(next)
            }
            return length
        }

        guard readByte() == 0x30, let _ = readLength() else { return nil }
        guard readByte() == 0x30, let algLen = readLength() else { return nil }
        index += algLen
        guard readByte() == 0x03, let bitLen = readLength() else { return nil }
        guard index < data.count else { return nil }
        _ = readByte() // unused bits
        let remaining = bitLen - 1
        guard remaining > 0, index + remaining <= data.count else { return nil }
        return Data(data[index..<index + remaining])
    }

    private static func buildSSHPublicKey(modulus: Data, exponent: Data) -> Data {
        func sshString(_ string: String) -> Data {
            let data = Data(string.utf8)
            return sshData(data)
        }

        func sshData(_ data: Data) -> Data {
            var length = UInt32(data.count).bigEndian
            var result = Data(bytes: &length, count: 4)
            result.append(data)
            return result
        }

        func mpint(_ data: Data) -> Data {
            guard !data.isEmpty else { return Data() }
            var start = data.startIndex
            let end = data.endIndex
            while start < data.index(before: end), data[start] == 0x00 {
                start = data.index(after: start)
            }
            let trimmed = data[start..<end]
            var result = Data()
            if let first = trimmed.first, first & 0x80 != 0 {
                result.append(0x00)
            }
            result.append(trimmed)
            return result
        }

        var key = Data()
        key.append(sshString("ssh-rsa"))
        key.append(sshData(mpint(exponent)))
        key.append(sshData(mpint(modulus)))
        return key
    }
}

private extension Data {
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1]) << 8
        let b2 = UInt32(self[offset + 2]) << 16
        let b3 = UInt32(self[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var value = value.littleEndian
        append(Data(bytes: &value, count: 4))
    }

    func hexPreview(maxBytes: Int) -> String {
        guard !isEmpty else { return "<empty>" }
        let length = count
        if length <= maxBytes {
            return hexString()
        }
        let headCount = maxBytes / 2
        let tailCount = maxBytes - headCount
        let head = self.prefix(headCount)
        let tail = self.suffix(tailCount)
        return "\(head.hexString())…\(tail.hexString()) (truncated \(maxBytes)/\(length))"
    }

    func hexString() -> String {
        var output = ""
        output.reserveCapacity(count * 2)
        for byte in self {
            output.append(String(format: "%02x", byte))
        }
        return output
    }
}
