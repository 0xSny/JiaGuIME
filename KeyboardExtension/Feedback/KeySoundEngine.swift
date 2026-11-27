import AVFoundation
import UIKit

final class KeySoundEngine {
    private let audioQueue = DispatchQueue(label: "com.custom.ime.sound", qos: .userInteractive)
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?
    private var deleteBuffer: AVAudioPCMBuffer?
    private var isConfigured = false

    func prepare() {
        audioQueue.async { [weak self] in
            self?.setupIfNeeded()
        }
    }

    func playKeyClick(volume: Float, isFunctionKey: Bool = false) {
        let clamped = max(0.0, min(1.0, volume))
        guard clamped > 0.01 else { return }

        audioQueue.async { [weak self] in
            guard let self else { return }
            self.setupIfNeeded()
            guard let engine = self.audioEngine,
                  let player = self.playerNode,
                  let buf = isFunctionKey ? self.deleteBuffer : self.clickBuffer else {
                DispatchQueue.main.async {
                    UIDevice.current.playInputClick()
                }
                return
            }

            if !engine.isRunning {
                try? engine.start()
            }
            if engine.isRunning {
                player.volume = clamped * 0.75
                player.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
                if !player.isPlaying {
                    player.play()
                }
            }
        }
    }

    private func setupIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        // Strictly non-interrupting, non-ducking ambient mixWithOthers session
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        clickBuffer = makeCrispClickBuffer(format: format, freq: 2450.0, durationMs: 3.2, amp: 0.42)
        deleteBuffer = makeCrispClickBuffer(format: format, freq: 1650.0, durationMs: 3.8, amp: 0.36)

        self.audioEngine = engine
        self.playerNode = player
        try? engine.start()
    }

    private func makeCrispClickBuffer(format: AVAudioFormat, freq: Double, durationMs: Double, amp: Float) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let frames = AVAudioFrameCount((sr * durationMs) / 1000.0)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buf.floatChannelData?[0] else {
            return nil
        }
        buf.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            let env = Float(exp(-t * 1450.0))
            let wave = Float(sin(2.0 * Double.pi * freq * t) + 0.35 * sin(2.0 * Double.pi * (freq * 1.9) * t))
            data[i] = amp * env * wave
        }
        return buf
    }
}
