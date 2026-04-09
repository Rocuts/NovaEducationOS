import SwiftUI
import SwiftData

struct SearchView: View {
    @Binding var selectedSubject: Subject?
    let settings: UserSettings
    @State private var searchText = ""
    @State private var resultsAppeared = false

    private var filteredSubjects: [Subject] {
        if searchText.isEmpty {
            return Subject.allCases
        }
        return Subject.allCases.filter { subject in
            subject.displayName.localizedCaseInsensitiveContains(searchText) ||
            subject.searchKeywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                LazyVStack(spacing: Nova.Spacing.lg) {
                    if searchText.isEmpty {
                        subjectResultsSection(title: "Todas las materias", subjects: filteredSubjects)
                    } else {
                        if !filteredSubjects.isEmpty {
                            subjectResultsSection(title: "Materias", subjects: filteredSubjects)
                        }

                        // Child view with dynamic @Query — database filters, not Swift in memory
                        SearchMessageResults(
                            searchText: searchText,
                            hasSubjectResults: !filteredSubjects.isEmpty
                        ) { subject in
                            selectedSubject = subject
                        }
                    }
                }
                .padding()
                .onAppear { resultsAppeared = true }
            }
            .contentMargins(.bottom, Nova.Spacing.tabBarClearance, for: .scrollContent)
        }
        .navigationTitle("Buscar")
        .searchable(text: $searchText, prompt: "Buscar materia o en tus conversaciones...")
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }

    // MARK: - Subject Results Section
    @ViewBuilder
    private func subjectResultsSection(title: String, subjects: [Subject]) -> some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
            if !searchText.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Nova.Spacing.xxs)
            }

            ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                SearchResultRow(subject: subject) {
                    selectedSubject = subject
                }
                .opacity(resultsAppeared ? 1 : 0)
                .offset(y: resultsAppeared ? 0 : 15)
                .animation(Nova.Animation.stagger(index: index), value: resultsAppeared)
            }
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Search Message Results (dynamic @Query subview pattern)
// Ref: WWDC23-10196 — @Query cannot change its predicate at runtime,
// so we move it to a child view whose init accepts parameters.

struct SearchMessageResults: View {
    @Query private var messages: [ChatMessage]
    let searchText: String
    let hasSubjectResults: Bool
    let onSelectSubject: (Subject) -> Void

    init(searchText: String, hasSubjectResults: Bool, onSelectSubject: @escaping (Subject) -> Void) {
        self.searchText = searchText
        self.hasSubjectResults = hasSubjectResults
        self.onSelectSubject = onSelectSubject

        // localizedStandardContains handles diacritics: "calculo" matches "cálculo"
        if searchText.count >= 2 {
            let text = searchText
            _messages = Query(
                filter: #Predicate<ChatMessage> { $0.content.localizedStandardContains(text) },
                sort: \.timestamp,
                order: .reverse
            )
        } else {
            _messages = Query(
                filter: #Predicate<ChatMessage> { _ in false },
                sort: \.timestamp,
                order: .reverse
            )
        }
    }

    var body: some View {
        if !messages.isEmpty {
            chatResultsSection
        } else if !hasSubjectResults {
            noResultsView
        }
    }

    private var chatResultsSection: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
            HStack {
                Text("En tus conversaciones")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(messages.count) resultado\(messages.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Nova.Spacing.xxs)

            ForEach(messages) { message in
                ChatResultRow(message: message, searchText: searchText) {
                    if let subject = Subject(rawValue: message.subjectId) {
                        onSelectSubject(subject)
                    }
                }
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: Nova.Spacing.xl) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.secondary)

