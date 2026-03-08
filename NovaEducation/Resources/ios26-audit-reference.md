# iOS 26 Audit Reference for NovaEducation

> Comprehensive reference document covering iOS 26 APIs, Swift 6 concurrency, Liquid Glass design,
> Foundation Models best practices, and SwiftData patterns. Compiled for the NovaEducation audit.

---

## 1. iOS 26 SwiftUI API Changes

### 1.1 Rendering Performance Improvements

iOS 26 rebuilt the SwiftUI rendering pipeline:
- **GPU usage**: reduced by 40%
- **Render time**: 39% faster
- **Memory**: 38% less usage

These gains are automatic -- no code changes required.

### 1.2 New SwiftUI Components & APIs

| API | Description | Relevance to NovaEducation |
|-----|-------------|---------------------------|
| `WebView(url:)` | Native WebView in SwiftUI | Could display educational web content |
| `TextEditor(.richText)` | Rich text editing support | Could enhance chat input |
| `.listSectionIndexTitle()` | Section index for lists | Could improve history/subject navigation |
| `.writingDirection(.automatic)` | Auto RTL/LTR detection | Not critical (Spanish is LTR) |
| `Chart3D` | 3D charts in Swift Charts | Could visualize progress data |
| `.backgroundExtensionEffect` | Extends/blurs background beyond bounds | Immersive design enhancement |
| `ToolbarSpacer` | Space between toolbar items | Better toolbar layout control |
| `.labelIconToTitleSpacing()` | Label spacing control | Finer UI tuning |

### 1.3 Tab Bar Updates

```swift
TabView(selection: $selectedTab) {
    Tab("Title", systemImage: "icon", value: .tab) {
        ContentView()
    }
    Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
        SearchView()
    }
}
.tabBarMinimizeBehavior(.onScrollDown)  // Auto-minimize on scroll
.tabViewBottomAccessory {               // Accessory above tab bar
    AccessoryView()
}
```

**Minimize behaviors:**
- `.automatic` -- system decides
- `.never` -- always visible
- `.onScrollDown` -- hides when scrolling down

### 1.4 Animation & Transitions

- `symbolEffect(.bounce, value:)` -- SF Symbol animations
- `.glassEffectID("id", in: namespace)` -- Liquid Glass morphing transitions
- `GlassEffectContainer(spacing:)` -- Groups glass elements for shared rendering

---

## 2. Liquid Glass Design Guidelines

### 2.1 Core Principle

Liquid Glass is **exclusively for the navigation layer** that floats above content. NEVER apply to content itself.

### 2.2 Three Glass Variants

| Variant | Transparency | Use Case |
|---------|-------------|----------|
| `.regular` | Medium | Default -- toolbars, buttons, nav bars |
| `.clear` | High | Media-rich backgrounds, bright foreground |
| `.identity` | None | Conditional toggling, disabled state |

### 2.3 Correct Usage

**DO use Liquid Glass for:**
- Navigation bars and toolbars
- Tab bars and bottom accessories
- Floating action buttons
- Sheets, popovers, menus
- Custom navigation controls

**DO NOT use Liquid Glass for:**
- Content layers (lists, tables, media)
- Full-screen backgrounds
- Scrollable content
- Stacked glass layers (glass cannot sample other glass)

### 2.4 The glassEffect Modifier

```swift
// Signature
func glassEffect<S: Shape>(
    _ glass: Glass = .regular,
    in shape: S = .capsule,
    isEnabled: Bool = true
) -> some View

// Basic
.glassEffect()

// With tinting (semantic color, NOT decorative)
.glassEffect(.regular.tint(.blue.opacity(0.8)))

// Interactive (iOS only) -- adds shimmer, scale, bounce
.glassEffect(.regular.interactive())

// Combined
.glassEffect(.regular.tint(.purple).interactive(), in: .circle)
```

### 2.5 Shape Options

