import AVFoundation
import Foundation
import UIKit

/// Servicio de efectos de sonido para celebraciones de gamificación.
/// Usa tonos del sistema (sin archivos de audio externos necesarios).
@MainActor
final class CelebrationSoundService {
    static let shared = CelebrationSoundService()
    private init() {}

    /// Controla si los sonidos están habilitados
    var isEnabled = true

    /// Guard contra reproducción concurrente
    private var isPlaying = false

    // MARK: - Sound Types

    enum CelebrationSound {
        case xpGain
        case questComplete
        case levelUp
        case achievementUnlock
        case streakMilestone
        case confettiBurst
    }

    // MARK: - System Sound IDs Reference
    // 1003 = Tock (pop sound)
    // 1004 = Key press click (subtle tick)
    // 1025 = Short positive tone
    // 1026 = Ascending tone (low)
    // 1027 = Ascending tone (mid)
    // 1032 = Ascending tone (high, positive confirmation)

    // MARK: - Play

    func play(_ sound: CelebrationSound) {
        guard isEnabled, !isPlaying else { return }

        switch sound {
        case .xpGain:
            playSystemSound(1004) // Subtle tick

        case .questComplete:
            playSystemSound(1025) // Short positive tone

        case .levelUp:
            // Multi-tone ascending sequence in a single Task chain
            isPlaying = true
            playSystemSound(1026) // Low ascending
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.15))
                self?.playSystemSound(1027) // Mid ascending
                try? await Task.sleep(for: .seconds(0.15))
                self?.playSystemSound(1032) // High confirmation
                self?.isPlaying = false
            }

        case .achievementUnlock:
            isPlaying = true
            playSystemSound(1026) // Low ascending
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.2))
                self?.playSystemSound(1032) // High confirmation
                self?.isPlaying = false
            }

        case .streakMilestone:
            playSystemSound(1032) // Positive confirmation

        case .confettiBurst:
            playSystemSound(1003) // Pop / tock
        }
    }

    nonisolated private func playSystemSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
}
