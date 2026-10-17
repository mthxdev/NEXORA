import SwiftUI

struct NexoraColors {
    static let primary = Color.accentColor
    static let secondary = Color.secondary
    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let separator = Color(.separator)
    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)
    static let blue = Color.blue
    static let orange = Color.orange
    static let purple = Color.purple
}

struct NexoraSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

struct NexoraTypography {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title1 = Font.title.weight(.semibold)
    static let title2 = Font.title2.weight(.semibold)
    static let title3 = Font.title3.weight(.medium)
    static let headline = Font.headline
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let caption2 = Font.caption2
}

struct NexoraRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

struct CardStyle: ViewModifier {
    let padding: CGFloat
    let backgroundColor: Color
    
    init(padding: CGFloat = NexoraSpacing.md, backgroundColor: Color = NexoraColors.cardBackground) {
        self.padding = padding
        self.backgroundColor = backgroundColor
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NexoraSpacing.md)
            .background(isEnabled ? NexoraColors.primary : NexoraColors.primary.opacity(0.5))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NexoraSpacing.md)
            .background(NexoraColors.cardBackground)
            .foregroundStyle(NexoraColors.primary)
            .clipShape(RoundedRectangle(cornerRadius: NexoraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: NexoraRadius.md)
                    .stroke(NexoraColors.primary, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(padding: CGFloat = NexoraSpacing.md, backgroundColor: Color = NexoraColors.cardBackground) -> some View {
        modifier(CardStyle(padding: padding, backgroundColor: backgroundColor))
    }
    
    func primaryButton(isEnabled: Bool = true) -> some View {
        buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    func secondaryButton() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(NexoraTypography.headline)
            .foregroundStyle(NexoraColors.secondaryLabel)
            .textCase(nil)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: NexoraSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(NexoraColors.tertiaryLabel)
                .accessibilityHidden(true)

            VStack(spacing: NexoraSpacing.xs) {
                Text(title)
                    .font(NexoraTypography.title3)
                    .foregroundStyle(NexoraColors.label)

                Text(description)
                    .font(NexoraTypography.subheadline)
                    .foregroundStyle(NexoraColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .primaryButton()
                    .frame(maxWidth: 200)
                    .padding(.top, NexoraSpacing.xs)
            }
        }
        .padding(NexoraSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: NexoraSpacing.lg) {
        Text("Design System Preview")
            .font(NexoraTypography.largeTitle)
        
        VStack(spacing: NexoraSpacing.md) {
            Text("Primary Button")
                .primaryButton()
            Text("Secondary Button")
                .secondaryButton()
            Text("Disabled Button")
                .primaryButton(isEnabled: false)
        }
        .padding(NexoraSpacing.md)
        .cardStyle()
        
        EmptyStateView(
            icon: "dumbbell",
            title: "Aucune séance",
            description: "Commencez votre premier entraînement pour voir vos progrès ici.",
            actionTitle: "Nouvelle séance",
            action: {}
        )
        .cardStyle()
    }
    .padding()
    .background(NexoraColors.groupedBackground)
}