import SwiftUI

/// A unified keyboard toolbar that shows subject-specific symbols
struct SubjectKeyboardToolbar: View {
    @Binding var text: String
    let keyboardType: SubjectKeyboardType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Button {
                        appendText(symbol)
                    } label: {
                        Text(displaySymbol(for: symbol))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .frame(minWidth: 44, minHeight: 44)
                            .background(symbolBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(accessibilityName(for: symbol, keyboard: keyboardType))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }

    private var symbolBackground: some View {
        Group {
            switch keyboardType {
            case .math:
                Color.blue.opacity(0.15)
            case .physics:
                Color.cyan.opacity(0.15)
            case .chemistry:
                Color.orange.opacity(0.15)
            case .none:
                Color.secondary.opacity(0.1)
            }
        }
    }

    private var symbols: [String] {
        switch keyboardType {
        case .math:
            return mathSymbols
        case .physics:
            return physicsSymbols
        case .chemistry:
            return chemistrySymbols
        case .none:
            return []
        }
    }

    // MARK: - Math Symbols
    private var mathSymbols: [String] {
        [
            // Basic arithmetic
            "+", "-", "×", "÷", "=", "≠",
            // Powers and roots
            "√", "∛", "x²", "xⁿ", "xₙ",
            // Constants
            "π", "e", "∞",
            // Calculus
            "∫", "∂", "∑", "∏", "lim",
            // Trigonometry
            "sin", "cos", "tan", "log", "ln",
            // Comparison
            "<", ">", "≤", "≥", "≈",
            // Grouping
            "(", ")", "[", "]", "{", "}",
            // Fractions
            "½", "⅓", "¼",
            // Arrows
            "→", "←", "↔",
            // Sets
            "∈", "∉", "⊂", "∪", "∩"
        ]
    }

    // MARK: - Physics Symbols
    private var physicsSymbols: [String] {
        [
            // Greek letters commonly used
            "α", "β", "γ", "δ", "θ", "λ", "μ", "ω", "Ω", "Δ", "Σ", "φ", "ρ", "τ",
            // Operations
            "=", "≠", "≈", "+", "-", "×", "÷",
            // Vectors and derivatives
            "→", "∂", "∇", "d/dt",
            // Powers
            "²", "³", "⁻¹", "⁻²",
            // Units prefix
            "k", "M", "G", "m", "μ", "n",
            // Common units
            "m/s", "m/s²", "kg", "N", "J", "W", "Pa", "Hz", "V", "A", "Ω",
            // Comparison
            "<", ">", "≤", "≥",
            // Grouping
            "(", ")", "[", "]",
            // Special
            "√", "∫", "∞", "°"
        ]
    }

    // MARK: - Chemistry Symbols
    private var chemistrySymbols: [String] {
        [
            // Subscripts for formulas
            "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉",
            // Superscripts for charges
            "⁺", "⁻", "²⁺", "²⁻", "³⁺", "³⁻",
            // Reaction arrows
            "→", "←", "⇌", "↔",
            // States of matter
            "(s)", "(l)", "(g)", "(aq)",
            // Common elements
            "H", "C", "N", "O", "S", "P", "Na", "K", "Ca", "Mg", "Fe", "Cu", "Zn", "Cl", "Br",
            // Bonds
            "—", "═", "≡",
            // Other
            "Δ", "°C", "pH", "mol", "M",
            // Operations
            "+", "=", "≠",
            // Grouping
            "(", ")", "[", "]"
        ]
    }

    // MARK: - Display Symbol
    private func displaySymbol(for raw: String) -> String {
        switch raw {
        case "x²": return "x²"
        case "xⁿ": return "xⁿ"
        case "xₙ": return "xₙ"
        case "d/dt": return "d/dt"
        case "m/s": return "m/s"
        case "m/s²": return "m/s²"
        default: return raw
        }
    }

    // MARK: - Accessibility Names
    private func accessibilityName(for symbol: String, keyboard: SubjectKeyboardType) -> String {
        // Context-dependent symbols
        if symbol == "N" {
            return keyboard == .chemistry ? "Nitrógeno" : "Newtons"
        }
        if symbol == "M" {
            return keyboard == .chemistry ? "Molar" : "Mega"
        }
        if symbol == "m" {
            return keyboard == .physics ? "Mili" : symbol
        }
        switch symbol {
        // Basic arithmetic
        case "+": return "Más"
        case "-": return "Menos"
        case "×": return "Multiplicar"
        case "÷": return "Dividir"
        case "=": return "Igual"
        case "≠": return "No igual"

        // Powers and roots
        case "√": return "Raíz cuadrada"
        case "∛": return "Raíz cúbica"
        case "x²": return "X al cuadrado"
        case "xⁿ": return "X a la n"
        case "xₙ": return "X sub n"

        // Constants
        case "π": return "Pi"
        case "e": return "Euler"
        case "∞": return "Infinito"

        // Calculus
        case "∫": return "Integral"
        case "∂": return "Derivada parcial"
        case "∑", "Σ": return "Sumatoria"
        case "∏": return "Productoria"
        case "lim": return "Límite"

        // Trigonometry
        case "sin": return "Seno"
        case "cos": return "Coseno"
        case "tan": return "Tangente"
        case "log": return "Logaritmo"
        case "ln": return "Logaritmo natural"

        // Comparison
        case "<": return "Menor que"
        case ">": return "Mayor que"
        case "≤": return "Menor o igual"
        case "≥": return "Mayor o igual"
        case "≈": return "Aproximadamente"

        // Grouping
        case "(": return "Paréntesis izquierdo"
        case ")": return "Paréntesis derecho"
        case "[": return "Corchete izquierdo"
        case "]": return "Corchete derecho"
        case "{": return "Llave izquierda"
        case "}": return "Llave derecha"

        // Fractions
        case "½": return "Un medio"
        case "⅓": return "Un tercio"
        case "¼": return "Un cuarto"

        // Arrows
        case "→": return "Flecha derecha"
        case "←": return "Flecha izquierda"
        case "↔": return "Flecha doble"
        case "⇌": return "Equilibrio"

        // Sets
        case "∈": return "Pertenece a"
        case "∉": return "No pertenece"
        case "⊂": return "Subconjunto"
        case "∪": return "Unión"
        case "∩": return "Intersección"

        // Greek letters (physics)
        case "α": return "Alfa"
        case "β": return "Beta"
        case "γ": return "Gamma"
        case "δ": return "Delta"
        case "θ": return "Theta"
        case "λ": return "Lambda"
        case "μ": return "Mu"
        case "ω": return "Omega"
        case "Ω": return "Omega mayúscula"
        case "Δ": return "Delta mayúscula"
        case "φ": return "Fi"
        case "ρ": return "Rho"
        case "τ": return "Tau"

        // Vectors
        case "∇": return "Nabla"
        case "d/dt": return "Derivada temporal"

        // Powers (physics)
        case "²": return "Al cuadrado"
        case "³": return "Al cubo"
        case "⁻¹": return "Inverso"
        case "⁻²": return "Menos dos"

        // Units
        case "m/s": return "Metros por segundo"
        case "m/s²": return "Metros por segundo al cuadrado"
        case "kg": return "Kilogramos"
        // "N" handled above (context-dependent: Newtons vs Nitrógeno)
        case "J": return "Joules"
        case "W": return "Watts"
        case "Pa": return "Pascales"
        case "Hz": return "Hertz"
        case "V": return "Voltios"
        case "A": return "Amperios"
        case "°": return "Grados"
        case "°C": return "Grados Celsius"

        // Unit prefixes
        case "k": return "Kilo"
        // "M" handled above (context-dependent: Mega vs Molar)
        case "G": return "Giga"
        // "m" handled above (context-dependent)
        case "n": return "Nano"

        // Chemistry subscripts
        case "₀": return "Subíndice cero"
        case "₁": return "Subíndice uno"
        case "₂": return "Subíndice dos"
        case "₃": return "Subíndice tres"
        case "₄": return "Subíndice cuatro"
        case "₅": return "Subíndice cinco"
        case "₆": return "Subíndice seis"
        case "₇": return "Subíndice siete"
        case "₈": return "Subíndice ocho"
        case "₉": return "Subíndice nueve"

        // Chemistry charges
        case "⁺": return "Carga positiva"
        case "⁻": return "Carga negativa"
        case "²⁺": return "Dos positivo"
        case "²⁻": return "Dos negativo"
        case "³⁺": return "Tres positivo"
        case "³⁻": return "Tres negativo"

        // States of matter
        case "(s)": return "Sólido"
        case "(l)": return "Líquido"
        case "(g)": return "Gas"
        case "(aq)": return "Acuoso"

        // Chemical bonds
        case "—": return "Enlace simple"
        case "═": return "Enlace doble"
        case "≡": return "Enlace triple"

        // Chemistry other
        case "pH": return "pH"
        case "mol": return "Mol"

        // Elements
        case "H": return "Hidrógeno"
        case "C": return "Carbono"
        case "O": return "Oxígeno"
        case "S": return "Azufre"
        case "P": return "Fósforo"
        case "Na": return "Sodio"
        case "K": return "Potasio"
        case "Ca": return "Calcio"
        case "Mg": return "Magnesio"
        case "Fe": return "Hierro"
        case "Cu": return "Cobre"
        case "Zn": return "Zinc"
        case "Cl": return "Cloro"
        case "Br": return "Bromo"

        default: return symbol
        }
    }

    // MARK: - Append Text
    private func appendText(_ symbol: String) {
        let insertion: String
        switch symbol {
        // Math insertions
        case "x²": insertion = "^2"
        case "xⁿ": insertion = "^"
        case "xₙ": insertion = "_"
        case "√": insertion = "√()"
        case "∛": insertion = "∛()"
        case "log": insertion = "log()"
        case "ln": insertion = "ln()"
        case "sin": insertion = "sin()"
        case "cos": insertion = "cos()"
        case "tan": insertion = "tan()"
        case "lim": insertion = "lim_{}"

        // Physics insertions
        case "d/dt": insertion = "d/dt()"
        case "m/s": insertion = " m/s"
        case "m/s²": insertion = " m/s²"
        case "⁻¹": insertion = "^{-1}"
        case "⁻²": insertion = "^{-2}"
        case "²": insertion = "^2"
        case "³": insertion = "^3"

        // Chemistry states
        case "(s)": insertion = "(s)"
        case "(l)": insertion = "(l)"
        case "(g)": insertion = "(g)"
        case "(aq)": insertion = "(aq)"

        // Charges
        case "²⁺": insertion = "^{2+}"
        case "²⁻": insertion = "^{2-}"
        case "³⁺": insertion = "^{3+}"
        case "³⁻": insertion = "^{3-}"

        default: insertion = symbol
        }

        text += insertion
    }
}

// MARK: - Preview
#Preview("Math Keyboard") {
    VStack {
        Spacer()
        SubjectKeyboardToolbar(text: .constant(""), keyboardType: .math)
    }
}

#Preview("Physics Keyboard") {
    VStack {
        Spacer()
        SubjectKeyboardToolbar(text: .constant(""), keyboardType: .physics)
    }
}

#Preview("Chemistry Keyboard") {
    VStack {
        Spacer()
        SubjectKeyboardToolbar(text: .constant(""), keyboardType: .chemistry)
    }
}
