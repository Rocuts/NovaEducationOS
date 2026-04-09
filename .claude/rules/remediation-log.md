# Plan de Remediación Técnica y Hardening

## Fase 1-3: Remediación (Feb 2026) - COMPLETADO

### Cambios aplicados
1. **Limpieza de imágenes**: normalización de `imageURLString` a `lastPathComponent` en `BackgroundSessionManager.swift`
2. **Primer mensaje del día**: conteo incluye `sourceRaw == "message"` o `"first_of_day"` en `ChatViewModel.swift`
3. **Sincronización identidad**: actualización explícita de `studentName`/`educationLevel` antes de recrear sesión
4. **Retry con prompt real**: `lastFailedPrompt` + `retryLastFailedMessage(...)` en ChatViewModel/ChatView
5. **No XP en cancelación**: guards `Task.isCancelled` en rutas render/interceptor/LLM
6. **Ciclo de voz hardened**: bandera `isSessionActive`, cancelación de `transitionTask`/`responseTask` en VoiceModeManager

### Tests unitarios
- `BackgroundSessionManagerTests.swift`: normalización imageURLString
- `ChatViewModelTests.swift`: primer mensaje del día, reconfigure identidad
- Checklist manual: chat, voz, borrado historial, Home stats

## Fase 4: iOS 26 Foundation Models Hardening - COMPLETADO

### Arquitectura de Seguridad del Modelo

