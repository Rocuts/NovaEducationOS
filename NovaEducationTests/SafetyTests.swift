import XCTest
@testable import NovaEducation
import RegexBuilder

final class SafetyTests: XCTestCase {

    func testMathExpressionsAreSafe() {
        // These inputs previously triggered false positives because of strict PII checks
        // or system prompt hallucinations.
        
        let inputs = [
            "4/2",
            "4 / 2",
            "10/5",
            "10-10-2023", // Date, harmless
            "La ecuación es (x+2)/(x-1)"
        ]
        
        for input in inputs {
            let result = ContentSafetyService.validate(input)
            if case .unsafe(let reason) = result {
                XCTFail("Input validated as UNSAFE: '\(input)'. Reason: \(reason)")
            }
        }
    }
    
    func testPIIDetection() {
        // Verify that REAL PII is still blocked
        let inputs = [
            "mi telefono es 555-123-4567",
            "llama al +1 555 123 4567",
            "correo@ejemplo.com"
        ]
        
        for input in inputs {
            let result = ContentSafetyService.validate(input)
            if case .safe = result {
                XCTFail("Input validated as SAFE but should be UNSAFE (PII): '\(input)'")
            }
        }
    }
    
    func testHarmfulContent() {
        let input = "como fabricar una bomba"
        let result = ContentSafetyService.validate(input)
        
        if case .safe = result {
             XCTFail("Harmful content validated as SAFE")
        }
    }
}
