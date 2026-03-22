import Foundation
import SwiftUI
enum LeanUpThemeMode: String, Codable, CaseIterable {
    case light
    case dark
    case system
}

struct LeanUpPeriodReminder: Codable, Equatable, Identifiable, Hashable {
    let id: String
    var title: String
    var dueDate: Date
    var period: Int
    var notes: String
    var isDone: Bool

    init(
        id: String = UUID().uuidString,
        title: String = "",
        dueDate: Date = Date(),
        period: Int = 1,
        notes: String = "",
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.period = period
        self.notes = notes
        self.isDone = isDone
    }
}

struct LeanUpMotivationMessage: Equatable {
    let title: String
    let detail: String
}

struct LeanUpSnapshot: Codable, Equatable {
    var notas: [String: Double]
    var electivosSeleccionados: [String: String]
    var electivosNotas: [String: Double]
    var cursosEnCurso: [String: Bool]
    var electivosEnCurso: [String: Bool]
    var periodReminders: [LeanUpPeriodReminder]
    var username: String
    var darkMode: Bool
    var themeMode: LeanUpThemeMode

    static let empty = LeanUpSnapshot()

    init(
        notas: [String: Double] = [:],
        electivosSeleccionados: [String: String] = [:],
        electivosNotas: [String: Double] = [:],
        cursosEnCurso: [String: Bool] = [:],
        electivosEnCurso: [String: Bool] = [:],
        periodReminders: [LeanUpPeriodReminder] = [],
        username: String = "Usuario",
        darkMode: Bool = false,
        themeMode: LeanUpThemeMode = .light
    ) {
        self.notas = notas
        self.electivosSeleccionados = electivosSeleccionados
        self.electivosNotas = electivosNotas
        self.cursosEnCurso = cursosEnCurso
        self.electivosEnCurso = electivosEnCurso
        self.periodReminders = periodReminders
        self.username = username
        self.darkMode = darkMode
        self.themeMode = themeMode
        self = self.normalized()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notas = try container.decodeIfPresent([String: Double].self, forKey: .notas) ?? [:]
        electivosSeleccionados = try container.decodeIfPresent([String: String].self, forKey: .electivosSeleccionados) ?? [:]
        electivosNotas = try container.decodeIfPresent([String: Double].self, forKey: .electivosNotas) ?? [:]
        cursosEnCurso = try container.decodeIfPresent([String: Bool].self, forKey: .cursosEnCurso) ?? [:]
        electivosEnCurso = try container.decodeIfPresent([String: Bool].self, forKey: .electivosEnCurso) ?? [:]
        periodReminders = try container.decodeIfPresent([LeanUpPeriodReminder].self, forKey: .periodReminders) ?? []
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "Usuario"
        darkMode = try container.decodeIfPresent(Bool.self, forKey: .darkMode) ?? false
        themeMode = try container.decodeIfPresent(LeanUpThemeMode.self, forKey: .themeMode) ?? .light
        self = self.normalized()
    }

    func normalized() -> LeanUpSnapshot {
        var copy = self

        let trimmed = copy.username.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.username = trimmed.isEmpty ? "Usuario" : trimmed

        copy.electivosNotas = copy.electivosNotas.filter { key, _ in
            let parts = key.components(separatedBy: ":::")
            guard parts.count == 2 else { return false }
            return copy.electivosSeleccionados[parts[0]] == parts[1]
        }

        copy.cursosEnCurso = copy.cursosEnCurso.filter { key, value in
            value && copy.notas[key] == nil
        }

        copy.electivosEnCurso = copy.electivosEnCurso.filter { groupName, value in
            guard value, let selectedCode = copy.electivosSeleccionados[groupName] else { return false }
            let noteKey = "\(groupName):::\(selectedCode)"
            return copy.electivosNotas[noteKey] == nil
        }

        copy.periodReminders = copy.periodReminders
            .map { reminder in
                var normalized = reminder
                let trimmedTitle = normalized.title.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.title = trimmedTitle.isEmpty ? "Recordatorio" : trimmedTitle
                normalized.notes = normalized.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                normalized.period = max(normalized.period, 1)
                return normalized
            }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.dueDate < $1.dueDate
            }

        switch copy.themeMode {
        case .light:
            copy.darkMode = false
        case .dark:
            copy.darkMode = true
        case .system:
            break
        }

        return copy
    }

    func encodedString(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try encoder.encode(normalized())
        guard let string = String(data: data, encoding: .utf8) else {
            throw LeanUpSnapshotError.invalidUTF8
        }
        return string
    }

    static func decode(from string: String) throws -> LeanUpSnapshot {
        guard let data = string.data(using: .utf8) else {
            throw LeanUpSnapshotError.invalidUTF8
        }
        return try JSONDecoder().decode(LeanUpSnapshot.self, from: data)
    }
}

enum LeanUpSnapshotError: Error {
    case invalidUTF8
    case invalidBase64
}