El Foundation Models framework ejecuta inferencia **100% on-device** en el Neural Engine. Private Cloud Compute (PCC) **nunca** es usado por este framework. Apple no registra inputs ni outputs (ref: [WWDC25-286](https://developer.apple.com/videos/play/wwdc2025/286/)).

1. **System prompt separado de datos no confiables** — `[CONTEXTO_ESTUDIANTE]` en payload por turno, siguiendo la arquitectura de capas recomendada en [WWDC25-248](https://developer.apple.com/videos/play/wwdc2025/248/)
2. **Sanitización** — normalización whitespace, eliminación control chars, límites longitud (4000 chars prompt, 40 nombre, 1200 memoria)
3. **Guard disponibilidad** — `SystemLanguageModel.default.availability` antes de crear sesión. Reasons: `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady` (ref: [SystemLanguageModel.Availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum))
4. **Prewarm asíncrono** — `session.prewarm(promptPrefix:)` con cancelación explícita. Reduce cold-start ~500ms
5. **Aislamiento por modo** — sesiones separadas chat/voz con recreación automática. Las sesiones serializan a nivel Neural Engine
6. **Error handling completo**:

| Error | Descripción | Recuperación |
|-------|-------------|-------------|
| `guardrailViolation` | Guardrails de seguridad activados | Refrasear; no se proporciona detalle del por qué; usar `logFeedbackAttachment()` para reportar falsos positivos |
| `exceededContextWindowSize` | Total tokens > 4096 | Crear nueva sesión con historial resumido (implementado: replay últimos 4 mensajes) |
| `unsupportedLanguageOrLocale` | Idioma no soportado | Verificar `supportsLocale()` previamente; catalán mapea a español |
| `assetsUnavailable` | Assets del modelo no descargados | Reintentar; verificar availability primero |
| `rateLimited` | Demasiadas requests en periodo corto | Sin retry-after documentado; implementar backoff exponencial |
| `decodingFailure` | Fallo decodificando output estructurado | Reintentar o fallback a texto plano |

Ref: [GenerationError docs](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror)

7. **Liquid Glass ajustado** — `regularMaterial` en contenido scrolleable, glass solo en controles flotantes

### Context Window: 4096 Tokens

- **Límite total**: 4096 tokens = instrucciones + historial + definiciones de tools + respuesta
- **Sin API de conteo público**: usar Instruments con el instrumento Foundation Models para medir tokens reales
- **Heurística**: ~3.5 chars/token para español, ~3-4 para inglés
- **`charCapacityThreshold` = 11,000 chars** (~70% capacidad estimada): trigger de summarización proactiva
- **Overflow**: `exceededContextWindowSize` → recrear sesión con historial condensado
- Ref: [TN3193: Managing the context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)

### Tool Protocol

- `name: String` + `description: String` + `Arguments: @Generable` + `func call() async throws -> String`
- `includesSchemaInInstructions = false` en todos los tools (reduce consumo de tokens)
- `GenerationOptions(sampling: .greedy)` para sesiones con tools (comportamiento determinístico)
- El modelo decide llamar tools basándose en la description; la instancia persiste toda la sesión
- Ref: [Tool calling docs](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling), [WWDC25-301](https://developer.apple.com/videos/play/wwdc2025/301/)

### Performance (iPhone 15 Pro)

- Time-to-first-token: ~0.6ms por token de prompt
- Velocidad de generación: ~30 tokens/segundo (hasta ~60 con token speculation)
- No aumenta tamaño del app (modelo es parte del OS)
- Ref: [Analyzing runtime performance](https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app)

### Validación pendiente (manual)
- [ ] Dispositivo sin Apple Intelligence: banner + error correcto
- [ ] Chat texto y voz: sin contaminación de estado
- [ ] Retry y cancelación: UX estable

### Sesiones WWDC Relacionadas

| Sesión | Título | Contenido |
|--------|--------|-----------|
| WWDC25-286 | Meet the Foundation Models framework | API core, sesiones, streaming, tools intro |
| WWDC25-301 | Deep dive into the Foundation Models framework | @Generable, Tool protocol, GenerationOptions, Instruments |
| WWDC25-248 | Explore prompt design & safety | System prompts, guardrails, patrones de seguridad |
| WWDC25-259 | Code-along: Bring on-device AI to your app | Tutorial práctico |

---

## Fase 5: Auditoría Integral y Correcciones (Abr 2026) - COMPLETADO

### Auditoría de Privacidad — PASS

- **CERO conexiones de red** en código de producción (ni URLSession, ni SDKs de terceros, ni analytics)
- **CERO datos salen del dispositivo** — cumple App Store Privacy Labels sin tracking
- Foundation Models = 100% on-device, sin Private Cloud Compute
- Speech = `requiresOnDeviceRecognition = true`
- Permisos: solo micrófono + reconocimiento de voz (justificados en español en Info.plist)
- Sin `NSTrackingUsageDescription`, sin cámara, sin ubicación, sin contactos

### Correcciones aplicadas

1. **CRÍTICO — Phone regex roto**: backslashes dobles en raw string `#"..."#` de `ContentSafetyService.swift` impedían detección de teléfonos como PII. En raw strings, `\\d` es literal `\` + `d`, no un digit class. Corregido a `\d`
2. **UX Empty States**: HistoryView, SearchView → `ContentUnavailableView` estándar (iOS 17+, escala automáticamente con Dynamic Type, semántica accesible built-in). StudentProgressView → empty state para usuarios nuevos (antes mostraba muro de ceros)
3. **InterceptorMetrics**: utterance en log sin `privacy: .private` → corregido. En producción, os_log redacta strings dinámicos por defecto, pero la anotación explícita es requerida
4. **ChemistrySolver**: force unwrap `Self.bySymbol[item.symbol]!` → optional binding `?.atomicMass ?? 0`
5. **VoiceModeView**: `Task.sleep(0.5)` sin guard `Task.isCancelled` → corregida race condition donde `startSession()` se llamaba después de `onDisappear`
6. **BackgroundSessionManager**: refactorizado de `actor` a `@MainActor final class`. Todo el trabajo ya era `await MainActor.run { }`, el actor era overhead innecesario de context-switch
7. **Streak duplicado 4x**: extraído a `DailyActivity.currentStreak(from:)` compartido (HomeViewModel, ProgressView, XPManager, AchievementManager)
8. **Dead code eliminado**: `showXPToast`/`dismissXPToast` (ChatViewModel), `stateColor`/`statusText` (VoiceModeView)
9. **Accesibilidad**: `ContentUnavailableView` en empty states, `CompactQuestsCard` + `CompactStreakBadge` + `SettingsToggleRow` con labels/hints en español, `AuroraBackgroundView` con `.accessibilityHidden(true)`

---

## Backlog: Optimización de SwiftData Queries

### Problema: @Query carga TODOS los registros en memoria

`HistoryView` y `SearchView` usan `@Query(sort: \ChatMessage.timestamp, order: .reverse)` sin filtro, materializando todos los `ChatMessage` en memoria. Con miles de mensajes, esto causa consumo excesivo de memoria.

### Solución: Patrón Subview Initializer para @Query Dinámico

`@Query` no soporta cambiar su predicado en runtime. La solución es mover `@Query` a un child view cuyo `init` acepta parámetros (ref: [WWDC23-10196](https://developer.apple.com/videos/play/wwdc2023/10196/)):

```swift
// Parent
struct SearchView: View {
    @State private var searchText = ""
    var body: some View {
        SearchResultsList(searchText: searchText)
            .searchable(text: $searchText)
    }
}

// Child con @Query dinámico — la base de datos filtra, no Swift en memoria
struct SearchResultsList: View {
    @Query private var messages: [ChatMessage]
    init(searchText: String) {
        let predicate = searchText.count >= 2
            ? #Predicate<ChatMessage> { $0.content.localizedStandardContains(searchText) }
            : #Predicate<ChatMessage> { _ in false }
        _messages = Query(filter: predicate, sort: \.timestamp, order: .reverse)
    }
}
```

Nota: `localizedStandardContains` es preferido sobre `localizedCaseInsensitiveContains` porque también maneja diacríticos (importante para español: "calculo" matchea "cálculo").

### Solución para HistoryView: fetchLimit + fetchCount

Reemplazar el fetch masivo por 12 queries targeted usando el compound index `[subjectId, timestamp]`:

```swift
func fetchRecentConversations(context: ModelContext) -> [(Subject, ChatMessage, Int)] {
    Subject.allCases.compactMap { subject in
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.subjectId == subject.rawValue },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.propertiesToFetch = [\.content, \.timestamp, \.subjectId]
        guard let lastMsg = try? context.fetch(descriptor).first else { return nil }

        let countDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.subjectId == subject.rawValue }
        )
        let count = (try? context.fetchCount(countDescriptor)) ?? 0
        return (subject, lastMsg, count)
    }
}
```

- `fetchLimit: 1` detiene después del primer row
- `propertiesToFetch` hace fetch parcial (propiedades no-fetched se cargan on-demand por faulting)
- `fetchCount` nunca materializa objetos — retorna solo el conteo
- Ref: [fetchCount docs](https://developer.apple.com/documentation/swiftdata/modelcontext/fetchcount(_:)), [propertiesToFetch docs](https://developer.apple.com/documentation/swiftdata/fetchdescriptor/propertiestofetch)

### AchievementManager: Debounce de 7 Queries

`checkAchievements` ejecuta 7 fetches separados por cada mensaje enviado. Optimizaciones:
- [ ] Debounce: verificar logros cada 5 mensajes, no cada 1
- [ ] Usar `fetchCount` donde solo se necesita conteo (ya implementado para algunos)
- [ ] Agregar `propertiesToFetch` en fetches de sessions/knowledge

---

## Backlog: ContentSafetyService — PII y Jailbreak

### Detección de PII faltante

**Prioridad 1 — Reemplazar phone regex con NSDataDetector:**

`NSDataDetector` maneja formatos internacionales automáticamente y agrega detección de direcciones gratis:

```swift
let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .address]
let detector = try NSDataDetector(types: types.rawValue)
detector.enumerateMatches(in: input, range: NSRange(input.startIndex..., in: input)) { result, _, _ in
    if result?.resultType == .phoneNumber { /* PII detectado */ }
    if result?.resultType == .address { /* PII detectado */ }
}
```

Ref: [NSDataDetector docs](https://developer.apple.com/documentation/foundation/nsdatadetector)

**Prioridad 2 — CURP (México, 18 caracteres):**

```swift
// Formato: 4 letras (nombre) + 6 dígitos (YYMMDD) + género H/M + 2 char estado + 3 consonantes + check
#"\b[A-Z][AEIOUX][A-Z]{2}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[HM](AS|B[CS]|C[CLMSH]|D[FG]|G[TR]|HG|JC|M[CNS]|N[ETL]|OC|PL|Q[TR]|S[PLR]|T[CSL]|VZ|YN|ZS)[B-DF-HJ-NP-TV-Z]{3}[A-Z\d]\d\b"#
```

Regex muy específico = bajo riesgo de falsos positivos.

**Prioridad 3 — Tarjetas de crédito (regex + Luhn):**

```swift
// Detectar 13-16 dígitos consecutivos, luego validar con Luhn para eliminar falsos positivos
#"\b(?:\d[ -]*?){13,16}\b"#
```

Luhn checksum elimina casi todos los falsos positivos (secuencias numéricas aleatorias casi nunca pasan Luhn).

**Prioridad 4 — RFC (México, 12-13 chars):**

```swift
#"\b[A-ZÑ&]{3,4}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}\b"#
```

### Jailbreak Detection — Normalización Antes de Matching

Apple Foundation Models bloquea ~70% de intentos de inyección con sus guardrails built-in (ref: análisis CyCraft 2025). ContentSafetyService es la primera línea de defensa para el otro 30% + detección de PII que Apple NO maneja.

**Prioridad alta — Normalización pre-matching:**

```swift
// 1. Strip zero-width characters (Unicode categoría Cf)
let cleaned = input.unicodeScalars
    .filter { !CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}\u{00AD}").contains($0) }

