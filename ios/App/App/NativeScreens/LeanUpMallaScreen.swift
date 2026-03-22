import SwiftUI
import UIKit

struct LeanUpMallaView: View {
    @ObservedObject var model: LeanUpAppModel
    @State private var route: LeanUpMallaDetailRoute?
    @State private var selectedPeriod: Int?
    @State private var selectedFilter: LeanUpMallaFilter = .all
    @State private var isSearchPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LeanUpMallaOverviewCard(model: model)

                if !model.academics.courses.isEmpty {
                    LeanUpMallaFocusCard(model: model, selectedPeriod: effectiveSelectedPeriod)
                }

                if !model.academics.courses.isEmpty {
                    LeanUpMallaStickyHeader(
                        periods: model.periods,
                        selectedPeriod: effectiveSelectedPeriod,
                        selectedFilter: $selectedFilter,
                        onSelectPeriod: { selectedPeriod = $0 }
                    )
                }

                if model.academics.courses.isEmpty {
                    LeanUpSurfaceCard {
                        Text("No pudimos cargar la base academica en este momento. Tu progreso guardado sigue intacto.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LeanUpSelectedPeriodSection(
                        period: effectiveSelectedPeriod,
                        model: model,
                        filter: selectedFilter
                    ) { item in
                        route = item
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .leanUpKeyboardFriendlyScroll()
        .background(LeanUpPageBackground())
        .navigationTitle("Malla")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSearchPresented = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $isSearchPresented) {
            LeanUpMallaSearchView(model: model) { item in
                route = item
                isSearchPresented = false
            }
        }
        .sheet(item: $route) { route in
            switch route {
            case .course(let course):
                LeanUpCourseDetailView(model: model, course: course)
            case .electiveGroup(let group):
                LeanUpElectiveGroupDetailView(model: model, group: group)
            }
        }
        .onAppear {
            if selectedPeriod == nil {
                selectedPeriod = model.focusPeriod ?? model.periods.first
            }
        }
    }
}

private extension LeanUpMallaView {
    var effectiveSelectedPeriod: Int {
        selectedPeriod ?? model.focusPeriod ?? model.periods.first ?? 1
    }
}

struct LeanUpMallaOverviewCard: View {
    @ObservedObject var model: LeanUpAppModel

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Control academico",
                    title: "La malla es tu tablero de seguimiento real.",
                    detail: "Aqui lo importante es revisar materias, registrar notas definitivas y detectar rapido que conviene recuperar o cerrar."
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    LeanUpInlineMetric(title: "Promedio", value: model.averageText)
                    LeanUpInlineMetric(title: "Creditos", value: "\(model.earnedCredits)")
                    LeanUpInlineMetric(title: "Por recuperar", value: "\(model.failedCount)")
                    LeanUpInlineMetric(title: "En curso", value: "\(model.inProgressCount)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(summaryLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(secondaryLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var summaryLine: String {
        if model.failedCount > 0 {
            return "Tu prioridad inmediata es recuperar \(model.failedCount) materia(s)."
        }

        if model.inProgressCount > 0 {
            return "Tienes \(model.inProgressCount) elemento(s) en curso que ya cuentan para leer mejor tu ritmo."
        }

        if let period = model.focusPeriod {
            return "El periodo \(period) es el siguiente bloque natural para seguir avanzando."
        }

        return "Tu base academica ya esta ordenada para seguir registrando avance con claridad."
    }

    private var secondaryLine: String {
        if model.selectedElectivesCount > 0 {
            return "Las electivas siguen apareciendo como complemento, pero el foco principal de esta pantalla esta en tus materias obligatorias."
        }

        return "Las electivas se mantienen como complemento y no como el centro de la lectura academica."
    }
}

struct LeanUpMallaFocusCard: View {
    @ObservedObject var model: LeanUpAppModel
    let selectedPeriod: Int

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                LeanUpSectionHeader(
                    eyebrow: "Siguiente paso",
                    title: focusTitle,
                    detail: focusDetail
                )

