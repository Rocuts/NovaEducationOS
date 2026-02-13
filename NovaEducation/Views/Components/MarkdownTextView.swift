import SwiftUI
import SwiftMath

/// A view that renders Markdown text with support for LaTeX math formulas
/// Uses SwiftMath for native, offline math rendering
struct MarkdownTextView: View {
    let content: String
    let isUser: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(content: String, isUser: Bool = false) {
        self.content = content
        self.isUser = isUser
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseContentBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    renderTextBlock(text)

                case .mathInline(let latex):
                    MathView(
                        latex: latex,
                        fontSize: 18,
                        textColor: textColor,
                        displayStyle: false
                    )

                case .mathBlock(let latex):
                    MathView(
                        latex: latex,
                        fontSize: 20,
                        textColor: textColor,
                        displayStyle: true
                    )
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Text Block Rendering (handles headers and paragraphs)

    @ViewBuilder
    private func renderTextBlock(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if let header = parseHeader(line) {
                    Text(parseMarkdown(header.text))
                        .font(header.font)
                        .fontWeight(.bold)
                        .padding(.top, 4)
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(parseMarkdown(line))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private struct HeaderInfo {
        let level: Int
        let text: String
        var font: Font {
            switch level {
            case 1: return .title
            case 2: return .title2
            case 3: return .title3
            default: return .headline
            }
        }
    }

    private func parseHeader(_ line: String) -> HeaderInfo? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("####") {
            let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            return HeaderInfo(level: 4, text: text)
        } else if trimmed.hasPrefix("###") {
            let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            return HeaderInfo(level: 3, text: text)
        } else if trimmed.hasPrefix("##") {
            let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return HeaderInfo(level: 2, text: text)
        } else if trimmed.hasPrefix("#") {
            let text = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            return HeaderInfo(level: 1, text: text)
        }
        return nil
    }

    private var textColor: UIColor {
        isUser ? .white : (colorScheme == .dark ? .white : .black)
    }

    // MARK: - Content Parsing

    private enum ContentBlock {
        case text(String)
        case mathInline(String)
        case mathBlock(String)
    }

    private func parseContentBlocks() -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let remaining = content

        // Pattern to match LaTeX: $$...$$, $...$, \[...\], \(...\)
        let pattern = #"(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$|\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\))"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(content)]
        }

        var lastEnd = remaining.startIndex

        let nsRange = NSRange(remaining.startIndex..., in: remaining)
        let matches = regex.matches(in: remaining, options: [], range: nsRange)

        for match in matches {
            guard let range = Range(match.range, in: remaining) else { continue }

            // Add text before this match
            if lastEnd < range.lowerBound {
                let textBefore = String(remaining[lastEnd..<range.lowerBound])
                if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(textBefore))
                }
            }

            // Extract the LaTeX content
            var latex = String(remaining[range])

            // Determine if it's block or inline and clean delimiters
            if latex.hasPrefix("$$") && latex.hasSuffix("$$") {
                latex = String(latex.dropFirst(2).dropLast(2))
                blocks.append(.mathBlock(latex.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else if latex.hasPrefix("$") && latex.hasSuffix("$") {
                latex = String(latex.dropFirst(1).dropLast(1))
                blocks.append(.mathInline(latex.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else if latex.hasPrefix("\\[") && latex.hasSuffix("\\]") {
                latex = String(latex.dropFirst(2).dropLast(2))
                blocks.append(.mathBlock(latex.trimmingCharacters(in: .whitespacesAndNewlines)))
            } else if latex.hasPrefix("\\(") && latex.hasSuffix("\\)") {
                latex = String(latex.dropFirst(2).dropLast(2))
                blocks.append(.mathInline(latex.trimmingCharacters(in: .whitespacesAndNewlines)))
            }

            lastEnd = range.upperBound
        }

        // Add remaining text
        if lastEnd < remaining.endIndex {
            let textAfter = String(remaining[lastEnd...])
            if !textAfter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(textAfter))
            }
        }

        // If no blocks were created, return the whole content as text
        if blocks.isEmpty {
            return [.text(content)]
        }

        return blocks
    }

    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            let options = AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
            return try AttributedString(markdown: text, options: options)
        } catch {
            return AttributedString(text)
        }
    }
}

// MARK: - SwiftMath View Wrapper

struct MathView: View {
    let latex: String
    var fontSize: CGFloat = 20
    var textColor: UIColor = .label
    var displayStyle: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            MathUIViewWrapper(
                latex: latex,
                fontSize: fontSize,
                textColor: textColor,
                displayStyle: displayStyle
            )
            .fixedSize()
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct MathUIViewWrapper: UIViewRepresentable {
    let latex: String
    var fontSize: CGFloat
    var textColor: UIColor
    var displayStyle: Bool

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.backgroundColor = .clear
        label.textAlignment = .left
        label.labelMode = displayStyle ? .display : .text
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        configureLabel(label)
        return label
    }

    func updateUIView(_ label: MTMathUILabel, context: Context) {
        configureLabel(label)
        label.invalidateIntrinsicContentSize()
    }

    private func configureLabel(_ label: MTMathUILabel) {
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = textColor
        label.labelMode = displayStyle ? .display : .text

        // Use Latin Modern Math font (default, looks great)
        if let font = MTFontManager().font(withName: "latinmodern-math", size: fontSize) {
            label.font = font
        }
    }
}

// MARK: - Preview

#Preview("Markdown Simple") {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownTextView(content: "Esto es **negrita** y *cursiva*", isUser: false)

        MarkdownTextView(content: "Lista:\n- Punto 1\n- Punto 2", isUser: false)

        MarkdownTextView(content: "### Título de Sección\nEste es el contenido debajo del título.", isUser: false)
    }
    .padding()
}

#Preview("Fórmulas Matemáticas") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Fórmula inline:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MarkdownTextView(
                    content: "La fórmula cuadrática es $x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$ muy útil.",
                    isUser: false
                )
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Group {
                Text("Ecuación en bloque:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MarkdownTextView(
                    content: """
                    Para resolver esta ecuación:

                    $$x^2 + 5x + 6 = 0$$

                    Factorizamos y obtenemos $x = -2$ o $x = -3$
                    """,
                    isUser: false
                )
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Group {
                Text("Física:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MarkdownTextView(
                    content: """
                    La energía cinética:

                    $$E_k = \\frac{1}{2}mv^2$$

                    Donde $m$ es masa y $v$ es velocidad.
                    """,
                    isUser: false
                )
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Group {
                Text("Integral:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MarkdownTextView(
                    content: """
                    $$\\int_{0}^{\\infty} e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$
                    """,
                    isUser: false
                )
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