// 2. Leetspeak normalization
let leetMap: [Character: Character] = ["0":"o","1":"i","3":"e","4":"a","5":"s","7":"t","@":"a","$":"s"]

// 3. Strip separators between single chars: "i.g.n.o.r.a" → "ignora"
let deobfuscated = input.replacingOccurrences(
    of: #"(\w)[.\-_\s](?=\w[.\-_\s])"#, with: "$1", options: .regularExpression
)
```

**Patrones a agregar (español + inglés):**
- Role-play: "finge que eres", "pretende que eres", "actua como si fueras"
- Indirecto: "el profesor dijo que ignores", "las nuevas instrucciones son"
- Inglés: "pretend you are", "you are now", "act as if you were"

### Regulatorio (COPPA)

La actualización COPPA de abril 2025 (compliance deadline abril 2026) expande la definición de "información personal". El procesamiento 100% on-device simplifica significativamente el compliance — no hay "recopilación" en el sentido regulatorio. La detección de PII sigue siendo necesaria como best-practice de seguridad del estudiante.

---

## Backlog: Dynamic Type — 28 Font Sizes Hardcodeados

### Tabla de Mapeo: .system(size:) → Semántico

| Size | Semántico (default pt) | Reemplazo | Archivos |
|------|----------------------|-----------|----------|
| 11pt | `.caption2` (11pt) | `.font(.caption2.bold())` | DailyQuestsCard |
| 12pt | `.caption` (12pt) | `.font(.caption.bold())` | NovaToastSystem |
| 13pt | `.footnote` (13pt) | `.font(.footnote.bold())` | XPProgressBar |
| 14pt | entre footnote/subheadline | `.font(.footnote.weight(.semibold))` | SettingsView |
| 15pt | `.subheadline` (15pt) | `.font(.subheadline.weight(.semibold))` | HomeView |
| 16pt | `.callout` (16pt) | `.font(.callout.weight(.semibold))` | ChatView, ChatHeaderView, SubjectCard |
| 18pt | entre body/title3 | `.font(.body.weight(.semibold))` | HomeView, VoiceModeView, ChatHeaderView, XPProgressBar |
| 20pt | `.title3` (20pt) | `.font(.title3.weight(.semibold))` | ChatView, XPProgressBar |
| 22pt | `.title2` (22pt) | `.font(.title2.weight(.semibold))` | SubjectCard |
| 24pt | entre title2/title | `@ScaledMetric(relativeTo: .title2) = 24` | NovaToastSystem |
| 32pt | entre title/largeTitle | `@ScaledMetric(relativeTo: .largeTitle) = 32` | ChatView |
| 42pt | sobre largeTitle | `@ScaledMetric(relativeTo: .largeTitle) = 42` | SettingsView |
| 44pt | sobre largeTitle | `@ScaledMetric(relativeTo: .largeTitle) = 44` | HomeView, AchievementUnlockView |
| 48pt | sobre largeTitle | `@ScaledMetric(relativeTo: .largeTitle) = 48` | HistoryView, SearchView |
| 56pt | sobre largeTitle | `@ScaledMetric(relativeTo: .largeTitle) = 56` | LevelUpCelebration |

### Patrones de Migración

```swift
// Patrón A: Reemplazo semántico directo (11-22pt)
// ANTES: .font(.system(size: 16, weight: .semibold))
// DESPUÉS: .font(.callout.weight(.semibold))

