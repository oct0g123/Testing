import AVFoundation
import Foundation

// MARK: - Sound types

enum SoundType {
    case feed, happy, sleep, wake, clean, medicine, exercise
    case achievement, levelUp, coin, event, catchTreat, miss, sad, sick
}

// MARK: - Audio Engine (generates tones via AVAudioEngine — no audio files needed)

final class AudioEngine {
    static let shared = AudioEngine()

    private let engine   = AVAudioEngine()
    private let mixer    = AVAudioMixerNode()
    private let sampleRate: Double = 44100

    private init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        mixer.outputVolume = 0.6
        do { try engine.start() } catch { }
    }

    // MARK: - Public API
    func play(_ sound: SoundType) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.playSoundImpl(sound)
        }
    }

    // MARK: - Sound recipes
    private func playSoundImpl(_ sound: SoundType) {
        switch sound {
        case .feed:
            tone(440, .sine,     0.25)
            tone(550, .sine,     0.20, vol: 0.15, delay: 0.10)
        case .happy:
            for (i, f) in [523.0, 659.0, 784.0].enumerated() {
                tone(f, .sine, 0.18, vol: 0.20, delay: Double(i) * 0.08)
            }
        case .sleep:
            tone(220, .sine, 0.90, vol: 0.10)
        case .wake:
            tone(330, .sine, 0.20)
            tone(440, .sine, 0.20, vol: 0.20, delay: 0.15)
        case .clean:
            tone(900, .sine, 0.15, vol: 0.20)
        case .medicine:
            tone(330, .sine, 0.20)
            tone(660, .sine, 0.25, vol: 0.20, delay: 0.20)
        case .exercise:
            tone(392, .sawtooth, 0.10)
            tone(493, .sawtooth, 0.10, vol: 0.20, delay: 0.12)
        case .achievement:
            for (i, f) in [523.0, 659.0, 784.0, 1047.0].enumerated() {
                tone(f, .sine, 0.50, vol: 0.25, delay: Double(i) * 0.12)
            }
        case .levelUp:
            for (i, f) in [392.0, 494.0, 587.0, 740.0, 880.0].enumerated() {
                tone(f, .sine, 0.50, vol: 0.30, delay: Double(i) * 0.10)
            }
        case .coin:
            tone(1047, .sine, 0.15, vol: 0.20)
        case .event:
            tone(311, .triangle, 0.40, vol: 0.14)
        case .catchTreat:
            tone(659, .sine, 0.10, vol: 0.30)
        case .miss:
            tone(150, .sawtooth, 0.20, vol: 0.18)
        case .sad:
            tone(200, .sawtooth, 0.60, vol: 0.10)
        case .sick:
            tone(180, .sawtooth, 0.70, vol: 0.12)
        }
    }

    // MARK: - Tone generator
    enum WaveType { case sine, sawtooth, triangle, square }

    private func tone(_ frequency: Double, _ wave: WaveType, _ duration: Double,
                      vol: Float = 0.22, delay: Double = 0) {
        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.playBuffer(frequency, wave, duration, vol)
            }
        } else {
            playBuffer(frequency, wave, duration, vol)
        }
    }

    private func playBuffer(_ frequency: Double, _ wave: WaveType, _ duration: Double, _ vol: Float) {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(duration * sampleRate)) else { return }
        buffer.frameLength = buffer.frameCapacity

        let data = buffer.floatChannelData![0]
        let count = Int(buffer.frameLength)
        let attack = max(1, Int(0.01 * sampleRate))
        let release = max(1, Int(min(0.15, duration * 0.4) * sampleRate))

        for i in 0..<count {
            let t = Double(i) / sampleRate
            var s: Float
            switch wave {
            case .sine:
                s = Float(sin(2 * .pi * frequency * t))
            case .sawtooth:
                s = Float(2 * (frequency * t - floor(frequency * t + 0.5)))
            case .triangle:
                let p = frequency * t
                s = Float(4 * abs(p - floor(p + 0.5)) - 1)
            case .square:
                s = sin(2 * .pi * frequency * t) > 0 ? 1 : -1
            }
            var env: Float
            if i < attack {
                env = vol * Float(i) / Float(attack)
            } else if i > count - release {
                env = vol * Float(count - i) / Float(release)
            } else {
                env = vol
            }
            data[i] = s * env
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: mixer, format: format)
        player.scheduleBuffer(buffer) { [weak self] in
            self?.engine.detach(player)
        }
        player.play()
    }
}
