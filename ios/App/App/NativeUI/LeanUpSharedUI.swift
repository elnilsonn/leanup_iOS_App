import SwiftUI
import UIKit
struct LeanUpSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.unadBlue)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct LeanUpProgressTrack: View {
    let title: String
    let valueText: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(valueText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 0)
                let clamped = min(max(progress, 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.65), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(width * clamped, 12))
                }
            }
            .frame(height: 10)
        }
    }
}

struct LeanUpStatusChip: View {
    let status: LeanUpProgressStatus
    let note: Double?

    var body: some View {
        HStack(spacing: 6) {
            if let note {
                Text(LeanUpGradeFormatter.display(note))
            }
            Text(status.title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(backgroundColor))
        .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.primary.opacity(0.08)
        case .inProgress:
            return Color.unadCyan.opacity(0.16)
        case .approved:
            return Color.green.opacity(0.14)
        case .failed:
            return Color.red.opacity(0.14)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending:
            return .secondary
        case .inProgress:
            return .unadCyan
        case .approved:
            return .green
        case .failed:
            return .red
        }
    }
}

struct LeanUpTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .foregroundStyle(.secondary)
    }
}

struct LeanUpInlineMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

struct FlowTagList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunked(items, size: 2), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        LeanUpTag(text: item)
                    }
                }
            }
        }
    }

    private func chunked(_ items: [String], size: Int) -> [[String]] {
        stride(from: 0, to: items.count, by: size).map { start in
            Array(items[start..<min(start + size, items.count)])
        }
    }
}

struct LeanUpSurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 1)
            )
    }

    private var cardFill: Color {
        Color.white.opacity(0.98)
    }

    private var cardStroke: Color {
        Color.unadBlue.opacity(0.08)
    }
}

struct LeanUpChecklistRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.unadBlue)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

struct LeanUpPriorityRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LeanUpPill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.16)))
        .foregroundStyle(.white)
    }
}

struct LeanUpPageBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: scheme == .dark
                    ? [
                        Color.black,
                        Color.unadNavy.opacity(0.96),
                        Color(red: 0.03, green: 0.09, blue: 0.18)
                    ]
                    : [
                        Color(red: 248 / 255, green: 250 / 255, blue: 255 / 255),
                        Color(red: 237 / 255, green: 245 / 255, blue: 252 / 255),
                        Color(red: 228 / 255, green: 240 / 255, blue: 248 / 255)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.unadCyan.opacity(scheme == .dark ? 0.14 : 0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 220
            )
            .offset(x: 70, y: -80)

            RadialGradient(
                colors: [
                    Color.unadGold.opacity(scheme == .dark ? 0.08 : 0.10),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 180
            )
            .offset(x: -50, y: 140)
        }
        .ignoresSafeArea()
    }
}

struct LeanUpPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.unadBlue)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct LeanUpSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ----------------------------------------------------------------------

private struct LeanUpKeyboardDismissOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                leanUpDismissKeyboard()
            }
        )
    }
}

extension View {
    @ViewBuilder
    func leanUpKeyboardFriendlyScroll() -> some View {
        if #available(iOS 16.0, *) {
            self
                .scrollDismissesKeyboard(.interactively)
                .modifier(LeanUpKeyboardDismissOnTapModifier())
        } else {
            self
                .modifier(LeanUpKeyboardDismissOnTapModifier())
        }
    }
}

private func leanUpDismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