- `.capsule` (default)
- `.circle`
- `.ellipse`
- `RoundedRectangle(cornerRadius:)`
- `.rect(cornerRadius: .containerConcentric)` -- aligns with container corners
- Custom shapes conforming to `Shape`

### 2.6 GlassEffectContainer

**Required** when placing multiple glass elements together. Glass cannot sample other glass; the container provides a shared sampling region.

```swift
GlassEffectContainer(spacing: 40.0) {
    Button("Action 1") { }
        .glassEffect(.regular)
    Button("Action 2") { }
        .glassEffect(.regular)
}
```

The `spacing` parameter controls morphing threshold -- elements within this distance visually blend.

### 2.7 Morphing with glassEffectID

Requirements:
1. Elements in the same `GlassEffectContainer`
2. Each tagged with `.glassEffectID(_:in:)` using a shared `@Namespace`
3. State change triggers conditional visibility
4. Animation applied to state modification

```swift
@Namespace private var ns

// State A
Button("Expand") { }
    .glassEffect(.regular)
    .glassEffectID("action", in: ns)

// State B
HStack {
    Button("A") { }
    Button("B") { }
}
.glassEffect(.regular)
.glassEffectID("action", in: ns)
```

### 2.8 Common Mistakes (Audit Checklist)

- [ ] Applying `.glassEffect()` to content (lists, scroll views)
- [ ] Using `.blur`, `.opacity`, or `.background` on a glass view
- [ ] Placing solid fills (Color.white, Color.black) behind glass
- [ ] Multiple glass elements without `GlassEffectContainer`
- [ ] Using glass for decoration instead of semantic meaning
- [ ] Not removing explicit backgrounds before applying glass
- [ ] Overusing glass on every UI element

### 2.9 Accessibility

Glass automatically adapts for:
- **Reduce Transparency**: increases frosting
- **Increase Contrast**: stark colors and borders
- **Reduce Motion**: tones down animations
- **Tinted mode** (iOS 26.1+): user-controlled opacity

Let the system handle accessibility -- don't override unless absolutely necessary.

---

## 3. Foundation Models Best Practices

### 3.1 Framework Overview

| Feature | Description |
|---------|-------------|
| **Model** | 2-bit quantized 3B parameter LLM |
| **Processing** | Primarily on-device, optional Private Cloud Compute |
| **Cost** | Free -- no token metering |
| **Privacy** | Data never leaves device (unless PCC) |
| **Requirements** | iOS 26+, iPhone 15 Pro+, M-series iPad/Mac |

### 3.2 LanguageModelSession

```swift
// Basic
let session = LanguageModelSession()

// With instructions (system prompt)
let session = LanguageModelSession {
    "You are a helpful tutor..."
}

// With tools
let session = LanguageModelSession(tools: [MyTool()]) {
    "System instructions..."
}

// With model selection
let session = LanguageModelSession(
    model: SystemLanguageModel.default,
    guardrails: .default,
    tools: [tool1, tool2],
    instructions: { "Instructions here" }
)
```

**Key properties:**
- `transcript` -- conversation history
- `isResponding` -- boolean for active generation
- `prewarm(promptPrefix:)` -- preloads model, reduces first-token latency by ~40%

### 3.3 Availability Checking

```swift
let model = SystemLanguageModel.default
switch model.availability {
case .available:
    // Safe to create session
case .unavailable(let reason):
    // Handle: .deviceNotEligible, .appleIntelligenceNotEnabled, etc.
}
```

**Best practice:** Cache availability status but recheck periodically (user may enable Apple Intelligence later).

### 3.4 Response Methods

```swift
// Simple text response
let result = try await session.respond(to: "prompt")
print(result.content)

// Structured response (guided generation)
let profile = try await session.respond(to: "prompt", generating: UserProfile.self)

// Streaming text
let stream = session.streamResponse(to: "prompt")
for try await partial in stream {
    // partial.content updates incrementally
}

// Streaming structured
let stream = session.streamResponse(to: "prompt", generating: Recipe.self)
for try await partial in stream {
    // partial is Recipe.PartiallyGenerated (all properties optional)
}
```

