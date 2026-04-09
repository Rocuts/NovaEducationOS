# NovaEducation

An iOS application that integrates a fully offline large language model to deliver personalized academic tutoring for children. Built on Apple's Foundation Models framework, all AI inference runs entirely on the device's Neural Engine — no student data is transmitted externally, no cloud API is called, and no internet connection is required. The system implements layered safety mitigations including input validation, prompt injection hardening, content moderation, PII detection, and privacy preservation by architectural design, making it suitable for unsupervised use by minors.

## Table of Contents

- [Safety Architecture](#safety-architecture)
- [On-Device AI Integration](#on-device-ai-integration)
- [Purpose](#purpose)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Technologies](#technologies)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Environment Configuration](#environment-configuration)
- [Application Flow](#application-flow)
- [Technical Decisions](#technical-decisions)
- [Testing](#testing)
- [Future Improvements](#future-improvements)
- [Contributing](#contributing)
- [License](#license)

## Safety Architecture

NovaEducation was designed from the ground up with safety as a core architectural concern — not an afterthought. Every interaction between a child and the AI model passes through multiple safety layers before, during, and after generation.

### Safety Pipeline

```
Student Input
  |
  v
[1] Input Sanitization
  |  - Control character removal
  |  - Whitespace normalization
  |  - Length enforcement (4,000 char cap)
  |  - Bracket neutralization in dynamic data
  |
  v
[2] Content Safety Validation (ContentSafetyService)
  |  - PII detection: emails, phone numbers
  |  - Harmful content blocking: violence, self-harm, hate speech, explicit material
  |  - Context-aware filtering: distinguishes educational use ("drug" in pharmacology) from harmful intent
  |  - Jailbreak attempt detection: "ignore your instructions", "forget everything", "prompt injection"
  |  - Bilingual coverage: patterns matched in both Spanish and English
  |
  v
[3] Prompt Hardening (FoundationModelService)
  |  - Student data (name, education level, knowledge context) isolated in tagged
  |    [CONTEXTO_ESTUDIANTE] blocks, structurally separated from system instructions
  |  - Explicit non-instruction policy: the model is told these blocks contain
  |    untrusted data and must not interpret them as commands
  |  - Student name capped at 40 characters, knowledge context at 600 characters
  |  - Dynamic data sanitized: brackets replaced, control characters stripped
  |
  v
[4] Deterministic Routing (before LLM processes the query)
  |  - Computational questions solved by exact solvers (MathSolver, PhysicsSolver,
  |    ChemistrySolver) — eliminates hallucination risk for factual answers
  |  - Visual requests handled by deterministic RenderPipeline
  |  - Only open-ended questions reach the language model directly
  |
  v
[5] Generation Safeguards
  |  - Repetition loop detection: aborts if last 40 characters repeat 4+ times
  |  - Useless response detection: identifies refusal patterns and short non-answers
  |  - Context window monitoring: proactive session recreation at 70% capacity
  |  - Cancellation safety: Task.isCancelled checks prevent XP awards on aborted generations
  |
  v
[6] Agentic Oversight (Tool Calling)
     - The model autonomously invokes tools (image generation, knowledge storage, quiz creation)
       but each tool operates within strict boundaries:
       - ImageGeneratorTool: validates disk space (50MB minimum), caps image dimensions (2048x2048),
         writes with complete file protection, requires iOS 18.4+ physical device
       - MemoryStoreTool: sanitizes input (500 char cap, bracket replacement), categorizes strictly
       - QuizGeneratorTool: enforces exactly 4 options, truncates explanations at 500 characters
     - No tool has network access or can read arbitrary files
```

### Privacy-Preserving Design

Privacy in NovaEducation is enforced at the architecture level, not by policy:

| Layer | Implementation |
|-------|---------------|
| **AI inference** | Runs on Apple Neural Engine; `LanguageModelSession` never contacts external servers |
| **Speech recognition** | `requiresOnDeviceRecognition = true` — audio never leaves the device |
| **Data persistence** | SwiftData with local-only `ModelContainer`; no sync, no cloud backup by default |
| **Generated images** | Saved to app sandbox (`Documents/GeneratedImages/`) with `.completeFileProtection` |
| **Logging** | Sensitive content redacted: `Logger.debug("Message sent: [REDACTED]")` |
| **Telemetry** | None. Zero analytics, zero tracking, zero external network calls |
| **PII handling** | Detected and blocked before reaching the model; never stored or logged |

This means a child can use the application without any personal data ever being transmitted, collected, or made accessible to third parties — including the developer.

### Content Safety Testing

The project includes dedicated test suites for safety edge cases:

- `ContentSafetyEdgeCaseTests.swift` — boundary conditions for PII detection, harmful content patterns, and jailbreak attempts
- `SafetyTests.swift` — validation of the safety pipeline integration
- `FoundationModelServiceTests.swift` — session creation guards, availability checks, and error recovery paths

## On-Device AI Integration

NovaEducation integrates Apple's Foundation Models framework to run a large language model directly on the device's Neural Engine. This is not a wrapper around a cloud API — the model lives on the hardware, processes locally, and responds in real time via streaming.

### How It Works

```
Student Input
  |
  v
On-Device Language Model (Apple Intelligence / Neural Engine)
  |-- Text generation via LanguageModelSession
  |-- Streaming token output via AsyncThrowingStream
  |-- Autonomous Tool Calling:
  |   |-- Image generation (ImagePlayground / ImageCreator)
  |   |-- Knowledge storage (StudentMemoryService)
  |   |-- Quiz generation (QuizGeneratorTool)
  |   +-- Knowledge recall (MemoryRecallTool)
  |
  v
Buffered response with real-time streaming to UI
```

### Technical Properties

| Property | Detail |
|----------|--------|
| **Inference location** | 100% on-device (Apple Neural Engine) |
| **Network dependency** | None — fully functional offline |
| **Data transmitted externally** | None — zero telemetry, zero API calls |
| **Model management** | Handled by iOS; no manual model download or update |
| **Session lifecycle** | Automatic creation, prewarm, context recovery, and isolation per interaction mode (text vs. voice) |
| **Context window management** | Proactive summarization at 70% capacity (~11,000 chars) with automatic session recreation and history replay |
| **Streaming** | Buffered token delivery with regex cleaning every 32 characters and repetition loop detection |
| **Tool Calling** | Model autonomously decides when to generate images, store knowledge, or create quizzes — within safety-bounded tool implementations |
| **Prompt hardening** | Student data isolated in tagged `[CONTEXTO_ESTUDIANTE]` blocks with explicit non-instruction policy |
| **Error recovery** | Automatic retry on context overflow: recreates session, replays last 4 messages, retries once |

### Three-Way Intelligent Routing

Before the language model processes a query, the system applies deterministic routing to guarantee correctness and reduce hallucination risk:

1. **Visual Intent** — `RenderIntentRouter` detects visual requests and generates 3D models/images via `RenderPipeline`; the LLM then explains the concept pedagogically
2. **Computational Intent** — Subject-specific interceptors (`MathSolver`, `PhysicsSolver`, `ChemistrySolver`, `SpanishGrammarSolver`) solve problems with exact computation; the LLM explains the pre-computed result step by step
3. **Conversational Intent** — Open-ended questions go directly to the on-device LLM for streamed response

This "app decides, AI teaches" architecture ensures that factual answers (arithmetic, formulas, chemical equations) are never hallucinated — they are computed deterministically, and the model's role is limited to pedagogical explanation.

## Purpose

NovaEducation transforms any compatible iOS device into a personal AI tutor for every child eager to learn. Any student with access to a supported device gains a private, intelligent learning companion that:

- Answers academic questions with step-by-step explanations across 12 subjects
- Solves math, physics, and chemistry problems deterministically before explaining with AI
- Generates educational images and interactive 3D models to visualize concepts
- Adapts its teaching to the student's education level (primary, secondary, high school, university)
- Motivates consistent study through gamification with XP, achievements, and daily quests
- Works completely offline — no internet connection required to learn
- Protects the child's privacy by design — no data ever leaves the device

## Key Features

### AI-Powered Tutoring
- **12 academic subjects**: Mathematics, Physics, Chemistry, Natural Sciences, Social Sciences, Language & Literature, English, Ethics, Technology, Arts, Physical Education, and a free-form mode
- **Three-way intelligent routing**: the system automatically determines whether a question requires visual rendering, deterministic computation, or a language model response
- **Subject-specific interceptors**: MathSolver, PhysicsSolver, ChemistrySolver, and SpanishGrammarSolver solve operations exactly before the LLM explains pedagogically
- **Real-time streaming** with buffered text cleaning and repetition loop detection
- **Voice mode**: bidirectional conversation with fully on-device speech recognition and text-to-speech

### Visual Generation
- **Educational images** via ImagePlayground (iOS 18.4+), invoked autonomously by the model through Tool Calling
- **3D models** generated by RenderPipeline with a concept catalog (atoms, molecules, geometric shapes)
- **Visual intent detection**: RenderIntentRouter analyzes the student's text to decide whether to generate a 3D model

### Gamification
- **XP system** with 12 point sources (messages, quizzes, quests, daily goals)
- **Dynamic multipliers** (up to 2.5x): daily streaks, subject variety, perfect quizzes, daily goal completion
- **32 achievements** across 6 categories: learning, streaks, exploration, schedule, mastery, and levels
- **Daily quests** with three difficulty tiers (quick, challenge, epic)
- **Level system**: from Novice (level 1) to Legend (level 30+), with titles and celebrations
- **Focus mode**: progressive phases (warm-up, focused, deep focus, flow state) with XP bonuses

### Student Memory
- **Knowledge storage**: the model stores and recalls what the student knows, their difficulties, and interests via autonomous Tool Calling
- **Quiz generation**: the model generates multiple-choice questions adapted to the student's level
- **Learning plans**: step-by-step sequences with progress tracking

## Architecture

### Pattern: MVVM + Service Layer

```
View (SwiftUI)
  |
  v
ViewModel (@Observable @MainActor)
  |
  v
Services (business logic, AI integration, safety validation)
  |
  v
Models (SwiftData @Model, local-only persistence)
```

### Message Processing Pipeline

```
Student Input
  |
  +-- ContentSafetyService.validate()  -->  Blocks if unsafe (PII, harmful, jailbreak)
  |
  +-- RenderIntentRouter.detect()      -->  If visual: RenderPipeline generates 3D model
  |                                         then LLM explains the concept
  |
  +-- SubjectIntentRouter.detect()     -->  If computation: Interceptor solves exactly
  |                                         then LLM explains step by step
  |
  +-- FoundationModelService.stream()  -->  If discussion/creative: direct LLM response
  |                                         with autonomous Tool Calling
  |
  +-- XPManager.awardXP()             -->  Gamification: XP, achievements, quests
```

## Project Structure

```
NovaEducation/
|-- App/
|   +-- NovaEducationApp.swift              # Entry point, ModelContainer with triple fallback
|
|-- Models/                                 # SwiftData @Model (local persistence)
|   |-- ChatMessage.swift                   # Chat messages with image and 3D attachment support
|   |-- UserSettings.swift                  # Student profile, total XP, level, preferences
|   |-- Subject.swift                       # Enum defining 12 academic subjects
|   |-- Achievement.swift                   # 32 achievement types across 6 categories
|   |-- DailyQuest.swift                    # Daily quests with difficulty and XP reward
|   |-- StudentKnowledge.swift              # Student knowledge + QuizQuestion + LearningPlan
|   |-- XPTransaction.swift                 # XP history + PlayerLevel system
|   |-- StudySession.swift                  # Study session tracking
|   |-- DailyActivity.swift                 # Daily activity tracking (streaks)
|   +-- SchemaVersioning.swift              # SwiftData schema versioning (V1 active)
|
|-- ViewModels/                             # @Observable @MainActor
|   |-- ChatViewModel.swift                 # Orchestrates chat, routing, XP, error recovery
|   |-- HomeViewModel.swift                 # Home screen state, daily quests
|   +-- SettingsViewModel.swift             # Settings UI state
|
|-- Views/
|   |-- MainTabView.swift                   # Root TabView with 5 tabs
|   |-- ChatView.swift                      # Chat interface with streaming display
|   |-- HomeView.swift                      # Home with gamification dashboard
|   |-- HistoryView.swift                   # Conversation history browser
|   |-- ProgressView.swift                  # Statistics dashboard
|   |-- SettingsView.swift                  # User preferences
|   |-- SearchView.swift                    # Subject search and selection
|   |-- VoiceModeView.swift                 # Voice interaction interface
|   |-- Components/                         # Reusable UI components
|   |   |-- MessageBubble.swift             # Message bubble with Markdown rendering
|   |   |-- XPProgressBar.swift             # Animated level progress bar
|   |   |-- SubjectCard.swift               # Subject card with Liquid Glass effect
|   |   |-- LevelUpCelebration.swift        # Level-up celebration animation
|   |   |-- DailyQuestsCard.swift           # Daily quests display card
|   |   |-- AchievementUnlockView.swift     # Achievement unlock popup
|   |   |-- NovaAvatarView.swift            # Tutor avatar
|   |   |-- ThinkingIndicator.swift         # AI generation indicator
|   |   |-- ParticleExplosionView.swift     # Particle effects for XP gains
|   |   |-- OracleOrbView.swift             # Animated orb for voice mode
|   |   |-- MarkdownTextView.swift          # Markdown content renderer
|   |   |-- GeometryView.swift              # 3D model viewer
|   |   |-- IslandNotificationView.swift    # Dynamic Island-style notifications
|   |   |-- AuroraBackgroundView.swift      # Animated aurora background
|   |   +-- Styles/
|   |       +-- SquishyButtonStyle.swift    # Tactile button animation style
|   +-- Modifiers/
|       |-- ShimmerModifier.swift           # Shimmer loading effect
|       |-- KineticHoverModifier.swift      # Kinetic hover animation
|       +-- FocusAwareModifier.swift        # Focus mode modifier
|
|-- Services/
|   |-- FoundationModelService.swift        # On-device AI integration (~1,065 lines)
|   |-- ImageGeneratorService.swift         # Image generation service
|   |-- ImageGeneratorTool.swift            # LLM Tool protocol for ImagePlayground
|   |-- MemoryTools.swift                   # LLM Tools: memory store, recall, quiz generation
|   |-- ContentSafetyService.swift          # Content safety validation (PII, harmful, jailbreak)
|   |-- XPManager.swift                     # XP calculation and multiplier system
|   |-- AchievementManager.swift            # Achievement checking and unlocking
|   |-- DailyQuestService.swift             # Daily quest management
|   |-- StudentMemoryService.swift          # Student knowledge persistence and retrieval
|   |-- FocusManager.swift                  # Focus mode with progressive phases
|   |-- VoiceModeManager.swift              # Voice conversation orchestration
|   |-- SpeechRecognitionService.swift      # On-device speech recognition
|   |-- TextToSpeechService.swift           # Text-to-speech with premium voices
|   |-- RenderPipeline.swift                # 3D/2D render orchestration
|   |-- RenderIntentRouter.swift            # Deterministic visual intent detection
|   |-- RenderTypes.swift                   # Render result models
|   |-- RenderMetrics.swift                 # Render performance metrics
|   |-- ConceptCatalog.swift                # Catalog of 3D-renderable concepts
|   |-- NotificationManager.swift           # Push notifications (daily study reminder)
|   |-- BackgroundSessionManager.swift      # Background task scheduling
|   |-- CelebrationSoundService.swift       # Celebration audio effects
|   |-- IslandNotificationManager.swift     # Dynamic Island notification queue
|   +-- Interceptors/                       # Deterministic subject-specific solvers
|       |-- SubjectInterceptor.swift        # Interceptor protocol definition
|       |-- SubjectIntentRouter.swift        # Router to select appropriate interceptor
|       |-- MathSolver.swift                # Arithmetic, roots, quadratic equations, factorials
|       |-- PhysicsSolver.swift             # Physics formulas
|       |-- ChemistrySolver.swift           # Chemical reactions and equations
|       |-- SpanishGrammarSolver.swift      # Grammar rules
|       +-- InterceptorMetrics.swift        # Interceptor performance tracking
|
|-- Utilities/
|   |-- DesignTokens.swift                  # Design system constants (colors, typography, spacing)
|   |-- ScrollOffsetKey.swift               # PreferenceKey for scroll offset tracking
|   +-- CleaningPatterns.swift              # Data cleanup utilities
|
|-- Extensions/
|   +-- Color+Hex.swift                     # Hex color parsing extension
|
|-- Resources/
|   +-- Models/                             # 3D model files
|
|-- Assets.xcassets/                        # App icons, colors, images
+-- KaTeX/                                  # Bundled LaTeX rendering library

NovaEducationTests/                         # Unit tests
|-- ChatViewModelTests.swift
|-- FoundationModelServiceTests.swift
|-- ContentSafetyEdgeCaseTests.swift        # Safety edge case testing
|-- PlayerLevelTests.swift
|-- FocusManagerTests.swift
|-- VoiceModeManagerTests.swift
|-- BackgroundSessionManagerTests.swift
|-- SafetyTests.swift                       # Safety pipeline integration tests
|-- ServiceTests.swift
+-- Testing/
    |-- GamificationTests.swift
    |-- InterceptorTests.swift
    |-- RenderTests.swift
    +-- StudentMemoryServiceTests.swift

NovaEducationUITests/                       # UI tests
+-- ChatViewUITests.swift
```

## Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| **Swift** | 6.0+ (compiling under 5.0) | Primary language |
| **SwiftUI** | iOS 26+ | UI framework |
| **SwiftData** | iOS 26+ | Local-only persistence (10 models, zero cloud sync) |
| **Foundation Models** | iOS 26+ | On-device AI inference for tutoring |
| **ImagePlayground** | iOS 18.4+ | On-device educational image generation |
| **Speech** | iOS 26+ | On-device speech recognition (`requiresOnDeviceRecognition = true`) |
| **AVSpeechSynthesizer** | iOS 26+ | Text-to-speech output |
| **SwiftMath** | 1.7.3 (SPM) | Mathematical expression rendering |
| **KaTeX** | Bundled | LaTeX rendering in chat messages |

### Hardware Requirements for AI
- **Foundation Models**: iPhone 15 Pro+ / iPad M1+ / Mac Apple Silicon with Apple Intelligence enabled
- **ImagePlayground**: physical device required (not available on simulator)
- **Speech**: any device compatible with iOS 26

### External Dependencies

| Dependency | Type | Purpose |
|------------|------|---------|
| [SwiftMath](https://github.com/mgriebling/SwiftMath) 1.7.3 | SPM | Mathematical expression and formula rendering |

All other functionality uses native Apple frameworks. No third-party analytics, tracking, or networking libraries are included.

## Prerequisites

- **Xcode 26+** (with iOS 26 SDK)
- **iOS 26+** deployment target
- **Apple Intelligence enabled** in Settings > Apple Intelligence & Siri
- Physical device for AI features (Foundation Models is not available on simulator)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/rocuts/NovaEducationOS.git
cd NovaEducationOS
```

2. Open in Xcode:
```bash
open NovaEducation.xcodeproj
```

3. SPM dependencies (SwiftMath) resolve automatically when the project opens.

4. Select a physical device or simulator running iOS 26+.

5. Build and run:
```bash
# Build
xcodebuild -scheme NovaEducation -configuration Debug build

# Run tests
xcodebuild test -scheme NovaEducation -destination 'platform=iOS Simulator,name=iPhone 16'

# Clean
xcodebuild clean -scheme NovaEducation
```

> **Note**: Foundation Models and ImagePlayground require a physical device with Apple Intelligence enabled. The app will display an availability banner and gracefully degrade on unsupported hardware.

## Environment Configuration

No environment variables, API keys, or external configuration are required. All AI processing runs on-device.

The app handles SwiftData initialization with a triple fallback strategy:
1. Creates `ModelContainer` with the primary store configuration
2. If migration fails, creates a new named store (`NovaEducation_Reset`)
3. Last resort: in-memory store so the app launches without crashing, with a user-facing alert

## Application Flow

### Startup
1. The app initializes the SwiftData `ModelContainer` with fallback handling
2. `MainTabView` presents 5 tabs: Home, Progress, Search, History, Settings
3. `HomeView` loads daily quests, current streak, and available subjects

### Study Session
1. The student selects a subject from HomeView
2. `ChatView` opens with the conversation history for that subject
3. The system configures `FoundationModelService` with the student's identity, education level, and appropriate tools
4. Every message passes through the safety pipeline and three-way routing (see [Architecture](#architecture))

### Response Cycle
```
Input -> Safety Validation -> Routing -> [Render | Interceptor | LLM] -> Streaming -> XP -> Achievements
```
1. **Safety validation**: PII detection, harmful content blocking, jailbreak prevention
2. **Intent detection**: visual (3D), computational (exact solver), or conversational (LLM)
3. **Generation**: deterministic result + LLM explanation, or direct LLM streamed response
4. **Gamification**: XP with multipliers, achievement checks, quest progress

### Voice Mode
1. The student activates voice mode from ChatView
2. `VoiceModeManager` orchestrates the cycle: listen -> process -> speak -> listen
3. Speech recognition via `SFSpeechRecognizer` (on-device, `requiresOnDeviceRecognition = true`)
4. Response via `AVSpeechSynthesizer` with premium voice selection
5. Audio pipeline manages TTS/STT transitions with hardware settle delays

### Context Management
- At 70% context capacity (~11,000 characters), the session is automatically recreated
- The last messages are replayed into the new session to preserve conversational continuity
- If context overflow occurs, the system retries once with a fresh session and history replay

## Technical Decisions

### 1. Deterministic Routing Before the LLM
**Decision**: Subject-specific interceptors (MathSolver, PhysicsSolver, etc.) solve computational problems exactly before the LLM participates.
**Rationale**: Eliminates hallucination risk for factual answers. The LLM's role is limited to pedagogical explanation of a pre-computed, verified result. This is a robustness guarantee — the system does not rely on the model for correctness in domains where exact computation is possible.

### 2. 100% On-Device Processing
**Decision**: Apple Foundation Models instead of cloud APIs.
**Rationale**: Guarantees student privacy at the architecture level, not by policy. Particularly critical for minors: no data transmission means no parental consent requirements for data collection, no risk of data breaches, and no dependency on network availability. Trade-off: requires hardware with Apple Intelligence support.

### 3. Prompt Hardening with Data Isolation
**Decision**: Student data (name, education level, knowledge context) is placed in a tagged `[CONTEXTO_ESTUDIANTE]` block structurally separated from system instructions, with an explicit policy stating these are untrusted data.
**Rationale**: Mitigates prompt injection attacks where a student's name or message content could contain adversarial instructions. The model is explicitly told not to interpret the student data block as commands.

### 4. Agentic Tool Calling with Safety Boundaries
**Decision**: The model autonomously invokes tools (image generation, knowledge storage, quiz creation) during conversation, but each tool enforces strict input validation, output limits, and resource constraints.
**Rationale**: Enables richer educational interactions without requiring the student to explicitly request each action, while ensuring that autonomous model behavior cannot exceed defined safety boundaries.

### 5. SwiftData without Direct Relationships
**Decision**: Models are linked by IDs (`subjectId`) rather than explicit SwiftData relationships.
**Rationale**: Avoids complexity of cascading deletes and schema migrations, enables independent queries with composite indices. Trade-off: no automatic referential integrity.

### 6. Singleton Services
**Decision**: Services like `FoundationModelService.shared`, `XPManager.shared`, and `AchievementManager.shared` use the Singleton pattern.
**Rationale**: Simplifies the dependency graph in a Swift/SwiftUI project without a standard DI framework. Acknowledged as technical debt (see [Future Improvements](#future-improvements)).

## Testing

```bash
# Run all tests
xcodebuild test -scheme NovaEducation -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Test Coverage

| Area | Files | What is Tested |
|------|-------|----------------|
| **Content Safety** | `ContentSafetyEdgeCaseTests.swift`, `SafetyTests.swift` | PII detection, harmful content patterns, jailbreak attempts, edge cases, safety pipeline integration |
| **Foundation Models** | `FoundationModelServiceTests.swift` | Session creation, availability guards, streaming, error recovery |
| **Chat ViewModel** | `ChatViewModelTests.swift` | Message sending, first-of-day detection, identity reconfiguration |
| **Gamification** | `PlayerLevelTests.swift`, `GamificationTests.swift` | Level calculation, XP awards, multipliers, achievement unlocking |
| **Focus Mode** | `FocusManagerTests.swift` | Phase transitions, milestones, session timing |
| **Voice Mode** | `VoiceModeManagerTests.swift` | Voice cycle states, session lifecycle |
| **Background Tasks** | `BackgroundSessionManagerTests.swift` | Image URL normalization |
| **Interceptors** | `InterceptorTests.swift` | Subject-specific solver accuracy |
| **Rendering** | `RenderTests.swift` | 3D render pipeline output |
| **Student Memory** | `StudentMemoryServiceTests.swift` | Knowledge storage, retrieval, deduplication |

## Future Improvements

### Safety and Robustness
- [ ] Expand content safety test coverage with adversarial prompt datasets
- [ ] Add granular error type handling in streaming (distinguish cancellation, guardrail violations, and model errors)
- [ ] Implement output validation for model-generated content before display
- [ ] Add safety benchmarks for evaluating content moderation effectiveness over time

### Architecture
- [ ] Refactor ChatViewModel: extract render and interceptor coordinators to reduce responsibilities
- [ ] Extract streaming response pattern: duplicated across 3 methods, should be a shared helper
- [ ] Resolve Singleton + @Observable issue: separate FoundationModelService into a session manager singleton and a per-ViewModel observable state (documented TODO in codebase)
- [ ] Introduce dependency injection to decouple services and improve testability

### Swift 6 Migration
- [ ] Enable Swift 6 strict concurrency per target
- [ ] Audit captures in `@Sendable` closures
- [ ] Review singletons for strict concurrency compliance

### Functionality
- [ ] Multi-language support (currently Spanish UI; model responds based on device locale)
- [ ] Collaborative learning mode between students
- [ ] Progress and statistics export
- [ ] iPad adaptive layouts with menu bar support
- [ ] iOS widget for daily progress tracking

## Contributing

1. Create a branch from `main`:
```bash
git checkout -b feat/feature-name
```

2. Verify the checklist before committing:
   - [ ] Follows MVVM (business logic in ViewModel/Service, not in View)
   - [ ] Liquid Glass used only for navigation and floating controls
   - [ ] Accessibility included (VoiceOver labels, Dynamic Type)
   - [ ] Validates safety if interacting with AI
   - [ ] async/await for asynchronous operations
   - [ ] Previews for Xcode Canvas
   - [ ] Checks `subject.supportsImages` before generating images

3. Run tests:
```bash
xcodebuild test -scheme NovaEducation -destination 'platform=iOS Simulator,name=iPhone 16'
```

4. Open a pull request to `main`.

### Commit Convention
```bash
feat:      # New feature
fix:       # Bug fix
refactor:  # Code refactoring without functional change
docs:      # Documentation
style:     # Formatting, no functional change
test:      # Tests
chore:     # Maintenance
```

## License

This project is licensed under the **NovaEducation Source-Available License v1.0** — see the [LICENSE](LICENSE) file for the full terms.

**In summary**: the source code is viewable for educational review and evaluation purposes only. You may **not** use, copy, modify, distribute, or create derivative works from this Software without prior explicit written permission from the author. This is **not** an open-source license.

For licensing inquiries or permission requests, contact the author directly.

---

Built by Johan Rocuts
