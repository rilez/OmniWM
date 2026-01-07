import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(
                isProminent ? .regular.tint(.accentColor) : .regular,
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}

struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 12

    init(cornerRadius: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
