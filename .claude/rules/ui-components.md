# Vistas y Componentes UI

## MainTabView

```swift
TabView(selection: $selectedTab) {
    Tab("Inicio", systemImage: "house.fill", value: .home) { HomeView() }
    Tab("Progreso", systemImage: "chart.bar.fill", value: .progress) { ProgressView() }
    Tab("Ajustes", systemImage: "gear", value: .settings) { SettingsView() }
}
.tabBarMinimizeBehavior(.onScrollDown)
```

## SubjectCard con Liquid Glass

```swift
Button(action: onTap) {
    VStack(spacing: 12) {
        Image(systemName: subject.icon).font(.largeTitle)
        Text(subject.displayName).font(.headline)
    }
    .frame(maxWidth: .infinity).padding()
}
.glassEffect(.regular)
```

## MessageBubble

- Alineación: usuario a la derecha, asistente a la izquierda
- Usa `MarkdownTextView` para contenido
- Si `message.hasImage`: muestra `AsyncImage(url: message.imageURL)`

## Animaciones

```swift
// Aparición de mensajes
.transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: messages.count)

// SF Symbols
Image(systemName: "sparkles").symbolEffect(.bounce, value: trigger)

// Glass morphing
.glassEffectID("button", in: namespace)
```

## ImageGenerationBanner

Muestra estado de generación de imágenes. Usa `viewModel.imageGenerationState` y `subject.color`.
