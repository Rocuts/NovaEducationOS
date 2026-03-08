# Accesibilidad

## Liquid Glass y Accesibilidad

Liquid Glass respeta automáticamente: Reduce Transparency, Increase Contrast, Reduce Motion.

## VoiceOver

```swift
Button { } label: { Image(systemName: "paperplane.fill") }
    .accessibilityLabel("Enviar mensaje")
    .accessibilityHint("Toca dos veces para enviar tu mensaje")

VStack { Text("Matemáticas"); Text("5 sesiones") }
    .accessibilityElement(children: .combine)
    .accessibilityValue("Progreso: \(progress)%")
```

## Dynamic Type

- Usar fuentes del sistema: `.body`, `.headline`, `.largeTitle`
- Escalar imágenes: `.imageScale(.large)`
- Layouts adaptativos: `@ScaledMetric var iconSize: CGFloat = 24`

## Contraste

- Usar colores semánticos: `.primary`, `.secondary`, `.background`
- Mínimo 4.5:1 para texto, 3:1 para elementos gráficos