### 3.5 @Generable and @Guide

```swift
@Generable
struct DailyQuest {
    @Guide(description: "Title of the quest in Spanish")
    let title: String

    @Guide(description: "Quest description", .count(1...3))
    let objectives: [String]

    @Guide(.anyOf(["quick", "challenge", "epic"]))
    let difficulty: String
}
```

**@Guide constraints:**
- `description:` -- natural-language hints for the model
- `.anyOf(_:)` -- restrict to specific values
- `.count(_:)` -- fix array length or range
- Regex patterns for string validation

### 3.6 Tool Protocol

```swift
final class MyTool: Tool {
    let name = "toolName"           // Short, no spaces
    let description = "What it does" // Model reads this to decide when to call

    @Generable
    struct Arguments {
        @Guide(description: "Parameter description")
        let param: String
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        // Execute tool logic
        return ToolOutput("Result string")
        // OR: return ToolOutput(generatedContent)
    }
}
```

**Key points:**
- Model **autonomously decides** when to invoke tools based on prompt + tool description
- Arguments MUST be `@Generable` (uses guided generation for type safety)
- Tool output reinserts into transcript for continued generation
- Use `nonisolated` on `call()` if the tool needs to run off the main actor

### 3.7 Safety & Guardrails

- Default guardrails enforce Apple's content guidelines (currently non-optional)
- Never interpolate untrusted user input directly into `instructions` (prompt injection risk)
- Keep instructions mostly static across sessions
- Use instructions to enforce behavioral boundaries

### 3.8 Performance Best Practices

1. **Prewarm sessions** during idle time: `try await session.prewarm()`
2. **Reuse sessions** for multi-turn conversations (stateful transcript)
3. **Use streaming** for responsive UI
4. **Use guided generation** to avoid JSON parsing overhead
5. **Short, specific prompts** -- use "in three sentences" or "in a few words"
6. **Check `isResponding`** before sending new requests

### 3.9 Fallback Strategy

```swift
func generateResponse() async {
    let model = SystemLanguageModel.default
    guard model.availability == .available else {
        // Fallback: show static content, cached responses, or manual input
        showFallbackUI()
        return
    }
    // Proceed with AI features
}
```

**Progressive enhancement:** Core functionality works without AI; intelligence features enhance when available.

---

## 4. Swift 6 Concurrency Rules

### 4.1 Strict Concurrency (Swift 6.0)

Swift 6.0 enables **complete concurrency checking by default**, converting previous warnings to compile-time errors. All data races are now caught at compile time.

### 4.2 Sendable Protocol

A `Sendable` type can safely cross actor boundaries:

| Automatically Sendable | Must Conform Explicitly |
|----------------------|------------------------|
| Value types (structs, enums) | Reference types with mutable state |
| `final class` with only `let` properties | Classes with `var` properties |
| Actors | Closures capturing mutable state |
| Types with explicit isolation (`@MainActor`) | |

### 4.3 Common Sendable Errors

```swift
// ERROR: Non-Sendable type 'MyClass' passed across actor boundary
class MyClass {
    var data: [String] = []  // Mutable state = not Sendable
}

// FIX 1: Make it an actor
actor MyClass {
    var data: [String] = []
}

// FIX 2: Make it Sendable with immutable state
final class MyClass: Sendable {
    let data: [String]
}

// FIX 3: Use @unchecked Sendable (ONLY if you guarantee thread safety)
final class MyClass: @unchecked Sendable {
    private let lock = NSLock()
    private var _data: [String] = []
}

// FIX 4 (Swift 6+): Use Mutex from Synchronization framework
import Synchronization
final class MyClass: Sendable {
    let data = Mutex<[String]>([])
}
```

### 4.4 Singleton Pattern Issues