                VStack(alignment: .leading, spacing: 12) {
                    LeanUpPriorityRow(
                        icon: model.failedCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                        tint: model.failedCount > 0 ? .red : .green,
                        title: model.failedCount > 0 ? "\(model.failedCount) materias por recuperar" : "No tienes materias en rojo",
                        detail: model.failedCount > 0
                            ? "Empieza por esas materias antes de abrir mas carga nueva."
                            : "Eso te deja concentrarte en seguir cerrando periodos con orden."
                    )

                    LeanUpPriorityRow(
                        icon: "square.and.pencil",
                        tint: model.inProgressCount > 0 ? .unadCyan : .unadBlue,
                        title: model.inProgressCount > 0
                            ? "\(model.inProgressCount) materias o electivas estan en curso"
                            : "\(model.pendingCourses.count) materias aun sin nota registrada",
                        detail: model.inProgressCount > 0
                            ? "Ese bloque alimenta mejor la proyeccion de ritmo mientras llegan tus notas finales."
                            : "Si ya tienes calificaciones definitivas, esta pantalla es donde mas valor ganas al actualizarlas."
                    )
                }

                let progress = model.progress(for: selectedPeriod)
                if progress.total > 0 {
                    LeanUpProgressTrack(
                        title: "Avance del periodo \(selectedPeriod)",
                        valueText: progress.completionText,
                        progress: progress.completionRatio,
                        tint: .unadBlue
                    )
                }
            }
        }
    }

    private var focusTitle: String {
        if model.failedCount > 0 {
            return "Primero estabiliza lo que hoy esta frenando el promedio."
        }

        return "El periodo \(selectedPeriod) es el tramo que estas revisando ahora."
    }

    private var focusDetail: String {
        if model.failedCount > 0 {
            return "La malla tiene que ayudarte a tomar decisiones academicas claras, no solo a ver datos. Por eso la prioridad se marca aqui arriba."
        }

        return "La idea es que esta pantalla te diga rapido donde mirar y que registrar, sin ruido innecesario."
    }
}

enum LeanUpMallaDetailRoute: Identifiable {
    case course(LeanUpCourse)
    case electiveGroup(LeanUpElectiveGroup)

    var id: String {
        switch self {
        case .course(let course):
            return "course-\(course.id)"
        case .electiveGroup(let group):
            return "elective-\(group.id)"
        }
    }
}

enum LeanUpMallaFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case inProgress
    case approved
    case failed
    case electives

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .pending: return "Pendientes"
        case .inProgress: return "En curso"
        case .approved: return "Aprobadas"
        case .failed: return "Reprobadas"
        case .electives: return "Electivas"
        }
    }
}

