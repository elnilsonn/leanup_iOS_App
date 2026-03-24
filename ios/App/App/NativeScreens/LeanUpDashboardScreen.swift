import SwiftUI

@MainActor
private struct LeanUpDashboardViewData {
    let username: String
    let heroMessage: String
    let heroBadgeIcon: String
    let heroBadgeValue: String
    let heroBadgeLabel: String
    let averageText: String
    let focusPeriodText: String
    let earnedCreditsText: String
    let registeredCountText: String
    let completedPeriodsCountText: String
    let pendingCountText: String
    let approvedCountText: String
    let failedCount: Int
    let paceTitle: String
    let paceDetail: String
    let paceValueText: String
    let remainingPeriodsText: String
    let inProgressCountText: String
    let completionPercentText: String
    let completionRatio: Double
    let periodAverageSeries: [LeanUpPeriodAveragePoint]
    let strongestCourses: [LeanUpGradedCourse]
    let mostDemandingCourses: [LeanUpGradedCourse]
    let unlockedAchievements: [LeanUpAchievement]
    let nextLockedAchievement: LeanUpAchievement?

    init(model: LeanUpAppModel) {
        let focusPeriod = model.focusPeriod.map(String.init) ?? "Listo"
        let completionText = model.completionPercentText
        let estimatedGraduationShortText = model.estimatedGraduationShortText

        username = model.snapshot.username
        averageText = model.averageText
        focusPeriodText = focusPeriod
        earnedCreditsText = "\(model.earnedCredits)"
        registeredCountText = "\(model.registeredCount)"
        completedPeriodsCountText = "\(model.completedPeriodsCount)"
        pendingCountText = "\(model.pendingCount)"
        approvedCountText = "\(model.approvedCount)"
        failedCount = model.failedCount
        paceTitle = model.paceTitle
        paceDetail = model.paceDetail
        paceValueText = model.paceValueText
        remainingPeriodsText = model.remainingPeriodsText
        inProgressCountText = model.inProgressCountText
        completionPercentText = completionText
        completionRatio = model.completionRatio
        periodAverageSeries = model.periodAverageSeries
        strongestCourses = model.strongestCourses
        mostDemandingCourses = model.mostDemandingCourses
        unlockedAchievements = model.unlockedAchievements
        nextLockedAchievement = model.nextLockedAchievement

        if model.approvedCount >= model.totalTrackableItems, model.totalTrackableItems > 0 {
            heroMessage = "Tu carrera ya se puede leer como una historia academica cerrada dentro de LeanUp."
        } else if model.failedCount > 0 {
            heroMessage = "Tu avance ya tiene suficiente informacion para tomar decisiones. Lo que mas puede acelerar tu ritmo ahora es recuperar los frentes en rojo."
        } else if model.registeredCount >= 3, model.estimatedGraduationText != nil {
            heroMessage = "Ya se puede proyectar el cierre de la carrera usando el ritmo real con el que vienes aprobando la malla."
        } else {
            heroMessage = "Registra mas notas y LeanUp podra leer con mas precision tu ritmo, la evolucion del promedio y la fecha estimada de grado."
        }

        heroBadgeIcon = estimatedGraduationShortText == nil ? "chart.xyaxis.line" : "calendar.badge.clock"
        heroBadgeValue = estimatedGraduationShortText ?? completionPercentText
        heroBadgeLabel = estimatedGraduationShortText == nil ? "Cierre actual" : "Grado estimado"
    }
}