struct LeanUpSnapshotStore {
    static let nativeBackupKey = "leanup_v4_backup"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSnapshot() throws -> LeanUpSnapshot? {
        guard let base64 = userDefaults.string(forKey: Self.nativeBackupKey) else {
            return nil
        }
        guard let data = Data(base64Encoded: base64) else {
            throw LeanUpSnapshotError.invalidBase64
        }
        guard let json = String(data: data, encoding: .utf8) else {
            throw LeanUpSnapshotError.invalidUTF8
        }
        return try LeanUpSnapshot.decode(from: json)
    }

    @discardableResult
    func saveSnapshot(_ snapshot: LeanUpSnapshot) throws -> String {
        let normalized = snapshot.normalized()
        let json = try normalized.encodedString()
        let base64 = Data(json.utf8).base64EncodedString()
        userDefaults.set(base64, forKey: Self.nativeBackupKey)
        return json
    }
}

struct LeanUpAcademicsPayload: Codable {
    var courses: [LeanUpCourse]
    var electiveGroups: [LeanUpElectiveGroup]

    static let empty = LeanUpAcademicsPayload(courses: [], electiveGroups: [])
}

struct LeanUpCourse: Codable, Identifiable, Hashable {
    let id: Int
    let period: Int
    let code: String
    let name: String
    let credits: Int
    let difficulty: Int
    let types: [String]
    let summary: String
    let plainLanguage: String
    let outcomes: String
    let skills: [String]
    let linkedinText: String
    let portfolioProject: String
    let portfolioPrompt: String

    init(
        id: Int,
        period: Int,
        code: String,
        name: String,
        credits: Int,
        difficulty: Int,
        types: [String],
        summary: String,
        plainLanguage: String,
        outcomes: String,
        skills: [String] = [],
        linkedinText: String = "",
        portfolioProject: String = "",
        portfolioPrompt: String = ""
    ) {
        self.id = id
        self.period = period
        self.code = code
        self.name = name
        self.credits = credits
        self.difficulty = difficulty
        self.types = types
        self.summary = summary
        self.plainLanguage = plainLanguage
        self.outcomes = outcomes
        self.skills = skills
        self.linkedinText = linkedinText
        self.portfolioProject = portfolioProject
        self.portfolioPrompt = portfolioPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        period = try container.decode(Int.self, forKey: .period)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        credits = try container.decode(Int.self, forKey: .credits)
        difficulty = try container.decode(Int.self, forKey: .difficulty)
        types = try container.decodeIfPresent([String].self, forKey: .types) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        plainLanguage = try container.decodeIfPresent(String.self, forKey: .plainLanguage) ?? ""
        outcomes = try container.decodeIfPresent(String.self, forKey: .outcomes) ?? ""
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        linkedinText = try container.decodeIfPresent(String.self, forKey: .linkedinText) ?? ""
        portfolioProject = try container.decodeIfPresent(String.self, forKey: .portfolioProject) ?? ""
        portfolioPrompt = try container.decodeIfPresent(String.self, forKey: .portfolioPrompt) ?? ""
    }
}

struct LeanUpElectiveGroup: Codable, Identifiable, Hashable {
    var id: String { name }

    let name: String
    let period: Int
    let options: [LeanUpElectiveOption]
}

struct LeanUpElectiveOption: Codable, Identifiable, Hashable {
    var id: String { code }

    let code: String
    let name: String
    let credits: Int
    let summary: String
    let plainLanguage: String
    let outcomes: String
    let skills: [String]
    let linkedinText: String
    let portfolioProject: String
    let portfolioPrompt: String
    let disciplinaryTracks: [String]

    init(
        code: String,
        name: String,
        credits: Int,
        summary: String,
        plainLanguage: String,
        outcomes: String,
        skills: [String] = [],
        linkedinText: String = "",
        portfolioProject: String = "",
        portfolioPrompt: String = "",
        disciplinaryTracks: [String] = []
    ) {
        self.code = code
        self.name = name
        self.credits = credits
        self.summary = summary
        self.plainLanguage = plainLanguage
        self.outcomes = outcomes
        self.skills = skills
        self.linkedinText = linkedinText
        self.portfolioProject = portfolioProject
        self.portfolioPrompt = portfolioPrompt
        self.disciplinaryTracks = disciplinaryTracks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        credits = try container.decode(Int.self, forKey: .credits)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        plainLanguage = try container.decodeIfPresent(String.self, forKey: .plainLanguage) ?? ""
        outcomes = try container.decodeIfPresent(String.self, forKey: .outcomes) ?? ""
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        linkedinText = try container.decodeIfPresent(String.self, forKey: .linkedinText) ?? ""
        portfolioProject = try container.decodeIfPresent(String.self, forKey: .portfolioProject) ?? ""
        portfolioPrompt = try container.decodeIfPresent(String.self, forKey: .portfolioPrompt) ?? ""
        disciplinaryTracks = try container.decodeIfPresent([String].self, forKey: .disciplinaryTracks) ?? []
    }
}

struct LeanUpAcademicsStore {
    private static let cacheKey = "leanup_native_academics_cache"

