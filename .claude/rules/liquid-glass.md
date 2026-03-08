# Liquid Glass - Directrices de Diseño (iOS 26)

Liquid Glass es el sistema de diseño de Apple (WWDC 2025). Material adaptativo que combina propiedades ópticas del vidrio con fluidez del líquido.

## Principios

- **Jerarquía**: Controles flotan sobre contenido como capa funcional distinta
- **Armonía**: Balancea hardware, contenido y controles con formas redondeadas naturales
- **Consistencia**: Diseño universal cross-platform

## Uso Correcto

**USAR para navegación y controles flotantes:**
```swift
.toolbarBackgroundVisibility(.visible, for: .navigationBar)  // Nav bars
TabView { }.tabBarMinimizeBehavior(.onScrollDown)             // Tab bars
Button { } label: { }.glassEffect(.regular)                   // Botones flotantes
.sheet(isPresented: $showSheet) { }                           // Sheets/popovers
HStack { }.glassEffect(.regular, in: .capsule)                // Controles custom
```

**NO USAR para contenido:**
```swift
List { }        // ❌ No glass en listas
ZStack { }.glassEffect()  // ❌ No como fondo de pantalla
ScrollView { }  // ❌ No en contenido scrolleable
// ❌ No apilar capas de glass
```

## GlassEffectContainer

Siempre agrupar elementos glass relacionados:
```swift
// ✅ CORRECTO
GlassEffectContainer(spacing: 40.0) {
    Button("Acción 1") { }.glassEffect(.regular)
    Button("Acción 2") { }.glassEffect(.regular)
}

// ❌ INCORRECTO: glass sin container
VStack {
    Button("Acción 1") { }.glassEffect(.regular)
    Button("Acción 2") { }.glassEffect(.regular)
}
```

## glassEffectID para Morphing

```swift
@Namespace private var glassNamespace

// Transición suave entre estados usando mismo ID
Button("Expandir") { }
    .glassEffect(.regular)
    .glassEffectID("actionButton", in: glassNamespace)
```

## Tab Bar iOS 26

```swift
TabView(selection: $selectedTab) {
    Tab("Inicio", systemImage: "house.fill", value: .home) { HomeView() }
    Tab("Buscar", systemImage: "magnifyingglass", value: .search, role: .search) { SearchView() }
}
.tabBarMinimizeBehavior(.onScrollDown)
.tabViewBottomAccessory { MiniPlayerView() }
```

Minimización: `.automatic` | `.never` | `.onScrollDown`