struct LeanUpMallaStickyHeader: View {
    let periods: [Int]
    let selectedPeriod: Int
    @Binding var selectedFilter: LeanUpMallaFilter
    let onSelectPeriod: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(periods, id: \.self) { period in
                        Button {
                            onSelectPeriod(period)
                        } label: {
                            Text("Periodo \(period)")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(period == selectedPeriod ? Color.unadBlue : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(period == selectedPeriod ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LeanUpMallaFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(filter == selectedFilter ? Color.unadNavy.opacity(0.92) : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(filter == selectedFilter ? Color.white : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.unadBlue.opacity(0.08), lineWidth: 1)
        )
    }
}

struct LeanUpSelectedPeriodSection: View {
    let period: Int
    @ObservedObject var model: LeanUpAppModel
    let filter: LeanUpMallaFilter
    let onOpen: (LeanUpMallaDetailRoute) -> Void

    var body: some View {
        let progress = model.progress(for: period)
        let courses = filteredCourses
        let electiveGroups = filteredElectiveGroups

        return LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Periodo \(period)")
                            .font(.title3.weight(.bold))
                        Text(periodSummary(progress: progress, visibleCount: courses.count + electiveGroups.count))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(progress.completionText)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.unadBlue.opacity(0.12)))
                        .foregroundStyle(Color.unadBlue)
                }

                LeanUpProgressTrack(
                    title: "Cierre del periodo",
                    valueText: progress.completionText,
                    progress: progress.completionRatio,
                    tint: progress.failed > 0 ? .red : .unadBlue
                )

                if courses.isEmpty && electiveGroups.isEmpty {
                    LeanUpSurfaceInsetCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Nada por mostrar con este filtro", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                            Text(emptyStateText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !courses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Materias")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        VStack(spacing: 12) {
                            ForEach(courses) { course in
                                Button {
                                    onOpen(.course(course))
                                } label: {
                                    LeanUpCourseRow(
                                        course: course,
                                        note: model.note(for: course),
                                        status: model.courseStatus(for: course)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !electiveGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Electivas complementarias")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.unadGold)
                            Spacer()
                            Text("Opcionales")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.unadGold)
                        }

                        Text("Van aparte porque complementan tu ruta, pero no deben robarle protagonismo a las materias principales del periodo.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 12) {
                            ForEach(electiveGroups) { group in
                                Button {
                                    onOpen(.electiveGroup(group))
                                } label: {
                                    LeanUpElectiveGroupRow(
                                        group: group,
                                        selectedOption: model.selectedOption(in: group),
                                        note: model.selectedOption(in: group).flatMap { model.electiveNote(groupName: group.name, optionCode: $0.code) },
                                        status: model.electiveStatus(for: group)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredCourses: [LeanUpCourse] {
        model.courses(in: period).filter { filter.matches(course: $0, model: model) }
    }

    private var filteredElectiveGroups: [LeanUpElectiveGroup] {
        model.electiveGroups(in: period).filter { filter.matches(group: $0, model: model) }
    }

    private func periodSummary(progress: LeanUpPeriodProgress, visibleCount: Int) -> String {
        "\(progress.approved) aprobadas - \(progress.failed) reprobadas - \(visibleCount) elementos visibles"
    }

    private var emptyStateText: String {
        switch filter {
        case .all:
            return "Este periodo aun no tiene materias o electivas visibles."
        case .pending:
            return "No hay pendientes urgentes en este periodo."
        case .inProgress:
            return "No hay materias en curso sin nota final en este periodo."
        case .approved:
            return "Todavia no tienes aprobadas visibles dentro de este periodo."
        case .failed:
            return "No tienes materias reprobadas en este periodo."
        case .electives:
            return "Este periodo no tiene grupos de electivas para revisar."
        }
    }
}

struct LeanUpCourseRow: View {
    let course: LeanUpCourse
    let note: Double?
    let status: LeanUpProgressStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Cod. \(course.code) - \(course.credits) creditos")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    LeanUpStatusChip(status: status, note: note)
                }

                Text(course.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(course.types.prefix(3), id: \.self) { type in
                            LeanUpCurriculumTag(text: type, style: .courseType(type))
                        }
                        LeanUpCurriculumTag(text: "Dificultad \(course.difficulty)", style: .difficulty(course.difficulty))

                        if isFailed {
                            LeanUpCurriculumTag(text: "Recuperar", style: .failed)
                        } else if isInProgress {
                            LeanUpCurriculumTag(text: "En curso", style: .inProgress)
                        } else if isPending {
                            LeanUpCurriculumTag(text: "Sin nota", style: .pending)
                        } else {
                            LeanUpCurriculumTag(text: "Aprobada", style: .approved)
                        }
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundFill)
        )
    }

    private var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    private var isInProgress: Bool {
        if case .inProgress = status { return true }
        return false
    }

    private var isPending: Bool {
        if case .pending = status { return true }
        return false
    }

    private var backgroundFill: Color {
        if isFailed {
            return Color.red.opacity(0.08)
        }

        if isInProgress {
            return Color.unadCyan.opacity(0.08)
        }

        return Color.primary.opacity(0.04)
    }
}

struct LeanUpElectiveGroupRow: View {
    let group: LeanUpElectiveGroup
    let selectedOption: LeanUpElectiveOption?
    let note: Double?
    let status: LeanUpProgressStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(selectedOption?.name ?? "Elige una opcion para este grupo")
                            .font(.footnote)
                            .foregroundStyle(selectedOption == nil ? .secondary : .primary)
                    }
                    Spacer()
                    LeanUpStatusChip(status: status, note: note)
                }

                Text("\(group.options.count) opciones disponibles")
                    .font(.footnote)
                    .foregroundStyle(Color.unadGold)

                HStack(spacing: 8) {
                    LeanUpCurriculumTag(text: "Electiva", style: .elective)
                    if let selectedOption {
                        LeanUpCurriculumTag(text: selectedOption.name, style: .electiveSoft)
                    }
                    if case .inProgress = status {
                        LeanUpCurriculumTag(text: "En curso", style: .inProgress)
                    }
                }
            }

            Image(systemName: "slider.horizontal.3")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unadGold.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.unadGold.opacity(0.18), lineWidth: 1)
        )
    }
}

enum LeanUpCurriculumTagStyle {
    case courseType(String)
    case difficulty(Int)
    case pending
    case inProgress
    case approved
    case failed
    case elective
    case electiveSoft

