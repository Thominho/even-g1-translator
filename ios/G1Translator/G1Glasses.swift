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
    private var peripherals: [String: CBPeripheral] = [:]         // side -> peripheral
    private var writeChars: [String: CBCharacteristic] = [:]
    private var waiters: [String: Waiter] = [:]
    private var seq: UInt8 = 0
    private var hbSeq: UInt8 = 0
    private var heartbeatTask: Task<Void, Never>?
    private var sendQueue: Task<Void, Never>?
    private var pendingText: String?
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
        found = [:]
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: nil)
        Task {
            try? await Task.sleep(for: .seconds(20))
            if self.state == .scanning {
                self.central.stopScan()
                self.state = .failed("G1 not found – close the Even Realities app and take the glasses out of the case.")
            }
        }
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
        guard isConnected else { return }
        pendingText = screen
        if sendQueue == nil {
            sendQueue = Task {
                while let next = self.pendingText {
                    self.pendingText = nil
                    await self.send(next)
                }
                self.sendQueue = nil
            }
        }
    }

    private func send(_ screen: String) async {
        seq &+= 1
        for packet in G1Protocol.textPackets(screen, seq: seq) {
            _ = await write(packet, side: "L", waitAck: true)   // left first…
            _ = await write(packet, side: "R", waitAck: true)   // …then right
        }
    }

    // MARK: - Writing with acknowledgement

    private final class Waiter {
        let cmd: UInt8
        var continuation: CheckedContinuation<Bool, Never>?
        init(cmd: UInt8) { self.cmd = cmd }
        func finish(_ ok: Bool) { continuation?.resume(returning: ok); continuation = nil }
    }

    @discardableResult
    private func write(_ data: Data, side: String, waitAck: Bool) async -> Bool {
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
                try? await Task.sleep(for: .milliseconds(1500))
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
        MainActor.assumeIsolated {
            guard state == .scanning, let parsed = G1Protocol.parseName(name) else { return }
            found[parsed.channel, default: [:]][parsed.side] = peripheral
            if let pair = found[parsed.channel], let l = pair["L"], let r = pair["R"] {
                central.stopScan()
                state = .connecting
                peripherals = ["L": l, "R": r]
                for p in [l, r] {
                    p.delegate = self
                    central.connect(p, options: nil)
                }
            }
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
