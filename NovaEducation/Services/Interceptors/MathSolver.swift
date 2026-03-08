import Foundation

// MARK: - MathSolver
// Deterministic math interceptor: arithmetic, roots, powers, factorials,
// percentages, quadratic equations. Apple explicitly says "avoid math operations
// — use non-AI code" for Foundation Models.

struct MathSolver: SubjectInterceptor, Sendable {

    let interceptorId = "math_solver"
    let supportedSubjects: Set<Subject> = [.math, .physics, .chemistry, .open]

    // MARK: - Detection

    func detect(_ text: String, subject: Subject) -> Bool {
        let normalized = normalize(text)

        // Check for math trigger verbs in Spanish
        let hasMathVerb = Self.mathVerbs.contains { normalized.contains($0) }

        // Check for arithmetic expression pattern
        let hasExpression = Self.expressionPattern.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil

        // Check for root symbol or keyword
        let hasRoot = normalized.contains("√") || normalized.contains("raiz")

        // Check for power/exponent
        let hasPower = normalized.contains("^") || normalized.contains("elevado") || normalized.contains("al cuadrado") || normalized.contains("al cubo")

        // Check for factorial
        let hasFactorial = Self.factorialPattern.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil

        // Check for percentage
        let hasPercentage = normalized.contains("%") || normalized.contains("por ciento") || normalized.contains("porcentaje")

        // Check for quadratic equation keywords
        let hasQuadratic = (normalized.contains("x²") || normalized.contains("x^2") || normalized.contains("ecuacion cuadratica") || normalized.contains("formula general"))
            && (normalized.contains("x") || normalized.contains("resuelve"))

        // Check for fraction
        let hasFraction = Self.fractionPattern.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil

        // Check for constants
        let hasConstant = normalized.contains("valor de pi") || normalized.contains("valor de e")
            || normalized == "pi" || normalized == "π"

        return hasMathVerb || hasExpression || hasRoot || hasPower || hasFactorial
            || hasPercentage || hasQuadratic || hasFraction || hasConstant
    }

    // MARK: - Solve

    func solve(_ text: String, subject: Subject) async -> InterceptorResult {
        let normalized = normalize(text)

        // 1. Constants
        if let result = solveConstant(normalized) { return result }

        // 2. Quadratic equations
        if let result = solveQuadratic(normalized) { return result }

        // 3. Square/cube roots
        if let result = solveRoot(normalized) { return result }

        // 4. Powers
        if let result = solvePower(normalized) { return result }

        // 5. Factorial
        if let result = solveFactorial(normalized) { return result }

        // 6. Percentage
        if let result = solvePercentage(normalized) { return result }

        // 7. Fraction
        if let result = solveFraction(normalized) { return result }

        // 8. Arithmetic expression (last — broadest matcher)
        if let result = solveArithmetic(normalized) { return result }

        return .passthrough(text)
    }

    // MARK: - Constants

    private func solveConstant(_ text: String) -> InterceptorResult? {
        if text.contains("valor de pi") || text == "pi" || text == "π" || text.contains("cuanto vale pi") {
            return InterceptorResult(
                answer: "π = 3.14159265358979",
                teacherInstruction: "[RESULTADO: π ≈ 3.14159] Explica qué es pi, su relación con el círculo (C = 2πr) y por qué es irracional.",
                category: .catalogHit,
                attachmentType: "formula_result",
                attachmentData: """
                {"symbol":"π","value":"3.14159265358979","name":"Pi","description":"Razón entre circunferencia y diámetro"}
                """,
                confidence: 1.0
            )
        }

        if text.contains("valor de e") || text.contains("numero de euler") || text.contains("numero e") {
            return InterceptorResult(
                answer: "e = 2.71828182845905",
                teacherInstruction: "[RESULTADO: e ≈ 2.71828] Explica el número de Euler, su importancia en cálculo y crecimiento exponencial.",
                category: .catalogHit,
                attachmentType: "formula_result",
                attachmentData: """
                {"symbol":"e","value":"2.71828182845905","name":"Número de Euler","description":"Base del logaritmo natural"}
                """,
                confidence: 1.0
            )
        }

        return nil
    }

    // MARK: - Quadratic Equations

