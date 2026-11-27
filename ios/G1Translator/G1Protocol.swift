import Foundation
import UIKit

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
    /// Accepts "G1_45_L_92333", "Even G1_45_L_92333" and similar advertised names.
    /// "Even G1_45_L_92333" -> ("45", "L"). Same rule as the official demo: the side is the "_L_" / "_R_" part,
    /// the channel (pair number) is the part before it.
    static func parseName(_ name: String?) -> (channel: String, side: String)? {
        guard let name else { return nil }
        let parts = name.split(separator: "_").map { String($0).trimmingCharacters(in: .whitespaces) }
        for i in 1..<max(parts.count, 1) where i < parts.count {
            let side = parts[i].uppercased()
            guard side == "L" || side == "R" else { continue }
            let channel = parts[i - 1].components(separatedBy: " ").last ?? parts[i - 1]
            guard !channel.isEmpty else { continue }
            return (channel, side)
        }
        return nil
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

// MARK: - Pictures (576×136, 1 bit) – boxes and a smaller font fit much more than the 5 text lines

enum G1Image {
    static let width = 576, height = 136
    static let address: [UInt8] = [0x00, 0x1C, 0x00, 0x00]   // where the glasses store the picture

    struct Box {
        var title: String      // e.g. "+ Rád, končím v pět"
        var body: String       // pronunciation
    }

    /// Optional header bar + up to 3 boxes side by side. Returns the BMP for the glasses and a preview.
    static func boxes(header: String, boxes: [Box]) -> (bmp: Data, preview: UIImage) {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setAllowsAntialiasing(false); cg.setShouldAntialias(false)
            cg.setAllowsFontSmoothing(false); cg.setShouldSmoothFonts(false)
            UIColor.black.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let headFont = UIFont.systemFont(ofSize: 17, weight: .medium)
            let titleFont = UIFont.systemFont(ofSize: 17, weight: .bold)
            let bodyFont = UIFont.systemFont(ofSize: 17, weight: .medium)
            var top: CGFloat = 0
            if !header.isEmpty {
                // what they said (up to 2 lines), then a line
                let h = draw(header, font: headFont, color: .white,
                             in: CGRect(x: 4, y: 0, width: size.width - 8, height: 44), maxLines: 2)
                let lineY = floor(h + 2) + 0.5
                let line = UIBezierPath()
                line.move(to: CGPoint(x: 0, y: lineY)); line.addLine(to: CGPoint(x: size.width, y: lineY))
                line.lineWidth = 1
                UIColor.white.setStroke()
                line.stroke()
                top = lineY + 3.5
            }
            let n = max(1, boxes.count)
            let gap: CGFloat = 6
            let w = floor((size.width - gap * CGFloat(n - 1)) / CGFloat(n))
            UIColor.white.setStroke()
            for (i, b) in boxes.enumerated() {
                let frame = CGRect(x: CGFloat(i) * (w + gap), y: top, width: w, height: size.height - top)
                let path = UIBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 6)
                path.lineWidth = 1
                path.stroke()
                let inner = frame.insetBy(dx: 6, dy: 3)
                let titleH = draw(b.title, font: titleFont, color: .white, in: inner, maxLines: 2)
                let sepY = floor(inner.minY + titleH + 2) + 0.5
                let sep = UIBezierPath()
                sep.move(to: CGPoint(x: inner.minX, y: sepY)); sep.addLine(to: CGPoint(x: inner.maxX, y: sepY))
                sep.lineWidth = 1
                sep.stroke()
                draw(b.body, font: bodyFont, color: .white,
                     in: CGRect(x: inner.minX, y: sepY + 2, width: inner.width, height: inner.maxY - sepY - 2), maxLines: 0)
            }
        }
        return (bmp(from: image), image)
    }

    @discardableResult
    private static func draw(_ s: String, font: UIFont, color: UIColor, in rect: CGRect, maxLines: Int) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let text = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        let fits = max(1, Int(floor(rect.height / font.lineHeight)))
        let lines = maxLines > 0 ? min(maxLines, fits) : fits
        let box = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: font.lineHeight * CGFloat(lines))
        text.draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        let needed = text.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin], context: nil).height
        return min(ceil(needed), box.height)
    }

    /// 1-bit BMP exactly like the official samples: palette [white, black], bottom-up rows,
    /// lit pixels use palette index 0.
    static func bmp(from image: UIImage) -> Data {
        guard let cgImage = image.cgImage else { return Data() }
        var gray = [UInt8](repeating: 0, count: width * height)
        gray.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let rowBytes = width / 8                       // 72 – already a multiple of 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        for y in 0..<height {
            let dst = (height - 1 - y) * rowBytes      // BMP rows go bottom-up
            for xb in 0..<rowBytes {
                var byte: UInt8 = 0
                for bit in 0..<8 where gray[y * width + xb * 8 + bit] < 128 {
                    byte |= 0x80 >> UInt8(bit)         // 1 = background, 0 = lit
                }
                pixels[dst + xb] = byte
            }
        }
        var d = Data()
        func u16(_ v: Int) { d.append(UInt8(v & 0xFF)); d.append(UInt8((v >> 8) & 0xFF)) }
        func u32(_ v: Int) { for i in 0..<4 { d.append(UInt8((v >> (8 * i)) & 0xFF)) } }
        let offset = 62
        d.append(contentsOf: [0x42, 0x4D]); u32(offset + pixels.count); u16(0); u16(0); u32(offset)
        u32(40); u32(width); u32(height); u16(1); u16(1); u32(0); u32(pixels.count); u32(2834); u32(2834); u32(0); u32(0)
        d.append(contentsOf: [0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00])
        d.append(contentsOf: pixels)
        return d
    }

    /// CRC-32 (the same as CRC-32/XZ used by the glasses).
    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
