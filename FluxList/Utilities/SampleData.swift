import Foundation
import SwiftData

/// Provides an in-memory SwiftData container pre-populated with realistic sample data.
///
/// Used by SwiftUI previews and tests so they can render views with meaningful
/// content without touching the real on-disk database.
@MainActor
enum SampleData {
    /// A shared, lazily-created in-memory container. Access this from `#Preview` blocks
    /// to get a fully populated model context.
    static let sampleContainer: ModelContainer = {
        let schema = Schema([User.self, Project.self, TaskList.self, ListItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        populateSampleData(in: container.mainContext)
        return container
    }()

    /// Inserts sample users, projects, lists, and items into the given context.
    static func populateSampleData(in context: ModelContext) {
        let robert = User(name: "Robert", email: "robert.cartin@gmail.com")
        let bernie = User(name: "Bernie", email: "bernie@example.com")
        context.insert(robert)
        context.insert(bernie)

        let robertID = robert.id.uuidString
        let bernieID = bernie.id.uuidString

        robert.friends = [bernieID]
        bernie.friends = [robertID]

        // Projects
        let websiteRedesign = Project(name: "Website Redesign")
        let mobileApp = Project(name: "Mobile App")
        context.insert(websiteRedesign)
        context.insert(mobileApp)

        // Lists — userIDs determines who sees the list
        let personal = TaskList(
            name: "Personal",
            colorName: "red",
            iconName: "person",
            createdBy: robertID
        )
        personal.userIDs = [robertID]

        let work = TaskList(
            name: "Work",
            colorName: "orange",
            iconName: "briefcase",
            project: websiteRedesign,
            createdBy: robertID
        )
        work.userIDs = [robertID, bernieID]

        let shopping = TaskList(
            name: "Shopping",
            colorName: "blue",
            iconName: "cart",
            createdBy: robertID
        )
        shopping.userIDs = [robertID, bernieID]

        let errands = TaskList(
            name: "Errands",
            colorName: "green",
            iconName: "mappin",
            createdBy: robertID
        )
        errands.userIDs = [robertID]

        [personal, work, shopping, errands].forEach { context.insert($0) }

        // Personal items
        let buyGroceries = ListItem(name: "Buy groceries", isCompleted: true, createdBy: robertID, taskList: personal)
        let callMom = ListItem(name: "Call mom", createdBy: robertID, taskList: personal)
        let gymWorkout = ListItem(name: "Gym workout", createdBy: robertID, taskList: personal)
        [buyGroceries, callMom, gymWorkout].forEach { context.insert($0) }

        // Work items
        let sprintPlanning = ListItem(name: "Sprint planning", createdBy: robertID, taskList: work)
        let sendInvoices = ListItem(name: "Send invoices", isCompleted: true, createdBy: robertID, taskList: work)
        let reviewPRs = ListItem(name: "Review PRs", createdBy: bernieID, taskList: work)
        let designSync = ListItem(name: "Design sync", createdBy: robertID, taskList: work)
        let planNextSprint = ListItem(name: "Plan next sprint", createdBy: robertID, taskList: work)
        [sprintPlanning, sendInvoices, reviewPRs, designSync, planNextSprint].forEach { context.insert($0) }

        // Shopping items
        let findBirthdayGift = ListItem(name: "Find birthday gift", isCompleted: true, createdBy: robertID, taskList: shopping)
        let compareEarbuds = ListItem(name: "Compare earbuds", createdBy: bernieID, taskList: shopping)
        [findBirthdayGift, compareEarbuds].forEach { context.insert($0) }

        // Set favorites using list IDs
        robert.favoriteListIDs = [personal.id.uuidString, work.id.uuidString]

        // Favorite task suggestions
        robert.favoriteSuggestions = [
            "Buy groceries",
            "Call mom",
            "Gym workout",
            "Review PRs",
            "Send invoices",
            "Pick up dry cleaning",
            "Book dentist appointment",
            "Update resume",
            "Pay bills",
            "Clean the house"
        ]
        bernie.favoriteSuggestions = [
            "Code review",
            "Update documentation",
            "Team standup",
            "Fix bug reports",
            "Deploy to staging"
        ]
    }
}