```swift
// ERROR: Static property 'shared' is not concurrency-safe
final class Manager {
    static let shared = Manager()
}

// FIX 1: Mark as @MainActor (if UI-related)
@MainActor
final class Manager {
    static let shared = Manager()
}

// FIX 2: Use nonisolated(unsafe) (if truly thread-safe)
final class Manager: Sendable {
    nonisolated(unsafe) static let shared = Manager()
}

// FIX 3: Make it an actor
actor Manager {
    static let shared = Manager()
}
```

### 4.5 @MainActor Rules

```swift
// All UI code should be @MainActor
@MainActor
@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []

    func sendMessage() async {
        // This runs on MainActor
        let response = try await fetchResponse()  // May hop threads
        messages.append(response)                   // Back on MainActor
    }
}
```

**Common pitfall:** Closures defined inside `@MainActor` methods inherit that isolation. If a framework calls those closures from a background thread, you crash.

### 4.6 Swift 6.2 Changes (Xcode 26)

#### Default MainActor Isolation

New Xcode 26 projects default to `@MainActor` isolation for everything:

```swift
// Package.swift
swiftSettings: [
    .defaultIsolation(MainActor.self)
]
```

With this enabled, all code runs on MainActor unless you explicitly opt out with `nonisolated` or `@concurrent`.

#### nonisolated Async Functions

**Before (Swift 6.1):** `nonisolated async` functions ran on background threads.
**After (Swift 6.2):** They inherit the caller's actor isolation context.

```swift
// Swift 6.2: This now runs on MainActor if called from MainActor
nonisolated func processData() async {
    // Inherits caller's isolation
}

// To explicitly run off MainActor:
@concurrent
nonisolated func processData() async {
    // Always runs concurrently
}
```

#### The @concurrent Attribute

Use `@concurrent` when you explicitly need background execution:

```swift
@MainActor
class NetworkClient {
    @concurrent
    nonisolated func fetchData() async throws -> Data {
        // Runs off MainActor
    }
}
```

### 4.7 Common Compilation Errors in iOS 26

| Error | Cause | Fix |
|-------|-------|-----|
| `Non-Sendable type passed across actor boundary` | Mutable reference type crosses isolation | Make Sendable, use actor, or add `@MainActor` |
| `Static property is not concurrency-safe` | Singleton without isolation | Add `@MainActor` or `nonisolated(unsafe)` |
| `Capture of non-Sendable in @Sendable closure` | Closure captures mutable state | Make captured type Sendable or use `sending` |
| `Call to MainActor-isolated from nonisolated context` | Background code calling UI code | Add `await` and `@MainActor` annotation |
| `Mutation of captured var in concurrently-executing code` | Shared mutable state in async | Use actor or Mutex |
| `Cannot convert '@MainActor () -> Void' to '() -> Void'` | Isolation mismatch in closures | Match isolation or use `Task { @MainActor in }` |

### 4.8 Concurrency Audit Checklist

- [ ] All `@Observable` ViewModels marked `@MainActor`
- [ ] Singletons properly isolated (`@MainActor` or `nonisolated(unsafe)`)
- [ ] No `@unchecked Sendable` without genuine thread safety
- [ ] Tool `call()` methods marked `nonisolated` if needed
- [ ] No data races in closure captures
- [ ] Background work uses `Task.detached` or `@concurrent` explicitly
- [ ] `try await` used for all async operations
- [ ] Error handling around all Foundation Models calls

---

## 5. SwiftData Patterns (iOS 26)

### 5.1 iOS 26 Changes

- **Model Inheritance**: Define shared data in base classes, extend in subclasses
- **Bug fix**: View updates now work correctly when mutating data under `@ModelActor`
- **Codable predicates**: Properties conforming to `Codable` can now be used in predicates
- Both fixes are backward compatible to iOS 17

### 5.2 Model Definition Pattern

```swift
@Model
final class ChatMessage {
    var id: UUID
    var content: String
    var timestamp: Date

    // Use stored properties for SwiftData, computed for convenience
    var imageURLString: String?

    var imageURL: URL? {
        get { URL(string: imageURLString ?? "") }
        set { imageURLString = newValue?.absoluteString }
    }

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
    }
}
```

