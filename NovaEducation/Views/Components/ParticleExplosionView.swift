import SwiftUI

struct ParticleExplosionView: View {
    let color: Color
    @State private var engine = ExplosionEngine()
    @State private var startDate: Date?

    var body: some View {
        ZStack {
            if startDate != nil {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = startDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                        engine.update(elapsed: elapsed, size: size)

                        if engine.isFinished {
                            DispatchQueue.main.async {
                                startDate = nil
                            }
                            return
                        }

                        for particle in engine.particles where particle.opacity > 0 {
                            var pContext = context
                            pContext.opacity = particle.opacity
                            pContext.translateBy(
                                x: particle.x * size.width,
                                y: particle.y * size.height
                            )
                            pContext.rotate(by: .degrees(particle.rotation))

                            let dim = 8 * particle.scale
                            let shapePath = Path(ellipseIn: CGRect(
                                x: -dim / 2,
                                y: -dim / 2,
                                width: dim,
                                height: dim
                            ))
                            pContext.fill(shapePath, with: .color(particle.color))
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .onAppear {
            engine.emit(count: 50, baseColor: color)
            startDate = Date()
        }
    }
}

// MARK: - Explosion Engine (Canvas-powered)

/// Motor de explosión de partículas de alto rendimiento.
/// NO usar @Observable - TimelineView ya fuerza el redibujado por frame,
/// y la observación causaría re-evaluaciones innecesarias del body (~60/seg).
final class ExplosionEngine {
    struct Particle {
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var scale: Double
        var color: Color
        var rotation: Double
        var rotationSpeed: Double
        var opacity: Double
    }

    private(set) var particles: [Particle] = []
    private(set) var isFinished = false
    private var lastElapsed: Double = 0
    private let lifetime: Double = 2.0
    private let maxParticles = 50

    func emit(count: Int, baseColor: Color) {
        particles.removeAll()
        isFinished = false
        lastElapsed = 0
        let cappedCount = min(count, maxParticles)
        particles.reserveCapacity(cappedCount)

        let colors: [Color] = [baseColor, .white, .yellow, baseColor.opacity(0.5)]

        for i in 0..<cappedCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 0.2...0.8)
            particles.append(Particle(
                x: 0.5,
                y: 0.5,
                vx: cos(angle) * speed * 0.02,
                vy: sin(angle) * speed * 0.02 - 0.035,
                scale: Double.random(in: 0.5...1.5),
                color: colors[i % colors.count],
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -5...5),
                opacity: 1.0
            ))
        }
    }

    func stop() {
        particles.removeAll()
        isFinished = true
    }

    func update(elapsed: Double, size: CGSize) {
        let dt = min(elapsed - lastElapsed, 1.0 / 30.0)
        lastElapsed = elapsed

        guard elapsed < lifetime else {
            if !isFinished {
                particles.removeAll()
                isFinished = true
            }
            return
        }

        let dtNorm = dt * 60.0 // Normalize to ~60fps baseline

        for i in particles.indices {
            guard particles[i].opacity > 0 else { continue }

            // Physics (dt-scaled for frame-rate independence)
            particles[i].vy += 0.0015 * dtNorm
            particles[i].x += particles[i].vx * dtNorm
            particles[i].y += particles[i].vy * dtNorm
            particles[i].rotation += particles[i].rotationSpeed * dtNorm
            particles[i].vx *= pow(0.98, dtNorm)
            particles[i].vy *= pow(0.98, dtNorm)

            // Fade out based on vertical position (falling particles disappear)
            particles[i].opacity = max(0, 1 - (particles[i].y * 1.2))
        }

        // Cleanup dead particles
        if elapsed > lifetime * 0.7 {
            particles.removeAll(where: { $0.opacity <= 0 })
            if particles.isEmpty {
                isFinished = true
            }
        }
    }
}
