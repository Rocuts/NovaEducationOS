# Seguridad, Privacidad y Localización

## Validación de Contenido

Siempre validar entrada ANTES de enviar a AI:
```swift
let validation = contentSafetyService.validate(inputText)
guard case .safe = validation else { showSafetyWarning(validation); return }
```

## Datos Sensibles

- NO guardar mensajes en logs → `Logger.debug("Message sent: [REDACTED]")`
- PII a detectar: teléfonos, emails, direcciones físicas, IDs

## Localización (Español)

Toda la UI en español. Mantener consistencia:
- "Inicio" (no "Home"), "Ajustes" (no "Settings"), "Enviar" (no "Send")
- Errores: "No se pudo enviar el mensaje. Intenta de nuevo."
- Fechas: `Text(date, format: .dateTime.day().month().year())` → "21 de enero de 2026"
- Números: formato español con punto separador de miles

## App Store

- Compilar con iOS 26 SDK / Xcode 26+
- Privacy Nutrition Labels: conversaciones locales, Speech on-device, notificaciones, sin tracking
- Age Rating: contenido educativo general, sin compras in-app
