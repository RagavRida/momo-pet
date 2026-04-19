import AVFoundation
import AppKit

/// Talking-Tom-style mic mimic: records user voice, plays it back pitched up.
final class Mimic: NSObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()

    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?
    private var silenceFrames = 0
    private let silenceThreshold: Float = 0.012
    private let silenceFramesNeeded = 22 // ~0.5s of silence ends the take
    private(set) var enabled = false

    var onPlaybackStart: (() -> Void)?
    var onPlaybackEnd: (() -> Void)?

    override init() {
        super.init()
        pitch.pitch = 900     // ~9 semitones up — Tom-like
        pitch.rate = 1.0
        engine.attach(player)
        engine.attach(pitch)
    }

    func enable(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard granted else { completion(false); return }
                self?.startListening()
                completion(self?.enabled ?? false)
            }
        }
    }

    func disable() {
        guard enabled else { return }
        enabled = false
        engine.inputNode.removeTap(onBus: 0)
        if player.isPlaying { player.stop() }
        engine.stop()
    }

    private func startListening() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // Connect player chain using input format
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.handleInput(buffer: buffer, format: format)
        }
        do {
            try engine.start()
            enabled = true
        } catch {
            NSLog("Mimic engine start failed: \(error)")
        }
    }

    private func handleInput(buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        let level = rms(buffer: buffer)
        let speaking = level > silenceThreshold

        if speaking {
            if recordingFile == nil { startRecording(format: format) }
            try? recordingFile?.write(from: buffer)
            silenceFrames = 0
        } else if recordingFile != nil {
            try? recordingFile?.write(from: buffer)
            silenceFrames += 1
            if silenceFrames >= silenceFramesNeeded {
                finishRecordingAndPlay()
            }
        }
    }

    private func startRecording(format: AVAudioFormat) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo_mimic_\(UUID().uuidString).caf")
        do {
            recordingFile = try AVAudioFile(forWriting: url, settings: format.settings)
            recordingURL = url
            silenceFrames = 0
        } catch {
            NSLog("Mimic record start failed: \(error)")
            recordingFile = nil
            recordingURL = nil
        }
    }

    private func finishRecordingAndPlay() {
        guard let url = recordingURL else { return }
        recordingFile = nil
        recordingURL = nil
        silenceFrames = 0
        DispatchQueue.main.async { [weak self] in
            self?.play(url: url)
        }
    }

    private func play(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            // ensure player chain matches file format
            engine.disconnectNodeOutput(player)
            engine.disconnectNodeOutput(pitch)
            engine.connect(player, to: pitch, format: file.processingFormat)
            engine.connect(pitch, to: engine.mainMixerNode, format: file.processingFormat)

            onPlaybackStart?()
            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.onPlaybackEnd?()
                    try? FileManager.default.removeItem(at: url)
                }
            }
            if !player.isPlaying { player.play() }
        } catch {
            NSLog("Mimic playback failed: \(error)")
            try? FileManager.default.removeItem(at: url)
            onPlaybackEnd?()
        }
    }

    private func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for ch in 0..<channels {
            let ptr = data[ch]
            for i in 0..<frames {
                sum += ptr[i] * ptr[i]
            }
        }
        return sqrt(sum / Float(frames * channels))
    }
}
