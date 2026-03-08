# SwiftUI iOS 26 - Nuevas Características

## Rendimiento

iOS 26 reconstruyó el pipeline de renderizado: GPU -40%, render -39%, memoria -38%.

## Nuevos Componentes

```swift
WebView(url: URL(string: "https://example.com")!)        // WebView nativo
TextEditor(text: $richText).textEditorStyle(.richText)    // Rich Text
SubscriptionOfferView(groupID: "premium_subscription")    // In-app purchases

// Section Index en listas
List {
    ForEach(sections) { section in
        Section(section.title) { ForEach(section.items) { Text($0.name) } }
            .listSectionIndexTitle(section.indexTitle)
    }
}
```

## iPadOS 26 - Menú Bar

```swift
.commands {
    CommandMenu("Archivo") {
        Button("Nuevo") { }
        Button("Abrir") { }
    }
}
```

## Dirección de Texto Automática

```swift
Text(localizedString).writingDirection(.automatic)  // Detecta RTL/LTR
```