            VStack(spacing: Nova.Spacing.sm) {
                Text("Sin resultados para \"\(searchText)\"")
                    .font(.title3.bold())

                Text("Prueba con otras palabras o revisa la ortografía")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Nova.Spacing.jumbo)
        .frame(maxWidth: .infinity)
        .padding(.top, Nova.Spacing.jumbo)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let subject: Subject
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Nova.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(subject.color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: subject.icon)
                        .font(.title3)
                        .foregroundStyle(subject.color)
                }

                // Text
                VStack(alignment: .leading, spacing: Nova.Spacing.xxs) {
                    Text(subject.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subject.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Toca dos veces para abrir")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Result Row
struct ChatResultRow: View {
    let message: ChatMessage
    let searchText: String
    let onTap: () -> Void

    private var subject: Subject? {
        Subject(rawValue: message.subjectId)
    }

    private var highlightedContent: AttributedString {
        let originalContent = message.content
        var content: String
        var addPrefixEllipsis = false
        var addSuffixEllipsis = false

        if let range = originalContent.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) {
            let startIndex = originalContent.index(range.lowerBound, offsetBy: -50, limitedBy: originalContent.startIndex) ?? originalContent.startIndex
            let endIndex = originalContent.index(range.upperBound, offsetBy: 100, limitedBy: originalContent.endIndex) ?? originalContent.endIndex
            content = String(originalContent[startIndex..<endIndex])
            addPrefixEllipsis = startIndex != originalContent.startIndex
            addSuffixEllipsis = endIndex != originalContent.endIndex
        } else if originalContent.count > 150 {
            content = String(originalContent.prefix(150))
            addSuffixEllipsis = true
        } else {
            content = originalContent
        }

        if addPrefixEllipsis { content = "..." + content }
        if addSuffixEllipsis { content = content + "..." }

        var attributed = AttributedString(content)

        if let range = attributed.range(of: searchText, options: .caseInsensitive) {
            attributed[range].backgroundColor = .yellow.opacity(0.4)
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
        }

        return attributed
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.timestamp, relativeTo: Date())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Nova.Spacing.md) {
                ZStack {
                    Circle()
                        .fill((subject?.color ?? .gray).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: message.role == .user ? "person.fill" : "sparkles")
                        .font(.body)
                        .foregroundStyle(subject?.color ?? .gray)
                }

                VStack(alignment: .leading, spacing: Nova.Spacing.xs) {
                    HStack {
                        Text(subject?.displayName ?? "Chat")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(formattedDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(highlightedContent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(Nova.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.md))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Toca dos veces para ver esta conversación")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subject Extensions for Search
extension Subject {
    var searchKeywords: [String] {
        switch self {
        case .math:
            return ["álgebra", "algebra", "cálculo", "calculo", "geometría", "geometria", "números", "numeros", "ecuaciones", "matemática", "matematica"]
        case .physics:
            return ["mecánica", "mecanica", "energía", "energia", "fuerza", "movimiento", "ondas", "electricidad"]
        case .chemistry:
            return ["elementos", "reacciones", "átomos", "atomos", "moléculas", "moleculas", "tabla periódica", "tabla periodica"]
        case .science:
            return ["biología", "biologia", "naturaleza", "animales", "plantas", "ecosistema", "ciencia"]
        case .social:
            return ["historia", "geografía", "geografia", "sociedad", "cultura", "economía", "economia"]
        case .language:
            return ["español", "espanol", "gramática", "gramatica", "literatura", "escritura", "lectura", "lengua"]
        case .english:
            return ["idioma", "vocabulario", "grammar", "speaking", "writing"]
        case .ethics:
            return ["valores", "moral", "ciudadanía", "ciudadania", "convivencia", "filosofía", "filosofia"]
        case .technology:
            return ["computación", "computacion", "programación", "programacion", "internet", "digital", "informática", "informatica"]
        case .arts:
            return ["música", "musica", "pintura", "dibujo", "teatro", "danza", "creatividad"]
        case .sports:
            return ["educación física", "educacion fisica", "ejercicio", "deporte", "salud", "actividad"]
        case .open:
            return ["general", "libre", "cualquier", "otro", "pregunta"]
        }
    }

    var shortDescription: String {
        switch self {
        case .math:
            return "Álgebra, cálculo, geometría y más"
        case .physics:
            return "Mecánica, energía y fenómenos físicos"
        case .chemistry:
            return "Elementos, reacciones y compuestos"
        case .science:
            return "Biología, ecología y medio ambiente"
        case .social:
            return "Historia, geografía y sociedad"
        case .language:
            return "Gramática, literatura y expresión"
        case .english:
            return "Vocabulario, gramática y conversación"
        case .ethics:
            return "Valores, ciudadanía y convivencia"
        case .technology:
            return "Computación, programación y digital"
        case .arts:
            return "Música, pintura y expresión artística"
        case .sports:
            return "Educación física y bienestar"
        case .open:
            return "Pregunta sobre cualquier tema"
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(selectedSubject: .constant(nil), settings: UserSettings())
    }
}
