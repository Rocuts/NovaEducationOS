# Rendimiento y Optimización

## Lazy Loading

```swift
ScrollView {
    LazyVStack(spacing: 12) { ForEach(messages) { MessageBubble(message: $0) } }
}

LazyVGrid(columns: columns, spacing: 16) { ForEach(subjects) { SubjectCard(subject: $0) } }
```

## Evitar Re-renders

- Extraer subviews estáticas como componentes separados
- Usar `@ViewBuilder` para vistas condicionales

## Async/Await

```swift
.task { await loadInitialData() }                    // Operaciones async
.task(id: selectedSubject) { await loadMessages(for: selectedSubject) }  // Con cancelación

// Streaming
for try await token in responseStream {
    await MainActor.run { currentResponse += token }
}
```