    private func solveQuadratic(_ text: String) -> InterceptorResult? {
        // Try to extract ax² + bx + c = 0
        guard let (a, b, c) = extractQuadraticCoefficients(text) else { return nil }

        let discriminant = b * b - 4 * a * c

        if discriminant < 0 {
            let answer = "La ecuación \(formatCoeff(a))x² \(formatSign(b))x \(formatSign(c)) = 0 no tiene soluciones reales (discriminante = \(formatNumber(discriminant)) < 0)"
            return InterceptorResult(
                answer: answer,
                teacherInstruction: "[RESULTADO: \(answer)] Explica por qué el discriminante negativo significa que no hay raíces reales y qué implica geométricamente.",
                category: .computed,
                attachmentType: "formula_result",
                attachmentData: """
                {"equation":"\(formatCoeff(a))x² + \(formatNumber(b))x + \(formatNumber(c)) = 0","discriminant":\(formatNumber(discriminant)),"solutions":"none","type":"quadratic"}
                """,
                confidence: 1.0
            )
        }

        let sqrtD = sqrt(discriminant)
        let x1 = (-b + sqrtD) / (2 * a)
        let x2 = (-b - sqrtD) / (2 * a)

        let answer: String
        let solutions: String
        if discriminant == 0 {
            answer = "x = \(formatNumber(x1))"
            solutions = "\(formatNumber(x1))"
        } else {
            answer = "x₁ = \(formatNumber(x1)), x₂ = \(formatNumber(x2))"
            solutions = "\(formatNumber(x1)), \(formatNumber(x2))"
        }

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer)] Usando la fórmula general: x = (-b ± √(b²-4ac)) / 2a con a=\(formatNumber(a)), b=\(formatNumber(b)), c=\(formatNumber(c)). Discriminante = \(formatNumber(discriminant)). Explica el procedimiento paso a paso.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"equation":"\(formatCoeff(a))x² + \(formatNumber(b))x + \(formatNumber(c)) = 0","discriminant":\(formatNumber(discriminant)),"solutions":"\(solutions)","type":"quadratic"}
            """,
            confidence: 1.0
        )
    }

    private func extractQuadraticCoefficients(_ text: String) -> (Double, Double, Double)? {
        // Pattern: ax² + bx + c = 0 or ax^2 + bx + c = 0
        // Supports forms like: x²+5x+6=0, 2x²-3x+1=0, x^2+5x+6=0
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "x²", with: "x^2")

        // Match pattern like: (coeff)x^2(sign)(coeff)x(sign)(const)=0
        let pattern = #"(-?\d*\.?\d*)x\^2([+-]\d*\.?\d*)x([+-]\d+\.?\d*)=0"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) else {
            return nil
        }

        func extractGroup(_ i: Int) -> String {
            guard let range = Range(match.range(at: i), in: cleaned) else { return "" }
            return String(cleaned[range])
        }

        let aStr = extractGroup(1)
        let bStr = extractGroup(2)
        let cStr = extractGroup(3)

        let a = aStr.isEmpty || aStr == "+" ? 1.0 : (aStr == "-" ? -1.0 : (Double(aStr) ?? 1.0))
        let b = bStr.isEmpty || bStr == "+" ? 1.0 : (bStr == "-" ? -1.0 : (Double(bStr) ?? 0.0))
        let c = Double(cStr) ?? 0.0

        guard a != 0 else { return nil }
        return (a, b, c)
    }

    // MARK: - Roots

    private func solveRoot(_ text: String) -> InterceptorResult? {
        // √(N) or "raiz cuadrada de N" or "raiz cubica de N"
        let isCubic = text.contains("cubica") || text.contains("∛")

        // Extract the number
        var number: Double?

        // Pattern: √(N) or √N or ∛(N)
        let symbolPattern = #"[√∛]\(?(\d+\.?\d*)\)?"#
        if let regex = try? NSRegularExpression(pattern: symbolPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            number = Double(text[range])
        }

        // Pattern: "raiz cuadrada/cubica de N"
        if number == nil {
            let wordPattern = #"raiz (?:cuadrada|cubica) de (\d+\.?\d*)"#
            if let regex = try? NSRegularExpression(pattern: wordPattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                number = Double(text[range])
            }
        }

        guard let n = number, n >= 0 else { return nil }

        let result: Double
        let symbol: String
        let explanation: String

        if isCubic {
            result = cbrt(n)
            symbol = "∛\(formatNumber(n))"
            explanation = "\(formatNumber(result))³ = \(formatNumber(n))"
        } else {
            result = sqrt(n)
            symbol = "√\(formatNumber(n))"
            explanation = "\(formatNumber(result))² = \(formatNumber(n))"
        }

        let answer = "\(symbol) = \(formatNumber(result))"

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer)] Explica por qué \(explanation). Describe qué es una raíz \(isCubic ? "cúbica" : "cuadrada") y cómo se calcula.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"expression":"\(symbol)","result":"\(formatNumber(result))","type":"root"}
            """,
            confidence: 1.0
        )
    }

    // MARK: - Powers

    private func solvePower(_ text: String) -> InterceptorResult? {
        var base: Double?
        var exponent: Double?

        // Pattern: N^M or N elevado a M
        let caretPattern = #"(\d+\.?\d*)\s*\^\s*(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: caretPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let bRange = Range(match.range(at: 1), in: text),
           let eRange = Range(match.range(at: 2), in: text) {
            base = Double(text[bRange])
            exponent = Double(text[eRange])
        }

        // "N elevado a M" or "N a la M"
        if base == nil {
            let wordPattern = #"(\d+\.?\d*)\s*(?:elevado a(?: la)?|a la)\s*(\d+\.?\d*)"#
            if let regex = try? NSRegularExpression(pattern: wordPattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let bRange = Range(match.range(at: 1), in: text),
               let eRange = Range(match.range(at: 2), in: text) {
                base = Double(text[bRange])
                exponent = Double(text[eRange])
            }
        }

        // "N al cuadrado" or "N al cubo"
        if base == nil {
            let squarePattern = #"(\d+\.?\d*)\s*al cuadrado"#
            if let regex = try? NSRegularExpression(pattern: squarePattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let bRange = Range(match.range(at: 1), in: text) {
                base = Double(text[bRange])
                exponent = 2
            }
        }
        if base == nil {
            let cubePattern = #"(\d+\.?\d*)\s*al cubo"#
            if let regex = try? NSRegularExpression(pattern: cubePattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let bRange = Range(match.range(at: 1), in: text) {
                base = Double(text[bRange])
                exponent = 3
            }
        }

        guard let b = base, let e = exponent else { return nil }

        // Safety: avoid absurdly large results
        guard e <= 100, b <= 1_000_000 else { return nil }

        let result = pow(b, e)
        guard result.isFinite else { return nil }

        let answer = "\(formatNumber(b))^\(formatNumber(e)) = \(formatNumber(result))"

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer)] Explica qué significa elevar \(formatNumber(b)) a la potencia \(formatNumber(e)) y cómo se calcula paso a paso.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"base":\(formatNumber(b)),"exponent":\(formatNumber(e)),"result":"\(formatNumber(result))","type":"power"}
            """,
            confidence: 1.0
        )
    }

    // MARK: - Factorial

    private func solveFactorial(_ text: String) -> InterceptorResult? {
        // N! or "factorial de N"
        var n: Int?

        let bangPattern = #"(\d+)\s*!"#
        if let regex = try? NSRegularExpression(pattern: bangPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            n = Int(text[range])
        }

        if n == nil {
            let wordPattern = #"factorial de (\d+)"#
            if let regex = try? NSRegularExpression(pattern: wordPattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                n = Int(text[range])
            }
        }

        guard let num = n, num >= 0, num <= 20 else { return nil } // 20! fits in Int

        let result = factorial(num)
        let answer = "\(num)! = \(result)"

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer)] Explica qué es un factorial: \(num)! = \(num) × \(num - 1) × ... × 1. Describe sus aplicaciones en combinatoria.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"n":\(num),"result":"\(result)","type":"factorial"}
            """,
            confidence: 1.0
        )
    }

    private func factorial(_ n: Int) -> Int {
        guard n > 1 else { return 1 }
        return (2...n).reduce(1, *)
    }

    // MARK: - Percentage

    private func solvePercentage(_ text: String) -> InterceptorResult? {
        // "N% de M" or "cuanto es el N por ciento de M"
        let patterns: [String] = [
            #"(\d+\.?\d*)%\s*de\s*(\d+\.?\d*)"#,
            #"(\d+\.?\d*)\s*por ciento de\s*(\d+\.?\d*)"#,
            #"el\s*(\d+\.?\d*)\s*por ciento de\s*(\d+\.?\d*)"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let pRange = Range(match.range(at: 1), in: text),
               let vRange = Range(match.range(at: 2), in: text),
               let percent = Double(text[pRange]),
               let value = Double(text[vRange]) {

                let result = (percent / 100.0) * value
                let answer = "\(formatNumber(percent))% de \(formatNumber(value)) = \(formatNumber(result))"

                return InterceptorResult(
                    answer: answer,
                    teacherInstruction: "[RESULTADO: \(answer)] Explica cómo calcular porcentajes: multiplicas \(formatNumber(value)) × \(formatNumber(percent))/100 = \(formatNumber(result)).",
                    category: .computed,
                    attachmentType: "formula_result",
                    attachmentData: """
                    {"percent":\(formatNumber(percent)),"value":\(formatNumber(value)),"result":"\(formatNumber(result))","type":"percentage"}
                    """,
                    confidence: 1.0
                )
            }
        }

        return nil
    }

    // MARK: - Fractions

    private func solveFraction(_ text: String) -> InterceptorResult? {
        // "N/M" as fraction — must have context suggesting fraction, not division
        let fractionWords = ["fraccion", "simplifica", "simplificar", "reducir", "minimo"]
        guard fractionWords.contains(where: { text.contains($0) }) else { return nil }

        let pattern = #"(\d+)\s*/\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nRange = Range(match.range(at: 1), in: text),
              let dRange = Range(match.range(at: 2), in: text),
              let num = Int(text[nRange]),
              let den = Int(text[dRange]),
              den != 0 else { return nil }

        let g = gcd(abs(num), abs(den))
        let sNum = num / g
        let sDen = den / g

        let answer = "\(num)/\(den) = \(sNum)/\(sDen)"
        let decimal = Double(num) / Double(den)

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer) (≈ \(formatNumber(decimal)))] Explica cómo simplificar la fracción dividiendo numerador y denominador entre su MCD (\(g)).",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"numerator":\(num),"denominator":\(den),"simplified_num":\(sNum),"simplified_den":\(sDen),"gcd":\(g),"decimal":"\(formatNumber(decimal))","type":"fraction"}
            """,
            confidence: 0.9
        )
    }

    private func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }

    // MARK: - Arithmetic

    private func solveArithmetic(_ text: String) -> InterceptorResult? {
        // Extract arithmetic expression and evaluate with NSExpression
        guard let expression = extractArithmeticExpression(text) else { return nil }

        // Safety: only allow basic arithmetic characters
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        let exprChars = CharacterSet(charactersIn: expression)
        guard allowed.isSuperset(of: exprChars) else { return nil }

        // Evaluate using NSExpression
        let nsExpr = NSExpression(format: expression)
        guard let result = nsExpr.expressionValue(with: nil, context: nil) as? NSNumber else {
            return nil
        }

        let doubleResult = result.doubleValue
        guard doubleResult.isFinite else { return nil }

        let answer = "\(expression) = \(formatNumber(doubleResult))"

        return InterceptorResult(
            answer: answer,
            teacherInstruction: "[RESULTADO: \(answer)] Explica el cálculo paso a paso, mencionando el orden de operaciones si aplica.",
            category: .computed,
            attachmentType: "formula_result",
            attachmentData: """
            {"expression":"\(expression)","result":"\(formatNumber(doubleResult))","type":"arithmetic"}
            """,
            confidence: 0.9
        )
    }

    private func extractArithmeticExpression(_ text: String) -> String? {
        // Find a math expression like "2+3", "15*4", "(3+2)*5"
        let pattern = #"\(?-?\d+\.?\d*\)?\s*[+\-*/]\s*\(?-?\d+\.?\d*\)?(?:\s*[+\-*/]\s*\(?-?\d+\.?\d*\)?)*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }

        let expr = String(text[range]).trimmingCharacters(in: .whitespaces)
        // Must have at least one operator
        guard expr.contains(where: { "+-*/".contains($0) && $0 != expr.first }) else { return nil }
        return expr
    }

    // MARK: - Helpers

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "¡", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatNumber(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 1e15 {
            return String(format: "%.0f", n)
        }
        // Up to 4 decimal places, trimming trailing zeros
        let formatted = String(format: "%.4f", n)
        return formatted
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    private func formatCoeff(_ n: Double) -> String {
        if n == 1 { return "" }
        if n == -1 { return "-" }
        return formatNumber(n)
    }

    private func formatSign(_ n: Double) -> String {
        if n >= 0 { return "+ \(formatNumber(n))" }
        return "- \(formatNumber(abs(n)))"
    }

    // MARK: - Patterns

    private static let mathVerbs: [String] = [
        "calcula", "calcular", "calculame",
        "cuanto es", "cuanto da", "cuanto vale",
        "resuelve", "resolver", "resuelveme",
        "suma", "sumar", "resta", "restar",
        "multiplica", "multiplicar", "divide", "dividir",
        "evalua", "evaluar",
        "simplifica", "simplificar",
        "factoriza", "factorizar",
        "cual es el resultado",
        "cuanto es el resultado",
    ]

    private static let expressionPattern: NSRegularExpression = {
        // Matches patterns like 2+3, 15*4, etc.
        try! NSRegularExpression(pattern: #"\d+\.?\d*\s*[+\-*/]\s*\d+\.?\d*"#)
    }()

    private static let factorialPattern: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"\d+\s*!"#)
    }()

    private static let fractionPattern: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"\d+\s*/\s*\d+"#)
    }()
}