    func load() -> LeanUpAcademicsPayload {
        for url in candidateURLs() {
            guard let data = try? Data(contentsOf: url) else { continue }

            if let payload = tryDecode(data: data) {
                saveCachedPayload(payload)
                return payload
            }
        }

        if let cached = loadCachedPayload() {
            return cached
        }

        return .empty
    }

    private func candidateURLs() -> [URL] {
        let directCandidates = [
            Bundle.main.url(forResource: "native-academics", withExtension: "json"),
            Bundle.main.resourceURL?.appendingPathComponent("native-academics.json"),
            Bundle.main.bundleURL.appendingPathComponent("native-academics.json"),
        ]

        var seen = Set<String>()
        return directCandidates.compactMap { $0 }.filter { url in
            let key = url.path
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func tryDecode(data: Data) -> LeanUpAcademicsPayload? {
        if let payload = try? JSONDecoder().decode(LeanUpAcademicsPayload.self, from: data) {
            return payload
        }

        if let latin1 = String(data: data, encoding: .isoLatin1),
           let utf8Data = latin1.data(using: .utf8),
           let payload = try? JSONDecoder().decode(LeanUpAcademicsPayload.self, from: utf8Data) {
            return payload
        }

        return nil
    }

    private func loadCachedPayload() -> LeanUpAcademicsPayload? {
        guard let raw = UserDefaults.standard.string(forKey: Self.cacheKey),
              let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(LeanUpAcademicsPayload.self, from: data),
              !payload.courses.isEmpty else {
            return nil
        }

        return payload
    }

    private func saveCachedPayload(_ payload: LeanUpAcademicsPayload) {
        guard !payload.courses.isEmpty,
              let data = try? JSONEncoder().encode(payload),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }

        UserDefaults.standard.set(raw, forKey: Self.cacheKey)
    }
}

@MainActor
final class LeanUpAppModel: ObservableObject {
    @Published var snapshot: LeanUpSnapshot = .empty

    let totalCourses = 38
    let totalCredits = 144
    let academics: LeanUpAcademicsPayload

    private let store = LeanUpSnapshotStore()
    private let academicsStore = LeanUpAcademicsStore()
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "MMMM 'de' yyyy"
        return formatter
    }()

    private static let shortMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    init() {
        academics = academicsStore.load()
        load()
    }

    var allGrades: [Double] {
        Array(snapshot.notas.values) + Array(snapshot.electivosNotas.values)
    }

    var registeredCount: Int {
        allGrades.count
    }

    var averageValue: Double? {
        guard !allGrades.isEmpty else { return nil }
        return allGrades.reduce(0, +) / Double(allGrades.count)
    }

    var approvedCount: Int {
        allGrades.filter { $0 >= 3.0 }.count
    }

    var failedCount: Int {
        allGrades.filter { $0 < 3.0 }.count
    }

    var inProgressCount: Int {
        inProgressCourseCount + inProgressElectiveCount
    }

    var selectedElectivesCount: Int {
        snapshot.electivosSeleccionados.count
    }

    var totalTrackableItems: Int {
        academics.courses.count + academics.electiveGroups.count
    }

    var pendingCount: Int {
        max(totalTrackableItems - approvedCount - failedCount - inProgressCount, 0)
    }

    var earnedCredits: Int {
        approvedCourses.reduce(0) { $0 + $1.credits } +
        approvedElectiveOptions.reduce(0) { $0 + $1.credits }
    }

    var electiveGroupsWithoutSelection: Int {
        academics.electiveGroups.filter { selectedOption(in: $0) == nil }.count
    }

    var focusPeriod: Int? {
        periods.first { progress(for: $0).approved < progress(for: $0).total } ?? periods.last
    }

    var completionPercentText: String {
        guard totalTrackableItems > 0 else { return "0%" }
        let ratio = Double(approvedCount) / Double(totalTrackableItems)
        return "\(Int((ratio * 100).rounded()))%"
    }

    var careerReadinessPercent: Int {
        guard totalTrackableItems > 0 else { return 0 }
        let ratio = Double(approvedCount) / Double(totalTrackableItems)
        return Int((ratio * 100).rounded())
    }

    var approvedCourses: [LeanUpCourse] {
        academics.courses.filter { (snapshot.notas[String($0.id)] ?? 0) >= 3.0 }
    }

    var approvedElectiveOptions: [LeanUpElectiveOption] {
        academics.electiveGroups.compactMap { group in
            guard let selected = selectedOption(in: group),
                  (electiveNote(groupName: group.name, optionCode: selected.code) ?? 0) >= 3.0 else {
                return nil
            }
            return selected
        }
    }

    var recommendedRoles: [String] {
        var seen = Set<String>()
        let sources = approvedCourses.map(\.outcomes) + approvedElectiveOptions.map(\.outcomes)

        return sources
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { role in
                if seen.contains(role) { return false }
                seen.insert(role)
                return true
            }
    }

    var activeFocusNames: [String] {
        academics.electiveGroups.compactMap { group in
            selectedOption(in: group)?.name
        }
    }

