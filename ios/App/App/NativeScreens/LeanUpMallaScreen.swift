import SwiftUI
import UIKit

struct LeanUpMallaView: View {
    @ObservedObject var model: LeanUpAppModel
    @State private var route: LeanUpMallaDetailRoute?
    @State private var selectedPeriod: Int?
    @State private var selectedFilter: LeanUpMallaFilter = .all
    @State private var searchQuery = ""
    @State private var isReminderListPresented = false
    @State private var periodResetScrollToken = 0
    @State private var filterResetScrollToken = 0
    @State private var periodResetScrollTarget: Int?
    @State private var filterResetScrollTarget: LeanUpMallaFilter = .all

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !model.academics.courses.isEmpty && !isSearchMode {
                            LeanUpMallaCompactOverviewCard(model: model, selectedPeriod: effectiveSelectedPeriod)
                            LeanUpMallaMotivationCard(model: model)
                            LeanUpMallaReminderPreviewCard(
                                reminders: model.upcomingReminders()
                            ) {
                                isReminderListPresented = true
                            }
                        }

                        if !model.academics.courses.isEmpty && !isSearchMode {
                            LeanUpMallaStickyHeader(
                                periods: model.periods,
                                selectedPeriod: effectiveSelectedPeriod,
                                selectedFilter: selectedFilter,
                                periodResetScrollToken: periodResetScrollToken,
                                filterResetScrollToken: filterResetScrollToken,
                                periodResetScrollTarget: periodResetScrollTarget ?? effectiveSelectedPeriod,
                                filterResetScrollTarget: filterResetScrollTarget,
                                onSelectPeriod: { tappedPeriod in
                                    if tappedPeriod == effectiveSelectedPeriod {
                                        periodResetScrollTarget = model.focusPeriod ?? model.periods.first ?? 1
                                        selectedPeriod = nil
                                        DispatchQueue.main.async {
                                            periodResetScrollToken += 1
                                        }
                                    } else {
                                        selectedPeriod = tappedPeriod
                                    }
                                },
                                onSelectFilter: { tappedFilter in
                                    if selectedFilter == tappedFilter {
                                        filterResetScrollTarget = .all
                                        selectedFilter = .all
                                        filterResetScrollToken += 1
                                    } else {
                                        selectedFilter = tappedFilter
                                    }
                                }
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
                    .frame(width: max(proxy.size.width - 40, 0), alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .opacity(showsSearchResults ? 0 : 1)
                .allowsHitTesting(!showsSearchResults)
                .accessibilityHidden(showsSearchResults)
                .transaction { transaction in
                    transaction.animation = nil
                }

                if showsSearchResults {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            LeanUpMallaInlineSearchSection(
                                query: trimmedSearchQuery,
                                results: searchResults
                            ) { item in
                                route = item
                            }

                            Color.clear
                                .frame(height: 120)
                        }
                        .frame(width: max(proxy.size.width - 40, 0), alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                    .leanUpKeyboardFriendlyScroll()
                    .background(LeanUpPageBackground())
                    .zIndex(1)
                }
            }
        }
        .leanUpKeyboardFriendlyScroll()
        .background(LeanUpPageBackground())
        .navigationTitle("Malla")
        .navigationBarTitleDisplayMode(.large)
        .modifier(
            LeanUpNativeMallaSearchModifier(
                query: $searchQuery,
                prompt: "Busca una materia"
            )
        )
        .sheet(isPresented: $isReminderListPresented) {
            LeanUpReminderListView(model: model, defaultPeriod: effectiveSelectedPeriod)
        }
        .sheet(item: $route) { route in
            LeanUpMallaDetailContainerView(model: model, initialRoute: route)
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

    var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasActiveSearch: Bool { !trimmedSearchQuery.isEmpty }

    var isSearchMode: Bool { hasActiveSearch }

    var showsSearchResults: Bool { hasActiveSearch }

    var searchResults: [LeanUpMallaSearchResult] {
        leanUpMallaSearchResults(model: model, query: trimmedSearchQuery)
    }
}

struct LeanUpMallaBannerCard<Content: View>: View {
    let compact: Bool
    let content: Content

    init(compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        content
            .padding(compact ? 14 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .stroke(Color.unadBlue.opacity(0.08), lineWidth: 1)
            )
    }
}

struct LeanUpMallaInlineSearchSection: View {
    let query: String
    let results: [LeanUpMallaSearchResult]
    let onOpen: (LeanUpMallaDetailRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resultados")
                        .font(.headline.weight(.semibold))
                    Text("Buscando \"\(query)\" en tu malla.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(results.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.unadBlue.opacity(0.12)))
                    .foregroundStyle(Color.unadBlue)
            }

            if results.isEmpty {
                LeanUpSurfaceCard {
                    Text("No encontramos coincidencias con ese texto.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(results) { result in
                        Button {
                            onOpen(result.route)
                        } label: {
                            LeanUpSurfaceCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.primary)
                                            Text("Periodo \(result.period)")
                                                .font(.caption)
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
        }
    }
}

struct LeanUpMallaCompactOverviewCard: View {
    @ObservedObject var model: LeanUpAppModel
    let selectedPeriod: Int

    var body: some View {
        LeanUpMallaBannerCard(compact: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Resumen rapido")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("P\(selectedPeriod)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.unadBlue.opacity(0.12)))
                        .foregroundStyle(Color.unadBlue)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    LeanUpMallaCompactMetric(title: "Prom.", value: model.averageText)
                    LeanUpMallaCompactMetric(title: "Cred.", value: "\(model.earnedCredits)")
                    LeanUpMallaCompactMetric(title: "Rojos", value: "\(model.failedCount)")
                    LeanUpMallaCompactMetric(title: "Curso", value: "\(model.inProgressCount)")
                }
            }
        }
    }
}