// Patrón B: Semántico + diseño rounded
// ANTES: .font(.system(size: 20, weight: .bold, design: .rounded))
// DESPUÉS: .font(.title3.bold()).fontDesign(.rounded)

// Patrón C: @ScaledMetric para sizes > 34pt (largeTitle max)
@ScaledMetric(relativeTo: .largeTitle) private var levelSize: CGFloat = 56
// DESPUÉS: .font(.system(size: levelSize, weight: .bold, design: .rounded))

// Patrón D: SF Symbols con tamaño custom
@ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44
Image(systemName: "plus.circle.fill").font(.system(size: iconSize))
```

### Large Content Viewer

Agregar `.accessibilityShowsLargeContentViewer` en controles glass-effect que no pueden crecer con Dynamic Type (tab bar items, header buttons, floating controls).

### Testing

- Xcode Preview canvas → Variants → Dynamic Type Variants (genera 12 previews)
- Testear mínimo: Default (Large), xSmall, AX5 (máximo accessibility)
- Ref: [WWDC24-10074: Get started with Dynamic Type](https://developer.apple.com/videos/play/wwdc2024/10074/)

---

## Swift 6 Backlog

### Estado Actual

`SWIFT_VERSION` = `5.0` con flags de Swift 6.2 activos:

| Build Setting | Valor | Efecto |
|---------------|-------|--------|
| `SWIFT_VERSION` | `5.0` | Violaciones de concurrencia son **warnings**, no errors |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | Habilita SE-0461 (NonisolatedNonsendingByDefault) + SE-0470 (InferIsolatedConformances) |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` | Tipos sin anotación explícita son `@MainActor` por defecto |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` | SE-0409: restringe visibilidad de imports implícitos |

**Implicación clave**: Al cambiar `SWIFT_VERSION` a `6.0`, cada warning de concurrencia se convierte en **error hard**. No hay cambio de comportamiento en las features de Approachable Concurrency — ya están activas.

### Proposals Relevantes

| Proposal | Nombre | Efecto en NovaEducationOS |
|----------|--------|--------------------------|
| SE-0337 | Incremental migration to concurrency | Base para migración gradual |
| SE-0412 | Strict concurrency for global variables | `static let` en clases `@MainActor final` es seguro; verificar variables globales a nivel de archivo |
| SE-0423 | @preconcurrency conformance | Necesario para TextToSpeechService → AVSpeechSynthesizerDelegate |
| SE-0461 | Nonisolated async functions run on caller's actor | Reduce errores de Sendable; funciones `nonisolated async` heredan aislamiento del caller |
| SE-0463 | ObjC completion handlers as @Sendable | Afecta callbacks ObjC bridged |
| SE-0470 | Global-actor isolated conformances | Compiler infiere automáticamente conformances aisladas; reduce necesidad de `@preconcurrency` |

Ref: [Apple: Adopting Strict Concurrency in Swift 6](https://developer.apple.com/documentation/swift/adoptingswift6), [Donny Wals: Swift 6.2 Concurrency](https://www.donnywals.com/exploring-concurrency-changes-in-swift-6-2/)

### Estado de Singletons (auditado Abr 2026) — TODOS OK

| Singleton | Aislamiento | Notas |
|-----------|------------|-------|
| FoundationModelService.shared | @Observable @MainActor | `static let` en clase @MainActor = seguro bajo SE-0412 |
| XPManager.shared | @Observable @MainActor | OK |
| AchievementManager.shared | @Observable @MainActor | OK |
| DailyQuestService.shared | @Observable @MainActor | OK |
| StudentMemoryService.shared | @MainActor | OK |
| BackgroundSessionManager.shared | @MainActor final class | Refactorizado de actor (Fase 5) |
| CelebrationSoundService.shared | @MainActor | OK |
| RenderPipeline.shared | @Observable @MainActor | OK |
| NotificationManager.shared | Sendable (stateless) | `let` + `Sendable` satisface SE-0412 |

Con `DefaultIsolation = MainActor`, acceder a `.shared` desde la mayoría del código es una llamada directa (sin `await`) porque todo corre en `@MainActor` por defecto. Solo contextos explícitamente `nonisolated` o `@concurrent` requieren `await`.

### Streaming: @Sendable Closures — YA CORRECTO

El patrón actual en `FoundationModelService.streamResponse`:
```swift
AsyncThrowingStream { continuation in  // @Sendable closure
    let task = Task { @MainActor [weak self] in ... }
}
```
- `continuation` es `Sendable`
- `[weak self]` captura referencia a clase @MainActor (seguro)
- `Task { @MainActor ... }` declara su aislamiento explícitamente
- Con SE-0461, funciones `nonisolated async` heredan contexto del caller, reduciendo requisitos de Sendable

### Plan de Migración (7 pasos)

1. **Contar warnings actuales**: `xcodebuild 2>&1 | grep "warning:" | grep -i "concurren\|sendable\|isolated"` para dimensionar el trabajo
2. **TextToSpeechService**: agregar `@preconcurrency AVSpeechSynthesizerDelegate` en la conformance. Con SE-0470 el compiler puede inferir la conformance aislada, pero si falla, usar @preconcurrency explícito
3. **Auditar variables globales a nivel de archivo** — verificar que cumplan SE-0412 (los `static let` en clases son seguros, pero `let` a nivel de archivo necesita ser `Sendable` o `nonisolated(unsafe)`)
4. **Verificar closures @Sendable** — las callbacks en ImageGeneratorTool/MemoryTools ya usan `Task { @MainActor in }` (patrón correcto)
5. **Cambiar `SWIFT_VERSION` a `6.0`** en Debug y Release en project.pbxproj
6. **Corregir errores restantes** — esperados mínimos dado el nivel de anotación actual y que `DefaultIsolation = MainActor` elimina la mayoría de falsos positivos
7. **Remover `@preconcurrency` imports** que el compiler indique innecesarios

Ref: [Donny Wals: Should you opt-in to Main Actor isolation?](https://www.donnywals.com/should-you-opt-in-to-swift-6-2s-main-actor-isolation/), [SwiftLee: Approachable Concurrency](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/)

### Checklist Completo

- [ ] Contar y clasificar warnings de concurrencia existentes
- [ ] Agregar `@preconcurrency` a conformance `AVSpeechSynthesizerDelegate` en TextToSpeechService
- [ ] Auditar variables globales a nivel de archivo para SE-0412
- [ ] Cambiar `SWIFT_VERSION` de `5.0` a `6.0`
- [ ] Corregir errores resultantes
- [ ] Migrar 28 font sizes hardcodeados a semánticos/@ScaledMetric
- [ ] Optimizar SwiftData queries (HistoryView, SearchView, AchievementManager)
- [ ] Expandir ContentSafetyService (NSDataDetector, CURP, jailbreak normalization)
- [ ] Suite completa en Xcode 26+ y dispositivo físico con Apple Intelligence
