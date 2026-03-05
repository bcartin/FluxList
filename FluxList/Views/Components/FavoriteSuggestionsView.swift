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

    var body: some View {
        if filteredSuggestions.isEmpty {
            ContentUnavailableView.search(text: filter)
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    Label("Favorites", systemImage: "star.fill")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    FlowLayout {
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
                .padding(.vertical)
            }
        }
    }
}

// MARK: - Flow Layout

/// A simple wrapping horizontal layout for chips/tags.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            positions,
            CGSize(width: maxWidth, height: currentY + rowHeight)
        )
    }
}