struct LeanUpMallaCompactMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

struct LeanUpMallaReminderPreviewCard: View {
    let reminders: [LeanUpPeriodReminder]
    let onExpand: () -> Void

    var body: some View {
        LeanUpMallaBannerCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fechas Importantes")
                            .font(.headline.weight(.semibold))
                        Text("Tus proximas 3 fechas manuales, sin importar el periodo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    LeanUpAnimatedExpandButton {
                        onExpand()
                    }
                }

                if reminders.isEmpty {
                    Text("Aun no tienes recordatorios en este periodo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(reminders) { reminder in
                            LeanUpReminderPreviewRow(reminder: reminder)
                        }
                    }
                }
            }
        }
    }
}

struct LeanUpReminderPreviewRow: View {
    let reminder: LeanUpPeriodReminder

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(reminder.isDone ? Color.green : Color.unadBlue)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((reminder.isDone ? Color.green : Color.unadBlue).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text("P\(reminder.period)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.unadBlue.opacity(0.12)))
                        .foregroundStyle(Color.unadBlue)
                    Text(reminder.dueDate, format: .dateTime.day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !reminder.notes.isEmpty {
                    Text(reminder.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }
}

struct LeanUpMallaMotivationCard: View {
    let model: LeanUpAppModel
    @State private var message: LeanUpMotivationMessage
    private let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    init(model: LeanUpAppModel) {
        self.model = model
        _message = State(initialValue: model.mallaMotivationMessage)
    }

    var body: some View {
        LeanUpMallaBannerCard(compact: true) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mensaje para hoy")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.unadBlue)

                    Text(message.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .id("\(message.title)|\(message.detail)")
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.985)), removal: .opacity))
            }
            .animation(.easeInOut(duration: 0.32), value: message)
        }
        .onReceive(timer) { _ in
            let nextMessage = model.mallaMotivationMessage
            guard nextMessage != message else { return }

            withAnimation(.easeInOut(duration: 0.32)) {
                message = nextMessage
            }
        }
    }
}

