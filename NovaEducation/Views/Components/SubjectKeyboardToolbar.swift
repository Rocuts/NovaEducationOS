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
