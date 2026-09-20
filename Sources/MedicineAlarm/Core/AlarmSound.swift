import AppKit
import AVFoundation

/// 弹窗期间循环播放的提示音 + 中文语音播报。
///
/// 用「每隔几秒响一次」而不是让一个音频文件无缝循环，听感更接近闹钟，
/// 也不会因为长时间播放而 Audio 会话出问题。
final class AlarmSound {

    /// 可选提示音。都来自 `/System/Library/Sounds`，免去往 bundle 里塞音频文件。
    /// 顺序不是字母序——把听感上「像闹钟、又不刺耳」的排在前面。
    static let availableChimes = [
        "Glass", "Ping", "Submarine", "Hero", "Morse", "Pop", "Purr",
        "Sosumi", "Tink", "Basso", "Blow", "Bottle", "Frog", "Funk",
    ]

    static let defaultChimeName = "Glass"

    private var chime: NSSound?
    private var loadedChimeName: String?
    private var chimeTimer: Timer?
    private var speechTimer: Timer?
    private let synthesizer = AVSpeechSynthesizer()

    private let preferences: Preferences

    private var speechText: String = ""
    private var speechEnabled = true

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
    }

    /// 开始提醒。`text` 是要朗读的内容，例如「该吃药了，激素服药」。
    func start(text: String, speak: Bool) {
        stop()
        speechText = text
        speechEnabled = speak

        loadChime(named: preferences.chimeName)

        playChime()
        if speak { speakNow(text) }

        // 间隔每次提醒时现读，设置里改完下一次提醒就生效
        let ct = Timer(timeInterval: max(1, preferences.chimeInterval), repeats: true) { [weak self] _ in
            self?.playChime()
        }
        RunLoop.main.add(ct, forMode: .common)
        chimeTimer = ct

        if speak {
            let st = Timer(timeInterval: 25, repeats: true) { [weak self] _ in
                guard let self, self.speechEnabled else { return }
                self.speakNow(self.speechText)
            }
            RunLoop.main.add(st, forMode: .common)
            speechTimer = st
        }
    }

    func stop() {
        chimeTimer?.invalidate()
        chimeTimer = nil
        speechTimer?.invalidate()
        speechTimer = nil
        chime?.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// 只响一声（用于「测试弹窗」或按钮点击反馈）。
    func playOnce() {
        playChime()
    }

    /// 试听某个提示音（设置窗口用）。走独立的实例，
    /// 不会打断正在循环的提醒，也不会被提醒的循环打断。
    func preview(_ name: String) {
        previewSound?.stop()
        let sound = Self.makeSound(named: name)
        previewSound = sound
        sound?.play()
    }

    private var previewSound: NSSound?

    private func loadChime(named name: String) {
        guard loadedChimeName != name || chime == nil else { return }
        loadedChimeName = name
        chime = Self.makeSound(named: name)
    }

    /// 按名字找系统音效；名字不存在时退回文件路径；再不行用默认音。
    private static func makeSound(named name: String) -> NSSound? {
        NSSound(named: NSSound.Name(name))
            ?? NSSound(
                contentsOf: URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff"),
                byReference: true
            )
            ?? NSSound(named: NSSound.Name(defaultChimeName))
    }

    private func playChime() {
        guard let chime else { return }
        // NSSound 正在播放时再调 play() 会直接返回 false，先停再放才能每次都响
        if chime.isPlaying { chime.stop() }
        chime.play()
    }

    private func speakNow(_ text: String) {
        guard !text.isEmpty else { return }
        // 前一句还没说完就直接掐掉，避免排队积压
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
}
