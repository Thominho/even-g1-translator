import CoreBluetooth
import Foundation

/// Connects to both temples of the G1 and shows text on the display.
@MainActor
final class G1Glasses: NSObject, ObservableObject {
    enum State: Equatable { case idle, scanning, connecting, connected, failed(String) }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastScreen = ""
    var onEvent: ((G1Protocol.Event, String) -> Void)?
    /// LC3 audio from the glasses microphone (payload without the 2-byte header).
    var onAudio: ((Data) -> Void)?
    /// Keep the glasses microphone on (re-enabled after reconnects).
    var wantMic = false
    private(set) var lastAudioAt = Date.distantPast
    private var micWatchdog: Task<Void, Never>?
    var charsPerLine: Double = 38

    private var central: CBCentralManager!
    private var found: [String: [String: CBPeripheral]] = [:]     // channel -> side -> peripheral
    /// Nearby Bluetooth devices (name + signal), strongest first – shown while searching, for diagnostics.
    @Published private(set) var nearby: [String] = []
    private var nearbyRSSI: [String: Int] = [:]
    /// The pair used last time (side -> peripheral id) – reconnects even when the glasses don't advertise.
    private let knownKey = "g1.knownPair"
    private var triedKnown = false
    private var attempt = 0
    private var peripherals: [String: CBPeripheral] = [:]         // side -> peripheral
    private var writeChars: [String: CBCharacteristic] = [:]
    private var waiters: [String: Waiter] = [:]
    private var seq: UInt8 = 0
    private var hbSeq: UInt8 = 0
    private var heartbeatTask: Task<Void, Never>?
    private var sendQueue: Task<Void, Never>?
    private enum Content { case text(String), image(Data, fallback: String) }
    private var pending: Content?
    private var wantConnect = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey: "g1translator"])
    }

    var isConnected: Bool { state == .connected }

    func connect() {
        wantConnect = true
        guard central.state == .poweredOn else { return }   // continues in centralManagerDidUpdateState
        attempt += 1
        found = [:]
        nearbyRSSI = [:]; nearby = []
        state = .scanning

        // 1. The pair we used last time – works even when iOS keeps the glasses connected (they stop advertising).
        if !triedKnown, let saved = UserDefaults.standard.dictionary(forKey: knownKey) as? [String: String],
           let l = saved["L"].flatMap(UUID.init), let r = saved["R"].flatMap(UUID.init) {
            triedKnown = true
            let ps = central.retrievePeripherals(withIdentifiers: [l, r])
            if let pl = ps.first(where: { $0.identifier == l }), let pr = ps.first(where: { $0.identifier == r }) {
                use(left: pl, right: pr)
                return
            }
        }

        // 2. Glasses connected to this iPhone at system level (bonded, e.g. kept after the Even app).
        let services = [G1Protocol.uartService, "180A", "180F"].map { CBUUID(string: $0) }
        for p in central.retrieveConnectedPeripherals(withServices: services) {
            note(p.name ?? "?", rssi: nil, connected: true)
            consider(p, name: p.name)
        }
        guard state == .scanning else { return }

        // 3. Scan for advertising glasses.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        let thisAttempt = attempt
        Task {
            try? await Task.sleep(for: .seconds(25))
            if self.state == .scanning, self.attempt == thisAttempt {
                self.central.stopScan()
                self.state = .failed("G1 not found – close the Even Realities app and take the glasses out of the case.")
            }
        }
    }

    /// Remembers a nearby device for the diagnostics list.
    fileprivate func note(_ name: String, rssi: Int?, connected: Bool) {
        let key = connected ? name + " · iOS" : name
        nearbyRSSI[key] = rssi ?? 0
        nearby = nearbyRSSI.sorted { $0.value > $1.value }.prefix(8).map { k, v in v == 0 ? k : "\(k)  \(v) dBm" }
    }

    func disconnect() {
        wantConnect = false
        heartbeatTask?.cancel()
        micWatchdog?.cancel()
        for p in peripherals.values { central.cancelPeripheralConnection(p) }
        peripherals = [:]; writeChars = [:]
        state = .idle
    }

    /// Shows text. Only the newest text is sent if the display is still busy.
    func show(_ text: String) {
        let screen = G1Protocol.tail(text, width: charsPerLine)
        lastScreen = screen
        enqueue(.text(screen))
    }

    /// A 576×136 1-bit BMP (boxes, more content); the text is shown if the picture can't be sent.
    func showImage(_ bmp: Data, fallback: String) {
        lastScreen = G1Protocol.tail(fallback, width: charsPerLine)
        enqueue(.image(bmp, fallback: lastScreen))
    }

    private func enqueue(_ content: Content) {
        guard isConnected else { return }
        pending = content          // only the newest screen matters
        if sendQueue == nil {
            sendQueue = Task {
                while let next = self.pending {
                    self.pending = nil
                    switch next {
                    case .text(let t):
                        if self.imageOnScreen { await self.leaveImage() }
                        await self.send(t)
                    case .image(let bmp, let fallback):
                        if await self.sendImage(bmp) {
                            self.imageOnScreen = true
                        } else {
                            if self.imageOnScreen { await self.leaveImage() }
                            await self.send(fallback)
                        }
                    }
                }
                self.sendQueue = nil
            }
        }
    }

    /// Back from the picture to the text screen: exit (0x18) clears it; the microphone is switched on again
    /// right away in case leaving the screen turned it off.
    private func leaveImage() async {
        let t = Date()
        _ = await write(Data([0x18]), side: "L", waitAck: true, timeoutMs: 800)
        _ = await write(Data([0x18]), side: "R", waitAck: true, timeoutMs: 800)
        imageOnScreen = false
        leftImageAt = Date()
        if wantMic {
            lastAudioAt = Date()
            await write(Data([G1Protocol.cmdMic, 1]), side: "R", waitAck: true)
        }
        dlog(String(format: "BLE left picture %.2fs", Date().timeIntervalSince(t)))
    }

    /// Picture upload as in the official demo: 0x15 packets (address in the first one), 0x20 end, 0x16 CRC.
    /// A picture stays under later text (text is drawn in a black box over it) → leave the picture first.
    private var imageOnScreen = false
    private var leftImageAt = Date.distantPast

    /// Pause between picture packets – as short as the glasses take (learnt: slower after a failed upload).
    private var imagePacing = 3

    private func sendImage(_ bmp: Data) async -> Bool {
        for attempt in 0..<2 {
            let t = Date()
            async let left = sendImage(bmp, side: "L")
            async let right = sendImage(bmp, side: "R")
            let (l, r) = await (left, right)
            dlog(String(format: "BLE image %.2fs, L %@ R %@, pacing %d ms", Date().timeIntervalSince(t),
                        l ? "ok" : "fail", r ? "ok" : "fail", imagePacing))
            if l && r { return true }
            if attempt == 0 { imagePacing = 8 }      // too fast for the glasses → official demo speed
            if pending != nil { return false }       // a newer screen is waiting anyway
        }
        return false
    }

    private func sendImage(_ bmp: Data, side: String) async -> Bool {
        guard let p = peripherals[side] else { return false }
        let maxLen = p.maximumWriteValueLength(for: .withoutResponse)
        let pack = min(194, maxLen - 6)
        guard pack > 20 else { return false }
        var index = 0
        var offset = 0
        while offset < bmp.count {
            let end = min(offset + pack, bmp.count)
            var packet = Data([0x15, UInt8(index & 0xFF)])
            if index == 0 { packet.append(contentsOf: G1Image.address) }
            packet.append(bmp.subdata(in: offset..<end))
            var spins = 0
            while !p.canSendWriteWithoutResponse, spins < 50 {   // don't overflow the BLE buffer
                try? await Task.sleep(for: .milliseconds(4)); spins += 1
            }
            await write(packet, side: side, waitAck: false)
            try? await Task.sleep(for: .milliseconds(imagePacing))
            index += 1
            offset = end
        }
        var finished = false
        for _ in 0..<3 where !finished {
            finished = await write(Data([0x20, 0x0D, 0x0E]), side: side, waitAck: true, timeoutMs: 3000)
        }
        guard finished else { return false }
        let crc = G1Image.crc32(Data(G1Image.address) + bmp)
        let crcPacket = Data([0x16, UInt8(crc >> 24), UInt8((crc >> 16) & 0xFF), UInt8((crc >> 8) & 0xFF), UInt8(crc & 0xFF)])
        return await write(crcPacket, side: side, waitAck: true, timeoutMs: 2000)
    }

    private func send(_ screen: String) async {
        seq &+= 1
        let t = Date()
        var acks = 0, total = 0
        for packet in G1Protocol.textPackets(screen, seq: seq) {
            if await write(packet, side: "L", waitAck: true) { acks += 1 }   // left first…
            if await write(packet, side: "R", waitAck: true) { acks += 1 }   // …then right
            total += 2
        }
        dlog(String(format: "BLE sent %.2fs, acks %d/%d", Date().timeIntervalSince(t), acks, total))
    }

    // MARK: - Writing with acknowledgement

    private final class Waiter {
        let cmd: UInt8
        var continuation: CheckedContinuation<Bool, Never>?
        init(cmd: UInt8) { self.cmd = cmd }
        func finish(_ ok: Bool) { continuation?.resume(returning: ok); continuation = nil }
    }

    @discardableResult
    private func write(_ data: Data, side: String, waitAck: Bool, timeoutMs: Int = 600) async -> Bool {
        guard let p = peripherals[side], let ch = writeChars[side] else { return false }
        guard waitAck else {
            p.writeValue(data, for: ch, type: .withoutResponse)
            return true
        }
        let waiter = Waiter(cmd: data[0])
        waiters[side]?.finish(false)
        waiters[side] = waiter
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            waiter.continuation = cont
            p.writeValue(data, for: ch, type: .withoutResponse)
            Task {
                try? await Task.sleep(for: .milliseconds(timeoutMs))
                waiter.finish(false)   // no ack in time – carry on
            }
        }
    }

    // MARK: - Microphone

    /// Turns the glasses microphone on/off (command 0x0E, right temple – as in the official demo).
    func setMic(_ on: Bool) {
        wantMic = on
        guard isConnected else { return }
        Task { await self.write(Data([G1Protocol.cmdMic, on ? 1 : 0]), side: "R", waitAck: true) }
        micWatchdog?.cancel()
        guard on else { return }
        lastAudioAt = Date()
        // if the audio stops (glasses switched the mic off), switch it on again
        micWatchdog = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if self.wantMic, self.isConnected, Date().timeIntervalSince(self.lastAudioAt) > 3 {
                    self.lastAudioAt = Date()
                    await self.write(Data([G1Protocol.cmdMic, 1]), side: "R", waitAck: false)
                }
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                hbSeq &+= 1
                await write(G1Protocol.heartbeat(seq: hbSeq), side: "L", waitAck: false)
                await write(G1Protocol.heartbeat(seq: hbSeq), side: "R", waitAck: false)
            }
        }
    }

    fileprivate func side(of p: CBPeripheral) -> String? {
        peripherals.first { $0.value.identifier == p.identifier }?.key
    }

    fileprivate func handle(_ data: Data, from side: String) {
        guard let first = data.first else { return }
        if first == G1Protocol.cmdMicData, data.count > 2 {
            lastAudioAt = Date()
            onAudio?(data.subdata(in: 2..<data.count))
            return
        }
        if first == G1Protocol.cmdEvent, data.count >= 2 {
            if var ev = G1Protocol.Event(rawValue: data[1]) {
                if ev == .tripleTap2 { ev = .tripleTap }
                // "exit to dashboard" (same code as a double tap) caused by our own exit command
                if ev == .doubleTap, Date().timeIntervalSince(leftImageAt) < 1.5 { return }
                onEvent?(ev, side)
            }
            return
        }
        if let w = waiters[side], w.cmd == first {
            w.finish(data.count < 2 || data[1] != G1Protocol.rspFail)
            waiters[side] = nil
        }
    }

    fileprivate func checkReady() {
        if writeChars["L"] != nil, writeChars["R"] != nil, state != .connected {
            state = .connected
            triedKnown = false
            if let l = peripherals["L"], let r = peripherals["R"] {
                UserDefaults.standard.set(["L": l.identifier.uuidString, "R": r.identifier.uuidString], forKey: knownKey)
            }
            startHeartbeat()
            if wantMic { setMic(true) }
            if !lastScreen.isEmpty { show(lastScreen) }
        }
    }
}