struct LeanUpAnimatedExpandButton: View {
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                    pressed = false
                }
            }
            action()
        } label: {
            HStack(spacing: 8) {
                Text("Expandir")
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .scaleEffect(pressed ? 1.08 : 1.0)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.unadBlue.opacity(0.12))
            )
            .foregroundStyle(Color.unadBlue)
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct LeanUpReminderListView: View {
    @ObservedObject var model: LeanUpAppModel
    let defaultPeriod: Int

    @Environment(\.dismiss) private var dismiss
    @State private var editingReminder: LeanUpPeriodReminder?
    @State private var isPresentingAddReminder = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LeanUpSurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fechas importantes")
                                .font(.headline.weight(.semibold))
                            Text("Aqui puedes ver todas tus fechas limite manuales, de cualquier periodo, editar lo que ya tienes y agregar nuevas entregas sin salir de Malla.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if reminders.isEmpty {
                        LeanUpSurfaceCard {
                            Text("Aun no has agregado recordatorios para este periodo.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(reminders) { reminder in
                            LeanUpReminderListRow(
                                reminder: reminder,
                                onToggleDone: {
                                    model.setReminderDone(!reminder.isDone, reminderID: reminder.id)
                                },
                                onEdit: {
                                    editingReminder = reminder
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(LeanUpPageBackground())
            .navigationTitle("Recordatorios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Volver", systemImage: "chevron.backward")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Agregar recordatorio") {
                        isPresentingAddReminder = true
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isPresentingAddReminder) {
            LeanUpReminderEditorView(model: model, period: defaultPeriod)
        }
        .sheet(item: $editingReminder) { reminder in
            LeanUpReminderEditorView(model: model, period: defaultPeriod, reminder: reminder)
        }
    }

    private var reminders: [LeanUpPeriodReminder] {
        model.reminders()
    }
}

struct LeanUpReminderListRow: View {
    let reminder: LeanUpPeriodReminder
    let onToggleDone: () -> Void
    let onEdit: () -> Void

    var body: some View {
        LeanUpSurfaceCard {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleDone) {
                    Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(reminder.isDone ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(reminder.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text("P\(reminder.period)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.unadBlue.opacity(0.12)))
                            .foregroundStyle(Color.unadBlue)
                        Text(reminder.dueDate, format: .dateTime.day().month(.wide).year())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !reminder.notes.isEmpty {
                        Text(reminder.notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Editar") {
                    onEdit()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.unadBlue)
            }
        }
    }
}

struct LeanUpReminderEditorView: View {
    @ObservedObject var model: LeanUpAppModel
    let period: Int
    let reminder: LeanUpPeriodReminder?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var dueDate: Date
    @State private var reminderPeriod: Int
    @State private var notes: String

    init(model: LeanUpAppModel, period: Int, reminder: LeanUpPeriodReminder? = nil) {
        self.model = model
        self.period = period
        self.reminder = reminder
        _title = State(initialValue: reminder?.title ?? "")
        _dueDate = State(initialValue: reminder?.dueDate ?? Date())
        _reminderPeriod = State(initialValue: reminder?.period ?? period)
        _notes = State(initialValue: reminder?.notes ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LeanUpSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Titulo del recordatorio", systemImage: "text.cursor")
                                .font(.headline.weight(.semibold))

                            TextField("Ej. Entrega actividad 3", text: $title)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                    }

                    LeanUpSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Fecha limite", systemImage: "calendar")
                                .font(.headline.weight(.semibold))

                            DatePicker(
                                "Selecciona la fecha",
                                selection: $dueDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                        }
                    }

                    LeanUpSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Periodo", systemImage: "square.grid.2x2")
                                .font(.headline.weight(.semibold))

                            Picker("Periodo", selection: $reminderPeriod) {
                                ForEach(model.periods, id: \.self) { period in
                                    Text("P\(period)").tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    LeanUpSurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Notas", systemImage: "note.text")
                                .font(.headline.weight(.semibold))

                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.primary.opacity(0.06))
                                )
                        }
                    }

                    if reminder != nil {
                        Button {
                            model.deleteReminder(reminder!.id)
                            dismiss()
                        } label: {
                            Label("Eliminar recordatorio", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(LeanUpSecondaryButtonStyle())
                        .tint(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(LeanUpPageBackground())
            .navigationTitle(reminder == nil ? "Nuevo recordatorio" : "Editar recordatorio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        saveReminder()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func saveReminder() {
        let updated = LeanUpPeriodReminder(
            id: reminder?.id ?? UUID().uuidString,
            title: title,
            dueDate: dueDate,
            period: reminderPeriod,
            notes: notes,
            isDone: reminder?.isDone ?? false
        )
        model.saveReminder(updated)
        dismiss()
    }
}

enum LeanUpMallaDetailRoute: Identifiable {
    case course(LeanUpCourse)
    case electiveGroup(LeanUpElectiveGroup, targetOptionCode: String? = nil)

    var id: String {
        switch self {
        case .course(let course):
            return "course-\(course.id)"
        case .electiveGroup(let group, let targetOptionCode):
            if let targetOptionCode {
                return "elective-\(group.id)-\(targetOptionCode)"
            }
            return "elective-\(group.id)"
        }
    }
}

struct LeanUpMallaDetailContainerView: View {
    @ObservedObject var model: LeanUpAppModel
    @State private var currentRoute: LeanUpMallaDetailRoute

    init(model: LeanUpAppModel, initialRoute: LeanUpMallaDetailRoute) {
        self.model = model
        _currentRoute = State(initialValue: initialRoute)
    }

    var body: some View {
        Group {
            switch currentRoute {
            case .course(let course):
                LeanUpCourseDetailView(model: model, course: course, onSelectRoute: updateRoute)
            case .electiveGroup(let group, let targetOptionCode):
                LeanUpElectiveGroupDetailView(
                    model: model,
                    group: group,
                    initialTargetOptionCode: targetOptionCode,
                    onSelectRoute: updateRoute
                )
            }
        }
        .id(currentRoute.id)
    }

    private func updateRoute(_ route: LeanUpMallaDetailRoute) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            currentRoute = route
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
    let selectedFilter: LeanUpMallaFilter
    let periodResetScrollToken: Int
    let filterResetScrollToken: Int
    let periodResetScrollTarget: Int
    let filterResetScrollTarget: LeanUpMallaFilter
    let onSelectPeriod: (Int) -> Void
    let onSelectFilter: (LeanUpMallaFilter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollViewReader { proxy in
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
                            .id("period-\(period)")
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .onAppear {
                    scrollPeriodBanner(using: proxy, animated: false)
                }
                .onChange(of: periodResetScrollToken) { _ in
                    scrollPeriodBanner(using: proxy, targetPeriod: periodResetScrollTarget, animated: true)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LeanUpMallaFilter.allCases) { filter in
                            Button {
                                onSelectFilter(filter)
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
                            .id("filter-\(filter.rawValue)")
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .onAppear {
                    scrollFilterBanner(using: proxy, animated: false)
                }
                .onChange(of: filterResetScrollToken) { _ in
                    scrollFilterBanner(using: proxy, targetFilter: filterResetScrollTarget, animated: true)
                }
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

    private func scrollPeriodBanner(using proxy: ScrollViewProxy, animated: Bool) {
        scrollPeriodBanner(using: proxy, targetPeriod: selectedPeriod, animated: animated)
    }

    private func scrollPeriodBanner(using proxy: ScrollViewProxy, targetPeriod: Int, animated: Bool) {
        scheduleCenteredScroll(
            using: proxy,
            targetID: "period-\(targetPeriod)",
            animated: animated,
            delays: animated ? [0.0, 0.08, 0.18, 0.32] : [0.0, 0.08]
        )
    }

    private func scrollFilterBanner(using proxy: ScrollViewProxy, animated: Bool) {
        scrollFilterBanner(using: proxy, targetFilter: selectedFilter, animated: animated)
    }

    private func scrollFilterBanner(using proxy: ScrollViewProxy, targetFilter: LeanUpMallaFilter, animated: Bool) {
        scheduleCenteredScroll(
            using: proxy,
            targetID: "filter-\(targetFilter.rawValue)",
            animated: animated,
            delays: animated ? [0.0, 0.08, 0.18] : [0.0]
        )
    }

    private func scheduleCenteredScroll(
        using proxy: ScrollViewProxy,
        targetID: String,
        animated: Bool,
        delays: [TimeInterval]
    ) {
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let action = {
                    proxy.scrollTo(targetID, anchor: .center)
                }

                if animated {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        action()
                    }
                } else {
                    action()
                }
            }
        }
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

                        LazyVStack(spacing: 12) {
                            ForEach(courses) { course in
                                LeanUpCourseRow(
                                    course: course,
                                    note: model.note(for: course),
                                    status: model.courseStatus(for: course)
                                )
                                .contentShape(Rectangle())
                                .modifier(
                                    LeanUpQuickInProgressGesture(
                                        isEnabled: canQuickToggle(course: course),
                                        isActive: model.isCourseInProgress(course),
                                        bottomGestureExclusionHeight: 44,
                                        onToggle: {
                                            model.setCourseInProgress(!model.isCourseInProgress(course), for: course.id)
                                        }
                                    )
                                )
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        onOpen(.course(course))
                                    }
                                )
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

                        LazyVStack(spacing: 12) {
                            ForEach(electiveGroups) { group in
                                LeanUpElectiveGroupRow(
                                    group: group,
                                    selectedOption: model.selectedOption(in: group),
                                    note: model.selectedOption(in: group).flatMap { model.electiveNote(groupName: group.name, optionCode: $0.code) },
                                    status: model.electiveStatus(for: group)
                                )
                                .contentShape(Rectangle())
                                .modifier(
                                    LeanUpQuickInProgressGesture(
                                        isEnabled: canQuickToggle(group: group),
                                        isActive: model.isElectiveInProgress(group),
                                        bottomGestureExclusionHeight: 0,
                                        onToggle: {
                                            model.setElectiveInProgress(!model.isElectiveInProgress(group), groupName: group.name)
                                        }
                                    )
                                )
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        onOpen(.electiveGroup(group))
                                    }
                                )
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

    private func canQuickToggle(course: LeanUpCourse) -> Bool {
        switch model.courseStatus(for: course) {
        case .pending, .inProgress:
            return true
        default:
            return false
        }
    }

    private func canQuickToggle(group: LeanUpElectiveGroup) -> Bool {
        guard let selected = model.selectedOption(in: group) else { return false }
        switch model.electiveStatus(for: group) {
        case .pending, .inProgress:
            break
        default:
            return false
        }
        return model.electiveNote(groupName: group.name, optionCode: selected.code) == nil
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

private struct LeanUpQuickInProgressGesture: ViewModifier {
    let isEnabled: Bool
    let isActive: Bool
    let bottomGestureExclusionHeight: CGFloat
    let onToggle: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var didTrigger = false
    @State private var hasLockedHorizontalSwipe = false

    func body(content: Content) -> some View {
        content
            .background(alignment: .leading) {
                if isEnabled && dragOffset > 0 {
                    actionBackground
                }
            }
            .offset(x: max(0, dragOffset * 0.14))
            .overlay(alignment: .topLeading) {
                GeometryReader { proxy in
                    Color.clear
                        .frame(
                            width: proxy.size.width,
                            height: max(0, proxy.size.height - bottomGestureExclusionHeight),
                            alignment: .topLeading
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 28)
                                .onChanged { value in
                                    guard isEnabled else { return }
                                    let interactiveHeight = max(0, proxy.size.height - bottomGestureExclusionHeight)
                                    guard value.startLocation.y <= interactiveHeight else { return }
                                    let horizontal = value.translation.width
                                    let vertical = abs(value.translation.height)

                                    if !hasLockedHorizontalSwipe {
                                        guard horizontal > 64, horizontal > vertical * 3.0 else { return }
                                        hasLockedHorizontalSwipe = true
                                    }

                                    guard hasLockedHorizontalSwipe else { return }

                                    let translation = max(0, horizontal)
                                    dragOffset = min(translation, 124)

                                    if translation > 118 && !didTrigger {
                                        didTrigger = true
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        onToggle()
                                    }
                                }
                                .onEnded { _ in
                                    didTrigger = false
                                    hasLockedHorizontalSwipe = false
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                                        dragOffset = 0
                                    }
                                }
                        )
                }
            }
    }

    private var actionBackground: some View {
        let progress = min(max(dragOffset / 124, 0), 1)

        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill((isActive ? Color.gray : Color.unadCyan).opacity(0.14))
            .opacity(progress)
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
    var onSelectRoute: (LeanUpMallaDetailRoute) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
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
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct LeanUpElectiveGroupDetailView: View {
    @ObservedObject var model: LeanUpAppModel
    let group: LeanUpElectiveGroup
    let initialTargetOptionCode: String?
    var onSelectRoute: (LeanUpMallaDetailRoute) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack?
    @State private var highlightedOptionCode: String?

    var body: some View {
        NavigationView {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            LeanUpSurfaceCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.name)
                                        .font(.title2.weight(.bold))
                                    Text(optionCountText)
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

                                        Text("Cada disciplinar especifico trae el mismo catalogo completo. Esta franja solo te ayuda a filtrar por ruta dentro del mismo grupo.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            ForEach(displayedOptions) { option in
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
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        if !option.plainLanguage.isEmpty {
                                            LeanUpElectiveOptionSection(
                                                title: "En palabras simples",
                                                systemImage: "lightbulb.fill",
                                                detail: option.plainLanguage
                                            )
                                        }

                                        if !option.outcomes.isEmpty {
                                            LeanUpElectiveOptionSection(
                                                title: "Salidas y aplicacion",
                                                systemImage: "briefcase.fill",
                                                detail: option.outcomes
                                            )
                                        }

                                        if !option.skills.isEmpty {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Label("Habilidades que esta electiva fortalece", systemImage: "star.square.on.square.fill")
                                                    .font(.subheadline.weight(.semibold))
                                                FlowTagList(items: Array(option.skills.prefix(8)))
                                            }
                                        }

                                        if !option.linkedinText.isEmpty {
                                            LeanUpMallaLinkedInInsetCard(text: option.linkedinText)
                                        }

                                        if !option.portfolioProject.isEmpty {
                                            LeanUpMallaPortfolioInsetCard(
                                                project: option.portfolioProject,
                                                prompt: option.effectivePortfolioPrompt
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(
                                            highlightedOptionCode == option.code ? Color.unadBlue.opacity(0.55) : Color.clear,
                                            lineWidth: highlightedOptionCode == option.code ? 2 : 0
                                        )
                                )
                                .id(option.code)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                    }
                    .leanUpKeyboardFriendlyScroll()
                    .background(LeanUpPageBackground())
                    .onAppear {
                        if selectedDisciplinaryTrack == nil {
                            selectedDisciplinaryTrack = initialDisciplinaryTrack
                        }
                        scrollToTargetIfNeeded(using: proxy, animated: false)
                    }
                    .onChange(of: selectedDisciplinaryTrack) { _ in
                        scrollToTargetIfNeeded(using: proxy, animated: true)
                    }
                }
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
            }
        }
        .navigationViewStyle(.stack)
    }

}

private extension LeanUpElectiveGroupDetailView {
    var targetOption: LeanUpElectiveOption? {
        guard let initialTargetOptionCode else { return nil }
        return group.options.first { $0.code == initialTargetOptionCode }
    }

    var initialDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack? {
        targetOption?.disciplinaryTrackValues.first ?? group.electiveDisciplinaryTrack ?? availableDisciplinaryTracks.first
    }

    var activeDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack? {
        selectedDisciplinaryTrack ?? group.electiveDisciplinaryTrack ?? availableDisciplinaryTracks.first
    }

    var availableDisciplinaryTracks: [LeanUpElectiveDisciplinaryTrack] {
        var seen = Set<LeanUpElectiveDisciplinaryTrack>()
        return group.options
            .flatMap(\.disciplinaryTrackValues)
            .filter { seen.insert($0).inserted }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var filteredOptions: [LeanUpElectiveOption] {
        guard let track = activeDisciplinaryTrack else { return group.options }

        return group.options.filter { option in
            option.disciplinaryTrackValues.isEmpty || option.disciplinaryTrackValues.contains(track)
        }
    }

    var displayedOptions: [LeanUpElectiveOption] {
        filteredOptions
    }

    var optionCountText: String {
        return "Periodo \(group.period) - \(filteredOptions.count) de \(group.options.count) opciones"
    }

    var headerDescription: String {
        if availableDisciplinaryTracks.isEmpty {
            return "Selecciona la electiva que realmente quieres cursar en este grupo. Solo una puede estar activa a la vez."
        }

        return "LeanUp filtra por ruta dentro de este mismo electivo para que no tengas que revisar las 18 opciones de golpe."
    }

    func scrollToTargetIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard let targetOptionCode = initialTargetOptionCode else { return }
        guard displayedOptions.contains(where: { $0.code == targetOptionCode }) else { return }

        DispatchQueue.main.async {
            let action = {
                proxy.scrollTo(targetOptionCode, anchor: .top)
            }

            if animated {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    action()
                }
            } else {
                action()
            }

            highlightOption(targetOptionCode)
        }
    }

    func highlightOption(_ optionCode: String) {
        highlightedOptionCode = optionCode
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if highlightedOptionCode == optionCode {
                withAnimation(.easeOut(duration: 0.24)) {
                    highlightedOptionCode = nil
                }
            }
        }
    }
}

enum LeanUpElectiveDisciplinaryTrack: String, CaseIterable, Identifiable, Hashable {
    case digitalTransformation
    case competitiveness
    case sustainability

    var id: String { rawValue }
    var sortOrder: Int {
        switch self {
        case .digitalTransformation: return 0
        case .competitiveness: return 1
        case .sustainability: return 2
        }
    }

    var title: String {
        switch self {
        case .digitalTransformation: return "Transformacion Digital"
        case .competitiveness: return "Competitividad"
        case .sustainability: return "Sustentabilidad"
        }
    }
}

private extension LeanUpElectiveGroup {
    var electiveDisciplinaryTrack: LeanUpElectiveDisciplinaryTrack? {
        let normalizedName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        if normalizedName.contains("transformacion digital") {
            return .digitalTransformation
        }

        if normalizedName.contains("competitividad") {
            return .competitiveness
        }

        if normalizedName.contains("sustentabilidad") || normalizedName.contains("sostenibilidad") {
            return .sustainability
        }

        return nil
    }
}

private extension LeanUpElectiveOption {
    var disciplinaryTrackValues: [LeanUpElectiveDisciplinaryTrack] {
        disciplinaryTracks.compactMap(LeanUpElectiveDisciplinaryTrack.init(rawValue:))
    }

    var effectivePortfolioPrompt: String {
        if !portfolioPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return portfolioPrompt
        }

        guard !portfolioProject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        return "Hola, soy estudiante de \(name) en la UNAD Colombia y tengo que desarrollar este proyecto de portafolio: \(portfolioProject). Quiero que me guies paso a paso para entenderlo y construirlo bien, no que lo hagas por mi. Empieza explicandome en palabras sencillas cual es el objetivo real de este proyecto y que entregables deberia preparar. Luego preguntame que enfoque quiero darle y espera mi respuesta antes de continuar."
    }
}

struct LeanUpElectiveOptionSection: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
                    idleTitle: "Copiar prompt para IA",
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

@MainActor
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
        leanUpMallaSearchResults(model: model, query: query.trimmingCharacters(in: .whitespacesAndNewlines))
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

private struct LeanUpDetailInlineResultsCard: View {
    let results: [LeanUpMallaSearchResult]
    let onSelect: (LeanUpMallaDetailRoute) -> Void

    var body: some View {
        LeanUpSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Resultados dentro de Malla", systemImage: "magnifyingglass")
                    .font(.headline.weight(.semibold))

                if results.isEmpty {
                    Text("No encontramos coincidencias con lo que escribiste.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(results.prefix(6))) { result in
                        Button {
                            onSelect(result.route)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct LeanUpNativeDetailSearchModifier: ViewModifier {
    @Binding var query: String
    @Binding var isPresented: Bool
    let prompt: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            searchableContentIOS26(content)
        } else if #available(iOS 17.0, *) {
            searchableContentIOS17(content)
        } else {
            content
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: prompt
                )
        }
    }

    @available(iOS 26.0, *)
    private func searchableContentIOS26(_ content: Content) -> some View {
        content
            .searchable(
                text: $query,
                isPresented: $isPresented,
                placement: .automatic,
                prompt: prompt
            )
            .searchToolbarBehavior(.minimize)
    }

    @available(iOS 17.0, *)
    private func searchableContentIOS17(_ content: Content) -> some View {
        content
            .searchable(
                text: $query,
                isPresented: $isPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: prompt
            )
    }
}

private struct LeanUpNativeMallaSearchModifier: ViewModifier {
    @Binding var query: String
    let prompt: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .searchable(
                    text: $query,
                    placement: .automatic,
                    prompt: prompt
                )
                .searchToolbarBehavior(.minimize)
        } else {
            content
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: prompt
                )
        }
    }
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

private func leanUpElectiveOptionMatches(_ option: LeanUpElectiveOption, query: String) -> Bool {
    guard !query.isEmpty else { return true }

    let values = [
        option.name,
        option.code,
        option.summary,
        option.plainLanguage,
        option.outcomes,
        option.linkedinText,
        option.portfolioProject,
        option.portfolioPrompt
    ] + option.skills

    return values.contains { leanUpMatches($0, query: query) }
}

@MainActor
private func leanUpMallaSearchResults(model: LeanUpAppModel, query: String) -> [LeanUpMallaSearchResult] {
    guard !query.isEmpty else { return [] }

    let courseResults = model.academics.courses.compactMap { course -> LeanUpMallaSearchResult? in
        guard leanUpCourseMatches(course, query: query) else { return nil }
        return LeanUpMallaSearchResult(
            id: "course-\(course.id)",
            title: course.name,
            subtitle: course.summary,
            period: course.period,
            route: .course(course),
            isElective: false
        )
    }

    let electiveResults = model.academics.electiveGroups.flatMap { group -> [LeanUpMallaSearchResult] in
        let optionMatches = group.options.compactMap { option -> LeanUpMallaSearchResult? in
            guard leanUpElectiveOptionMatches(option, query: query) else { return nil }
            return LeanUpMallaSearchResult(
                id: "option-\(group.id)-\(option.code)",
                title: option.name,
                subtitle: "\(group.name) · Codigo \(option.code)",
                period: group.period,
                route: .electiveGroup(group, targetOptionCode: option.code),
                isElective: true
            )
        }

        if !optionMatches.isEmpty {
            return optionMatches
        }

        guard leanUpMatches(group.name, query: query) else { return [] }
        return [
            LeanUpMallaSearchResult(
                id: "group-\(group.id)",
                title: group.name,
                subtitle: model.selectedOption(in: group)?.name ?? "\(group.options.count) opciones disponibles",
                period: group.period,
                route: .electiveGroup(group),
                isElective: true
            )
        ]
    }

    return (courseResults + electiveResults).sorted {
        if $0.period == $1.period { return $0.title < $1.title }
        return $0.period < $1.period
    }
}

private func leanUpMatches(_ value: String, query: String) -> Bool {
    let normalizedValue = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    return normalizedValue.contains(normalizedQuery)
}


