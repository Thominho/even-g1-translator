import Foundation

/// Even Realities G1 BLE protocol (Nordic UART on each temple).
/// Based on the official EvenDemoApp: send to the LEFT temple first, then the RIGHT one.
enum G1Protocol {
    static let uartService = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    static let uartWrite   = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"   // phone -> glasses
    static let uartNotify  = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"   // glasses -> phone

    static let cmdText: UInt8 = 0x4E
    static let cmdEvent: UInt8 = 0xF5
    static let cmdHeartbeat: UInt8 = 0x25
    static let cmdMic: UInt8 = 0x0E
    static let cmdMicData: UInt8 = 0xF1
    static let rspOK: UInt8 = 0xC9
    static let rspFail: UInt8 = 0xCA

    static let screenTextNew: UInt8 = 0x71   // 0x70 = text show, 0x01 = new content
    static let maxChunk = 180
    static let linesPerScreen = 5

    enum Event: UInt8 {
        case doubleTap = 0x00, singleTap = 0x01, headUp = 0x02, headDown = 0x03
        case tripleTap = 0x04, tripleTap2 = 0x05
        case longPress = 0x17, longPressRelease = 0x18
    }

    /// "G1_45_L_92333" -> ("45", "L")
    static func parseName(_ name: String?) -> (channel: String, side: String)? {
        guard let name, name.hasPrefix("G1_") else { return nil }
        let parts = name.split(separator: "_")
        guard parts.count >= 3, ["L", "R"].contains(parts[2].uppercased()) else { return nil }
        return (String(parts[1]), parts[2].uppercased())
    }

    static func heartbeat(seq: UInt8) -> Data {
        Data([cmdHeartbeat, 6, 0, seq, 0x04, seq])
    }

    /// 0x4E packets for one screen of text:
    /// cmd, seq, total_pkg, cur_pkg, newscreen, pos_hi, pos_lo, cur_page, max_page, data
    static func textPackets(_ text: String, seq: UInt8, page: Int = 0, totalPages: Int = 1) -> [Data] {
        let bytes = Array(text.utf8)
        var chunks: [[UInt8]] = stride(from: 0, to: bytes.count, by: maxChunk).map {
            Array(bytes[$0..<min($0 + maxChunk, bytes.count)])
        }
        if chunks.isEmpty { chunks = [[]] }
        return chunks.enumerated().map { i, chunk in
            Data([cmdText, seq, UInt8(chunks.count), UInt8(i), screenTextNew, 0, 0,
                  UInt8(page & 0xFF), UInt8(max(1, totalPages) & 0xFF)] + chunk)
        }
    }

    // MARK: - Text layout (display 488 px wide, ~38 average characters per line)

    static func charWidth(_ c: Character) -> Double {
        if "iIl.,:;'!|".contains(c) { return 0.5 }
        if "mwMW@".contains(c) { return 1.5 }
        return 1.0
    }

    static func width(_ s: Substring) -> Double { s.reduce(0) { $0 + charWidth($1) } }
    static func width(_ s: String) -> Double { width(Substring(s)) }

    static func wrap(_ text: String, width maxW: Double = 38) -> [String] {
        var lines: [String] = []
        for para in text.components(separatedBy: "\n") {
            var cur = ""
            for word in para.split(separator: " ", omittingEmptySubsequences: true) {
                let cand = cur.isEmpty ? String(word) : cur + " " + word
                if width(cand) <= maxW { cur = cand; continue }
                if !cur.isEmpty { lines.append(cur) }
                var w = Substring(word)
                while width(w) > maxW {
                    var cut = w.startIndex
                    var acc = 0.0
                    while cut < w.endIndex, acc + charWidth(w[cut]) <= maxW {
                        acc += charWidth(w[cut]); cut = w.index(after: cut)
                    }
                    lines.append(String(w[..<cut])); w = w[cut...]
                }
                cur = String(w)
            }
            lines.append(cur)
        }
        while let last = lines.last, last.isEmpty, lines.count > 1 { lines.removeLast() }
        return lines
    }

    /// The last screen (max 5 lines) – for live subtitles.
    static func tail(_ text: String, width: Double = 38) -> String {
        wrap(text, width: width).suffix(linesPerScreen).joined(separator: "\n")
    }

    static func fits(_ text: String, width: Double = 38) -> Bool {
        wrap(text, width: width).count <= linesPerScreen
    }
}
