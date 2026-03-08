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
- Checklist manual: chat, voz, borrado historial, Home stats ✅

## Fase 4: iOS 26 Foundation Models Hardening - COMPLETADO

1. System prompt separado de datos no confiables (`[CONTEXTO_ESTUDIANTE]` en payload por turno)
2. Sanitización: normalización whitespace, eliminación control chars, límites longitud
3. Guard disponibilidad Apple Intelligence antes de crear sesión
4. Prewarm asíncrono con cancelación explícita
5. Aislamiento por modo interacción (chat/voz) con recreación automática
6. Error handling: `unsupportedLanguageOrLocale`, `guardrailViolation`, eliminado `backendUnavailable`
7. Liquid Glass ajustado: `regularMaterial` en contenido scrolleable, glass solo en controles

### Validación pendiente (manual)
- [ ] Dispositivo sin Apple Intelligence: banner + error correcto
- [ ] Chat texto y voz: sin contaminación de estado
- [ ] Retry y cancelación: UX estable

## Swift 6 Backlog (NO migrado aún)

`SWIFT_VERSION` actual: `5.0`

- [ ] Activar Swift 6 por target
- [ ] Auditar capturas en closures `@Sendable`
- [ ] Revisar singletons para concurrencia estricta
- [ ] Suite completa en Xcode 26+ y dispositivo físico