    var fill: Color {
        switch self {
        case .courseType(let type):
            let normalized = type.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            if normalized.contains("pract") { return Color.unadCyan.opacity(0.16) }
            if normalized.contains("teor") { return Color.unadBlue.opacity(0.14) }
            if normalized.contains("numero") { return Color.unadGold.opacity(0.20) }
            if normalized.contains("lectura") { return Color.unadNavy.opacity(0.12) }
            return Color.primary.opacity(0.08)
        case .difficulty(let value):
            switch value {
            case 1: return Color.green.opacity(0.16)
            case 2: return Color.unadBlue.opacity(0.14)
            case 3: return Color.unadGold.opacity(0.20)
            default: return Color.red.opacity(0.16)
            }
        case .pending:
            return Color.primary.opacity(0.08)
        case .inProgress:
            return Color.unadCyan.opacity(0.16)
        case .approved:
            return Color.green.opacity(0.16)
        case .failed:
            return Color.red.opacity(0.16)
        case .elective:
            return Color.unadGold.opacity(0.22)
        case .electiveSoft:
            return Color.unadGold.opacity(0.12)
        }
    }

    var foreground: Color {
        switch self {
        case .courseType(let type):
            let normalized = type.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            if normalized.contains("pract") { return .unadCyan }
            if normalized.contains("teor") { return .unadBlue }
            if normalized.contains("numero") { return .unadGold }
            if normalized.contains("lectura") { return .unadNavy }
            return .secondary
        case .difficulty(let value):
            switch value {
            case 1: return .green
            case 2: return .unadBlue
            case 3: return .unadGold
            default: return .red
            }
        case .pending:
            return .secondary
        case .inProgress:
            return .unadCyan
        case .approved:
            return .green
        case .failed:
            return .red
        case .elective, .electiveSoft:
            return .unadGold
        }
    }
}

struct LeanUpCurriculumTag: View {
    let text: String
    let style: LeanUpCurriculumTagStyle

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(style.fill))
            .foregroundStyle(style.foreground)
    }
}

struct LeanUpCourseDetailView: View {
    @ObservedObject var model: LeanUpAppModel
    let course: LeanUpCourse
    @Environment(\.dismiss) private var dismiss
    @State private var isSearchPresented = false
    @State private var searchRoute: LeanUpMallaDetailRoute?

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LeanUpSurfaceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(course.name)
                                    .font(.title2.weight(.bold))
                                Text("Codigo \(course.code) - \(course.credits) creditos - Periodo \(course.period)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(course.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }

                        LeanUpSurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("En palabras simples", systemImage: "lightbulb.fill")
                                    .font(.headline.weight(.semibold))
                                Text(course.plainLanguage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LeanUpSurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Salidas y aplicacion", systemImage: "briefcase.fill")
                                    .font(.headline.weight(.semibold))
                                Text(course.outcomes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !course.skills.isEmpty {
                            LeanUpSurfaceCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Habilidades que esta materia fortalece", systemImage: "star.square.on.square.fill")
                                        .font(.headline.weight(.semibold))
                                    FlowTagList(items: Array(course.skills.prefix(8)))
                                }
                            }
                        }

                        if !course.linkedinText.isEmpty {
                            LeanUpMallaLinkedInCard(text: course.linkedinText)
                        }

                        if !course.portfolioProject.isEmpty {
                            LeanUpMallaPortfolioCard(
                                project: course.portfolioProject,
                                prompt: course.portfolioPrompt
                            )
                        }

                        LeanUpGradeEditorCard(
                            title: "Tu nota en esta materia",
                            subtitle: "Puedes escribir 35 para que la app lo entienda como 3.5.",
                            currentGrade: model.note(for: course)
                        ) { value in
                            model.setCourseGrade(value, for: course.id)
                        }

                        LeanUpAcademicStateCard(
                            title: "Estado actual",
                            subtitle: "Marcala como en curso mientras la estas viendo. Cuando llegue la nota final, esa nota pasa a mandar.",
                            isOn: model.isCourseInProgress(course),
                            canToggle: model.note(for: course) == nil
                        ) { isOn in
                            model.setCourseInProgress(isOn, for: course.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .leanUpKeyboardFriendlyScroll()
                .background(LeanUpPageBackground())
            }
            .navigationTitle("Materia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Atras", systemImage: "chevron.backward")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isSearchPresented) {
            LeanUpMallaSearchView(model: model) { item in
                searchRoute = item
                isSearchPresented = false
            }
        }
        .sheet(item: $searchRoute) { route in
            switch route {
            case .course(let course):
                LeanUpCourseDetailView(model: model, course: course)
            case .electiveGroup(let group):
                LeanUpElectiveGroupDetailView(model: model, group: group)
            }
        }
    }
}

