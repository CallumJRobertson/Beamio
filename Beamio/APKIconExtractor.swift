import Foundation
import zlib

enum APKIconExtractor {
    static func extractIcon(from apkURL: URL) -> Data? {
        guard let archive = ZipArchive(url: apkURL) else { return nil }
        let entries = archive.entries
        guard let entry = selectBestIconEntry(from: entries) else { return nil }
        return archive.extract(entry: entry)
    }

    private static func selectBestIconEntry(from entries: [ZipEntry]) -> ZipEntry? {
        let pngs = entries.filter { $0.name.lowercased().hasSuffix(".png") }
        let webps = entries.filter { $0.name.lowercased().hasSuffix(".webp") }
        let jpgs = entries.filter {
            let lower = $0.name.lowercased()
            return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
        }
        let images = !pngs.isEmpty ? pngs : (!webps.isEmpty ? webps : jpgs)
        if images.isEmpty { return nil }

        let preferred = images.filter { name in
            let lower = name.name.lowercased()
            return lower.contains("mipmap") || lower.contains("drawable")
        }

        let candidates = preferred.isEmpty ? images : preferred
        return candidates.max { lhs, rhs in
            iconScore(for: lhs) < iconScore(for: rhs)
        }
    }

    private static func iconScore(for entry: ZipEntry) -> Int {
        let name = entry.name.lowercased()
        var score = 0

        if name.contains("ic_launcher") {
            score += 1000
        }
        if name.contains("ic_launcher_foreground") {
            score += 200
        }
        if name.contains("app_icon") || name.contains("appicon") {
            score += 400
        }
        if name.contains("icon") || name.contains("logo") {
            score += 150
        }

        if name.contains("xxxhdpi") { score += 500 }
        else if name.contains("xxhdpi") { score += 400 }
        else if name.contains("xhdpi") { score += 300 }
        else if name.contains("hdpi") { score += 200 }
        else if name.contains("mdpi") { score += 100 }

        score += min(200, Int(entry.uncompressedSize / 1024))
        return score
    }
}

struct ZipEntry {
    let name: String
    let compressionMethod: UInt16
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let localHeaderOffset: UInt32
}

final class ZipArchive {
    let entries: [ZipEntry]
    private let url: URL

    init?(url: URL) {
        self.url = url
        guard let entries = ZipArchive.readCentralDirectory(url: url) else { return nil }
        self.entries = entries
    }

    func extract(entry: ZipEntry) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let localHeaderOffset = UInt64(entry.localHeaderOffset)
        guard let header = try? read(handle: handle, offset: localHeaderOffset, length: 30) else { return nil }
        guard header.readUInt32LE(at: 0) == 0x04034b50 else { return nil }

        let nameLength = Int(header.readUInt16LE(at: 26))
        let extraLength = Int(header.readUInt16LE(at: 28))
        let dataOffset = localHeaderOffset + 30 + UInt64(nameLength + extraLength)

        guard let compressed = try? read(handle: handle, offset: dataOffset, length: Int(entry.compressedSize)) else { return nil }

        switch entry.compressionMethod {
        case 0:
            return compressed
        case 8:
            return decompressDeflate(compressed, expectedSize: Int(entry.uncompressedSize))
        default:
            return nil
        }
    }

    private static func readCentralDirectory(url: URL) -> [ZipEntry]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let fileSize = handle.seekToEndOfFile()
        let maxSearch = min(UInt64(22 + 65535), fileSize)
        let searchStart = fileSize > maxSearch ? fileSize - maxSearch : 0
        guard let tail = try? read(handle: handle, offset: searchStart, length: Int(maxSearch)) else { return nil }

        guard let eocdIndex = tail.lastIndex(of: 0x06, withPrefix: [0x50, 0x4b, 0x05]) else { return nil }
        let eocdOffset = Int(eocdIndex) - 3
        guard eocdOffset + 22 <= tail.count else { return nil }

        let eocd = tail.subdata(in: eocdOffset..<(eocdOffset + 22))
        let totalEntries = Int(eocd.readUInt16LE(at: 10))
        let centralSize = Int(eocd.readUInt32LE(at: 12))
        let centralOffset = Int(eocd.readUInt32LE(at: 16))

        guard let central = try? read(handle: handle, offset: UInt64(centralOffset), length: centralSize) else { return nil }
        var entries: [ZipEntry] = []
        var index = 0

        while index + 46 <= central.count {
            guard central.readUInt32LE(at: index) == 0x02014b50 else { break }
            let compression = central.readUInt16LE(at: index + 10)
            let compressedSize = central.readUInt32LE(at: index + 20)
            let uncompressedSize = central.readUInt32LE(at: index + 24)
            let nameLength = Int(central.readUInt16LE(at: index + 28))
            let extraLength = Int(central.readUInt16LE(at: index + 30))
            let commentLength = Int(central.readUInt16LE(at: index + 32))
            let localOffset = central.readUInt32LE(at: index + 42)

            let nameStart = index + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= central.count else { break }
            let nameData = central.subdata(in: nameStart..<nameEnd)
            let name = String(data: nameData, encoding: .utf8) ?? ""

            entries.append(
                ZipEntry(
                    name: name,
                    compressionMethod: compression,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localOffset
                )
            )

            index = nameEnd + extraLength + commentLength
        }

        if totalEntries > 0, entries.count > totalEntries {
            return Array(entries.prefix(totalEntries))
        }

        return entries
    }

    private static func read(handle: FileHandle, offset: UInt64, length: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        return try handle.read(upToCount: length) ?? Data()
    }

    private func read(handle: FileHandle, offset: UInt64, length: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        return try handle.read(upToCount: length) ?? Data()
    }
}

private func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
    guard expectedSize > 0 else { return Data() }

    var stream = z_stream()
    var result = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard result == Z_OK else { return nil }
    defer { inflateEnd(&stream) }

    var output = Data(count: expectedSize)
    var decodedSize = 0

    let status: Int32 = data.withUnsafeBytes { inputPtr in
        output.withUnsafeMutableBytes { outputPtr in
            guard let inBase = inputPtr.bindMemory(to: Bytef.self).baseAddress,
                  let outBase = outputPtr.bindMemory(to: Bytef.self).baseAddress else {
                return Z_DATA_ERROR
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inBase)
            stream.avail_in = uInt(data.count)
            stream.next_out = outBase
            stream.avail_out = uInt(expectedSize)

            let inflateResult = inflate(&stream, Z_FINISH)
            decodedSize = expectedSize - Int(stream.avail_out)
            return inflateResult
        }
    }

    guard status == Z_STREAM_END || status == Z_OK else { return nil }
    output.count = max(decodedSize, 0)
    return output
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        let b0 = UInt16(self[offset])
        let b1 = UInt16(self[offset + 1]) << 8
        return b0 | b1
    }

    func lastIndex(of byte: UInt8, withPrefix prefix: [UInt8]) -> Int? {
        guard count >= prefix.count + 1 else { return nil }
        let bytes = [UInt8](self)
        for i in stride(from: bytes.count - 1, through: prefix.count, by: -1) {
            if bytes[i] == byte {
                var matches = true
                for (offset, pref) in prefix.enumerated() {
                    if bytes[i - prefix.count + offset] != pref {
                        matches = false
                        break
                    }
                }
                if matches {
                    return i
                }
            }
        }
        return nil
    }
}
