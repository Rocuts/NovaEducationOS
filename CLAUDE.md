# NovaEducation

App educativa iOS con Apple Intelligence para tutoría personalizada en 12 materias. Estudiantes hispanohablantes. On-device AI con Foundation Models.

## Stack

- **Swift 6.0+** / **SwiftUI** / **SwiftData** / **iOS 26+**
- **AI:** Foundation Models (on-device) + ImagePlayground (generación de imágenes)
- **Arquitectura:** MVVM + Services
- **Version Swift (proyecto):** 5.0 (Swift 6 en backlog)

## Reglas Críticas

1. **Leer código existente** antes de proponer cambios
2. **UI siempre en español** — "Inicio", "Ajustes", "Enviar" (nunca inglés)
3. **Liquid Glass SOLO para navegación/controles flotantes**, nunca para contenido
4. **Validar seguridad** antes de cualquier interacción con AI
5. **Preferir editar** archivos existentes, no crear nuevos
6. **No over-engineering** — soluciones simples y directas
7. **MVVM estricto** — sin lógica de negocio en vistas
8. **@Observable** para ViewModels (no ObservableObject)
9. **Accesibilidad** en cada componente (VoiceOver, Dynamic Type)
10. **Tool Calling** para funcionalidades que el modelo invoca autónomamente
11. **Verificar `subject.supportsImages`** antes de generar imágenes
12. **async/await** para operaciones asíncronas, streaming con `AsyncThrowingStream`

## Build y Test

```bash
xcodebuild -scheme NovaEducation -configuration Debug build
xcodebuild test -scheme NovaEducation -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild clean -scheme NovaEducation
```

## Git

```bash
# Prefijos: feat: | fix: | refactor: | docs: | style: | test: | chore:
git commit -m "feat: descripción corta del cambio"
```

## Checklist Nuevas Features

- [ ] Sigue MVVM (lógica en ViewModel/Service, no en View)
- [ ] Liquid Glass solo en navegación
- [ ] Accesibilidad (VoiceOver labels, Dynamic Type)
- [ ] Textos en español
- [ ] Valida seguridad si interactúa con AI
- [ ] async/await para operaciones asíncronas
- [ ] Previews para Xcode Canvas
- [ ] Verifica `subject.supportsImages` si genera imágenes

## Guías Detalladas

Las reglas completas están en `.claude/rules/`:

| Archivo | Contenido |
|---------|-----------|
| `liquid-glass.md` | Diseño Liquid Glass, GlassEffectContainer, morphing |
| `swiftui-ios26.md` | Nuevas APIs SwiftUI, WebView, Rich Text |
| `architecture.md` | MVVM, estructura carpetas, convenciones código |
| `data-models.md` | SwiftData models, Subject enum, imágenes |
| `services.md` | Foundation Models, Tool Calling, ImageGenerator |
| `ui-components.md` | Vistas, MessageBubble, animaciones |
| `accessibility.md` | VoiceOver, Dynamic Type, contraste |
| `performance.md` | Lazy loading, re-renders, async patterns |
| `testing.md` | Unit tests, previews, comandos build |
| `security.md` | Validación contenido, privacidad, localización |
| `remediation-log.md` | Fases 1-4 remediación, Swift 6 backlog |

## Referencias

- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [ImagePlayground](https://developer.apple.com/documentation/imageplayground)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [WWDC 2025 - Foundation Models](https://developer.apple.com/videos/play/wwdc2025/286/)
- [WWDC 2025 - SwiftUI new design](https://developer.apple.com/videos/play/wwdc2025/323/)