// MARK: - CoreBluetooth delegates

extension G1Glasses: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if central.state == .poweredOn, wantConnect, state == .idle || state == .scanning { connect() }
            if central.state == .unauthorized { state = .failed("Bluetooth permission denied – allow it in Settings.") }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {}

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            if let name, rssi > -95, rssi != 127, state == .scanning { note(name, rssi: rssi, connected: false) }
            consider(peripheral, name: name)
        }
    }

    /// Collects left/right temples of one pair and connects once both are found.
    func consider(_ peripheral: CBPeripheral, name: String?) {
        guard state == .scanning, let parsed = G1Protocol.parseName(name) else { return }
        found[parsed.channel, default: [:]][parsed.side] = peripheral
        if let pair = found[parsed.channel], let l = pair["L"], let r = pair["R"] {
            use(left: l, right: r)
        }
    }

    private func use(left l: CBPeripheral, right r: CBPeripheral) {
        central.stopScan()
        state = .connecting
        peripherals = ["L": l, "R": r]
        writeChars = [:]
        for p in [l, r] {
            p.delegate = self
            if p.state == .connected { p.discoverServices([CBUUID(string: G1Protocol.uartService)]) }
            else { central.connect(p, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]) }
        }
        // CoreBluetooth never gives up on its own: if the pair doesn't answer, search again.
        let thisAttempt = attempt
        Task {
            try? await Task.sleep(for: .seconds(15))
            guard self.state == .connecting, self.attempt == thisAttempt else { return }
            for p in [l, r] { self.central.cancelPeripheralConnection(p) }
            self.peripherals = [:]
            self.connect()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: G1Protocol.uartService)])
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.assumeIsolated { state = .failed(error?.localizedDescription ?? "Connection failed") }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.assumeIsolated {
            guard let side = side(of: peripheral) else { return }
            writeChars[side] = nil
            imageOnScreen = false
            if wantConnect {
                state = .connecting
                central.connect(peripheral, options: nil)   // reconnect automatically
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == CBUUID(string: G1Protocol.uartService) })
        else { return }
        peripheral.discoverCharacteristics([CBUUID(string: G1Protocol.uartWrite),
                                            CBUUID(string: G1Protocol.uartNotify)], for: service)
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        MainActor.assumeIsolated {
            guard let side = side(of: peripheral) else { return }
            for ch in service.characteristics ?? [] {
                if ch.uuid == CBUUID(string: G1Protocol.uartWrite) { writeChars[side] = ch }
                if ch.uuid == CBUUID(string: G1Protocol.uartNotify) { peripheral.setNotifyValue(true, for: ch) }
            }
            checkReady()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        guard let data = characteristic.value else { return }
        MainActor.assumeIsolated {
            if let side = side(of: peripheral) { handle(data, from: side) }
        }
    }
}