struct LeanUpElectiveGroupDetailView: View {
    @ObservedObject var model: LeanUpAppModel
    let group: LeanUpElectiveGroup
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack?
    @State private var isSearchPresented = false
    @State private var searchRoute: LeanUpMallaDetailRoute?

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LeanUpSurfaceCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.name)
                                    .font(.title2.weight(.bold))
                                Text("Periodo \(group.period) - \(filteredOptions.count) opciones visibles")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(headerDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !availableDisciplinaryTracks.isEmpty {
                            LeanUpSurfaceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Ruta del electivo disciplinar")
                                        .font(.subheadline.weight(.semibold))

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(availableDisciplinaryTracks) { track in
                                                Button {
                                                    selectedDisciplinaryTrack = track
                                                } label: {
                                                    Text(track.title)
                                                        .font(.caption.weight(.bold))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            Capsule()
                                                                .fill(track == activeDisciplinaryTrack ? Color.unadCyan.opacity(0.92) : Color.primary.opacity(0.06))
                                                        )
                                                        .foregroundStyle(track == activeDisciplinaryTrack ? Color.white : Color.secondary)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 2)
                                    }

                                    Text("Cada ruta guarda su propia seleccion. Aqui puedes revisar Transformacion Digital, Competitividad o Sustentabilidad sin salir del panel.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        ForEach(filteredOptions) { option in
                            LeanUpSurfaceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(option.name)
                                                .font(.headline.weight(.semibold))
                                            Text("Codigo \(option.code) - \(option.credits) creditos")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if model.selectedOption(in: group)?.code == option.code {
                                            Text("Activa")
                                                .font(.footnote.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Capsule().fill(Color.unadBlue.opacity(0.12)))
                                                .foregroundStyle(Color.unadBlue)
                                        }
                                    }

                                    Text(option.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    LeanUpSurfaceInsetCard {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Label("En palabras simples", systemImage: "lightbulb.fill")
                                                .font(.subheadline.weight(.semibold))
                                            Text(option.plainLanguage)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    LeanUpSurfaceInsetCard {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Label("Salidas y aplicacion", systemImage: "briefcase.fill")
                                                .font(.subheadline.weight(.semibold))
                                            Text(option.outcomes)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if !option.skills.isEmpty {
                                        FlowTagList(items: Array(option.skills.prefix(6)))
                                    }

                                    if !option.linkedinText.isEmpty {
                                        LeanUpMallaLinkedInInsetCard(text: option.linkedinText)
                                    }

                                    if !option.portfolioProject.isEmpty {
                                        LeanUpMallaPortfolioInsetCard(
                                            project: option.portfolioProject,
                                            prompt: option.portfolioPrompt
                                        )
                                    }

                                    Button {
                                        model.selectElectiveOption(groupName: group.name, optionCode: option.code)
                                    } label: {
                                        Label(
                                            model.selectedOption(in: group)?.code == option.code ? "Electiva seleccionada" : "Elegir esta electiva",
                                            systemImage: model.selectedOption(in: group)?.code == option.code ? "checkmark.circle.fill" : "circle"
                                        )
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(LeanUpPrimaryButtonStyle())

                                    if model.selectedOption(in: group)?.code == option.code {
                                        LeanUpGradeEditorCard(
                                            title: "Nota de esta electiva",
                                            subtitle: "Si aun no la cursas, puedes dejarla vacia.",
                                            currentGrade: model.electiveNote(groupName: group.name, optionCode: option.code)
                                        ) { value in
                                            model.setElectiveGrade(value, groupName: group.name, optionCode: option.code)
                                        }

                                        LeanUpAcademicStateCard(
                                            title: "Estado actual",
                                            subtitle: "Usa en curso para que LeanUp entienda tu carga activa aun sin nota final.",
                                            isOn: model.isElectiveInProgress(group),
                                            canToggle: model.electiveNote(groupName: group.name, optionCode: option.code) == nil
                                        ) { isOn in
                                            model.setElectiveInProgress(isOn, groupName: group.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .leanUpKeyboardFriendlyScroll()
                .background(LeanUpPageBackground())
            }
            .navigationTitle("Electiva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Atras", systemImage: "chevron.backward")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if selectedDisciplinaryTrack == nil {
                selectedDisciplinaryTrack = group.defaultDisciplinaryTrack ?? availableDisciplinaryTracks.first
            }
        }
        .sheet(isPresented: $isSearchPresented) {
            LeanUpMallaSearchView(model: model) { item in
                searchRoute = item
                isSearchPresented = false
            }
        }
        .sheet(item: $searchRoute) { route in
            switch route {
            case .course(let course):
                LeanUpCourseDetailView(model: model, course: course)
            case .electiveGroup(let group):
                LeanUpElectiveGroupDetailView(model: model, group: group)
            }
        }
    }
}

private extension LeanUpElectiveGroupDetailView {
    var activeDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack? {
        selectedDisciplinaryTrack
    }

    var availableDisciplinaryTracks: [LeanUpElectiveDisciplinaryTrack] {
        let tracks = group.options.flatMap(\.electiveDisciplinaryTrackValues)
        var seen = Set<LeanUpElectiveDisciplinaryTrack>()
        return tracks.filter { seen.insert($0).inserted }
    }

    var filteredOptions: [LeanUpElectiveOption] {
        guard let selectedDisciplinaryTrack else {
            return group.options
        }

        return group.options.filter { $0.electiveDisciplinaryTrackValues.contains(selectedDisciplinaryTrack) }
    }

    var headerDescription: String {
        if availableDisciplinaryTracks.isEmpty {
            return "Selecciona la electiva que realmente quieres cursar en este grupo. Solo una puede estar activa a la vez."
        }

        return "Este electivo disciplinar incluye varias rutas. Usa el banner para cambiar entre Transformacion Digital, Competitividad y Sustentabilidad sin mezclar todas las opciones de golpe."
    }
}

enum LeanUpElectiveDisciplinaryTrack: String, CaseIterable, Identifiable, Hashable {
    case digitalTransformation
    case competitiveness
    case sustainability

    var id: String { rawValue }

    var title: String {
        switch self {
        case .digitalTransformation: return "Transformacion Digital"
        case .competitiveness: return "Competitividad"
        case .sustainability: return "Sustentabilidad"
        }
    }
}

private extension LeanUpElectiveGroup {
    var defaultDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack? {
        if name.contains("Transformación Digital") {
            return .digitalTransformation
        }

        if name.contains("Competitividad") {
            return .competitiveness
        }

        if name.contains("Sustentabilidad") {
            return .sustainability
        }

        return nil
    }
}

private extension LeanUpElectiveOption {
    var electiveDisciplinaryTrackValues: [LeanUpElectiveDisciplinaryTrack] {
        disciplinaryTracks.compactMap(LeanUpElectiveDisciplinaryTrack.init(rawValue:))
    }
}

struct LeanUpMallaLinkedInCard: View {
    let text: String

    var body: some View {
        LeanUpSurfaceCard {
            LeanUpMallaLinkedInContent(
                text: text,
                titleFont: .headline.weight(.semibold),
                bodyFont: .subheadline
            )
        }
    }
}

struct LeanUpMallaLinkedInInsetCard: View {
    let text: String

    var body: some View {
        LeanUpSurfaceInsetCard {
            LeanUpMallaLinkedInContent(
                text: text,
                titleFont: .subheadline.weight(.semibold),
                bodyFont: .footnote
            )
        }
    }
}

struct LeanUpMallaLinkedInContent: View {
    let text: String
    let titleFont: Font
    let bodyFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Traductor de LinkedIn", systemImage: "text.badge.checkmark")
                        .font(titleFont)
                    Text("Texto listo para copiar o adaptar en tu perfil.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                LeanUpCopyFeedbackButton(
                    sourceText: text,
                    idleTitle: "Copiar texto",
                    successTitle: "✓ Copiado",
                    systemImage: "doc.on.doc",
                    successSystemImage: "checkmark.circle.fill"
                )
            }

            Text(text)
                .font(bodyFont)
                .foregroundStyle(.secondary)
        }
    }
}

struct LeanUpMallaPortfolioCard: View {
    let project: String
    let prompt: String

    var body: some View {
        LeanUpSurfaceCard {
            LeanUpMallaPortfolioContent(
                project: project,
                prompt: prompt,
                titleFont: .headline.weight(.semibold),
                bodyFont: .subheadline
            )
        }
    }
}

struct LeanUpMallaPortfolioInsetCard: View {
    let project: String
    let prompt: String

    var body: some View {
        LeanUpSurfaceInsetCard {
            LeanUpMallaPortfolioContent(
                project: project,
                prompt: prompt,
                titleFont: .subheadline.weight(.semibold),
                bodyFont: .footnote
            )
        }
    }
}

struct LeanUpMallaPortfolioContent: View {
    let project: String
    let prompt: String
    let titleFont: Font
    let bodyFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Portafolio", systemImage: "folder.fill.badge.plus")
                .font(titleFont)

            Text(project)
                .font(bodyFont)
                .foregroundStyle(.secondary)

            if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LeanUpCopyFeedbackButton(
                    sourceText: prompt,
                    idleTitle: "🤖 Copiar prompt para IA",
                    successTitle: "✓ Prompt copiado",
                    systemImage: "sparkles.rectangle.stack",
                    successSystemImage: "checkmark.circle.fill",
                    fillColor: Color.unadBlue.opacity(0.09),
                    width: nil
                )
            }
        }
    }
}