struct LeanUpDashboardView: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        let data = LeanUpDashboardViewData(model: model)

        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - 40, 0)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LeanUpDashboardHero(
                        username: data.username,
                        message: data.heroMessage,
                        badgeIcon: data.heroBadgeIcon,
                        badgeValue: data.heroBadgeValue,
                        badgeLabel: data.heroBadgeLabel,
                        averageText: data.averageText,
                        focusPeriodText: data.focusPeriodText,
                        earnedCreditsText: data.earnedCreditsText,
                        registeredCountText: data.registeredCountText,
                        completedPeriodsCountText: data.completedPeriodsCountText
                    )
                    LeanUpDashboardSnapshotBand(
                        averageText: data.averageText,
                        earnedCreditsText: data.earnedCreditsText,
                        approvedCountText: data.approvedCountText,
                        pendingCountText: data.pendingCountText,
                        failedCount: data.failedCount
                    )
                    LeanUpDashboardPaceCard(
                        title: data.paceTitle,
                        detail: data.paceDetail,
                        valueText: data.paceValueText,
                        remainingPeriodsText: data.remainingPeriodsText,
                        inProgressCountText: data.inProgressCountText,
                        completionPercentText: data.completionPercentText,
                        completionRatio: data.completionRatio
                    )
                    LeanUpDashboardGpaTrackerCard(
                        points: data.periodAverageSeries
                    )
                    LeanUpDashboardPerformanceCard(
                        strongestCourses: data.strongestCourses,
                        mostDemandingCourses: data.mostDemandingCourses
                    )
                    LeanUpDashboardAchievementsCard(
                        unlockedAchievements: data.unlockedAchievements,
                        nextLockedAchievement: data.nextLockedAchievement
                    )
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(LeanUpPageBackground())
        .navigationTitle("LeanUp")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct LeanUpDashboardHero: View {
    let username: String
    let message: String
    let badgeIcon: String
    let badgeValue: String
    let badgeLabel: String
    let averageText: String
    let focusPeriodText: String
    let earnedCreditsText: String
    let registeredCountText: String
    let completedPeriodsCountText: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(heroGradient)

            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                .frame(width: 216, height: 216)
                .offset(x: 178, y: -84)

            Circle()
                .fill(Color.unadGold.opacity(0.12))
                .frame(width: 96, height: 96)
                .offset(x: 216, y: -10)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Panel de avance")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.white.opacity(0.74))

                        Text("Hola, \(username)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.82))
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        Image(systemName: badgeIcon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.unadGold)

                        Text(badgeValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)

                        Text(badgeLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                }

                HStack(spacing: 12) {
                    LeanUpInlineMetric(title: "Promedio", value: averageText)
                    LeanUpInlineMetric(title: "Periodo foco", value: focusPeriodText)
                }

                HStack(spacing: 10) {
                    LeanUpPill(text: "\(earnedCreditsText) creditos", icon: "bolt.fill")
                    LeanUpPill(text: "\(registeredCountText) notas", icon: "chart.bar.fill")
                    LeanUpPill(text: "\(completedPeriodsCountText) periodos cerrados", icon: "flag.checkered")
                }
            }
            .padding(24)
        }
        .shadow(color: Color.unadNavy.opacity(scheme == .dark ? 0.035 : 0.07), radius: scheme == .dark ? 2 : 6, x: 0, y: scheme == .dark ? 1 : 4)
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.unadNavy.opacity(scheme == .dark ? 0.98 : 0.94),
                Color.unadBlue.opacity(scheme == .dark ? 0.90 : 0.86),
                Color.unadCyan.opacity(scheme == .dark ? 0.76 : 0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

}

struct LeanUpDashboardSnapshotBand: View {
    let averageText: String
    let earnedCreditsText: String
    let approvedCountText: String
    let pendingCountText: String
    let failedCount: Int

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            LeanUpDashboardStatTile(
                eyebrow: "Promedio",
                value: averageText,
                subtitle: "Rendimiento acumulado",
                tint: .unadBlue,
                icon: "waveform.path.ecg"
            )
            LeanUpDashboardStatTile(
                eyebrow: "Creditos",
                value: earnedCreditsText,
                subtitle: "Ganados hasta hoy",
                tint: .unadGold,
                icon: "bolt.badge.checkmark.fill"
            )
            LeanUpDashboardStatTile(
                eyebrow: "Aprobadas",
                value: approvedCountText,
                subtitle: "Base consolidada",
                tint: .green,
                icon: "checkmark.seal.fill"
            )
            LeanUpDashboardStatTile(
                eyebrow: "Pendientes",
                value: pendingCountText,
                subtitle: "Aun por cerrar",
                tint: failedCount > 0 ? .orange : .unadCyan,
                icon: "scope"
            )
        }
    }
}

struct LeanUpDashboardPaceCard: View {
    let title: String
    let detail: String
    let valueText: String
    let remainingPeriodsText: String
    let inProgressCountText: String
    let completionPercentText: String
    let completionRatio: Double

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 12),
        GridItem(.flexible(minimum: 0), spacing: 12),
        GridItem(.flexible(minimum: 0), spacing: 12)
    ]

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LeanUpSectionHeader(
                    eyebrow: "Ritmo de avance",
                    title: title,
                    detail: detail
                )

                LazyVGrid(columns: columns, spacing: 12) {
                    LeanUpDashboardAccentStat(
                        title: "Ritmo",
                        value: valueText,
                        caption: "Periodos equivalentes por tramo cursado",
                        tint: .unadBlue
                    )

                    LeanUpDashboardAccentStat(
                        title: "Restan",
                        value: remainingPeriodsText,
                        caption: "Periodos estimados",
                        tint: .unadGold
                    )

                    LeanUpDashboardAccentStat(
                        title: "En curso",
                        value: inProgressCountText,
                        caption: "Carga activa",
                        tint: .unadCyan
                    )
                }

                LeanUpProgressTrack(
                    title: "Malla aprobada hasta ahora",
                    valueText: completionPercentText,
                    progress: completionRatio,
                    tint: .unadBlue
                )
            }
        }
    }
}

