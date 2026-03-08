import Testing
@testable import NovaEducation

@Suite("Interceptor Pipeline Tests")
struct InterceptorTests {

    @Test("Math Detection Tests")
    func mathDetectionTests() {
        let solver = MathSolver()
        let positives: [(String, Subject)] = [
            ("2+2", .math),
            ("cuanto es 5*3", .math),
            ("√144", .math),
            ("raiz cuadrada de 25", .math),
            ("5^3", .math),
            ("5 al cuadrado", .math),
            ("3!", .math),
            ("factorial de 5", .math),
            ("20% de 150", .math),
            ("x²+5x+6=0", .math),
            ("calcula 10/2", .math),
            ("resuelve 8*7", .math),
            ("cuanto da 15-3", .math),
            ("valor de pi", .math),
            ("100+200+300", .math),
            ("simplifica 4/8", .math),
            ("7 elevado a 2", .math),
            ("raiz cubica de 27", .math),
            ("10 por ciento de 500", .math),
            ("calculame 99*99", .math),
            ("cuanto vale pi", .open),
            ("2+3", .open),
            ("√(64)", .physics),
        ]

        for (text, subject) in positives {
            #expect(solver.detect(text, subject: subject), "Should detect: \"\(text)\" [\(subject)]")
        }
    }

    @Test("Math Solve Tests")
    func mathSolveTests() async {
        let solver = MathSolver()
        let cases: [(String, Subject, String)] = [
            ("2+3", .math, "5"),
            ("10*5", .math, "50"),
            ("100/4", .math, "25"),
            ("√144", .math, "12"),
            ("raiz cuadrada de 25", .math, "5"),
            ("5^3", .math, "125"),
            ("5 al cuadrado", .math, "25"),
            ("3!", .math, "6"),
            ("factorial de 5", .math, "120"),
            ("20% de 200", .math, "40"),
            ("valor de pi", .math, "3.14159"),
        ]

        for (text, subject, expected) in cases {
            let result = await solver.solve(text, subject: subject)
            #expect(result.answer.contains(expected) && result.category != .passthrough, "Solve \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
        }
    }

    @Test("Math Negative Tests")
    func mathNegativeTests() {
        let solver = MathSolver()
        let negatives: [(String, Subject)] = [
            ("hola como estas", .math),
            ("explicame que son las fracciones", .math),
            ("que es una integral", .math),
            ("historia de pitagoras", .math),
            ("me gusta la matematica", .math),
            ("ayudame con mi tarea", .math),
            ("que es un polinomio", .math),
        ]

        for (text, subject) in negatives {
            #expect(!solver.detect(text, subject: subject), "Should NOT detect: \"\(text)\"")
        }
    }

