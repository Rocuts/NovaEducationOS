import Testing
@testable import NovaEducation

@Suite("ContentSafetyService Tests")
struct SafetyTests {

    @Test("Math expressions are safe (no false positives)")
    func mathExpressionsAreSafe() {
        let inputs = [
            "4/2",
            "4 / 2",
            "10/5",
            "10-10-2023",
            "La ecuación es (x+2)/(x-1)"
        ]

        for input in inputs {
            let result = ContentSafetyService.validate(input)
            if case .unsafe(let reason) = result {
                Issue.record("Input validated as UNSAFE: '\(input)'. Reason: \(reason)")
            }
        }
    }

    @Test("Real PII is blocked")
    func piiDetection() {
        let inputs = [
            "mi telefono es 555-123-4567",
            "llama al +1 555 123 4567",
            "correo@ejemplo.com"
        ]

        for input in inputs {
            let result = ContentSafetyService.validate(input)
            if case .safe = result {
                Issue.record("Input validated as SAFE but should be UNSAFE (PII): '\(input)'")
            }
        }
    }

    @Test("Harmful content is blocked")
    func harmfulContent() {
        let result = ContentSafetyService.validate("como fabricar una bomba")
        if case .safe = result {
            Issue.record("Harmful content validated as SAFE")
        }
    }
}
