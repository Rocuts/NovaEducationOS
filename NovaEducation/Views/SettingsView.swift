import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext
    @State private var showingNameEditor = false
    @State private var tempName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Section
                profileSection

                // Study Preferences
                studyPreferencesSection

                // Notifications
                notificationsSection

                // Appearance
                appearanceSection

                // Accessibility
                accessibilitySection

                // About
                aboutSection
            }
            .padding()
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingNameEditor) {
            nameEditorSheet
        }
        .onChange(of: settings.notificationsEnabled) {
            updateNotifications()
        }
        .onChange(of: settings.studyRemindersEnabled) {
            updateNotifications()
        }
        .onChange(of: settings.studyReminderTime) {
            updateNotifications()
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.purple.opacity(0.03),
                Color.blue.opacity(0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 16) {
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
            VStack(spacing: 4) {
                Text(settings.studentName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(settings.educationLevel.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Edit Button
            Button {
                tempName = settings.studentName
                showingNameEditor = true
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
        .padding(.vertical, 24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
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
                    subtitle: "Feedback haptico al interactuar",
                    isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: {
                            settings.hapticsEnabled = $0
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
                SettingsRow(icon: "app.badge.fill", iconColor: .blue, title: "Version") {
                    Text("1.0.0")
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
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Tu nombre")
                        .font(.headline)

                    Text("Este nombre aparecera en la pantalla de inicio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Nombre", text: $tempName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                Spacer()
            }
            .padding()
            .navigationTitle("Editar nombre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        showingNameEditor = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if !tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            settings.studentName = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                            settings.updatedAt = Date()
                        }
                        showingNameEditor = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    private func updateNotifications() {
        if settings.notificationsEnabled && settings.studyRemindersEnabled {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleDailyReminder(at: settings.studyReminderTime)
        } else {
            NotificationManager.shared.cancelReminders()
        }
    }
}

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.gradient)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        SettingsView(settings: UserSettings())
    }
    .modelContainer(for: [ChatMessage.self, UserSettings.self, StudySession.self, DailyActivity.self, Achievement.self], inMemory: true)
}
