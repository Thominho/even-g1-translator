import Foundation

/// Decodes the G1 microphone stream: LC3, 16 kHz mono, 10 ms frames of 20 bytes
/// (same parameters as Even Realities' official demo) → 16-bit PCM.
final class Lc3Decoder {
    static let frameBytes = 20
    private let dtUs: Int32 = 10_000
    private let srHz: Int32 = 16_000
    private let memory: UnsafeMutableRawPointer
    private let decoder: lc3_decoder_t
    private let samples: Int
    private var pcm: [Int16]

    init() {
        let size = Int(lc3_decoder_size(dtUs, srHz))
        memory = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        decoder = lc3_setup_decoder(dtUs, srHz, 0, memory)
        samples = Int(lc3_frame_samples(dtUs, srHz))
        pcm = [Int16](repeating: 0, count: samples)
    }

    deinit { memory.deallocate() }

    /// One BLE audio payload (several LC3 frames) → PCM bytes (Int16, little endian).
    func decode(_ lc3: Data) -> Data {
        var out = Data(capacity: lc3.count / Self.frameBytes * samples * 2)
        lc3.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset + Self.frameBytes <= raw.count {
                pcm.withUnsafeMutableBytes { dst in
                    _ = lc3_decode(decoder, base + offset, Int32(Self.frameBytes),
                                   LC3_PCM_FORMAT_S16, dst.baseAddress, 1)
                    out.append(contentsOf: dst.bindMemory(to: UInt8.self))
                }
                offset += Self.frameBytes
            }
        }
        return out
    }
}
