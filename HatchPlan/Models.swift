import Foundation

enum Species: String, CaseIterable, Codable {
    case chicken, duck, turkey, quail, goose, custom
    var displayName: String { rawValue.capitalized }
    var iconName: String {
        switch self {
        case .chicken: return "bird"
        case .duck: return "drop"
        case .turkey: return "leaf"
        case .quail: return "circle"
        case .goose: return "cloud"
        case .custom: return "questionmark"
        }
    }
}

struct IncubationStage: Codable, Hashable {
    var dayRange: ClosedRange<Int>
    var tempMin: Double, tempMax: Double
    var rhMin: Double, rhMax: Double
    var notes: String = ""
}

struct IncubationPreset: Codable, Identifiable, Hashable {
    let id = UUID()
    var species: Species
    var totalDays: Int
    var turnPerDay: Int
    var stopTurnDay: Int
    var stages: [IncubationStage]

    static let chicken = IncubationPreset(
        species: .chicken,
        totalDays: 21,
        turnPerDay: 4,
        stopTurnDay: 18,
        stages: [
            IncubationStage(dayRange: 1...17, tempMin: 37.6, tempMax: 37.8, rhMin: 45, rhMax: 55),
            IncubationStage(dayRange: 18...21, tempMin: 37.4, tempMax: 37.6, rhMin: 60, rhMax: 70)
        ]
    )

    static let duck = IncubationPreset(
        species: .duck,
        totalDays: 28,
        turnPerDay: 4,
        stopTurnDay: 26,
        stages: [
            IncubationStage(dayRange: 1...25, tempMin: 37.5, tempMax: 37.5, rhMin: 50, rhMax: 55),
            IncubationStage(dayRange: 26...28, tempMin: 37.3, tempMax: 37.5, rhMin: 65, rhMax: 75)
        ]
    )

    static let turkey = IncubationPreset(
        species: .turkey,
        totalDays: 28,
        turnPerDay: 4,
        stopTurnDay: 26,
        stages: [
            IncubationStage(dayRange: 1...25, tempMin: 37.5, tempMax: 37.5, rhMin: 50, rhMax: 55),
            IncubationStage(dayRange: 26...28, tempMin: 37.3, tempMax: 37.5, rhMin: 65, rhMax: 70)
        ]
    )

    static let quail = IncubationPreset(
        species: .quail,
        totalDays: 18,
        turnPerDay: 6,
        stopTurnDay: 15,
        stages: [
            IncubationStage(dayRange: 1...14, tempMin: 37.6, tempMax: 37.8, rhMin: 45, rhMax: 55),
            IncubationStage(dayRange: 15...18, tempMin: 37.4, tempMax: 37.6, rhMin: 65, rhMax: 70)
        ]
    )

    static let goose = IncubationPreset(
        species: .goose,
        totalDays: 31,
        turnPerDay: 3,
        stopTurnDay: 28,
        stages: [
            IncubationStage(dayRange: 1...27, tempMin: 37.5, tempMax: 37.5, rhMin: 50, rhMax: 55),
            IncubationStage(dayRange: 28...31, tempMin: 37.3, tempMax: 37.5, rhMin: 70, rhMax: 75)
        ]
    )

    static let `default`: [Species: IncubationPreset] = [
        .chicken: chicken,
        .duck: duck,
        .turkey: turkey,
        .quail: quail,
        .goose: goose
    ]
}

struct Batch: Codable, Identifiable, Hashable, Equatable {
    let id = UUID()
    var name: String
    var species: Species
    var startDate: Date
    var totalEggs: Int
    var notes: String = ""
    var preset: IncubationPreset
    var hatchedCount: Int = 0
    var isFinished: Bool = false

    var totalDays: Int { preset.totalDays }
    var stopTurnDay: Int { preset.stopTurnDay }
    
    static func == (lhs: Batch, rhs: Batch) -> Bool {
        lhs.id == rhs.id
    }
}

struct SensorReading: Codable, Identifiable {
    let id = UUID()
    var batchId: UUID
    var timestamp: Date
    var temp: Double
    var humidity: Double
}

struct IncubationTask: Codable, Identifiable {
    let id = UUID()
    var batchId: UUID
    var type: TaskType
    var dueAt: Date
    var status: Status = .pending

    enum TaskType: String, Codable {
        case turn, candle, stopTurn, hatch, vent, water
        var title: String {
            switch self {
            case .turn: return "Turn eggs"
            case .candle: return "Candling"
            case .stopTurn: return "Stop turning"
            case .hatch: return "Hatching"
            case .vent: return "Ventilate"
            case .water: return "Add water"
            }
        }
    }

    enum Status: Codable { case pending, done, missed }
}