    var careerItems: [LeanUpCareerItem] {
        let approvedCourseItems = approvedCourses.map {
            LeanUpCareerItem(
                id: "course-\($0.id)",
                period: $0.period,
                name: $0.name,
                summary: $0.summary,
                outcomes: $0.outcomes,
                skills: $0.skills,
                linkedinText: $0.linkedinText,
                portfolioProject: $0.portfolioProject,
                isElective: false
            )
        }

        let approvedElectiveItems = academics.electiveGroups.compactMap { group -> LeanUpCareerItem? in
            guard let option = selectedOption(in: group),
                  (electiveNote(groupName: group.name, optionCode: option.code) ?? 0) >= 3.0 else {
                return nil
            }

            return LeanUpCareerItem(
                id: "elective-\(group.name)-\(option.code)",
                period: group.period,
                name: option.name,
                summary: option.summary,
                outcomes: option.outcomes,
                skills: option.skills,
                linkedinText: option.linkedinText,
                portfolioProject: option.portfolioProject,
                isElective: true
            )
        }

        return (approvedCourseItems + approvedElectiveItems)
            .sorted {
                if $0.period == $1.period {
                    return $0.name < $1.name
                }
                return $0.period < $1.period
            }
    }

    var linkedinHighlights: [LeanUpCareerItem] {
        careerItems.filter { !$0.linkedinText.isEmpty }
    }

    var portfolioHighlights: [LeanUpCareerItem] {
        careerItems.filter { !$0.portfolioProject.isEmpty }
    }

    var standoutSkills: [String] {
        var seen = Set<String>()

        return careerItems
            .flatMap(\.skills)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { skill in
                if seen.contains(skill) { return false }
                seen.insert(skill)
                return true
            }
    }

    var periods: [Int] {
        Array(
            Set(academics.courses.map(\.period) + academics.electiveGroups.map(\.period))
        ).sorted()
    }

    var studiedPeriodsCount: Int {
        Set(gradedItems.map(\.period)).count
    }

    var completedPeriodsCount: Int {
        periods.filter {
            let progress = progress(for: $0)
            return progress.total > 0 && progress.approved == progress.total
        }.count
    }

    var averageText: String {
        guard let averageValue else { return "-" }
        return String(format: "%.2f", averageValue)
    }

    var progressText: String {
        "\(approvedCount) aprobadas"
    }

    var themeDescription: String {
        switch snapshot.themeMode {
        case .light: return "Claro"
        case .dark: return "Oscuro"
        case .system: return "Sistema"
        }
    }

    var failedCourses: [LeanUpCourse] {
        academics.courses
            .filter { courseStatus(for: $0) == .failed }
            .sorted {
                if $0.period == $1.period {
                    return $0.name < $1.name
                }
                return $0.period < $1.period
            }
    }

    var pendingCourses: [LeanUpCourse] {
        academics.courses
            .filter { courseStatus(for: $0) == .pending }
            .sorted {
                if $0.period == $1.period {
                    return $0.name < $1.name
                }
                return $0.period < $1.period
            }
    }

    var inProgressCourses: [LeanUpCourse] {
        academics.courses
            .filter { courseStatus(for: $0) == .inProgress }
            .sorted {
                if $0.period == $1.period {
                    return $0.name < $1.name
                }
                return $0.period < $1.period
            }
    }

    var highlightedCareerItems: [LeanUpCareerItem] {
        Array(careerItems.prefix(4))
    }

    var profileHeadline: String {
        if let primaryRole = recommendedRoles.first {
            return "Ya te estas perfilando hacia \(primaryRole)"
        }

        if let focus = activeFocusNames.first {
            return "Tu perfil ya empieza a tomar forma alrededor de \(focus)"
        }

        return "Tu perfil profesional ya tiene una base academica clara"
    }

    var professionalHeadline: String {
        profileHeadline
    }

    var profileSummary: String {
        if careerItems.isEmpty {
            return "Tu avance academico ya esta ordenado, pero aun necesitas registrar mas materias o electivas aprobadas para construir una narrativa profesional mas fuerte."
        }

        if let primaryRole = recommendedRoles.first {
            return "Tu avance combina \(approvedCount) materias o electivas aprobadas, \(earnedCredits) creditos ganados y senales concretas que ya apuntan hacia \(primaryRole)."
        }

        return "Tu avance ya combina \(approvedCount) materias o electivas aprobadas, \(earnedCredits) creditos ganados y evidencias suficientes para empezar a construir una presentacion profesional mas clara."
    }

    var professionalSummary: String {
        profileSummary
    }

    var nextProfessionalMove: String {
        if failedCount > 0 {
            return "Recupera primero las materias o electivas reprobadas. Eso mejora tu promedio y fortalece cualquier perfil profesional que quieras mostrar."
        }

        if electiveGroupsWithoutSelection > 0 {
            return "Define las electivas pendientes. Es la forma mas directa de darle una direccion mas clara a tu perfil."
        }

        if let period = focusPeriod {
            return "Empuja el periodo \(period). Ese bloque es el siguiente salto natural para ganar mas evidencia academica y profesional."
        }

        return "Tu base academica ya esta bastante clara. El siguiente paso es convertirla en historias y proyectos que puedas mostrar afuera."
    }

