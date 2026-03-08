import Testing
@testable import NovaEducation

@Suite("Render Pipeline Tests")
struct RenderTests {

    @Test("Router Positive Tests (should detect render intent)")
    func routerPositiveTests() {
        let cases: [(String, String)] = [
            ("Muéstrame un átomo", "muestrame"),
            ("Muéstreme una pirámide", "muestreme"),
            ("Muestra una esfera", "muestra"),
            ("Enséñame un cubo", "ensename"),
            ("Enséñeme un cilindro", "enseneme"),
            ("Dibújame una pirámide", "dibujame"),
            ("Dibújeme una estrella", "dibujeme"),
            ("Dibuja un triángulo", "dibuja"),
            ("Píntame una pirámide amarilla", "pintame"),
            ("Pínteme un cubo rojo", "pinteme"),
            ("Pinta una esfera azul", "pinta"),
            ("Genera una imagen de un volcán", "genera"),
            ("Genera un modelo del sistema solar", "genera modelo"),
            ("Crea un átomo", "crea"),
            ("Créame una molécula", "creame"),
            ("Renderiza un cono", "renderiza"),
            ("Visualiza una pirámide", "visualiza"),
            ("Haz un cubo", "haz"),
            ("Hazme una esfera", "hazme"),
            ("Construye un cilindro", "construye"),
            ("Quiero ver un átomo", "quiero ver"),
            ("Quiero verlo en 3D", "quiero verlo"),
            ("Quiero verla girar", "quiero verla"),
            ("Déjame ver una pirámide", "dejame ver"),
            ("Déjame verlo", "dejame verlo"),
            ("¿Puedo ver un cubo?", "puedo ver"),
            ("¿Podrías mostrar un volcán?", "podrias mostrar"),
            ("Dame una imagen de una flor", "dame una imagen"),
            ("Dame un dibujo del corazón", "dame un dibujo"),
            ("Dame un modelo del ADN", "dame un modelo"),
            ("¿Cómo se ve un átomo?", "como se ve"),
            ("¿Cómo luce una célula?", "como luce"),
            ("Necesito ver una molécula", "necesito ver"),
            ("Me gustaría ver una pirámide", "me gustaria ver"),
            ("Pon una imagen del sol", "pon una imagen"),
            ("Genera imagen de la luna", "genera imagen"),
            ("Crear imagen de saturno", "crear imagen"),
            ("Imagen de un volcán", "imagen de"),
            ("Dibujo de una flor", "dibujo de"),
            ("Modelo de un átomo", "modelo de"),
            ("Muéstrame un cubo en 3D", "en 3d"),
            ("Quiero ver un átomo en tres dimensiones", "tres dimensiones"),
            ("Haz un objeto 3D de una pirámide", "objeto 3d"),
            ("Genera un modelo 3D", "modelo 3d"),
            ("Muéstrame una figura 3D", "figura 3d"),
            ("Muéstrame una pirámide", "piramide"),
            ("Quiero ver un cubo", "cubo"),
            ("Dibuja una esfera", "esfera"),
            ("Haz un cono", "cono"),
            ("Crea un cilindro", "cilindro"),
            ("Muéstrame un toroide", "toroide"),
            ("Hazme una dona", "dona"),
            ("Genera una cápsula", "capsula"),
            ("Muéstrame un átomo", "atomo"),
            ("Enséñame una molécula", "molecula"),
            ("Quiero ver la molécula de agua", "agua"),
            ("Dibuja una célula", "celula"),
            ("Muéstrame el ADN", "adn"),
            ("Haz un corazón", "corazon"),
            ("Muéstrame un pulmón", "pulmon"),
            ("Genera un ojo", "ojo"),
            ("Crea un cerebro", "cerebro"),
            ("Dibuja una flor", "flor"),
            ("Muéstrame un árbol", "arbol"),
            ("Haz una hoja", "hoja"),
            ("Muéstrame un volcán", "volcan"),
            ("Crea una montaña", "montana"),
            ("Muéstrame un péndulo", "pendulo"),
            ("Hazme un imán", "iman"),
            ("Genera una onda", "onda"),
            ("Muéstrame un cristal", "cristal"),
            ("Quiero ver un microscopio", "microscopio"),
            ("Enséñame un telescopio", "telescopio"),
            ("Dibuja una brújula", "brujula"),
            ("Hazme un prisma", "prisma"),
            ("Genera un agujero negro", "agujero negro"),
            ("Muéstrame un cohete", "cohete"),
            ("Crea un fósil", "fosil"),
            ("Dibuja una batería", "bateria"),
            ("Pirámide amarilla", "piramide amarilla"),
            ("Cubo rojo", "cubo rojo"),
            ("Esfera azul", "esfera azul"),
            ("Cono verde", "cono verde"),
            ("Cilindro naranja", "cilindro naranja"),
            ("Muéstrame la Tierra", "tierra"),
            ("Quiero ver Marte", "marte"),
            ("Haz Saturno", "saturno"),
            ("Muéstrame Júpiter", "jupiter"),
            ("Genera la Luna", "luna"),
            ("Crea el Sol", "sol"),
            ("Muéstrame una estrella", "estrella"),
            ("Quiero ver el sistema solar", "sistema solar"),
            ("Oye, muéstrame un átomo", "informal oye"),
            ("Hey, hazme una pirámide", "informal hey"),
            ("Por fa muéstrame un cubo", "informal porfa"),
            ("Me puedes mostrar una esfera?", "question form"),
            ("A ver, dibuja un cono", "a ver"),
            ("Pon un volcán ahí", "pon"),
            ("Pásame una imagen del sol", "pasame"),
            ("Muéstrame el sistema solar", "sistema solar"),
            ("Quiero ver la tabla periódica", "tabla periodica"),
            ("Dibuja la molécula de agua", "molecula de agua"),
            ("Muéstrame un enlace químico", "enlace quimico"),
            ("Haz una reacción química", "reaccion quimica"),
            ("Muéstrame una pirámide amarilla en 3D", "compound"),
            ("Quiero ver un cubo rojo grande", "compound size"),
            ("Dibújame una esfera azul que gire", "compound anim"),
            ("Genera una imagen del sistema solar", "compound image"),
            ("Podrías dibujarme un átomo", "conditional"),
            ("¿Me muestras un cubo?", "question"),
            ("Necesito que me dibujes una pirámide", "subjunctive"),
            ("Quisiera ver una molécula", "quisiera"),
            ("Muestrame un atomo", "no accents"),
            ("Enseneme una piramide", "no accents 2"),
            ("Pintame una piramide amarilla", "no accents 3"),
            ("Muéstrame una bacteria", "bacteria"),
            ("Quiero ver un virus", "virus"),
            ("Dibuja un dinosaurio", "dinosaurio"),
            ("Muéstrame un esqueleto", "esqueleto"),
            ("Genera un tornado", "tornado"),
            ("Muéstrame un arcoíris", "arcoiris"),
            ("Haz un circuito", "circuito"),
            ("Muéstrame la fotosíntesis", "fotosintesis"),
            ("¿Cómo es un átomo?", "como es"),
            ("MUÉSTRAME UN ÁTOMO", "uppercase"),
            ("   muéstrame un cubo   ", "whitespace"),
            ("muéstrame...un átomo!", "punctuation"),
        ]

        for (input, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.hasRenderIntent, "[\(tag)] '\(input)' → expected render intent detected")
        }
    }

    @Test("Router Negative Tests (should NOT detect render intent)")
    func routerNegativeTests() {
        let cases: [(String, String)] = [
            ("¿Qué es un átomo?", "what is"),
            ("Explícame qué es una molécula", "explain"),
            ("¿Cuántos electrones tiene el carbono?", "how many"),
            ("Define célula", "define"),
            ("¿Para qué sirve el ADN?", "what for"),
            ("Cuéntame sobre los volcanes", "tell me about"),
            ("¿Cuál es la fórmula del agua?", "formula"),
            ("Resuelve esta ecuación: x² + 5x + 6 = 0", "solve"),
            ("¿Qué significa fotosíntesis?", "meaning"),
            ("Hola, ¿cómo estás?", "greeting"),
            ("Buenos días Nova", "greeting 2"),
            ("Gracias por tu ayuda", "thanks"),
            ("¿Me puedes ayudar con matemáticas?", "help request"),
            ("No entiendo este tema", "confusion"),
            ("¿Puedes repetir?", "repeat"),
            ("Hazme un quiz de ciencias", "quiz request"),
            ("¿Cuánto es 2 + 2?", "math"),
            ("Traduce 'hello' al español", "translate"),
            ("¿Quién fue Simón Bolívar?", "history"),
            ("¿Cómo se dice 'dog' en español?", "vocabulary"),
            ("Dame una pista", "hint"),
            ("Explica paso a paso", "step by step"),
            ("¿Cuál es la respuesta correcta?", "answer"),
            ("Haz un resumen del tema", "summary"),
            ("¿Qué opinas sobre la ética?", "opinion"),
        ]

        for (input, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(!result.hasRenderIntent, "[\(tag)] '\(input)' → should NOT have render intent (\(result.intent))")
        }
    }

    @Test("Negation Tests (should NOT detect render intent)")
    func negationTests() {
        let cases: [(String, String)] = [
            ("No me muestres nada", "no me muestres"),
            ("No muestres un cubo", "no muestres"),
            ("No me enseñes nada", "no me ensenes"),
            ("No dibujes una pirámide", "no dibujes"),
            ("No pintes una esfera", "no pintes"),
            ("No generes una imagen", "no generes"),
            ("No crees un modelo", "no crees"),
            ("No quiero ver un cubo", "no quiero ver"),
            ("No necesito ver un átomo", "no necesito ver"),
            ("Sin imagen por favor", "sin imagen"),
            ("No hace falta mostrar nada", "no hace falta"),
            ("No es necesario generar nada", "no es necesario"),
            ("No me hagas una pirámide", "no me hagas"),
            ("No renderices nada", "no renderices"),
            ("No visualices un modelo", "no visualices"),
            ("No quiero ver un cubo rojo", "negation + color + shape"),
            ("No me muestres el átomo", "negation + concept"),
        ]

        for (input, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(!result.hasRenderIntent, "[\(tag)] '\(input)' → should be negated")
        }
    }

    @Test("Repeat Tests (should trigger modification/repeat)")
    func repeatTests() {
        let cases: [(String, String)] = [
            ("Otra vez", "otra vez"),
            ("De nuevo", "de nuevo"),
            ("Lo mismo", "lo mismo"),
            ("Repítelo", "repitelo"),
            ("Vuelve a mostrarlo", "vuelve a"),
            ("Hazlo otra vez", "hazlo otra vez"),
            ("Muéstramelo de nuevo", "muestramelo de nuevo"),
            ("Otra vez lo mismo", "otra vez lo mismo"),
            ("Lo mismo otra vez", "lo mismo otra vez"),
            ("De nuevo lo mismo", "de nuevo lo mismo"),
            ("Repite lo mismo", "repite lo mismo"),
            ("Lo mismo pero en verde", "repeat + color"),
            ("De nuevo pero más grande", "repeat + size"),
        ]

        for (input, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.isModification, "[\(tag)] '\(input)' → isModification expected to be true")
        }
    }

    @Test("New Verb Tests (added verbs should trigger render)")
    func newVerbTests() {
        let cases: [(String, String)] = [
            ("Ponme una pirámide amarilla", "ponme"),
            ("Ponle una esfera azul", "ponle"),
            ("Pon un cubo rojo", "pon"),
            ("Ármame un cubo", "armame"),
            ("Arma una pirámide", "arma"),
            ("Fórmame una esfera", "formame"),
            ("Forma un cilindro", "forma"),
            ("Hágame un cono", "hagame"),
            ("Genérame un átomo", "generame"),
            ("Represéntame el ADN", "representame"),
            ("Representa una molécula", "representa"),
            ("Diséñame un modelo del sol", "disenme"),
            ("Diseña una pirámide", "disena"),
            ("Constrúyeme una esfera", "construyeme"),
            ("Me armas un cubo rojo?", "informal armame"),
            ("Un volcán en 3D por favor", "implicit render + concept"),
            ("Hazme un modelo del sistema solar", "hazme modelo"),
        ]

        for (input, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.hasRenderIntent, "[\(tag)] '\(input)' → expected render intent")
        }
    }

    @Test("Router Mode Tests (2D vs 3D detection)")
    func routerModeTests() {
        let cases: [(String, RenderIntent, String)] = [
            ("Muéstrame un cubo en 3D", .render3D, "explicit 3d"),
            ("Quiero ver una pirámide en tres dimensiones", .render3D, "tres dimensiones"),
            ("Hazme un modelo 3D del átomo", .render3D, "modelo 3d"),
            ("Muéstrame una esfera que gire", .render3D, "girar"),
            ("Quiero rotarlo", .render3D, "rotar"),
            ("Muéstrame una pirámide", .render3D, "geometry default"),
            ("Haz un cubo", .render3D, "geometry default 2"),
            ("Dibújame una imagen del volcán", .render2D, "imagen"),
            ("Dame un diagrama del corazón", .render2D, "diagrama"),
            ("Píntame una ilustración de una flor", .render2D, "ilustracion"),
            ("Genera un esquema del circuito", .render2D, "esquema"),
            ("Hazme un dibujo del sistema solar", .render2D, "dibujo"),
            ("Muéstrame un átomo", .render3D, "ambiguous concept → 3D"),
        ]

        for (input, expectedIntent, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.hasRenderIntent, "[\(tag)] '\(input)' → expected render intent")
            #expect(result.intent == expectedIntent, "[\(tag)] '\(input)' → expected \(expectedIntent), got \(result.intent)")
        }
    }

    @Test("Color Detection Tests")
    func colorDetectionTests() {
        let cases: [(String, RenderColor, String)] = [
            ("pirámide amarilla", .yellow, "amarilla"),
            ("cubo rojo", .red, "rojo"),
            ("esfera azul", .blue, "azul"),
            ("cono verde", .green, "verde"),
            ("cilindro naranja", .orange, "naranja"),
            ("pirámide morada", .purple, "morada"),
            ("esfera rosa", .pink, "rosa"),
            ("cubo blanco", .white, "blanco"),
            ("pirámide negra", .black, "negra"),
            ("esfera gris", .gray, "gris"),
            ("cubo marrón", .brown, "marron"),
            ("pirámide dorada", .gold, "dorada"),
            ("esfera plateada", .silver, "plateada"),
            ("cono café", .brown, "cafe"),
            ("cilindro celeste", .cyan, "celeste"),
        ]

        for (input, expectedColor, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.detectedColor == expectedColor, "[\(tag)] '\(input)' → expected \(expectedColor), got \(String(describing: result.detectedColor))")
        }
    }

    @Test("Primitive Detection Tests")
    func primitiveDetectionTests() {
        let cases: [(String, RenderPrimitive, String)] = [
            ("muéstrame una pirámide", .pyramid, "piramide"),
            ("haz un cubo", .cube, "cubo"),
            ("crea una esfera", .sphere, "esfera"),
            ("genera un cono", .cone, "cono"),
            ("muéstrame un cilindro", .cylinder, "cilindro"),
            ("haz un toroide", .torus, "toroide"),
            ("crea una dona", .torus, "dona"),
            ("muéstrame una cápsula", .capsule, "capsula"),
            ("haz una pelota", .sphere, "pelota"),
            ("crea un dado", .cube, "dado"),
            ("muéstrame un globo", .sphere, "globo"),
            ("genera un tubo", .cylinder, "tubo"),
            ("haz un triángulo", .pyramid, "triangulo"),
        ]

        for (input, expectedPrimitive, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.detectedPrimitive == expectedPrimitive, "[\(tag)] '\(input)' → expected \(expectedPrimitive), got \(String(describing: result.detectedPrimitive))")
        }
    }

    @Test("Concept Catalog Tests")
    func conceptCatalogTests() {
        let cases: [(String, Bool, String)] = [
            ("átomo", true, "atomo"),
            ("molécula", true, "molecula"),
            ("molécula de agua", true, "agua"),
            ("H2O", true, "h2o"),
            ("célula", true, "celula"),
            ("ADN", true, "adn"),
            ("sistema solar", true, "sistema solar"),
            ("pirámide", true, "piramide"),
            ("volcán", true, "volcan"),
            ("corazón", true, "corazon"),
            ("cerebro", true, "cerebro"),
            ("flor", true, "flor"),
            ("Tierra", true, "tierra"),
            ("Saturno", true, "saturno"),
            ("estrella", true, "estrella"),
            ("cristal", true, "cristal"),
            ("imán", true, "iman"),
            ("péndulo", true, "pendulo"),
            ("la molécula del agua", true, "synonym"),
            ("los planetas", true, "planets synonym"),
            ("el átomo", true, "el atomo synonym"),
            ("pelota", true, "pelota synonym"),
            ("microscopio", true, "microscopio"),
            ("telescopio", true, "telescopio"),
            ("brújula", true, "brujula"),
            ("prisma", true, "prisma"),
            ("agujero negro", true, "agujero negro"),
            ("cohete", true, "cohete"),
            ("fósil", true, "fosil"),
            ("batería", true, "bateria"),
            ("computadora", false, "not in catalog"),
            ("algoritmo", false, "not in catalog 2"),
            ("democracia", false, "not in catalog 3"),
        ]

        for (input, shouldMatch, tag) in cases {
            let hasMatch = ConceptCatalog.hasMatch(input)
            #expect(hasMatch == shouldMatch, "[\(tag)] '\(input)' → match was \(hasMatch), expected \(shouldMatch)")
        }
    }

    @Test("Modification Tests")
    func modificationTests() {
        let cases: [(String, Bool, String)] = [
            ("hazlo más grande", true, "bigger"),
            ("hazla más grande", true, "bigger f"),
            ("más grande", true, "bigger short"),
            ("hazlo más pequeño", true, "smaller"),
            ("más chico", true, "smaller chico"),
            ("cámbialo a rojo", true, "color change"),
            ("ponlo en azul", true, "color change blue"),
            ("que sea verde", true, "color change green"),
            ("gíralo", true, "rotate"),
            ("que gire", true, "rotate gire"),
            ("muéstrame un cubo", false, "new render"),
            ("¿qué es un átomo?", false, "question"),
        ]

        for (input, shouldBeModification, tag) in cases {
            let result = RenderIntentRouter.detect(input)
            #expect(result.isModification == shouldBeModification, "[\(tag)] '\(input)' → isModif=\(result.isModification), expected \(shouldBeModification)")
        }
    }

    @Test("Validation Tests")
    func validationTests() {
        let fallback = RenderRequest.fallback
        #expect(fallback.resolvedPrimitive == .cube && fallback.color == .blue, "Fallback request has unexpected defaults")

        let fallbackOutput = RenderOutput.fallback
        #expect(fallbackOutput.attachmentData != nil && !fallbackOutput.spokenSummary.isEmpty, "Fallback output missing data")

        let summary = fallbackOutput.spokenSummary
        #expect(summary.count <= 120, "Fallback spoken summary exceeds 120 chars: \(summary.count)")
    }

    @Test("Fallback Tests")
    func fallbackTests() {
        let positiveCases: [String] = [
            "Muéstrame un átomo",
            "Dibuja una pirámide amarilla",
            "Quiero ver un cubo rojo en 3D",
            "Genera una esfera azul",
            "Muéstrame el sistema solar",
            "Haz una molécula",
            "Pintame un volcán",
            "Crea un corazón",
        ]

        for input in positiveCases {
            let result = RenderIntentRouter.detect(input)
            let hasCatalog = ConceptCatalog.hasMatch(input)
            let hasPrimitive = result.detectedPrimitive != nil

            #expect(hasCatalog || hasPrimitive || result.hasRenderIntent, "'\(input)' → no resolution path available")
        }
    }
}
