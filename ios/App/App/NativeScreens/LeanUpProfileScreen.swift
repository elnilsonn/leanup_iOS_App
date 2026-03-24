import SwiftUI

struct LeanUpProfileView: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LeanUpProfileSnapshotCard(model: model)
                LeanUpProfileAlignmentCard(model: model)
                LeanUpProfileMilestoneCard(model: model)
                LeanUpProfileTypeMapCard(model: model)
                LeanUpProfileServiceCard(model: model)
                LeanUpProfilePortfolioCard(model: model)
                LeanUpProfileFreelancerCard(model: model)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(LeanUpPageBackground())
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct LeanUpProfileSnapshotCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.preferredDisplayName ?? model.snapshot.username)
                            .font(.title2.weight(.bold))

                        Text(model.profileStrategicSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        LeanUpProfileStatusPill(
                            text: model.electiveAlignmentInsight.statusTitle,
                            tone: model.electiveAlignmentInsight.tone
                        )
                        LeanUpProfileMetricBadge(
                            title: "Proximo hito",
                            value: model.profileNextMilestone.badgeText
                        )
                    }
                }
            }
        }
    }
}

private struct LeanUpProfileAlignmentCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        let insight = model.electiveAlignmentInsight

        return LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Direccion",
                    title: "Que tan alineado estas",
                    detail: insight.detail
                )

                HStack(alignment: .center, spacing: 10) {
                    LeanUpProfileStatusPill(text: insight.statusTitle, tone: insight.tone)
                    Text(insight.confidenceText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if !insight.detectedAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Areas detectadas")
                            .font(.subheadline.weight(.semibold))
                        FlowTagList(items: insight.detectedAreas)
                    }
                }

                LeanUpProfileCallout(
                    title: insight.title,
                    detail: insight.recommendation,
                    tone: insight.tone
                )
            }
        }
    }
}

private struct LeanUpProfileMilestoneCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        let milestone = model.profileNextMilestone

        return LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Momentum",
                    title: "Proximo hito",
                    detail: milestone.detail
                )

                LeanUpProgressTrack(
                    title: "Camino al \(milestone.targetPercent)%",
                    valueText: milestone.badgeText,
                    progress: milestone.progress,
                    tint: Color.unadBlue
                )

                HStack(spacing: 12) {
                    LeanUpProfileMetricBadge(
                        title: "Creditos hoy",
                        value: "\(model.earnedCredits)"
                    )
                    LeanUpProfileMetricBadge(
                        title: "Faltan",
                        value: "\(milestone.creditsRemaining)"
                    )
                }
            }
        }
    }
}

private struct LeanUpProfileTypeMapCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        let typeMap = model.subjectTypeMap

        return LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Cobertura",
                    title: "Mapa de tipos de materia",
                    detail: typeMap.summary
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(typeMap.entries) { entry in
                        LeanUpProfileTypeTile(entry: entry)
                    }
                }
            }
        }
    }
}

private struct LeanUpProfileServiceCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        let service = model.recommendedStarterService

        return LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Salida real",
                    title: "Primer servicio vendible",
                    detail: service.summary
                )

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(service.title)
                            .font(.title3.weight(.bold))
                        Text(service.whyYouCanOfferIt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        LeanUpProfileStatusPill(text: service.confidenceText, tone: service.tone)
                        LeanUpProfileMetricBadge(title: "Referencia", value: service.priceText)
                    }
                }

                if !service.supportingSignals.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Senales que ya lo sostienen")
                            .font(.subheadline.weight(.semibold))
                        FlowTagList(items: service.supportingSignals)
                    }
                }

                LeanUpProfileCallout(
                    title: "Siguiente evidencia que te falta",
                    detail: service.nextEvidence,
                    tone: .blue
                )
            }
        }
    }
}

private struct LeanUpProfilePortfolioCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Portafolio",
                    title: "Portafolio minimo viable",
                    detail: "Estas son las 3 piezas que hoy mas te conviene construir para salir mejor parado al buscar tu primer cliente."
                )

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.minimumViablePortfolio) { item in
                        LeanUpProfilePortfolioRoadmapCard(item: item)
                    }
                }
            }
        }
    }
}

private struct LeanUpProfileFreelancerCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        let checklist = model.freelancerChecklist

        return LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Independencia",
                    title: "Checklist de freelancer",
                    detail: checklist.overallDetail
                )

                LeanUpProfileCallout(
                    title: checklist.overallTitle,
                    detail: "Aqui se ve cuanto sostienen hoy tu perfil, tus habilidades, tu portafolio y tus herramientas para empezar a cobrar algo pequeno con mas criterio.",
                    tone: checklistTone(for: checklist)
                )

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(checklist.items) { item in
                        LeanUpProfileChecklistRow(item: item)
                    }
                }
            }
        }
    }

    private func checklistTone(for checklist: LeanUpFreelancerChecklist) -> LeanUpProfileInsightTone {
        if checklist.overallTitle.contains("Listo") {
            return .green
        }
        if checklist.overallTitle.contains("Cerca") {
            return .blue
        }
        return .orange
    }
}

private struct LeanUpProfileTypeTile: View {
    let entry: LeanUpSubjectTypeCount

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.type)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                LeanUpProfileTinyMetric(label: "Llevas", value: "\(entry.approved)")
                LeanUpProfileTinyMetric(label: "Faltan", value: "\(entry.remaining)")
            }

            let total = max(entry.approved + entry.remaining, 1)
            LeanUpProgressTrack(
                title: "Cobertura",
                valueText: "\(entry.approved)/\(total)",
                progress: Double(entry.approved) / Double(total),
                tint: Color.unadCyan
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct LeanUpProfilePortfolioRoadmapCard: View {
    let item: LeanUpPortfolioRoadmapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Text(item.objective)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                LeanUpProfileStatusPill(
                    text: item.readiness.title,
                    tone: tone(for: item.readiness)
                )
            }

            Text(item.whyItMatters)
                .font(.footnote)
                .foregroundStyle(.primary)

            if !item.supportingSignals.isEmpty {
                FlowTagList(items: item.supportingSignals)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func tone(for readiness: LeanUpPortfolioReadinessState) -> LeanUpProfileInsightTone {
        switch readiness {
        case .ready: return .green
        case .almostReady: return .blue
        case .missingBase: return .orange
        }
    }
}

private struct LeanUpProfileChecklistRow: View {
    let item: LeanUpFreelancerChecklistItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: statusIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(statusColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    LeanUpProfileStatusPill(text: item.status.title, tone: tone(for: item.status))
                }
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var statusColor: Color {
        switch item.status {
        case .ready: return .green
        case .inProgress: return .unadBlue
        case .pending: return .orange
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .ready: return "checkmark"
        case .inProgress: return "arrow.forward"
        case .pending: return "minus"
        }
    }

    private func tone(for status: LeanUpFreelancerChecklistStatus) -> LeanUpProfileInsightTone {
        switch status {
        case .ready: return .green
        case .inProgress: return .blue
        case .pending: return .orange
        }
    }
}

private struct LeanUpProfileCallout: View {
    let title: String
    let detail: String
    let tone: LeanUpProfileInsightTone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(toneColor)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(toneColor.opacity(0.08))
        )
    }

    private var toneColor: Color {
        switch tone {
        case .blue: return .unadBlue
        case .green: return .green
        case .gold: return .unadGold
        case .orange: return .orange
        case .red: return .red
        }
    }
}

private struct LeanUpProfileStatusPill: View {
    let text: String
    let tone: LeanUpProfileInsightTone

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(toneColor.opacity(0.14)))
            .foregroundStyle(toneColor)
    }

    private var toneColor: Color {
        switch tone {
        case .blue: return .unadBlue
        case .green: return .green
        case .gold: return .unadGold
        case .orange: return .orange
        case .red: return .red
        }
    }
}

private struct LeanUpProfileMetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

private struct LeanUpProfileTinyMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