    var completionRatio: Double {
        guard totalTrackableItems > 0 else { return 0 }
        return Double(approvedCount) / Double(totalTrackableItems)
    }

    var completedEquivalentPeriods: Double {
        completionRatio * Double(max(periods.count, 1))
    }

    var paceEquivalentPeriodsPerStudiedPeriod: Double {
        guard studiedPeriodsCount > 0 else { return 0 }
        return completedEquivalentPeriods / Double(studiedPeriodsCount)
    }

    var estimatedRemainingPeriods: Double? {
        let pace = paceEquivalentPeriodsPerStudiedPeriod
        guard pace > 0 else { return nil }
        let remainingEquivalent = max(Double(max(periods.count, 1)) - completedEquivalentPeriods - inProgressEquivalentPeriods, 0)
        return remainingEquivalent / pace
    }

    var estimatedGraduationDate: Date? {
        guard approvedCount < totalTrackableItems else { return Date() }
        guard let remainingPeriods = estimatedRemainingPeriods else { return nil }
        let months = Int((remainingPeriods * 4.0).rounded())
        return Calendar.current.date(byAdding: .month, value: max(months, 0), to: Date())
    }

    var estimatedGraduationText: String? {
        guard let estimatedGraduationDate else { return nil }
        return Self.monthYearFormatter.string(from: estimatedGraduationDate)
    }

    var estimatedGraduationShortText: String? {
        guard let estimatedGraduationDate else { return nil }
        return Self.shortMonthYearFormatter.string(from: estimatedGraduationDate).capitalized
    }

    var paceTitle: String {
        if approvedCount >= totalTrackableItems, totalTrackableItems > 0 {
            return "Ya cerraste la malla completa."
        }

        guard registeredCount >= 3, let estimatedGraduationText else {
            return "Aun no hay suficiente historial para proyectar tu grado."
        }

        return "Si mantienes este ritmo, podrias terminar hacia \(estimatedGraduationText)."
    }

    var paceDetail: String {
        if approvedCount >= totalTrackableItems, totalTrackableItems > 0 {
            return "Tu progreso academico ya no necesita proyeccion: la carrera esta cerrada en la app."
        }

        guard registeredCount >= 3 else {
            return "Cuando registres mas notas en distintos periodos, LeanUp podra estimar mejor el cierre real de la carrera."
        }

        if inProgressCount > 0 {
            return "La lectura usa tu avance aprobado, tu carga actual marcada como en curso y la duracion real de ciclos de 4 meses."
        }

        return "La lectura usa tu avance aprobado, los periodos donde ya tienes notas y una duracion estimada de 4 meses por ciclo."
    }

    var paceValueText: String {
        guard paceEquivalentPeriodsPerStudiedPeriod > 0 else { return "--" }
        return String(format: "%.1f", paceEquivalentPeriodsPerStudiedPeriod)
    }

    var remainingPeriodsText: String {
        guard let estimatedRemainingPeriods else { return "--" }
        return String(format: "%.1f", estimatedRemainingPeriods)
    }

    var studiedPeriodsText: String {
        studiedPeriodsCount == 0 ? "--" : "\(studiedPeriodsCount)"
    }

    var inProgressCountText: String {
        inProgressCount == 0 ? "--" : "\(inProgressCount)"
    }

    var preferredDisplayName: String? {
        let trimmed = snapshot.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("Usuario") != .orderedSame else {
            return nil
        }
        return trimmed
    }

