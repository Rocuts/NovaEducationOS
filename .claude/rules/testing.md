# Testing

## Unit Tests (ViewModels)

```swift
@Test
func testSendMessage() async {
    let viewModel = ChatViewModel()
    viewModel.inputText = "Hola, necesito ayuda con matemáticas"
    await viewModel.sendMessage()
    #expect(viewModel.messages.count == 2)
    #expect(viewModel.messages[0].role == .user)
}
```

## Tests de Servicios

```swift
@Test
func testContentSafetyValidation() {
    let service = ContentSafetyService()
    let safeResult = service.validate("¿Cómo resuelvo una ecuación cuadrática?")
    #expect(safeResult == .safe)
}
```

## Previews

```swift
#Preview("HomeView - Default") { HomeView().modelContainer(previewContainer) }
#Preview("HomeView - Dark Mode") { HomeView().modelContainer(previewContainer).preferredColorScheme(.dark) }
#Preview("ChatView - With Messages") { ChatView(subject: .math).modelContainer(previewContainerWithMessages) }
```

## Build y Test

```bash
xcodebuild -scheme NovaEducation -configuration Debug build
xcodebuild test -scheme NovaEducation -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild clean -scheme NovaEducation
```
