import SwiftUI

private struct LeanUpSettingsViewData {
    let currentDisplayName: String
    let themeDescription: String
    let currentThemeMode: LeanUpThemeMode
    let registeredCountText: String
    let approvedCountText: String
    let selectedElectivesCountText: String
    let earnedCreditsText: String
    let localStorageStatusText: String

    init(model: LeanUpAppModel) {
        currentDisplayName = model.currentDisplayName
        themeDescription = model.themeDescription
        currentThemeMode = model.snapshot.themeMode
        registeredCountText = "\(model.registeredCount)"
        approvedCountText = "\(model.approvedCount)"
        selectedElectivesCountText = "\(model.selectedElectivesCount)"
        earnedCreditsText = "\(model.earnedCredits)"
        localStorageStatusText = model.localStorageStatusText
    }
}

struct LeanUpSettingsView: View {
    @ObservedObject var model: LeanUpAppModel
    @State private var draftName = ""
    @State private var showResetNameAlert = false
    @State private var showClearProgressAlert = false
    @State private var nameSaveFeedback = false

    var body: some View {
        let data = LeanUpSettingsViewData(model: model)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LeanUpSettingsQuickControlCard(
                    currentDisplayName: data.currentDisplayName,
                    themeDescription: data.themeDescription
                )

                LeanUpSettingsIdentityCard(
                    draftName: $draftName,
                    isSaved: nameSaveFeedback,
                    onSave: saveName,
                    onReset: { showResetNameAlert = true }
                )

                LeanUpSettingsAppearanceCard(
                    currentThemeMode: data.currentThemeMode,
                    onSelectTheme: { model.setTheme($0) }
                )

                LeanUpSettingsStorageCard(
                    registeredCountText: data.registeredCountText,
                    approvedCountText: data.approvedCountText,
                    selectedElectivesCountText: data.selectedElectivesCountText,
                    earnedCreditsText: data.earnedCreditsText,
                    currentDisplayName: data.currentDisplayName,
                    themeDescription: data.themeDescription,
                    localStorageStatusText: data.localStorageStatusText,
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
            Text("Tu nombre volvera al valor por defecto de LeanUp.")
        }
        .alert("Limpiar progreso academico", isPresented: $showClearProgressAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar progreso", role: .destructive) {
                model.clearAcademicProgress()
            }
        } message: {
            Text("Se borraran notas y electivas guardadas en este iPhone. Tu nombre y el tema activo se conservaran.")
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

private struct LeanUpSettingsQuickControlCard: View {
    let currentDisplayName: String
    let themeDescription: String

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Centro de control")
                            .font(.title3.weight(.bold))
                        Text("Desde aqui ajustas tu identidad, el aspecto visual y el estado local de LeanUp en este iPhone.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.unadBlue)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.unadBlue.opacity(0.10))
                        )
                }

                HStack(spacing: 10) {
                    LeanUpSettingsMetricBadge(title: "Nombre", value: currentDisplayName)
                    LeanUpSettingsMetricBadge(title: "Tema", value: themeDescription)
                    LeanUpSettingsMetricBadge(title: "Estado", value: "Local")
                }
            }
        }
    }
}

private struct LeanUpSettingsIdentityCard: View {
    @Binding var draftName: String
    let isSaved: Bool
    let onSave: () -> Void
    let onReset: () -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Identidad",
                    title: "Como quieres que te vea LeanUp",
                    detail: "Este nombre ayuda a que LeanUp te hable de una forma mas cercana, clara y personal."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre visible")
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

                    Text("Se usa en saludos y lecturas personalizadas dentro de LeanUp.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button(action: onSave) {
                        Label(isSaved ? "Guardado" : "Guardar", systemImage: isSaved ? "checkmark.seal.fill" : "checkmark.circle.fill")
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

private struct LeanUpSettingsAppearanceCard: View {
    let currentThemeMode: LeanUpThemeMode
    let onSelectTheme: (LeanUpThemeMode) -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Apariencia",
                    title: "Como quieres ver la app",
                    detail: "Elige una apariencia estable para este iPhone o deja que LeanUp siga el modo del sistema."
                )

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(LeanUpThemeMode.allCases, id: \.self) { mode in
                        Button {
                            onSelectTheme(mode)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: mode))
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(currentThemeMode == mode ? Color.unadBlue : .secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title(for: mode))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(description(for: mode))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: currentThemeMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(currentThemeMode == mode ? Color.unadBlue : .secondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(currentThemeMode == mode ? Color.unadBlue.opacity(0.10) : Color.primary.opacity(0.05))
                            )
                        }
                        .buttonStyle(.plain)
                    }
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
        case .light: return "Limpio, brillante y directo."
        case .dark: return "Mas comodo para sesiones largas o de noche."
        case .system: return "Sigue automaticamente la preferencia del iPhone."
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

private struct LeanUpSettingsStorageCard: View {
    let registeredCountText: String
    let approvedCountText: String
    let selectedElectivesCountText: String
    let earnedCreditsText: String
    let currentDisplayName: String
    let themeDescription: String
    let localStorageStatusText: String
    let onClearProgress: () -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Datos",
                    title: "Tus datos en este iPhone",
                    detail: "LeanUp guarda tu avance localmente para que tu progreso se mantenga estable, privado y siempre disponible en este iPhone."
                )

                HStack(spacing: 10) {
                    LeanUpSettingsMetricBadge(title: "Notas", value: registeredCountText)
                    LeanUpSettingsMetricBadge(title: "Aprobadas", value: approvedCountText)
                }

                HStack(spacing: 10) {
                    LeanUpSettingsMetricBadge(title: "Electivas", value: selectedElectivesCountText)
                    LeanUpSettingsMetricBadge(title: "Creditos", value: earnedCreditsText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    LeanUpSettingsInfoRow(title: "Nombre actual", value: currentDisplayName)
                    LeanUpSettingsInfoRow(title: "Tema activo", value: themeDescription)
                    LeanUpSettingsInfoRow(title: "Estado local", value: localStorageStatusText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Mantenimiento")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Si necesitas empezar de nuevo, puedes limpiar solo el progreso academico guardado. Tu nombre y la apariencia se conservan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(action: onClearProgress) {
                        Label("Limpiar progreso academico", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(LeanUpSecondaryButtonStyle())
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.red.opacity(0.05))
                )
            }
        }
    }
}

private struct LeanUpSettingsAboutCard: View {
    private let appInfo = LeanUpAppInfo.current

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Acerca de",
                    title: appInfo.displayName,
                    detail: "LeanUp para iPhone, pensado como apoyo nativo para Marketing y Negocios Digitales en la UNAD."
                )

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

private struct LeanUpSettingsMetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
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
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

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