struct LeanUpCopyFeedbackButton: View {
    let sourceText: String
    let idleTitle: String
    let successTitle: String
    let systemImage: String
    let successSystemImage: String
    var fillColor: Color = Color.primary.opacity(0.08)
    var width: CGFloat? = 128

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = sourceText
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                copied = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    copied = false
                }
            }
        } label: {
            Label(copied ? successTitle : idleTitle, systemImage: copied ? successSystemImage : systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
        }
        .foregroundStyle(copied ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(copied ? Color.green : fillColor)
        )
        .frame(maxWidth: width ?? .infinity)
        .scaleEffect(copied ? 1.02 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: copied)
    }
}

struct LeanUpMallaSearchView: View {
    @ObservedObject var model: LeanUpAppModel
    let onSelect: (LeanUpMallaDetailRoute) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LeanUpSurfaceCard {
                        Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Usa el buscador del sistema para encontrar una materia, un codigo, una electiva o una habilidad sin recorrer toda la malla."
                            : "\(results.count) resultado(s) encontrados.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LeanUpSurfaceCard {
                            Text("El acceso a buscar queda en la barra superior y el campo de busqueda lo maneja el sistema.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if results.isEmpty {
                        LeanUpSurfaceCard {
                            Text("No encontramos coincidencias con ese texto. Prueba con el nombre, el codigo o una habilidad.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(results) { result in
                            Button {
                                dismiss()
                                onSelect(result.route)
                            } label: {
                                LeanUpSurfaceCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(result.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text("Periodo \(result.period)")
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            LeanUpCurriculumTag(
                                                text: result.isElective ? "Electiva" : "Materia",
                                                style: result.isElective ? .elective : .courseType("Teorica")
                                            )
                                        }

                                        Text(result.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .leanUpKeyboardFriendlyScroll()
            .background(LeanUpPageBackground())
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Materia, codigo, electiva o habilidad")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var results: [LeanUpMallaSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let courseResults = model.academics.courses.compactMap { course -> LeanUpMallaSearchResult? in
            guard leanUpCourseMatches(course, query: trimmed) else { return nil }
            return LeanUpMallaSearchResult(
                id: "course-\(course.id)",
                title: course.name,
                subtitle: course.summary,
                period: course.period,
                route: .course(course),
                isElective: false
            )
        }

        let electiveResults = model.academics.electiveGroups.compactMap { group -> LeanUpMallaSearchResult? in
            guard leanUpElectiveGroupMatches(group, query: trimmed) else { return nil }
            return LeanUpMallaSearchResult(
                id: "group-\(group.id)",
                title: group.name,
                subtitle: model.selectedOption(in: group)?.name ?? "\(group.options.count) opciones disponibles",
                period: group.period,
                route: .electiveGroup(group),
                isElective: true
            )
        }

        return (courseResults + electiveResults).sorted {
            if $0.period == $1.period { return $0.title < $1.title }
            return $0.period < $1.period
        }
    }
}

struct LeanUpMallaSearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let period: Int
    let route: LeanUpMallaDetailRoute
    let isElective: Bool
}

struct LeanUpGradeEditorCard: View {
    let title: String
    let subtitle: String
    let currentGrade: Double?
    let onSave: (Double?) -> Void

    @State private var draft = ""
    @State private var error: String?

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: "square.and.pencil")
                    .font(.headline.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button {
                        adjust(by: -0.1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(LeanUpSecondaryButtonStyle())

                    TextField("1.0 - 5.0", text: $draft)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )

                    Button {
                        adjust(by: 0.1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(LeanUpSecondaryButtonStyle())
                }

                if let currentGrade {
                    Text("Nota actual: \(LeanUpGradeFormatter.display(currentGrade))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 10) {
                    Button {
                        save()
                    } label: {
                        Label("Guardar nota", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(LeanUpPrimaryButtonStyle())

                    Button {
                        draft = ""
                        error = nil
                        onSave(nil)
                    } label: {
                        Label("Limpiar", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(LeanUpSecondaryButtonStyle())
                }
            }
            .onAppear {
                draft = currentGrade.map(LeanUpGradeFormatter.display) ?? ""
            }
        }
    }

    private func adjust(by delta: Double) {
        let base = LeanUpGradeFormatter.parse(draft) ?? currentGrade ?? 3.0
        let adjusted = min(5.0, max(1.0, (base + delta).roundedToTenth))
        draft = LeanUpGradeFormatter.display(adjusted)
        error = nil
    }

    private func save() {
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onSave(nil)
            error = nil
            return
        }

        guard let grade = LeanUpGradeFormatter.parse(draft) else {
            error = "Nota invalida. Usa valores entre 1.0 y 5.0. Tambien puedes escribir 35 para 3.5."
            return
        }

        onSave(grade)
        draft = LeanUpGradeFormatter.display(grade)
        error = nil
    }
}

struct LeanUpAcademicStateCard: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let canToggle: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: "calendar.badge.clock")
                    .font(.headline.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle(isOn: Binding(get: { isOn }, set: onChange)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Marcar como en curso")
                            .font(.subheadline.weight(.semibold))
                        Text(canToggle ? "Esto ayuda a que LeanUp lea mejor tu carga actual." : "Si ya registraste una nota final, la materia deja de estar en curso.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.unadCyan)
                .disabled(!canToggle)
            }
        }
    }
}

enum LeanUpGradeFormatter {
    static func parse(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: ",", with: ".")

        guard var value = Double(text) else { return nil }
        if floor(value) == value, value >= 10, value <= 50 {
            value /= 10
        }
        guard value >= 1, value <= 5 else { return nil }
        return value.roundedToTenth
    }

    static func display(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

extension Double {
    var roundedToTenth: Double {
        (self * 10).rounded() / 10
    }
}

@MainActor
private extension LeanUpMallaFilter {
    func matches(course: LeanUpCourse, model: LeanUpAppModel) -> Bool {
        let status = model.courseStatus(for: course)

        switch self {
        case .all:
            return true
        case .pending:
            return status == .pending
        case .inProgress:
            return status == .inProgress
        case .approved:
            return status == .approved
        case .failed:
            return status == .failed
        case .electives:
            return false
        }
    }

    func matches(group: LeanUpElectiveGroup, model: LeanUpAppModel) -> Bool {
        let selected = model.selectedOption(in: group)
        let status = model.electiveStatus(for: group)

        switch self {
        case .all:
            return true
        case .pending:
            return selected == nil || status == .pending
        case .inProgress:
            return selected != nil && status == .inProgress
        case .approved:
            return status == .approved
        case .failed:
            return status == .failed
        case .electives:
            return true
        }
    }
}

private func leanUpCourseMatches(_ course: LeanUpCourse, query: String) -> Bool {
    guard !query.isEmpty else { return true }

    let values = [
        course.name,
        course.code,
        course.summary,
        course.plainLanguage,
        course.outcomes
    ] + course.types + course.skills

    return values.contains { leanUpMatches($0, query: query) }
}

private func leanUpElectiveGroupMatches(_ group: LeanUpElectiveGroup, query: String) -> Bool {
    guard !query.isEmpty else { return true }

    if leanUpMatches(group.name, query: query) {
        return true
    }

    return group.options.contains { option in
        let values = [
            option.name,
            option.code,
            option.summary,
            option.plainLanguage,
            option.outcomes
        ] + option.skills

        return values.contains { leanUpMatches($0, query: query) }
    }
}

private func leanUpMatches(_ value: String, query: String) -> Bool {
    let normalizedValue = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    return normalizedValue.contains(normalizedQuery)
}