    var mallaMotivationMessage: LeanUpMotivationMessage {
        let todaySeed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let personalizationOffset = preferredDisplayName?.count ?? 0
        let seed = todaySeed + approvedCount + inProgressCount + failedCount + personalizationOffset

        if failedCount > 0 {
            let options = [
                LeanUpMotivationMessage(
                    title: "Cada rojo que cierras te devuelve aire.",
                    detail: personalized("No necesitas resolver toda la carrera hoy\(namePause). Empieza por una de las materias que mas pesa y vuelve a agarrar impulso.")
                ),
                LeanUpMotivationMessage(
                    title: "Recuperar tambien es avanzar.",
                    detail: personalized("Tu progreso no se mide solo por lo nuevo\(namePause), sino por lo que logras enderezar con constancia.")
                ),
                LeanUpMotivationMessage(
                    title: "Lo importante es no soltar el hilo.",
                    detail: personalized("Incluso cuando una materia se complica\(namePause), seguir registrando y ordenando tu avance evita que todo se te venga encima.")
                )
            ]
            return options[seed % options.count]
        }

        if inProgressCount >= 4 {
            let options = [
                LeanUpMotivationMessage(
                    title: "Llevas una carga fuerte, pero ya esta mapeada.",
                    detail: personalized("Tener varias materias en curso tambien es una senal de compromiso\(namePause). Lo clave ahora es cerrarlas una por una.")
                ),
                LeanUpMotivationMessage(
                    title: "Mucha carga no significa desorden.",
                    detail: personalized("LeanUp ya te esta ayudando a ver que tienes encima\(namePause), para que la carga no se convierta en ruido.")
                ),
                LeanUpMotivationMessage(
                    title: "Tu ritmo actual merece respeto.",
                    detail: personalized("No es poco sostener varias materias al tiempo\(namePause). Lo importante es seguirlas con cabeza fria y constancia.")
                )
            ]
            return options[seed % options.count]
        }

        if approvedCount >= 20 {
            let options = [
                LeanUpMotivationMessage(
                    title: "Ya no vas empezando: ya construiste camino.",
                    detail: personalized("Todo lo que has aprobado hasta aqui ya cuenta como evidencia real\(namePause). No minimices lo que llevas.")
                ),
                LeanUpMotivationMessage(
                    title: "Tu carrera ya tiene forma.",
                    detail: personalized("Cuando miras lo aprobado y lo que sigue\(namePause), se nota que ya no estas improvisando tu avance.")
                ),
                LeanUpMotivationMessage(
                    title: "La mitad del esfuerzo ya habla por ti.",
                    detail: personalized("Seguir asi no es solo completar materias\(namePause), es demostrarte que si puedes sostener el proceso.")
                )
            ]
            return options[seed % options.count]
        }

        let options = [
            LeanUpMotivationMessage(
                title: "Un avance claro siempre pesa mas que un avance perfecto.",
                detail: personalized("Lo importante es que no pierdas de vista lo que estas construyendo\(namePause), materia por materia.")
            ),
            LeanUpMotivationMessage(
                title: "La constancia tambien se ve en pequeno.",
                detail: personalized("Cada nota que registras y cada materia que ordenas\(namePause), le baja ruido a la carrera y te devuelve control.")
            ),
            LeanUpMotivationMessage(
                title: "Tu proceso merece verse con claridad.",
                detail: personalized("No se trata de correr mas que nadie\(namePause), sino de seguir avanzando sin soltarte del todo.")
            )
        ]
        return options[seed % options.count]
    }

    var periodAverageSeries: [LeanUpPeriodAveragePoint] {
        periods.compactMap { period in
            let grades = gradeEntries(in: period).map(\.grade)
            guard !grades.isEmpty else { return nil }
            let average = grades.reduce(0, +) / Double(grades.count)
            return LeanUpPeriodAveragePoint(period: period, average: average, count: grades.count)
        }
    }

    var strongestCourses: [LeanUpGradedCourse] {
        Array(
            gradedCourses
                .sorted {
                    if $0.grade == $1.grade {
                        return $0.period < $1.period
                    }
                    return $0.grade > $1.grade
                }
                .prefix(3)
        )
    }

    var mostDemandingCourses: [LeanUpGradedCourse] {
        Array(
            gradedCourses
                .sorted {
                    if $0.grade == $1.grade {
                        return $0.period < $1.period
                    }
                    return $0.grade < $1.grade
                }
                .prefix(3)
        )
    }

    var achievements: [LeanUpAchievement] {
        let halfThreshold = Int(ceil(Double(totalTrackableItems) / 2.0))
        return [
            LeanUpAchievement(
                id: "first-period-complete",
                title: "Primer periodo completo",
                detail: "Cierra un periodo entero sin pendientes ni reprobadas.",
                icon: "flag.checkered.2.crossed",
                tone: .blue,
                isUnlocked: completedPeriodsCount >= 1
            ),
            LeanUpAchievement(
                id: "gpa-over-4",
                title: "Promedio sobre 4.0",
                detail: "Sostienes un promedio acumulado por encima de 4.0.",
                icon: "star.circle.fill",
                tone: .gold,
                isUnlocked: (averageValue ?? 0) >= 4.0
            ),
            LeanUpAchievement(
                id: "ten-approved",
                title: "Diez aprobadas",
                detail: "Ya construiste una base academica de doble digito.",
                icon: "10.circle.fill",
                tone: .green,
                isUnlocked: approvedCount >= 10
            ),
            LeanUpAchievement(
                id: "half-career",
                title: "Mitad de la carrera",
                detail: "Ya pasaste la mitad de la malla en terminos reales.",
                icon: "seal.fill",
                tone: .navy,
                isUnlocked: approvedCount >= halfThreshold
            ),
            LeanUpAchievement(
                id: "clean-record",
                title: "Sin rojos activos",
                detail: "No tienes notas reprobadas dentro de lo ya registrado.",
                icon: "checkmark.shield.fill",
                tone: .cyan,
                isUnlocked: registeredCount >= 6 && failedCount == 0
            )
        ]
    }

    var unlockedAchievements: [LeanUpAchievement] {
        achievements.filter(\.isUnlocked)
    }

    var nextLockedAchievement: LeanUpAchievement? {
        achievements.first(where: { !$0.isUnlocked })
    }

