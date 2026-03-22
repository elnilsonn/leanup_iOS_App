import SwiftUI
struct LeanUpSettingsView: View {
    @ObservedObject var model: LeanUpAppModel
    @State private var draftName = ""
    @State private var showResetNameAlert = false
    @State private var showClearProgressAlert = false
    @State private var nameSaveFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LeanUpSettingsProfileCard(
                    draftName: $draftName,
                    isSaved: nameSaveFeedback,
                    onSave: saveName,
                    onReset: { showResetNameAlert = true }
                )

                LeanUpSettingsAppearanceCard(model: model)

                LeanUpSettingsDataCard(
                    model: model,
                    onClearProgress: { showClearProgressAlert = true }
                )

                LeanUpSettingsAboutCard()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .onAppear {
                draftName = model.snapshot.username
            }
        }
        .leanUpKeyboardFriendlyScroll()
        .background(LeanUpPageBackground())
        .navigationTitle("Configuracion")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reiniciar nombre", isPresented: $showResetNameAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Reiniciar", role: .destructive) {
                model.resetUsername()
                draftName = model.snapshot.username
                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                    nameSaveFeedback = false
                }
            }
        } message: {
            Text("Tu saludo volvera al nombre por defecto de LeanUp.")
        }
        .alert("Limpiar progreso academico", isPresented: $showClearProgressAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar progreso", role: .destructive) {
                model.clearAcademicProgress()
            }
        } message: {
            Text("Se borraran notas y electivas seleccionadas guardadas en este iPhone. Tu nombre y tema se conservaran.")
        }
    }

    private func saveName() {
        model.setUsername(draftName)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            nameSaveFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                nameSaveFeedback = false
            }
        }
    }
}

struct LeanUpSettingsProfileCard: View {
    @Binding var draftName: String
    let isSaved: Bool
    let onSave: () -> Void
    let onReset: () -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Perfil de usuario", systemImage: "person.text.rectangle.fill")
                    .font(.headline.weight(.semibold))

                Text("Gestiona el nombre con el que LeanUp te saluda y personaliza tu experiencia dentro de la app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tu nombre")
                        .font(.subheadline.weight(.semibold))

                    TextField("Escribe tu nombre", text: $draftName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .onSubmit(onSave)

                    Text("Este nombre aparece en el saludo principal del Dashboard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button(action: onSave) {
                        Label(isSaved ? "Guardado" : "Guardar nombre", systemImage: isSaved ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(LeanUpPrimaryButtonStyle())
                    .scaleEffect(isSaved ? 1.02 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSaved)

                    Button(action: onReset) {
                        Label("Reiniciar", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(LeanUpSecondaryButtonStyle())
                }
            }
        }
    }
}

struct LeanUpSettingsAppearanceCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Apariencia", systemImage: "circle.lefthalf.filled")
                    .font(.headline.weight(.semibold))

                Text("Elige como quieres ver LeanUp en tu iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(LeanUpThemeMode.allCases, id: \.self) { mode in
                    Button {
                        model.setTheme(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: mode))
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(title(for: mode))
                                    .font(.subheadline.weight(.semibold))
                                Text(description(for: mode))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: model.snapshot.themeMode == mode ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.snapshot.themeMode == mode ? Color.unadBlue : .secondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(model.snapshot.themeMode == mode ? Color.unadBlue.opacity(0.10) : Color.primary.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func title(for mode: LeanUpThemeMode) -> String {
        switch mode {
        case .light: return "Claro"
        case .dark: return "Oscuro"
        case .system: return "Sistema"
        }
    }

    private func description(for mode: LeanUpThemeMode) -> String {
        switch mode {
        case .light: return "Usa una apariencia limpia y luminosa."
        case .dark: return "Prioriza contraste suave para la noche."
        case .system: return "Sigue automaticamente el modo del iPhone."
        }
    }

    private func icon(for mode: LeanUpThemeMode) -> String {
        switch mode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "iphone"
        }
    }
}

struct LeanUpSettingsDataCard: View {
    @ObservedObject var model: LeanUpAppModel
    let onClearProgress: () -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Datos guardados", systemImage: "internaldrive.fill")
                    .font(.headline.weight(.semibold))

                Text("LeanUp guarda tus cambios automaticamente en este iPhone para que tu progreso este siempre disponible y ordenado.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    LeanUpInlineMetric(title: "Notas", value: "\(model.registeredCount)")
                    LeanUpInlineMetric(title: "Aprobadas", value: "\(model.approvedCount)")
                    LeanUpInlineMetric(title: "Electivas", value: "\(model.selectedElectivesCount)")
                    LeanUpInlineMetric(title: "Creditos", value: "\(model.earnedCredits)")
                }

                VStack(alignment: .leading, spacing: 10) {
                    LeanUpSettingsInfoRow(title: "Tema activo", value: model.themeDescription)
                    LeanUpSettingsInfoRow(title: "Nombre actual", value: model.snapshot.username)
                    LeanUpSettingsInfoRow(title: "Estado", value: "Guardado local activo")
                }

                Button(action: onClearProgress) {
                    Label("Limpiar progreso academico", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(LeanUpSecondaryButtonStyle())
            }
        }
    }
}

struct LeanUpSettingsAboutCard: View {
    private let appInfo = LeanUpAppInfo.current

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Acerca de LeanUp", systemImage: "info.circle.fill")
                    .font(.headline.weight(.semibold))

                VStack(alignment: .leading, spacing: 6) {
                    Text(appInfo.displayName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Guia academica y profesional para Marketing y Negocios Digitales en la UNAD.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    LeanUpSettingsInfoRow(title: "Version", value: appInfo.versionLine)
                    LeanUpSettingsInfoRow(title: "Desarrollador", value: "Nilson Leandro Solis Asprilla")
                    LeanUpSettingsInfoRow(title: "Programa", value: "Marketing y Negocios Digitales - UNAD")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Contacto")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 10) {
                        if let whatsappURL = appInfo.whatsappURL {
                            Link(destination: whatsappURL) {
                                Label("WhatsApp", systemImage: "message.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(LeanUpSecondaryButtonStyle())
                        }

                        if let emailURL = appInfo.emailURL {
                            Link(destination: emailURL) {
                                Label("Correo", systemImage: "envelope.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(LeanUpSecondaryButtonStyle())
                        }
                    }

                    if let githubURL = appInfo.githubURL {
                        Link(destination: githubURL) {
                            Label("Repositorio en GitHub", systemImage: "link")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(LeanUpSecondaryButtonStyle())
                    }
                }
            }
        }
    }
}

struct LeanUpSettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }
}

struct LeanUpAppInfo {
    let displayName: String
    let version: String
    let build: String

    static let current = LeanUpAppInfo(
        displayName: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "LeanUp",
        version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    )

    var versionLine: String {
        "v\(version) - build \(build)"
    }

    var emailURL: URL? {
        URL(string: "mailto:nsolisasprilla@icloud.com?subject=Contacto%20desde%20LeanUp")
    }

    var whatsappURL: URL? {
        URL(string: "https://wa.me/34645568327")
    }

    var githubURL: URL? {
        URL(string: "https://github.com/elnilsonn/leanup-app")
    }
}


