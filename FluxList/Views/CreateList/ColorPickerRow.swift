import SwiftUI

/// A horizontally scrollable row of color swatches. The currently selected
/// color shows a checkmark overlay.
struct ColorPickerRow: View {
    /// The color currently chosen for the list.
    @Binding var selectedColor: AppColor

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(AppColor.allCases) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .bold()
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
