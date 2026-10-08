//
//  ZipWriter.swift
//  gilwellSCROM
//
//  Minimal ZIP writer, no dependencies: "stored" entries (no compression), UTF-8 names.
//  That is enough for SCORM packages (a few hundred KB) and Moodle accepts it.
//

import Foundation

nonisolated struct ZipWriter {
    private struct Entry {
        let name: String
        let data: Data
        let crc: UInt32
    }

    private var entries: [Entry] = []
    private let timestamp: (time: UInt16, data: UInt16)

    init(data: Date = Date()) {
        let c = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: data)
        let year = max(1980, c.year ?? 1980)
        let data16 = UInt16(((year - 1980) << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1))
        let time16 = UInt16(((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2))
        self.timestamp = (time16, data16)
    }

    /// Adds a file. `name` uses "/" as the separator (e.g. "css/style.css").
    mutating func add(_ name: String, _ data: Data) {
        entries.append(Entry(name: name, data: data, crc: ZipWriter.crc32(data)))
    }

    var count: Int { entries.count }

    /// Builds the complete ZIP file.
    func build() -> Data {
        var output = Data()
        var offsets: [UInt32] = []

        for e in entries {
            offsets.append(UInt32(output.count))
            let name = Array(e.name.utf8)
            output.append(contentsOf: ZipWriter.le(UInt32(0x04034b50)))
            output.append(contentsOf: ZipWriter.le(UInt16(20)))              // version needed
            output.append(contentsOf: ZipWriter.le(UInt16(0x0800)))          // bit 11: UTF-8 names
            output.append(contentsOf: ZipWriter.le(UInt16(0)))               // method 0 = stored
            output.append(contentsOf: ZipWriter.le(timestamp.time))
            output.append(contentsOf: ZipWriter.le(timestamp.data))
            output.append(contentsOf: ZipWriter.le(e.crc))
            output.append(contentsOf: ZipWriter.le(UInt32(e.data.count)))   // compressed size
            output.append(contentsOf: ZipWriter.le(UInt32(e.data.count)))   // uncompressed size
            output.append(contentsOf: ZipWriter.le(UInt16(name.count)))
            output.append(contentsOf: ZipWriter.le(UInt16(0)))               // extra field
            output.append(contentsOf: name)
            output.append(e.data)
        }

        let directoryStart = UInt32(output.count)

        for (i, e) in entries.enumerated() {
            let name = Array(e.name.utf8)
            output.append(contentsOf: ZipWriter.le(UInt32(0x02014b50)))
            output.append(contentsOf: ZipWriter.le(UInt16(20)))              // version made by
            output.append(contentsOf: ZipWriter.le(UInt16(20)))              // version needed
            output.append(contentsOf: ZipWriter.le(UInt16(0x0800)))
            output.append(contentsOf: ZipWriter.le(UInt16(0)))
            output.append(contentsOf: ZipWriter.le(timestamp.time))
            output.append(contentsOf: ZipWriter.le(timestamp.data))
            output.append(contentsOf: ZipWriter.le(e.crc))
            output.append(contentsOf: ZipWriter.le(UInt32(e.data.count)))
            output.append(contentsOf: ZipWriter.le(UInt32(e.data.count)))
            output.append(contentsOf: ZipWriter.le(UInt16(name.count)))
            output.append(contentsOf: ZipWriter.le(UInt16(0)))               // extra
            output.append(contentsOf: ZipWriter.le(UInt16(0)))               // comment
            output.append(contentsOf: ZipWriter.le(UInt16(0)))               // starting disk
            output.append(contentsOf: ZipWriter.le(UInt16(0)))               // internal attributes
            output.append(contentsOf: ZipWriter.le(UInt32(0)))               // external attributes
            output.append(contentsOf: ZipWriter.le(offsets[i]))
            output.append(contentsOf: name)
        }

        let directorySize = UInt32(output.count) - directoryStart

        output.append(contentsOf: ZipWriter.le(UInt32(0x06054b50)))
        output.append(contentsOf: ZipWriter.le(UInt16(0)))                   // this disk
        output.append(contentsOf: ZipWriter.le(UInt16(0)))                   // directory disk
        output.append(contentsOf: ZipWriter.le(UInt16(entries.count)))
        output.append(contentsOf: ZipWriter.le(UInt16(entries.count)))
        output.append(contentsOf: ZipWriter.le(directorySize))
        output.append(contentsOf: ZipWriter.le(directoryStart))
        output.append(contentsOf: ZipWriter.le(UInt16(0)))                   // file comment
        return output
    }

    // MARK: - Helpers

    /// Little-endian integer, byte by byte.
    private static func le<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        (0..<MemoryLayout<T>.size).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { (i: Int) -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for byte in data {
            c = crcTable[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8)
        }
        return c ^ 0xFFFFFFFF
    }
}