    @Test("Physics Constant Tests")
    func physicsConstantTests() async {
        let solver = PhysicsSolver()
        let cases: [(String, String)] = [
            ("velocidad de la luz", "299"),
            ("constante de gravedad", "9.8"),
            ("constante de planck", "6.626"),
            ("numero de avogadro", "6.022"),
            ("constante de boltzmann", "1.381"),
            ("carga del electron", "1.602"),
            ("presion atmosferica", "101"),
            ("velocidad del sonido", "343"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .physics), "Should detect constant: \"\(text)\"")
            if solver.detect(text, subject: .physics) {
                let result = await solver.solve(text, subject: .physics)
                #expect(result.answer.contains(expected), "Constant \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Physics Formula Tests")
    func physicsFormulaTests() async {
        let solver = PhysicsSolver()
        let cases: [(String, String)] = [
            ("F si m=10 y a=5", "50"),
            ("fuerza si masa=10kg y aceleracion=5", "50"),
            ("velocidad si distancia=100 y tiempo=10", "10"),
            ("convierte 100 fahrenheit a celsius", "37"),
            ("convierte 0 celsius a fahrenheit", "32"),
            ("convierte 100 celsius a kelvin", "373"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .physics), "Should detect formula: \"\(text)\"")
            if solver.detect(text, subject: .physics) {
                let result = await solver.solve(text, subject: .physics)
                #expect(result.answer.contains(expected), "Formula \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Physics Conversion Tests")
    func physicsConversionTests() async {
        let solver = PhysicsSolver()
        let cases: [(String, String)] = [
            ("convierte 5 km a metros", "5000"),
            ("convierte 1000 gramos a kg", "1"),
            ("convierte 1 hora a segundos", "3600"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .physics), "Should detect conversion: \"\(text)\"")
            if solver.detect(text, subject: .physics) {
                let result = await solver.solve(text, subject: .physics)
                #expect(result.answer.contains(expected), "Conversion \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Chemistry Element Tests")
    func chemistryElementTests() async {
        let solver = ChemistrySolver()
        let cases: [(String, String)] = [
            ("que es el carbono", "Carbono"),
            ("propiedades del hierro", "Hierro"),
            ("elemento Fe", "Hierro"),
            ("elemento numero 79", "Oro"),
            ("elemento Au", "Oro"),
            ("que es el hidrogeno", "Hidrógeno"),
            ("elemento numero 1", "Hidrógeno"),
            ("dime sobre el oxigeno", "Oxígeno"),
            ("informacion del sodio", "Sodio"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .chemistry), "Should detect element: \"\(text)\"")
            if solver.detect(text, subject: .chemistry) {
                let result = await solver.solve(text, subject: .chemistry)
                #expect(result.answer.contains(expected), "Element \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Chemistry Molar Mass Tests")
    func chemistryMolarMassTests() async {
        let solver = ChemistrySolver()
        let cases: [(String, String)] = [
            ("masa molar del H2O", "18"),
            ("masa molar del NaCl", "58"),
            ("peso molecular del CO2", "44"),
            ("masa molar de H2SO4", "98"),
            ("masa molar del O2", "32"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .chemistry), "Should detect molar mass: \"\(text)\"")
            if solver.detect(text, subject: .chemistry) {
                let result = await solver.solve(text, subject: .chemistry)
                #expect(result.answer.contains(expected), "Molar mass \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Grammar Conjugation Tests")
    func grammarConjugationTests() async {
        let solver = SpanishGrammarSolver()
        let cases: [(String, String)] = [
            ("conjuga el verbo ser en presente", "soy"),
            ("conjuga hablar en preterito", "hablé"),
            ("conjugacion de ir en futuro", "iré"),
            ("conjuga tener en presente", "tengo"),
            ("conjuga hacer en preterito", "hice"),
            ("conjuga poder en condicional", "podría"),
            ("conjugame el verbo estar en presente", "estoy"),
            ("conjuga comer en presente", "como"),
            ("conjuga vivir en presente", "vivo"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .language), "Should detect conjugation: \"\(text)\"")
            if solver.detect(text, subject: .language) {
                let result = await solver.solve(text, subject: .language)
                #expect(result.answer.lowercased().contains(expected.lowercased()), "Conjugation \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Grammar Rule Tests")
    func grammarRuleTests() async {
        let solver = SpanishGrammarSolver()
        let cases: [(String, String)] = [
            ("cuando se usa b o v", "b"),
            ("regla de acentuacion", "acent"),
            ("cuando se usa la h", "h"),
            ("regla de mayusculas", "mayúscula"),
            ("cuando se usa g o j", "g"),
        ]

        for (text, expected) in cases {
            #expect(solver.detect(text, subject: .language), "Should detect rule: \"\(text)\"")
            if solver.detect(text, subject: .language) {
                let result = await solver.solve(text, subject: .language)
                #expect(result.answer.lowercased().contains(expected.lowercased()), "Rule \"\(text)\": expected \"\(expected)\" in \"\(result.answer)\"")
            }
        }
    }

    @Test("Router Integration Tests")
    func routerIntegrationTests() {
        let mathCases: [(String, Subject)] = [
            ("2+2", .math),
            ("√144", .math),
            ("valor de pi", .math),
        ]
        for (text, subject) in mathCases {
            #expect(SubjectIntentRouter.detect(text, subject: subject) != nil, "Router should match: \"\(text)\" [\(subject)]")
        }

        let physicsCases: [(String, Subject)] = [
            ("velocidad de la luz", .physics),
            ("F si m=10 y a=5", .physics),
        ]
        for (text, subject) in physicsCases {
            #expect(SubjectIntentRouter.detect(text, subject: subject) != nil, "Router should match: \"\(text)\" [\(subject)]")
        }

        let chemCases: [(String, Subject)] = [
            ("que es el carbono", .chemistry),
            ("masa molar del H2O", .chemistry),
        ]
        for (text, subject) in chemCases {
            #expect(SubjectIntentRouter.detect(text, subject: subject) != nil, "Router should match: \"\(text)\" [\(subject)]")
        }

        let langCases: [(String, Subject)] = [
            ("conjuga el verbo ser en presente", .language),
            ("cuando se usa b o v", .language),
        ]
        for (text, subject) in langCases {
            #expect(SubjectIntentRouter.detect(text, subject: subject) != nil, "Router should match: \"\(text)\" [\(subject)]")
        }

        let openCases: [(String, Subject)] = [
            ("2+2", .open),
            ("velocidad de la luz", .open),
            ("que es el carbono", .open),
            ("conjuga ser en presente", .open),
        ]
        for (text, subject) in openCases {
            #expect(SubjectIntentRouter.detect(text, subject: subject) != nil, "Router should match in .open: \"\(text)\"")
        }

        #expect(SubjectIntentRouter.detect("conjuga ser en presente", subject: .math) == nil, "Grammar should not match in .math subject")
        #expect(SubjectIntentRouter.detect("masa molar del H2O", subject: .language) == nil, "Chemistry should not match in .language subject")
    }

    @Test("Fallthrough (No Match) Tests")
    func fallthroughTests() {
        let noMatch: [(String, Subject)] = [
            ("hola como estas", .math),
            ("explicame la segunda guerra mundial", .social),
            ("que opinas de la justicia", .ethics),
            ("como hago un programa en python", .technology),
            ("cuentame un chiste", .open),
            ("me gusta esta app", .math),
            ("que es el amor", .ethics),
            ("como se dice hola en ingles", .english),
        ]

        for (text, subject) in noMatch {
            #expect(SubjectIntentRouter.detect(text, subject: subject) == nil, "Should NOT match: \"\(text)\" [\(subject)]")
        }
    }
}
