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
    private var cachedAllGrades: [Double] = []
    private var cachedApprovedCourses: [LeanUpCourse] = []
    private var cachedSelectedElectiveOptions: [LeanUpElectiveOption] = []
    private var cachedApprovedElectiveOptions: [LeanUpElectiveOption] = []
    private var cachedPeriods: [Int] = []
    private var cachedCoursesByPeriod: [Int: [LeanUpCourse]] = [:]
    private var cachedElectiveGroupsByPeriod: [Int: [LeanUpElectiveGroup]] = [:]
    private var cachedElectiveGroupsWithoutSelection = 0
    private var cachedCareerItems: [LeanUpCareerItem] = []
    private var cachedGradedCourses: [LeanUpGradedCourse] = []
    private var cachedGradedItems: [LeanUpGradeEntry] = []
    private var cachedInProgressCourseCount = 0
    private var cachedInProgressElectiveCount = 0
    private var cachedApprovedSignalCorpus: [String] = []
    private var cachedAlignmentAreaScoresSnapshot: [String: Int] = [:]
    private var cachedProgressByPeriod: [Int: LeanUpPeriodProgress] = [:]
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
        cachedAllGrades
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
        cachedElectiveGroupsWithoutSelection
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
        cachedApprovedCourses
    }

    var approvedElectiveOptions: [LeanUpElectiveOption] {
        cachedApprovedElectiveOptions
    }

    var selectedElectiveOptions: [LeanUpElectiveOption] {
        cachedSelectedElectiveOptions
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
        cachedCareerItems
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
        cachedPeriods
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

    var currentDisplayName: String {
        preferredDisplayName ?? snapshot.username
    }

    var localStorageStatusText: String {
        if registeredCount == 0 && selectedElectivesCount == 0 {
            return "Listo para empezar a guardar progreso local"
        }

        return "Guardado local activo en este iPhone"
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

    var profileNextMilestone: LeanUpMilestoneInsight {
        let thresholds = [25, 50, 75, 100]
        let earned = min(earnedCredits, totalCredits)
        let currentPercent = totalCredits == 0 ? 0 : Int((Double(earned) / Double(totalCredits) * 100).rounded())

        if earned >= totalCredits {
            return LeanUpMilestoneInsight(
                title: "Ya cerraste el 100% de la carrera",
                detail: "Tu siguiente hito ya no es academico: toca convertir esa base en una oferta, un portafolio y una narrativa profesional propia.",
                badgeText: "100%",
                targetPercent: 100,
                creditsRemaining: 0,
                progress: 1
            )
        }

        let nextPercent = thresholds.first { percent in
            let targetCredits = Int((Double(totalCredits) * Double(percent) / 100.0).rounded())
            return earned < targetCredits
        } ?? 100
        let targetCredits = Int((Double(totalCredits) * Double(nextPercent) / 100.0).rounded())
        let remaining = max(targetCredits - earned, 0)
        let detail: String

        switch nextPercent {
        case 25:
            detail = "Te faltan \(remaining) creditos para llegar al 25% y dejar de estar en fase de arranque. Ese punto ya te da una base mas estable para hablar de criterio y disciplina."
        case 50:
            detail = "Te faltan \(remaining) creditos para llegar al 50% de la carrera. Ahí ya se empieza a sentir media carrera real detrás de tu perfil."
        case 75:
            detail = "Te faltan \(remaining) creditos para llegar al 75%. Ese umbral ya te acerca a propuestas mucho mas serias y con mejor sustento."
        default:
            detail = "Te faltan \(remaining) creditos para cerrar la carrera. Ya no es una base inicial: estas afinando el tramo final."
        }

        return LeanUpMilestoneInsight(
            title: "Te faltan \(remaining) creditos para llegar al \(nextPercent)%",
            detail: detail,
            badgeText: "\(currentPercent)%",
            targetPercent: nextPercent,
            creditsRemaining: remaining,
            progress: totalCredits == 0 ? 0 : Double(earned) / Double(totalCredits)
        )
    }

    var electiveAlignmentInsight: LeanUpProfileAlignmentInsight {
        let selections = selectedElectiveOptions
        guard !selections.isEmpty else {
            return LeanUpProfileAlignmentInsight(
                statusTitle: "Aun sin lectura fuerte",
                title: "Todavia no hay suficientes electivos definidos",
                detail: "Tu direccion todavia no se puede leer con claridad porque aun faltan electivos por escoger. Aqui vale mas definir que acumular señales sueltas.",
                detectedAreas: [],
                recommendation: "Empieza por escoger los electivos que mas se acerquen al tipo de trabajo que te gustaria probar primero.",
                confidenceText: "Confianza baja",
                tone: .orange
            )
        }

        let areaScores = alignmentAreaScores(for: selections)
        let sortedAreas = areaScores
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }

        let topAreas = sortedAreas.prefix(3).map(\.key)
        let topScore = sortedAreas.first?.value ?? 0
        let secondScore = sortedAreas.dropFirst().first?.value ?? 0
        let totalScore = max(areaScores.values.reduce(0, +), 1)
        let dominantShare = Double(topScore) / Double(totalScore)

        if selections.count < 2 {
            return LeanUpProfileAlignmentInsight(
                statusTitle: "Aun temprano",
                title: "Ya asoma una direccion, pero aun es muy pronto",
                detail: "Por ahora tu eleccion empieza a apuntar a \(topAreas.first ?? "una linea posible"), pero una sola senal todavia no alcanza para hablar de especializacion.",
                detectedAreas: topAreas,
                recommendation: electiveGroupsWithoutSelection > 0
                    ? "Define el siguiente electivo en la misma linea si quieres que tu perfil se lea mas coherente."
                    : "Si quieres reforzar esa linea, procura que tus siguientes proyectos y materias aprobadas vayan en la misma direccion.",
                confidenceText: "Confianza baja",
                tone: .orange
            )
        }

        if dominantShare >= 0.58 && (topScore - secondScore) >= 2 {
            return LeanUpProfileAlignmentInsight(
                statusTitle: "Alineado",
                title: "Tus electivos ya apuntan a una linea bastante clara",
                detail: "Lo mas fuerte hoy es \(topAreas.first ?? "tu linea principal"). No se siente disperso: empieza a leerse como una direccion concreta.",
                detectedAreas: topAreas,
                recommendation: electiveGroupsWithoutSelection > 0
                    ? "Si mantienes esa misma linea en los proximos electivos, tu perfil se va a leer cada vez mas especializado."
                    : "Ahora conviene que tu portafolio y tu primer servicio giren alrededor de esa misma linea.",
                confidenceText: selections.count >= 3 ? "Confianza media-alta" : "Confianza media",
                tone: .green
            )
        }

        if dominantShare >= 0.40 {
            return LeanUpProfileAlignmentInsight(
                statusTitle: "Mixto",
                title: "Tu perfil mezcla dos lineas con bastante peso",
                detail: "Hay una combinacion visible entre \(topAreas.prefix(2).joined(separator: " y ")). No es ruido, pero tampoco una sola especializacion cerrada.",
                detectedAreas: topAreas,
                recommendation: "Si quieres venderte mas claro afuera, define cual de esas lineas quieres que mande y usa las otras como apoyo.",
                confidenceText: "Confianza media",
                tone: .blue
            )
        }

        return LeanUpProfileAlignmentInsight(
            statusTitle: "Diversificado",
            title: "Tus electivos hoy se sienten mas diversos que especializados",
            detail: "Hay varias senales abiertas al mismo tiempo y ninguna domina del todo. Eso no es malo, pero hoy tu perfil se lee mas exploratorio que enfocado.",
            detectedAreas: topAreas,
            recommendation: "El siguiente electivo y tu proximo proyecto deberian empujar una sola linea si quieres que el perfil gane nitidez.",
            confidenceText: "Confianza media",
            tone: .gold
        )
    }

    var subjectTypeMap: LeanUpSubjectTypeMap {
        let typedEntries = LeanUpProfileStrategyLibrary.trackedSubjectTypes.map { type in
            LeanUpSubjectTypeCount(
                type: type,
                approved: approvedTypedItems.filter { normalizedTypes(for: $0).contains(type) }.count,
                remaining: remainingTypedItems.filter { normalizedTypes(for: $0).contains(type) }.count
            )
        }

        let dominant = typedEntries.max { lhs, rhs in
            if lhs.approved == rhs.approved {
                return lhs.type > rhs.type
            }
            return lhs.approved < rhs.approved
        }?.type

        let lagging = typedEntries.max { lhs, rhs in
            if lhs.remaining == rhs.remaining {
                return lhs.type > rhs.type
            }
            return lhs.remaining < rhs.remaining
        }?.type

        let summary: String
        if let dominant, let lagging {
            summary = "Lo mas avanzado hoy va por \(dominant), mientras que \(lagging) es donde mas recorrido visible te sigue faltando en las materias que si traen tipologia explicita."
        } else {
            summary = "A medida que apruebes mas materias y definas mas electivos, este mapa se volvera mas legible."
        }

        return LeanUpSubjectTypeMap(
            entries: typedEntries,
            dominantType: dominant,
            laggingType: lagging,
            summary: summary
        )
    }

    var recommendedStarterService: LeanUpServiceRecommendation {
        let matchedRules = LeanUpProfileStrategyLibrary.serviceRules.map { rule -> (LeanUpServiceRule, Int) in
            let areaScore = rule.requiredAreas.reduce(0) { partial, area in
                partial + (alignmentAreaScoresSnapshot[area] ?? 0)
            }
            let keywordScore = matchCount(for: rule.keywords, in: approvedSignalCorpus) * 2
            let creditScore = earnedCredits >= rule.minCredits ? 3 : max(earnedCredits / 12, 0)
            return (rule, areaScore + keywordScore + creditScore)
        }
        let bestRule = matchedRules.sorted {
            if $0.1 == $1.1 {
                return $0.0.minCredits < $1.0.minCredits
            }
            return $0.1 > $1.1
        }.first?.0 ?? LeanUpProfileStrategyLibrary.serviceRules[0]

        let confidence: String
        switch earnedCredits {
        case 0..<18:
            confidence = "Confianza baja"
        case 18..<36:
            confidence = "Confianza media-baja"
        case 36..<72:
            confidence = "Confianza media"
        default:
            confidence = "Confianza media-alta"
        }

        let supportingSignals = Array(profileSupportSignals(matching: bestRule.keywords).prefix(4))
        let reason: String
        if supportingSignals.isEmpty {
            reason = "Tu base actual ya deja ver una combinacion inicial de criterio academico y habilidades transferibles para empezar pequeno y con prudencia."
        } else {
            reason = "Hoy ya puedes justificarlo desde señales reales como \(supportingSignals.joined(separator: ", "))."
        }

        let tone: LeanUpProfileInsightTone = earnedCredits >= bestRule.minCredits ? .green : .blue

        return LeanUpServiceRecommendation(
            title: bestRule.title,
            summary: bestRule.summary,
            whyYouCanOfferIt: reason,
            priceText: LeanUpProfileStrategyLibrary.priceText(for: bestRule.priceRangeUSD),
            nextEvidence: bestRule.nextEvidence,
            confidenceText: confidence,
            supportingSignals: supportingSignals,
            tone: tone
        )
    }

    var minimumViablePortfolio: [LeanUpPortfolioRoadmapItem] {
        let rankedRules = LeanUpProfileStrategyLibrary.portfolioRules
            .map { rule -> (LeanUpPortfolioRule, Int) in
                (rule, matchCount(for: rule.keywords, in: approvedSignalCorpus))
            }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.title < $1.0.title
                }
                return $0.1 > $1.1
            }

        return Array(rankedRules.prefix(3)).map { rule, score in
            let readiness: LeanUpPortfolioReadinessState
            switch score {
            case 4...:
                readiness = .ready
            case 2...3:
                readiness = .almostReady
            default:
                readiness = .missingBase
            }

            return LeanUpPortfolioRoadmapItem(
                id: rule.id,
                title: rule.title,
                objective: rule.objective,
                whyItMatters: rule.whyItMatters,
                readiness: readiness,
                supportingSignals: Array(profileSupportSignals(matching: rule.keywords).prefix(3))
            )
        }
    }

    var freelancerChecklist: LeanUpFreelancerChecklist {
        let profileStatus: LeanUpFreelancerChecklistStatus
        if preferredDisplayName != nil && earnedCredits >= 24 {
            profileStatus = .ready
        } else if preferredDisplayName != nil || earnedCredits >= 12 {
            profileStatus = .inProgress
        } else {
            profileStatus = .pending
        }

        let skillStatus: LeanUpFreelancerChecklistStatus
        if standoutSkills.count >= 10 && careerItems.count >= 6 {
            skillStatus = .ready
        } else if standoutSkills.count >= 5 {
            skillStatus = .inProgress
        } else {
            skillStatus = .pending
        }

        let readyPortfolioItems = minimumViablePortfolio.filter { $0.readiness == .ready }.count
        let portfolioStatus: LeanUpFreelancerChecklistStatus
        if readyPortfolioItems >= 2 {
            portfolioStatus = .ready
        } else if minimumViablePortfolio.contains(where: { $0.readiness != .missingBase }) {
            portfolioStatus = .inProgress
        } else {
            portfolioStatus = .pending
        }

        let toolsScore = matchCount(for: LeanUpProfileStrategyLibrary.toolKeywords, in: approvedSignalCorpus)
        let toolsStatus: LeanUpFreelancerChecklistStatus
        if toolsScore >= 5 {
            toolsStatus = .ready
        } else if toolsScore >= 2 {
            toolsStatus = .inProgress
        } else {
            toolsStatus = .pending
        }

        let items = [
            LeanUpFreelancerChecklistItem(
                id: "profile",
                title: "Perfil profesional",
                detail: profileStatus == .ready
                    ? "Ya hay suficiente base para presentarte con una narrativa inicial bastante clara."
                    : "Tu narrativa ya arranco, pero aun conviene darle mas forma antes de salir a vender fuerte.",
                status: profileStatus
            ),
            LeanUpFreelancerChecklistItem(
                id: "skills",
                title: "Habilidades demostrables",
                detail: skillStatus == .ready
                    ? "Tus materias aprobadas ya dejan ver habilidades repetidas y con bastante evidencia."
                    : "Todavia conviene consolidar mejor que sabes hacer y en que se repite tu fortaleza.",
                status: skillStatus
            ),
            LeanUpFreelancerChecklistItem(
                id: "portfolio",
                title: "Portafolio minimo",
                detail: portfolioStatus == .ready
                    ? "Ya hay al menos dos piezas que podrian empezar a sostener conversaciones reales con clientes."
                    : "Aun te conviene convertir mejor tu recorrido academico en proyectos visibles.",
                status: portfolioStatus
            ),
            LeanUpFreelancerChecklistItem(
                id: "tools",
                title: "Herramientas base",
                detail: toolsStatus == .ready
                    ? "Tu recorrido ya muestra herramientas y flujos suficientemente utiles para un trabajo independiente inicial."
                    : "Todavia sirve reforzar herramientas operativas antes de ofrecerte con mas seguridad.",
                status: toolsStatus
            )
        ]

        let readyCount = items.filter { $0.status == .ready }.count
        let progressCount = items.filter { $0.status == .inProgress }.count
        let overallTitle: String
        let overallDetail: String

        if readyCount >= 3 {
            overallTitle = "Listo para probar ofertas pequenas"
            overallDetail = "Todavia conviene moverte con prudencia, pero ya tienes base suficiente para empezar a cobrar proyectos acotados."
        } else if readyCount + progressCount >= 3 {
            overallTitle = "Cerca de cobrar tu primer servicio"
            overallDetail = "Tu base ya no esta verde del todo. Falta ordenar mejor evidencia y propuesta, no empezar desde cero."
        } else {
            overallTitle = "Aun verde"
            overallDetail = "La base va creciendo, pero todavia conviene seguir acumulando evidencia antes de salir a vender fuerte."
        }

        return LeanUpFreelancerChecklist(
            items: items,
            overallTitle: overallTitle,
            overallDetail: overallDetail
        )
    }

    var profileStrategicSummary: String {
        let name = preferredDisplayName ?? "Tu perfil"
        return "\(name) hoy se lee mejor cuando unes \(electiveAlignmentInsight.statusTitle.lowercased()), el siguiente hito en \(profileNextMilestone.targetPercent)% y una oferta inicial como \(recommendedStarterService.title.lowercased())."
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
        let intervalToken = Int(Date().timeIntervalSince1970 / 300.0)
        let shuffledIndex = ((intervalToken * 73) + 19) % LeanUpMotivationLibrary.totalCount
        let title = LeanUpMotivationLibrary.titles[shuffledIndex / LeanUpMotivationLibrary.endings.count]
        let ending = LeanUpMotivationLibrary.endings[shuffledIndex % LeanUpMotivationLibrary.endings.count]
        let contextPool = motivationContextPool
        let context = contextPool[(intervalToken * 29 + 7) % contextPool.count]

        return LeanUpMotivationMessage(
            title: title,
            detail: "\(context) \(ending)"
        )
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
        applySnapshot((try? store.loadSnapshot()) ?? .empty)
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
        cachedCoursesByPeriod[period] ?? []
    }

    func electiveGroups(in period: Int) -> [LeanUpElectiveGroup] {
        cachedElectiveGroupsByPeriod[period] ?? []
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
        cachedProgressByPeriod[period] ?? LeanUpPeriodProgress(approved: 0, failed: 0, total: 0)
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
        applySnapshot(updated)
        _ = try? store.saveSnapshot(snapshot)
    }

    private var gradedCourses: [LeanUpGradedCourse] {
        cachedGradedCourses
    }

    private var gradedItems: [LeanUpGradeEntry] {
        cachedGradedItems
    }

    private func gradeEntries(in period: Int) -> [LeanUpGradeEntry] {
        gradedItems.filter { $0.period == period }
    }

    private var inProgressCourseCount: Int {
        cachedInProgressCourseCount
    }

    private var inProgressElectiveCount: Int {
        cachedInProgressElectiveCount
    }

    private var averageItemsPerPeriod: Double {
        guard !periods.isEmpty else { return Double(totalTrackableItems) }
        return Double(totalTrackableItems) / Double(periods.count)
    }

    private var inProgressEquivalentPeriods: Double {
        guard averageItemsPerPeriod > 0 else { return 0 }
        return Double(inProgressCount) / averageItemsPerPeriod
    }

    private var approvedTypedItems: [LeanUpTypeTrackable] {
        approvedCourses.map { LeanUpTypeTrackable(types: $0.types) }
    }

    private var remainingTypedItems: [LeanUpTypeTrackable] {
        pendingCourses.map { LeanUpTypeTrackable(types: $0.types) } +
        failedCourses.map { LeanUpTypeTrackable(types: $0.types) } +
        inProgressCourses.map { LeanUpTypeTrackable(types: $0.types) }
    }

    private var approvedSignalCorpus: [String] {
        cachedApprovedSignalCorpus
    }

    private var alignmentAreaScoresSnapshot: [String: Int] {
        cachedAlignmentAreaScoresSnapshot
    }

    private func applySnapshot(_ newSnapshot: LeanUpSnapshot) {
        let normalized = newSnapshot.normalized()
        let derived = buildDerivedState(for: normalized)
        cachedAllGrades = derived.allGrades
        cachedApprovedCourses = derived.approvedCourses
        cachedSelectedElectiveOptions = derived.selectedElectiveOptions
        cachedApprovedElectiveOptions = derived.approvedElectiveOptions
        cachedPeriods = derived.periods
        cachedCoursesByPeriod = derived.coursesByPeriod
        cachedElectiveGroupsByPeriod = derived.electiveGroupsByPeriod
        cachedElectiveGroupsWithoutSelection = derived.electiveGroupsWithoutSelection
        cachedCareerItems = derived.careerItems
        cachedGradedCourses = derived.gradedCourses
        cachedGradedItems = derived.gradedItems
        cachedInProgressCourseCount = derived.inProgressCourseCount
        cachedInProgressElectiveCount = derived.inProgressElectiveCount
        cachedApprovedSignalCorpus = derived.approvedSignalCorpus
        cachedAlignmentAreaScoresSnapshot = derived.alignmentAreaScoresSnapshot
        cachedProgressByPeriod = derived.progressByPeriod
        snapshot = normalized
    }

    private func buildDerivedState(for snapshot: LeanUpSnapshot) -> LeanUpDerivedState {
        let allGrades = Array(snapshot.notas.values) + Array(snapshot.electivosNotas.values)
        var approvedCourses: [LeanUpCourse] = []
        var selectedElectiveOptions: [LeanUpElectiveOption] = []
        var approvedElectiveOptions: [LeanUpElectiveOption] = []
        var approvedElectivePairs: [(LeanUpElectiveGroup, LeanUpElectiveOption)] = []
        var periods = Set<Int>()
        var coursesByPeriod: [Int: [LeanUpCourse]] = [:]
        var electiveGroupsByPeriod: [Int: [LeanUpElectiveGroup]] = [:]
        var electiveGroupsWithoutSelection = 0
        var gradedCourses: [LeanUpGradedCourse] = []
        var gradedItems: [LeanUpGradeEntry] = []
        var inProgressCourseCount = 0
        var inProgressElectiveCount = 0
        var progressBuilder: [Int: (approved: Int, failed: Int, total: Int)] = [:]

        for course in academics.courses {
            periods.insert(course.period)
            coursesByPeriod[course.period, default: []].append(course)
            progressBuilder[course.period, default: (0, 0, 0)].total += 1

            let key = String(course.id)
            if let grade = snapshot.notas[key] {
                gradedCourses.append(
                    LeanUpGradedCourse(
                        id: "course-\(course.id)",
                        name: course.name,
                        period: course.period,
                        grade: grade
                    )
                )
                gradedItems.append(LeanUpGradeEntry(period: course.period, grade: grade))

                if grade >= 3.0 {
                    approvedCourses.append(course)
                    progressBuilder[course.period, default: (0, 0, 0)].approved += 1
                } else {
                    progressBuilder[course.period, default: (0, 0, 0)].failed += 1
                }
            } else if snapshot.cursosEnCurso[key] == true {
                inProgressCourseCount += 1
            }
        }

        for group in academics.electiveGroups {
            periods.insert(group.period)
            electiveGroupsByPeriod[group.period, default: []].append(group)
            progressBuilder[group.period, default: (0, 0, 0)].total += 1

            guard let selectedCode = snapshot.electivosSeleccionados[group.name],
                  let option = group.options.first(where: { $0.code == selectedCode }) else {
                electiveGroupsWithoutSelection += 1
                continue
            }

            selectedElectiveOptions.append(option)
            let key = "\(group.name):::\(selectedCode)"

            if let grade = snapshot.electivosNotas[key] {
                gradedItems.append(LeanUpGradeEntry(period: group.period, grade: grade))

                if grade >= 3.0 {
                    approvedElectiveOptions.append(option)
                    approvedElectivePairs.append((group, option))
                    progressBuilder[group.period, default: (0, 0, 0)].approved += 1
                } else {
                    progressBuilder[group.period, default: (0, 0, 0)].failed += 1
                }
            } else if snapshot.electivosEnCurso[group.name] == true {
                inProgressElectiveCount += 1
            }
        }

        let careerItems = (
            approvedCourses.map {
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
            } +
            approvedElectivePairs.map { group, option in
                LeanUpCareerItem(
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
        ).sorted {
            if $0.period == $1.period {
                return $0.name < $1.name
            }
            return $0.period < $1.period
        }

        let courseSignals = approvedCourses.flatMap { course in
            [course.name, course.summary, course.plainLanguage, course.outcomes, course.linkedinText, course.portfolioProject] + course.skills
        }
        let electiveSignals = approvedElectivePairs.flatMap { group, option in
            [group.name, option.name, option.summary, option.outcomes, option.linkedinText, option.portfolioProject] + option.skills
        }
        let approvedSignalCorpus = (courseSignals + electiveSignals).map(\.leanUpProfileKey)
        let alignmentAreaScoresSnapshot = alignmentAreaScores(for: selectedElectiveOptions)
        let sortedPeriods = periods.sorted()
        let progressByPeriod = Dictionary(uniqueKeysWithValues: sortedPeriods.map { period in
            let progress = progressBuilder[period] ?? (0, 0, 0)
            return (
                period,
                LeanUpPeriodProgress(
                    approved: progress.approved,
                    failed: progress.failed,
                    total: progress.total
                )
            )
        })

        return LeanUpDerivedState(
            allGrades: allGrades,
            approvedCourses: approvedCourses,
            selectedElectiveOptions: selectedElectiveOptions,
            approvedElectiveOptions: approvedElectiveOptions,
            periods: sortedPeriods,
            coursesByPeriod: coursesByPeriod,
            electiveGroupsByPeriod: electiveGroupsByPeriod,
            electiveGroupsWithoutSelection: electiveGroupsWithoutSelection,
            careerItems: careerItems,
            gradedCourses: gradedCourses,
            gradedItems: gradedItems,
            inProgressCourseCount: inProgressCourseCount,
            inProgressElectiveCount: inProgressElectiveCount,
            approvedSignalCorpus: approvedSignalCorpus,
            alignmentAreaScoresSnapshot: alignmentAreaScoresSnapshot,
            progressByPeriod: progressByPeriod
        )
    }

    private func alignmentAreaScores(for options: [LeanUpElectiveOption]) -> [String: Int] {
        let corpus = options.flatMap { option in
            [option.name, option.summary, option.outcomes, option.linkedinText, option.portfolioProject] + option.skills
        }.map(\.leanUpProfileKey)

        guard !corpus.isEmpty else { return [:] }

        return Dictionary(
            uniqueKeysWithValues: LeanUpProfileStrategyLibrary.electiveClusters.map { cluster in
                (cluster.area, matchCount(for: cluster.keywords, in: corpus))
            }
        ).filter { $0.value > 0 }
    }

    private func normalizedTypes(for item: LeanUpTypeTrackable) -> [String] {
        let rawTypes = item.types.map(\.leanUpProfileKey)
        return LeanUpProfileStrategyLibrary.trackedSubjectTypes.filter { target in
            rawTypes.contains(target.leanUpProfileKey)
        }
    }

    private func matchCount(for keywords: [String], in corpus: [String]) -> Int {
        keywords.reduce(0) { total, keyword in
            let normalizedKeyword = keyword.leanUpProfileKey
            let found = corpus.contains { token in
                token.contains(normalizedKeyword) || normalizedKeyword.contains(token)
            }
            return total + (found ? 1 : 0)
        }
    }

    private func profileSupportSignals(matching keywords: [String]) -> [String] {
        let signals = careerItems.flatMap { item in
            [item.name] + item.skills
        }

        var seen = Set<String>()
        return signals.filter { signal in
            let normalized = signal.leanUpProfileKey
            let matches = keywords.contains { keyword in
                let normalizedKeyword = keyword.leanUpProfileKey
                return normalized.contains(normalizedKeyword) || normalizedKeyword.contains(normalized)
            }
            guard matches else { return false }
            let key = signal.leanUpProfileKey
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private var motivationContextPool: [String] {
        var contexts = [
            personalizedLead(
                named: "Sigue leyendo tu proceso con mas suavidad, \(displayName).",
                unnamed: "Sigue leyendo tu proceso con mas suavidad."
            ),
            personalizedLead(
                named: "No todo lo importante se nota de inmediato, \(displayName).",
                unnamed: "No todo lo importante se nota de inmediato."
            ),
            personalizedLead(
                named: "Tu carrera tambien se esta construyendo en como vuelves hoy, \(displayName).",
                unnamed: "Tu carrera tambien se esta construyendo en como vuelves hoy."
            ),
            personalizedLead(
                named: "Mereces mirarte con un poco mas de justicia, \(displayName).",
                unnamed: "Mereces mirarte con un poco mas de justicia."
            )
        ]

        if failedCount > 0 {
            contexts.append(
                personalizedLead(
                    named: "Tener una materia por recuperar no borra lo que ya has levantado, \(displayName).",
                    unnamed: "Tener una materia por recuperar no borra lo que ya has levantado."
                )
            )
            contexts.append(
                personalizedLead(
                    named: "Esa materia pendiente no define toda tu historia academica, \(displayName).",
                    unnamed: "Esa materia pendiente no define toda tu historia academica."
                )
            )
        }

        if inProgressCount >= 4 {
            contexts.append(
                personalizedLead(
                    named: "Estas sosteniendo bastante carga a la vez, \(displayName), y eso tambien merece reconocimiento.",
                    unnamed: "Estas sosteniendo bastante carga a la vez, y eso tambien merece reconocimiento."
                )
            )
            contexts.append(
                personalizedLead(
                    named: "Que hoy haya mucho encima no significa que estes haciendolo mal, \(displayName).",
                    unnamed: "Que hoy haya mucho encima no significa que estes haciendolo mal."
                )
            )
        }

        if approvedCount >= 20 {
            contexts.append(
                personalizedLead(
                    named: "Ya hay una base seria debajo de ti, \(displayName), incluso si a veces no la sientes.",
                    unnamed: "Ya hay una base seria debajo de ti, incluso si a veces no la sientes."
                )
            )
            contexts.append(
                personalizedLead(
                    named: "Tu carrera ya tiene camino recorrido, \(displayName), no estas empezando de cero cada semana.",
                    unnamed: "Tu carrera ya tiene camino recorrido, no estas empezando de cero cada semana."
                )
            )
        }

        return contexts
    }

    private var displayName: String {
        preferredDisplayName ?? "Usuario"
    }

    private func personalizedLead(named: String, unnamed: String) -> String {
        preferredDisplayName == nil ? unnamed : named
    }
}

private struct LeanUpTypeTrackable {
    let types: [String]
}

private struct LeanUpDerivedState {
    let allGrades: [Double]
    let approvedCourses: [LeanUpCourse]
    let selectedElectiveOptions: [LeanUpElectiveOption]
    let approvedElectiveOptions: [LeanUpElectiveOption]
    let periods: [Int]
    let coursesByPeriod: [Int: [LeanUpCourse]]
    let electiveGroupsByPeriod: [Int: [LeanUpElectiveGroup]]
    let electiveGroupsWithoutSelection: Int
    let careerItems: [LeanUpCareerItem]
    let gradedCourses: [LeanUpGradedCourse]
    let gradedItems: [LeanUpGradeEntry]
    let inProgressCourseCount: Int
    let inProgressElectiveCount: Int
    let approvedSignalCorpus: [String]
    let alignmentAreaScoresSnapshot: [String: Int]
    let progressByPeriod: [Int: LeanUpPeriodProgress]
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


