import SwiftUI

/// Displays the user's favorite item suggestions as tappable chips in a flow layout.
///
/// Shown inside the add-item bar when the text field is focused. Tapping a chip
/// instantly adds that item to the current list. Suggestions that already exist
/// in the list are hidden.
struct FavoriteSuggestionsView: View {
    /// All of the user's saved favorite suggestion strings.
    let suggestions: [String]
    /// The current text in the add-item text field, used to narrow the suggestions.
    let filter: String
    /// Names of items already in the current list (excluded from suggestions).
    let existingItems: Set<String>
    /// Called when the user taps a suggestion chip to add it.
    let onSelect: (String) -> Void

    /// Suggestions filtered to exclude items already in the list, then further
    /// narrowed by the search text (if any).
    private var filteredSuggestions: [String] {
        let available = suggestions.filter { !existingItems.contains($0) }
        if filter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return available
        }
        return available.filter { $0.localizedStandardContains(filter) }
    }

    private let rows = [
        GridItem(.fixed(36)),
        GridItem(.fixed(36))
    ]

    var body: some View {
        if !filteredSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Favorites", systemImage: "star.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button {
                                onSelect(suggestion)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.gradientMid)

                                    Text(suggestion)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.fill.tertiary, in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.vertical)
            .background(.bar)
        }
    }
}


