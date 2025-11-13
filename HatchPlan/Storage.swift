import Foundation

final class Storage {
    static let shared = Storage()
    private let defaults = UserDefaults.standard

    func saveBatches(_ batches: [Batch]) {
        if let data = try? JSONEncoder().encode(batches) {
            defaults.set(data, forKey: "batches")
        }
    }

    func loadBatches() -> [Batch] {
        guard let data = defaults.data(forKey: "batches"),
              let batches = try? JSONDecoder().decode([Batch].self, from: data) else {
            return []
        }
        return batches
    }

    func saveTasks(_ tasks: [IncubationTask]) {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: "tasks")
        }
    }

    func loadTasks() -> [IncubationTask] {
        guard let data = defaults.data(forKey: "tasks"),
              let tasks = try? JSONDecoder().decode([IncubationTask].self, from: data) else {
            return []
        }
        return tasks
    }
}
