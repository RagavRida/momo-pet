import AVFoundation

/// High-pitched Tom-like voice synthesizer for Momo.
final class Voice: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        let cleaned = strip(text)
        guard !cleaned.isEmpty else { return }
        let utt = AVSpeechUtterance(string: cleaned)
        utt.pitchMultiplier = 1.7      // Tom-like high pitch
        utt.rate = 0.52
        utt.volume = 0.9
        utt.preUtteranceDelay = 0.05
        utt.postUtteranceDelay = 0.1
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utt)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    /// Strip emoji & non-ASCII for clean speech output.
    private func strip(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            // Keep printable ASCII + basic punctuation
            return scalar.value < 128 && (scalar.properties.isAlphabetic || CharacterSet(charactersIn: " .,!?'-").contains(scalar) || ("0"..."9").contains(Character(scalar)))
        }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.onStart?() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.onFinish?() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.onFinish?() }
    }
}
