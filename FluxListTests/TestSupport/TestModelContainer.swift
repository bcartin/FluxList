import SwiftData
@testable import FluxList

/// Provides a shared in-memory `ModelContainer` for all SwiftData tests.
///
/// SwiftData's `@Model` type metadata cannot be safely initialized from
/// multiple containers concurrently. By reusing a single container (and
/// creating fresh `ModelContext` instances per test), we avoid the runtime
/// crash that occurs when Swift Testing runs suites in parallel.
@MainActor
enum TestModelContainer {
    /// A single in-memory container shared across the entire test process.
    static let shared: ModelContainer = {
        let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // Using try! is acceptable here — a failure means the test environment
        // itself is broken and no tests can run.
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    /// Returns a fresh `ModelContext` backed by the shared container.
    /// Deletes all existing data first so each test starts clean.
    static func newContext() -> ModelContext {
        let context = ModelContext(shared)
        context.autosaveEnabled = false

        // Clear any leftover data from previous tests
        do {
            try context.delete(model: ListItem.self)
            try context.delete(model: TaskList.self)
            try context.delete(model: Project.self)
            try context.delete(model: User.self)
            try context.save()
        } catch {
            // Ignore cleanup errors — fresh container should be empty anyway
        }

        return context
    }
}