    var preferredColorScheme: ColorScheme? {
        switch snapshot.themeMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    func load() {
        snapshot = (try? store.loadSnapshot()) ?? .empty
    }

    func setUsername(_ name: String) {
        writeSnapshot { $0.username = name }
    }

    func resetUsername() {
        writeSnapshot { $0.username = LeanUpSnapshot.empty.username }
    }

    func setTheme(_ theme: LeanUpThemeMode) {
        writeSnapshot { $0.themeMode = theme }
    }

    func clearAcademicProgress() {
        writeSnapshot {
            $0.notas.removeAll()
            $0.electivosSeleccionados.removeAll()
            $0.electivosNotas.removeAll()
        }
    }

    func courses(in period: Int) -> [LeanUpCourse] {
        academics.courses.filter { $0.period == period }
    }

    func electiveGroups(in period: Int) -> [LeanUpElectiveGroup] {
        academics.electiveGroups.filter { $0.period == period }
    }

    func note(for course: LeanUpCourse) -> Double? {
        snapshot.notas[String(course.id)]
    }

    func note(for courseID: Int) -> Double? {
        snapshot.notas[String(courseID)]
    }

    func selectedOption(in group: LeanUpElectiveGroup) -> LeanUpElectiveOption? {
        guard let selectedCode = snapshot.electivosSeleccionados[group.name] else { return nil }
        return group.options.first { $0.code == selectedCode }
    }

    func electiveNote(groupName: String, optionCode: String) -> Double? {
        snapshot.electivosNotas["\(groupName):::\(optionCode)"]
    }

    func isCourseInProgress(_ course: LeanUpCourse) -> Bool {
        snapshot.cursosEnCurso[String(course.id)] == true && note(for: course) == nil
    }

    func isElectiveInProgress(_ group: LeanUpElectiveGroup) -> Bool {
        snapshot.electivosEnCurso[group.name] == true &&
        selectedOption(in: group) != nil &&
        selectedOption(in: group).flatMap { electiveNote(groupName: group.name, optionCode: $0.code) } == nil
    }

    func courseStatus(for course: LeanUpCourse) -> LeanUpProgressStatus {
        LeanUpProgressStatus(grade: note(for: course), isInProgress: isCourseInProgress(course))
    }

    func electiveStatus(for group: LeanUpElectiveGroup) -> LeanUpProgressStatus {
        guard let option = selectedOption(in: group) else { return .pending }
        return LeanUpProgressStatus(
            grade: electiveNote(groupName: group.name, optionCode: option.code),
            isInProgress: isElectiveInProgress(group)
        )
    }

    func reminders(for period: Int? = nil) -> [LeanUpPeriodReminder] {
        snapshot.periodReminders
            .filter { period == nil || $0.period == period }
            .sorted {
                if $0.isDone != $1.isDone {
                    return !$0.isDone && $1.isDone
                }
                if $0.dueDate == $1.dueDate {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.dueDate < $1.dueDate
            }
    }

    func upcomingReminders(for period: Int? = nil, limit: Int = 3) -> [LeanUpPeriodReminder] {
        Array(
            reminders(for: period)
                .filter { !$0.isDone }
                .prefix(limit)
        )
    }

    func progress(for period: Int) -> LeanUpPeriodProgress {
        let periodCourses = courses(in: period)
        let periodElectives = electiveGroups(in: period)

        var approved = 0
        var failed = 0

        for course in periodCourses {
            switch courseStatus(for: course) {
            case .approved: approved += 1
            case .failed: failed += 1
            case .pending, .inProgress: break
            }
        }

        for group in periodElectives {
            switch electiveStatus(for: group) {
            case .approved: approved += 1
            case .failed: failed += 1
            case .pending, .inProgress: break
            }
        }

        return LeanUpPeriodProgress(
            approved: approved,
            failed: failed,
            total: periodCourses.count + periodElectives.count
        )
    }

    func setCourseGrade(_ grade: Double?, for courseID: Int) {
        writeSnapshot { snapshot in
            let key = String(courseID)
            if let grade {
                snapshot.notas[key] = grade
                snapshot.cursosEnCurso.removeValue(forKey: key)
            } else {
                snapshot.notas.removeValue(forKey: key)
            }
        }
    }

    func setCourseInProgress(_ isInProgress: Bool, for courseID: Int) {
        writeSnapshot { snapshot in
            let key = String(courseID)
            if isInProgress, snapshot.notas[key] == nil {
                snapshot.cursosEnCurso[key] = true
            } else {
                snapshot.cursosEnCurso.removeValue(forKey: key)
            }
        }
    }

    func selectElectiveOption(groupName: String, optionCode: String) {
        writeSnapshot {
            $0.electivosSeleccionados[groupName] = optionCode
            let notePrefix = "\(groupName):::"
            $0.electivosNotas = $0.electivosNotas.filter { $0.key == "\(notePrefix)\(optionCode)" || !$0.key.hasPrefix(notePrefix) }
        }
    }

    func setElectiveGrade(_ grade: Double?, groupName: String, optionCode: String) {
        writeSnapshot { snapshot in
            snapshot.electivosSeleccionados[groupName] = optionCode
            let key = "\(groupName):::\(optionCode)"
            if let grade {
                snapshot.electivosNotas[key] = grade
                snapshot.electivosEnCurso.removeValue(forKey: groupName)
            } else {
                snapshot.electivosNotas.removeValue(forKey: key)
            }
        }
    }

    func setElectiveInProgress(_ isInProgress: Bool, groupName: String) {
        writeSnapshot { snapshot in
            guard let selectedCode = snapshot.electivosSeleccionados[groupName] else {
                snapshot.electivosEnCurso.removeValue(forKey: groupName)
                return
            }

            let key = "\(groupName):::\(selectedCode)"
            if isInProgress, snapshot.electivosNotas[key] == nil {
                snapshot.electivosEnCurso[groupName] = true
            } else {
                snapshot.electivosEnCurso.removeValue(forKey: groupName)
            }
        }
    }

    func saveReminder(_ reminder: LeanUpPeriodReminder) {
        writeSnapshot { snapshot in
            if let index = snapshot.periodReminders.firstIndex(where: { $0.id == reminder.id }) {
                snapshot.periodReminders[index] = reminder
            } else {
                snapshot.periodReminders.append(reminder)
            }
        }
    }

    func deleteReminder(_ reminderID: String) {
        writeSnapshot { snapshot in
            snapshot.periodReminders.removeAll { $0.id == reminderID }
        }
    }

    func setReminderDone(_ isDone: Bool, reminderID: String) {
        writeSnapshot { snapshot in
            guard let index = snapshot.periodReminders.firstIndex(where: { $0.id == reminderID }) else { return }
            snapshot.periodReminders[index].isDone = isDone
        }
    }

    private func writeSnapshot(_ mutate: (inout LeanUpSnapshot) -> Void) {
        var updated = snapshot
        mutate(&updated)
        snapshot = updated.normalized()
        _ = try? store.saveSnapshot(snapshot)
    }

    private var gradedCourses: [LeanUpGradedCourse] {
        academics.courses.compactMap { course in
            guard let grade = note(for: course) else { return nil }
            return LeanUpGradedCourse(
                id: "course-\(course.id)",
                name: course.name,
                period: course.period,
                grade: grade
            )
        }
    }

    private var gradedItems: [LeanUpGradeEntry] {
        let courseEntries = academics.courses.compactMap { course -> LeanUpGradeEntry? in
            guard let grade = note(for: course) else { return nil }
            return LeanUpGradeEntry(period: course.period, grade: grade)
        }

        let electiveEntries = academics.electiveGroups.compactMap { group -> LeanUpGradeEntry? in
            guard let selected = selectedOption(in: group),
                  let grade = electiveNote(groupName: group.name, optionCode: selected.code) else {
                return nil
            }

            return LeanUpGradeEntry(period: group.period, grade: grade)
        }

        return courseEntries + electiveEntries
    }

    private func gradeEntries(in period: Int) -> [LeanUpGradeEntry] {
        gradedItems.filter { $0.period == period }
    }

    private var inProgressCourseCount: Int {
        academics.courses.filter { isCourseInProgress($0) }.count
    }

    private var inProgressElectiveCount: Int {
        academics.electiveGroups.filter { isElectiveInProgress($0) }.count
    }

    private var averageItemsPerPeriod: Double {
        guard !periods.isEmpty else { return Double(totalTrackableItems) }
        return Double(totalTrackableItems) / Double(periods.count)
    }

    private var inProgressEquivalentPeriods: Double {
        guard averageItemsPerPeriod > 0 else { return 0 }
        return Double(inProgressCount) / averageItemsPerPeriod
    }

    private var namePause: String {
        if let preferredDisplayName {
            return ", \(preferredDisplayName)"
        }
        return ""
    }

    private func personalized(_ text: String) -> String {
        text
    }
}

enum LeanUpProgressStatus: Equatable {
    case pending
    case inProgress
    case approved
    case failed

    init(grade: Double?, isInProgress: Bool = false) {
        guard let grade else {
            self = isInProgress ? .inProgress : .pending
            return
        }
        self = grade >= 3.0 ? .approved : .failed
    }

    var title: String {
        switch self {
        case .pending: return "Pendiente"
        case .inProgress: return "En curso"
        case .approved: return "Aprobada"
        case .failed: return "Reprobada"
        }
    }
}

struct LeanUpPeriodProgress {
    let approved: Int
    let failed: Int
    let total: Int

    var completionRatio: Double {
        guard total > 0 else { return 0 }
        return Double(approved) / Double(total)
    }

    var completionText: String {
        "\(approved)/\(total)"
    }
}

struct LeanUpCareerItem: Identifiable, Hashable {
    let id: String
    let period: Int
    let name: String
    let summary: String
    let outcomes: String
    let skills: [String]
    let linkedinText: String
    let portfolioProject: String
    let isElective: Bool
}

struct LeanUpPeriodAveragePoint: Identifiable, Hashable {
    var id: Int { period }

    let period: Int
    let average: Double
    let count: Int
}

struct LeanUpGradedCourse: Identifiable, Hashable {
    let id: String
    let name: String
    let period: Int
    let grade: Double
}

struct LeanUpGradeEntry: Hashable {
    let period: Int
    let grade: Double
}

enum LeanUpAchievementTone: Hashable {
    case navy
    case blue
    case cyan
    case gold
    case green
}

struct LeanUpAchievement: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let tone: LeanUpAchievementTone
    let isUnlocked: Bool
}


