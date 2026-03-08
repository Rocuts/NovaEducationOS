import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Nova.Spacing.sectionGap) {
                // Profile Section
                profileSection
                    .opacity(viewModel.sectionsAppeared ? 1 : 0)
                    .offset(y: viewModel.sectionsAppeared ? 0 : 15)
                    .animation(Nova.Animation.stagger(index: 0), value: viewModel.sectionsAppeared)

                // Study Preferences
                studyPreferencesSection
                    .opacity(viewModel.sectionsAppeared ? 1 : 0)
                    .offset(y: viewModel.sectionsAppeared ? 0 : 15)
                    .animation(Nova.Animation.stagger(index: 1), value: viewModel.sectionsAppeared)

                // Notifications
                notificationsSection
                    .opacity(viewModel.sectionsAppeared ? 1 : 0)
                    .offset(y: viewModel.sectionsAppeared ? 0 : 15)
                    .animation(Nova.Animation.stagger(index: 2), value: viewModel.sectionsAppeared)

                // Appearance
                appearanceSection
                    .opacity(viewModel.sectionsAppeared ? 1 : 0)
                    .offset(y: viewModel.sectionsAppeared ? 0 : 15)
                    .animation(Nova.Animation.stagger(index: 3), value: viewModel.sectionsAppeared)

                // Accessibility
                accessibilitySection
                    .opacity(viewModel.sectionsAppeared ? 1 : 0)
                    .offset(y: viewModel.sectionsAppeared ? 0 : 15)
                    .animation(Nova.Animation.stagger(index: 4), value: viewModel.sectionsAppeared)

                // About
                aboutSection
                    .opacity(viewModel.sectionsAppeared ? 1 : 0)
                    .offset(y: viewModel.sectionsAppeared ? 0 : 15)
                    .animation(Nova.Animation.stagger(index: 5), value: viewModel.sectionsAppeared)
            }
            .padding()
            .onAppear { viewModel.sectionsAppeared = true }
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .sheet(isPresented: $viewModel.showingNameEditor) {
            nameEditorSheet
        }
        .alert("Notificaciones deshabilitadas", isPresented: $viewModel.showNotificationDeniedAlert) {
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Para recibir recordatorios de estudio, habilita las notificaciones en los ajustes del sistema.")
        }
        .onChange(of: settings.notificationsEnabled) {
            viewModel.updateNotifications(settings: settings)
        }
        .onChange(of: settings.studyRemindersEnabled) {
            viewModel.updateNotifications(settings: settings)
        }
        .onChange(of: settings.studyReminderTime) {
            viewModel.updateNotifications(settings: settings)
        }
    }

    private var backgroundGradient: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: Nova.Spacing.lg) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text(settings.studentName.prefix(1).uppercased())
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)

            // Name
            VStack(spacing: Nova.Spacing.xxs) {
                Text(settings.studentName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(settings.educationLevel.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Edit Button
            Button {
                viewModel.tempName = settings.studentName
                viewModel.showingNameEditor = true
            } label: {
                Label("Editar perfil", systemImage: "pencil")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Nova.Spacing.xxl)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.sheet))
    }

    // MARK: - Study Preferences
    private var studyPreferencesSection: some View {
        SettingsSection(title: "Preferencias de estudio", icon: "book.fill") {
            VStack(spacing: 0) {
                // Education Level
                SettingsRow(icon: "graduationcap.fill", iconColor: .blue, title: "Nivel educativo") {
                    Menu {
                        ForEach(EducationLevel.allCases, id: \.self) { level in
                            Button {
                                settings.educationLevel = level
                                settings.updatedAt = Date()
                            } label: {
                                Label(level.displayName, systemImage: level.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(settings.educationLevel.displayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Divider()
                    .padding(.leading, 52)

                // Daily Goal
                SettingsRow(icon: "target", iconColor: .orange, title: "Meta diaria") {
                    Menu {
                        ForEach([0, 15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                            Button {
                                settings.dailyGoalMinutes = minutes
                                settings.updatedAt = Date()
                            } label: {
                                if minutes == 0 {
                                    Text("Sin meta")
                                } else {
                                    Text("\(minutes) min")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(settings.dailyGoalMinutes == 0 ? "Sin meta" : "\(settings.dailyGoalMinutes) min")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notifications
    private var notificationsSection: some View {
        SettingsSection(title: "Notificaciones", icon: "bell.fill") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.badge.fill",
                    iconColor: .red,
                    title: "Notificaciones",
                    subtitle: "Recibe alertas de la app",
                    isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: {
                            settings.notificationsEnabled = $0
                            settings.updatedAt = Date()
                        }
                    )
                )

                if settings.notificationsEnabled {
                    Divider()
                        .padding(.leading, 52)

                    SettingsToggleRow(
                        icon: "alarm.fill",
                        iconColor: .purple,
                        title: "Recordatorios de estudio",
                        subtitle: "Te recordamos estudiar diariamente",
                        isOn: Binding(
                            get: { settings.studyRemindersEnabled },
                            set: {
                                settings.studyRemindersEnabled = $0
                                settings.updatedAt = Date()
                            }
                        )
                    )

                    if settings.studyRemindersEnabled {
                        Divider()
                            .padding(.leading, 52)

                        SettingsRow(icon: "clock.fill", iconColor: .indigo, title: "Hora del recordatorio") {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { settings.studyReminderTime },
                                    set: {
                                        settings.studyReminderTime = $0
                                        settings.updatedAt = Date()
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Appearance
    private var appearanceSection: some View {
        SettingsSection(title: "Apariencia", icon: "paintbrush.fill") {
            VStack(spacing: 0) {
                SettingsRow(icon: "circle.lefthalf.filled", iconColor: .cyan, title: "Tema") {
                    Menu {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button {
                                settings.preferredTheme = theme
                                settings.updatedAt = Date()
                            } label: {
                                Label(theme.displayName, systemImage: theme.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(settings.preferredTheme.displayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Accessibility
    private var accessibilitySection: some View {
        SettingsSection(title: "Accesibilidad", icon: "accessibility") {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "speaker.wave.2.fill",
                    iconColor: .green,
                    title: "Sonidos",
                    subtitle: "Efectos de sonido en la app",
                    isOn: Binding(
                        get: { settings.soundsEnabled },
                        set: {
                            settings.soundsEnabled = $0
                            settings.updatedAt = Date()
                        }
                    )
                )

                Divider()
                    .padding(.leading, 52)

                SettingsToggleRow(
                    icon: "hand.tap.fill",
                    iconColor: .pink,
                    title: "Vibraciones",
                    subtitle: "Feedback háptico al interactuar",
                    isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: {
                            settings.hapticsEnabled = $0
                            Nova.Haptics.isEnabled = $0
                            settings.updatedAt = Date()
                        }
                    )
                )
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        SettingsSection(title: "Acerca de", icon: "info.circle.fill") {
            VStack(spacing: 0) {
                SettingsRow(icon: "app.badge.fill", iconColor: .blue, title: "Versión") {
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.leading, 52)

                SettingsRow(icon: "heart.fill", iconColor: .red, title: "Hecho con") {
                    Text("SwiftUI + Liquid Glass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Name Editor Sheet
    private var nameEditorSheet: some View {
        NavigationStack {
            VStack(spacing: Nova.Spacing.xxl) {
                VStack(spacing: Nova.Spacing.sm) {
                    Text("Tu nombre")
                        .font(.headline)

                    Text("Este nombre aparecerá en la pantalla de inicio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Nombre", text: $viewModel.tempName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))

                Spacer()
            }
            .padding()
            .navigationTitle("Editar nombre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.showingNameEditor = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        viewModel.saveName(settings: settings)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.md) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, Nova.Spacing.xxs)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                content
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: Nova.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Nova.Radius.sm)
                    .fill(iconColor.gradient)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.body)

            Spacer()

            accessory
        }
        .padding(.horizontal, Nova.Spacing.lg)
        .padding(.vertical, Nova.Spacing.md)
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Nova.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Nova.Radius.sm)
                    .fill(iconColor.gradient)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: Nova.Spacing.xxxs) {
                Text(title)
                    .font(.body)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(.horizontal, Nova.Spacing.lg)
        .padding(.vertical, Nova.Spacing.sm)
    }
}

#Preview {
    NavigationStack {
        SettingsView(settings: UserSettings())
    }
    .modelContainer(for: [ChatMessage.self, UserSettings.self, StudySession.self, DailyActivity.self, Achievement.self], inMemory: true)
}