struct LeanUpDashboardGpaTrackerCard: View {
    let points: [LeanUpPeriodAveragePoint]

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LeanUpSectionHeader(
                    eyebrow: "GPA tracker",
                    title: trendTitle,
                    detail: trendDetail
                )

                if points.isEmpty {
                    LeanUpDashboardEmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "Todavia no hay suficientes notas distribuidas por periodo para dibujar la evolucion del promedio."
                    )
                } else {
                    LeanUpDashboardLineChart(points: points)

                    HStack(spacing: 12) {
                        LeanUpDashboardAccentStat(
                            title: "Ultimo",
                            value: latestAverageText,
                            caption: latestCaption,
                            tint: .unadBlue
                        )
                        LeanUpDashboardAccentStat(
                            title: "Mejor",
                            value: bestAverageText,
                            caption: bestCaption,
                            tint: .green
                        )
                    }
                }
            }
        }
    }

    private var trendTitle: String {
        guard let first = points.first,
              let last = points.last else {
            return "Tu evolucion del promedio aparecera aqui."
        }

        let delta = last.average - first.average
        if abs(delta) < 0.1 {
            return "Tu promedio viene bastante estable entre periodos."
        }

        if delta > 0 {
            return "Tu promedio muestra una evolucion positiva."
        }

        return "Tu promedio pide una correccion en los siguientes periodos."
    }

    private var trendDetail: String {
        guard points.count > 1 else {
            return "A medida que registres mas periodos, podras ver si tu rendimiento se esta estabilizando o no."
        }

        return "Este grafico usa tus notas reales por periodo para mostrar si el promedio ha venido subiendo, bajando o sosteniendose."
    }

    private var latestAverageText: String {
        guard let latest = points.last else { return "--" }
        return String(format: "%.2f", latest.average)
    }

    private var latestCaption: String {
        guard let latest = points.last else { return "Sin periodo" }
        return "Periodo \(latest.period)"
    }

    private var bestAverageText: String {
        guard let best = points.max(by: { $0.average < $1.average }) else { return "--" }
        return String(format: "%.2f", best.average)
    }

    private var bestCaption: String {
        guard let best = points.max(by: { $0.average < $1.average }) else { return "Sin pico" }
        return "Pico en P\(best.period)"
    }
}

struct LeanUpDashboardPerformanceCard: View {
    let strongestCourses: [LeanUpGradedCourse]
    let mostDemandingCourses: [LeanUpGradedCourse]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LeanUpSectionHeader(
                    eyebrow: "Lectura de rendimiento",
                    title: "Tus notas ya dejan ver donde te fue mejor y donde te costo mas.",
                    detail: "La idea no es etiquetar materias faciles o dificiles en abstracto, sino leer tu desempeno real para encontrar patrones."
                )

                if strongestCourses.isEmpty && mostDemandingCourses.isEmpty {
                    LeanUpDashboardEmptyState(
                        icon: "graduationcap.circle",
                        text: "Cuando registres notas de materias normales, aqui apareceran tus mejores resultados y las materias mas retadoras."
                    )
                } else {
                    if horizontalSizeClass == .compact {
                        VStack(alignment: .leading, spacing: 12) {
                            strongestColumn
                            demandingColumn
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            strongestColumn
                            demandingColumn
                        }
                    }
                }
            }
        }
    }

    private var strongestColumn: some View {
        LeanUpDashboardPerformanceColumn(
            title: "Mejor te fue en",
            tint: .green,
            items: strongestCourses
        )
    }

    private var demandingColumn: some View {
        LeanUpDashboardPerformanceColumn(
            title: "Mas retadoras",
            tint: mostDemandingCourses.contains(where: { $0.grade < 3.0 }) ? .red : .orange,
            items: mostDemandingCourses
        )
    }
}

