import Foundation
import CoreHaptics
import UIKit

@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool

    // Reused UIKit generators so we don't allocate + prepare on every tap.
    // `prepare()` is called once; subsequent fires are effectively free.
    private let lightImpact: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light); g.prepare(); return g
    }()
    private let notificationFeedback: UINotificationFeedbackGenerator = {
        let g = UINotificationFeedbackGenerator(); g.prepare(); return g
    }()

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
            engine?.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    guard let self else { return }
                    if reason == .applicationSuspended || reason == .systemError {
                        try? self.engine?.start()
                    }
                }
            }
            try engine?.start()
        } catch {
            RFLogger.general.error("CHHapticEngine initialization failed: \(error.localizedDescription) — falling back to UIKit generators")
            supportsHaptics = false
        }
    }

    // Light tap — scan complete, save success
    func playSuccess() {
        guard supportsHaptics else {
            lightImpact.impactOccurred()
            return
        }

        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)

        playPattern([event])
    }

    // Double tap — urgency alert
    func playUrgency() {
        guard supportsHaptics else {
            notificationFeedback.notificationOccurred(.warning)
            return
        }

        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let intensity1 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let intensity2 = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)

        let event1 = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity1], relativeTime: 0)
        let event2 = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity2], relativeTime: 0.15)

        playPattern([event1, event2])
    }

    // Soft continuous — scanning in progress
    func playScanning() {
        guard supportsHaptics else { return }

        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [sharpness, intensity], relativeTime: 0, duration: 0.5)

        playPattern([event])
    }

    // Error haptic
    func playError() {
        notificationFeedback.notificationOccurred(.error)
    }

    private func playPattern(_ events: [CHHapticEvent]) {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Silently fail — haptics are non-essential
        }
    }
}