### 5.3 Container Setup

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            ChatMessage.self,
            UserSettings.self,
            Achievement.self
        ])
    }
}
```

### 5.4 Query Patterns

```swift
// In views
@Query(sort: \ChatMessage.timestamp, order: .reverse)
private var messages: [ChatMessage]

// Filtered query
@Query(filter: #Predicate<ChatMessage> { $0.subjectId == "math" })
private var mathMessages: [ChatMessage]

// In ViewModels / Services
let descriptor = FetchDescriptor<ChatMessage>(
    predicate: #Predicate { $0.subjectId == subjectId },
    sortBy: [SortDescriptor(\.timestamp)]
)
let messages = try modelContext.fetch(descriptor)
```

### 5.5 SwiftData Audit Checklist

- [ ] All `@Model` classes use stored properties (not computed) for persisted data
- [ ] `UUID` and `Date` defaults set in `init`, not as property defaults
- [ ] Relationships properly defined with inverse references
- [ ] `ModelContainer` includes all model types
- [ ] Queries use `#Predicate` (type-safe) not string-based
- [ ] No force-unwrapping of optional SwiftData properties
- [ ] `modelContext.save()` called where needed (or relying on auto-save)

---

## 6. ImagePlayground Framework

### 6.1 Requirements

- iOS 18.4+ for `ImageCreator` (programmatic generation)
- Physical device with Apple Intelligence enabled
- iPhone 15 Pro+ / iPad with M1+ / Mac with Apple Silicon

### 6.2 Tool Calling Integration

The recommended pattern (used in NovaEducation):

```swift
final class ImageGeneratorTool: Tool {
    let name = "generateEducationalImage"
    let description = "Generates educational illustration..."

    @Generable
    struct Arguments {
        @Guide(description: "Descriptive prompt in English")
        let imagePrompt: String
        @Guide(description: "Brief reason in Spanish")
        let reasonForImage: String
    }

    nonisolated func call(arguments: Arguments) async throws -> ToolOutput {
        // Use ImageCreator to generate
        // Save to Documents/GeneratedImages/
        return ToolOutput("Image generated")
    }
}
```

### 6.3 Subject-Based Image Support

Only enable image generation for visual subjects:
```swift
var supportsImages: Bool {
    switch self {
    case .open, .science, .social, .language, .english, .arts, .sports: return true
    case .math, .physics, .chemistry, .technology, .ethics: return false
    }
}
```

---

## 7. Accessibility Compliance

### 7.1 Required for All Views

```swift
// VoiceOver labels (Spanish)
.accessibilityLabel("Enviar mensaje")
.accessibilityHint("Toca dos veces para enviar")

// Group related elements
.accessibilityElement(children: .combine)

// Dynamic values
.accessibilityValue("Progreso: \(progress)%")
```

### 7.2 Dynamic Type

```swift
// Always use system fonts
.font(.body)  // NOT .font(.system(size: 16))

// Scale images with text
@ScaledMetric var iconSize: CGFloat = 24

// Adaptive layouts
ViewThatFits {
    HorizontalLayout()
    VerticalLayout()
}
```

### 7.3 Color Contrast

- Minimum 4.5:1 for body text
- Minimum 3:1 for large text and UI elements
- Use semantic colors: `.primary`, `.secondary`, `.background`

---

## 8. Performance Patterns

### 8.1 Lazy Loading

```swift
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(messages) { message in
            MessageBubble(message: message)
        }
    }
}
```

### 8.2 Task Management

```swift
// Auto-cancelled when view disappears
.task {
    await loadData()
}

// Auto-cancelled and restarted when ID changes
.task(id: selectedSubject) {
    await loadMessages(for: selectedSubject)
}
```

### 8.3 Foundation Models Performance

1. Call `prewarm()` during idle time
2. Reuse sessions for multi-turn conversations
3. Use streaming for responsive UI updates
4. Check `isResponding` before new requests
5. Cache availability status

---

## 9. Security & Privacy

### 9.1 Content Safety

- Validate ALL user input before sending to Foundation Models
- Detect and block PII (phone numbers, emails, addresses, IDs)
- Never interpolate untrusted input into system instructions
- Use Foundation Models guardrails (`.default`)

### 9.2 On-Device Processing

- Speech recognition: `requiresOnDeviceRecognition = true`
- Foundation Models: primarily on-device
- Images: generated locally, stored in app sandbox

### 9.3 Data Handling

- No user data sent to external servers
- Conversations stored locally via SwiftData
- No third-party analytics or tracking

---

## 10. App Store Requirements (April 2026)

- Must compile with iOS 26 SDK (Xcode 26+)
- Minimum device: iPhone 11+
- Privacy Nutrition Labels must be declared
- Age rating: educational content, no external UGC

---

## 11. Phase 4 Hardening (Applied)

### 11.1 Foundation Models

- System instructions moved to stable policy-only content (no direct interpolation of student-controlled text).
- Dynamic student context now sent as per-turn payload blocks and sanitized before usage.
- Added session `prewarm()` after creation, with cancellation when session is recreated.
- Added explicit interaction mode isolation for requests (`text` vs `voice`) to avoid cross-mode contamination.
- Added modern generation error mapping for language/locale and guardrail categories.
- Removed non-iOS legacy backend assumptions from error flow.

### 11.2 Liquid Glass Scope

- Navigation-layer glass retained (header/input/nav controls).
- Decorative glass in scrolled content replaced with standard material where applicable.

### 11.3 Swift 6 Preparation (No Flip Yet)

- Project remains on `SWIFT_VERSION = 5.0` for this hardening iteration.
- Next dedicated migration phase should enable Swift 6 and resolve strict-concurrency findings.

---

## Sources

### Apple Official
- [Foundation Models Documentation](https://developer.apple.com/documentation/FoundationModels)
- [Applying Liquid Glass to Custom Views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession)
- [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Adopting Swift 6](https://developer.apple.com/documentation/swift/adoptingswift6)
- [SwiftData Updates](https://developer.apple.com/documentation/updates/swiftdata)

### WWDC 2025 Sessions
- [What's New in SwiftUI (WWDC25-256)](https://developer.apple.com/videos/play/wwdc2025/256/)
- [Build a SwiftUI App with New Design (WWDC25-323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Meet Foundation Models (WWDC25-286)](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep Dive Foundation Models (WWDC25-301)](https://developer.apple.com/videos/play/wwdc2025/301/)
- [Explore Prompt Design & Safety (WWDC25-248)](https://developer.apple.com/videos/play/wwdc2025/248/)

### Community References
- [Liquid Glass Reference (GitHub)](https://github.com/conorluddy/LiquidGlassReference)
- [Donny Wals: Liquid Glass Custom UI](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [Donny Wals: Swift 6.2 Concurrency Changes](https://www.donnywals.com/exploring-concurrency-changes-in-swift-6-2/)
- [SwiftLee: Default Actor Isolation](https://www.avanderlee.com/concurrency/default-actor-isolation-in-swift-6-2/)
- [AzamSharp: Foundation Models Guide](https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html)
- [CreateWithSwift: Foundation Models](https://www.createwithswift.com/exploring-the-foundation-models-framework/)
- [Foundation Models Gist](https://gist.github.com/koher/214301df47eeeb5c426cbcfd72700a8e)
- [Fatbobman: SwiftData at WWDC25](https://fatbobman.com/en/posts/wwdc-2025-first-impressions/)
- [Hacking with Swift: Swift 6.2](https://www.hackingwithswift.com/articles/277/whats-new-in-swift-6-2)

---

*Generated: February 2026*
*For: NovaEducation iOS 26 Audit*