struct LeanUpDashboardAchievementsCard: View {
    let unlockedAchievements: [LeanUpAchievement]
    let nextLockedAchievement: LeanUpAchievement?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                LeanUpSectionHeader(
                    eyebrow: "Logros desbloqueados",
                    title: unlockedTitle,
                    detail: unlockedDetail
                )

                if unlockedAchievements.isEmpty {
                    LeanUpDashboardEmptyState(
                        icon: "rosette",
                        text: "Todavia no hay badges activos. A medida que cierres periodos y sostengas el promedio, apareceran aqui."
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(unlockedAchievements) { achievement in
                            LeanUpDashboardAchievementBadge(achievement: achievement)
                        }
                    }
                }

                if let next = nextLockedAchievement {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Siguiente por desbloquear")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: next.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(toneColor(for: next.tone))
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(toneColor(for: next.tone).opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(next.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(next.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var unlockedTitle: String {
        if unlockedAchievements.isEmpty {
            return "Tus badges apareceran a medida que avances."
        }

        return "Ya desbloqueaste \(unlockedAchievements.count) hitos reales de tu carrera."
    }

    private var unlockedDetail: String {
        "Estos logros salen de tus notas, tu promedio y el cierre efectivo de la malla."
    }

    private func toneColor(for tone: LeanUpAchievementTone) -> Color {
        switch tone {
        case .navy:
            return .unadNavy
        case .blue:
            return .unadBlue
        case .cyan:
            return .unadCyan
        case .gold:
            return .unadGold
        case .green:
            return .green
        }
    }
}

struct LeanUpDashboardStatTile: View {
    let eyebrow: String
    let value: String
    let subtitle: String
    let tint: Color
    let icon: String

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LeanUpDashboardAccentStat: View {
    let title: String
    let value: String
    let caption: String
    let tint: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(scheme == .dark ? tint.opacity(0.16) : tint.opacity(0.10))
        )
    }
}

struct LeanUpDashboardPerformanceColumn: View {
    let title: String
    let tint: Color
    let items: [LeanUpGradedCourse]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if items.isEmpty {
                Text("Aun sin lectura suficiente.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Periodo \(item.period)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 8)

                        Text(String(format: "%.1f", item.grade))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(tint.opacity(0.12)))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

struct LeanUpDashboardAchievementBadge: View {
    let achievement: LeanUpAchievement
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: achievement.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(toneColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(toneColor.opacity(0.14))
                )

            Text(achievement.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            Text(achievement.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(scheme == .dark ? Color.unadDarkSurfaceSecondary : Color.primary.opacity(0.05))
        )
    }

    private var toneColor: Color {
        switch achievement.tone {
        case .navy:
            return .unadNavy
        case .blue:
            return .unadBlue
        case .cyan:
            return .unadCyan
        case .gold:
            return .unadGold
        case .green:
            return .green
        }
    }
}

struct LeanUpDashboardLineChart: View {
    let points: [LeanUpPeriodAveragePoint]
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let chartPoints = linePoints(in: proxy.size)

                ZStack {
                    VStack(spacing: proxy.size.height / 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 1)
                        }
                    }

                    Path { path in
                        guard chartPoints.count > 1 else { return }
                        path.move(to: chartPoints[0])
                        chartPoints.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.unadBlue, Color.unadCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )

                      ForEach(Array(chartPoints.enumerated()), id: \.offset) { index, point in
                          Circle()
                              .fill(scheme == .dark ? Color.unadDarkSurfacePrimary : Color.white)
                              .frame(width: 12, height: 12)
                              .overlay(
                                  Circle()
                                      .stroke(Color.unadBlue, lineWidth: 3)
                            )
                            .position(point)
                    }
                }
            }
            .frame(height: 150)

            HStack {
                ForEach(points) { point in
                    Text("P\(point.period)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func linePoints(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let values = points.map(\.average)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 5
        let valueRange = max(maxValue - minValue, 0.4)
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        return points.enumerated().map { index, point in
            let x: CGFloat
            if points.count == 1 {
                x = width / 2
            } else {
                x = CGFloat(index) / CGFloat(points.count - 1) * width
            }

            let normalizedY = (point.average - minValue) / valueRange
            let y = height - CGFloat(normalizedY) * max(height - 12, 1) - 6
            return CGPoint(x: x, y: y)
        }
    }
}

struct LeanUpDashboardEmptyState: View {
    let icon: String
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unadBlue)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unadBlue.opacity(0.10))
                )

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(scheme == .dark ? Color.unadDarkSurfaceSecondary : Color.primary.opacity(0.05))
        )
    }
}
