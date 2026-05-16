import SwiftUI

enum NotionDesign {
    enum Colors {
        static let primary = Color(hex: 0x5645D4)
        static let primaryPressed = Color(hex: 0x4534B3)
        static let brandNavy = Color(hex: 0x0A1530)
        static let brandNavyDeep = Color(hex: 0x070F24)
        static let canvas = Color(hex: 0xFFFFFF)
        static let surface = Color(hex: 0xF6F5F4)
        static let surfaceSoft = Color(hex: 0xFAFAF9)
        static let widget = Color(hex: 0xFCFCFB)
        static let memoBackground = Color(hex: 0xFEF7D6)
        static let hairline = Color(hex: 0xE5E3DF)
        static let hairlineSoft = Color(hex: 0xEDE9E4)
        static let hairlineStrong = Color(hex: 0xC8C4BE)
        static let ink = Color(hex: 0x1A1A1A)
        static let charcoal = Color(hex: 0x37352F)
        static let slate = Color(hex: 0x5D5B54)
        static let steel = Color(hex: 0x787671)
        static let stone = Color(hex: 0xA4A097)
        static let muted = Color(hex: 0xBBB8B1)
        static let error = Color(hex: 0xE03131)
        static let success = Color(hex: 0x1AAE39)
        static let redLight = Color(hex: 0xFFF0F0)
        static let primaryLight = Color(hex: 0xEDE9FC)
        static let peach = Color(hex: 0xFFE8D4)
        static let rose = Color(hex: 0xFDE0EC)
        static let mint = Color(hex: 0xD9F3E1)
        static let lavender = Color(hex: 0xE6E0F5)
        static let sky = Color(hex: 0xDCECFA)
        static let yellow = Color(hex: 0xF9E79F)
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let widget: CGFloat = 12
    }

    enum Panel {
        static let shadowPadding: CGFloat = 0
        static let floatingShadowPadding: CGFloat = 18
        static let headerHeight: CGFloat = 46
        static let headerHorizontalPadding: CGFloat = 12
        static let headerSideSlotWidth: CGFloat = 92
    }

    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
    }

    enum Fonts {
        static func pretendard(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(AppFontRegistry.primaryFontName, size: size).weight(weight)
        }

        static let heading = pretendard(size: 20, weight: .semibold)
        static let body = pretendard(size: 15)
        static let bodyMedium = pretendard(size: 15, weight: .medium)
        static let caption = pretendard(size: 14)
        static let captionBold = pretendard(size: 14, weight: .semibold)
        static let microBold = pretendard(size: 13, weight: .semibold)
        static let button = pretendard(size: 15, weight: .medium)
        static let timer = pretendard(size: 46, weight: .semibold)
    }

    enum Shadows {
        static let widget = Color.black.opacity(0.18)
        static let floating = Color.black.opacity(0.24)
        static let soft = Color.black.opacity(0.10)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct NotionCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(NotionDesign.Colors.canvas, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.large)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 22, x: 0, y: 14)
    }
}

struct FloatingWidgetSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var shadowColor: Color = NotionDesign.Shadows.widget
    var backgroundColor: Color?

    func body(content: Content) -> some View {
        content
            .background { backgroundShape }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(NotionDesign.Colors.hairlineStrong.opacity(0.42), lineWidth: 1)
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .strokeBorder(Color.white.opacity(0.78), lineWidth: 1)
            }
            .compositingGroup()
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if let backgroundColor {
            shape.fill(backgroundColor)
        } else {
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.99),
                        NotionDesign.Colors.widget.opacity(0.98),
                        Color(hex: 0xF8F7F5).opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

struct PanelHeader<Trailing: View>: View {
    let title: String
    var background: Color = NotionDesign.Colors.canvas
    var hairline: Color = NotionDesign.Colors.hairline
    @ViewBuilder let trailing: () -> Trailing
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            Text(title)
                .font(NotionDesign.Fonts.captionBold)
                .foregroundStyle(NotionDesign.Colors.charcoal)
                .lineLimit(1)

            HStack(spacing: 0) {
                PanelWindowControls(window: window)
                    .frame(width: NotionDesign.Panel.headerSideSlotWidth, alignment: .leading)

                Spacer(minLength: 0)

                trailing()
                    .frame(width: NotionDesign.Panel.headerSideSlotWidth, alignment: .trailing)
            }
            .padding(.horizontal, NotionDesign.Panel.headerHorizontalPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: NotionDesign.Panel.headerHeight)
        .background(background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(hairline)
                .frame(height: 1)
        }
        .background(WindowAccessor { window = $0 })
    }
}

private struct PanelWindowControls: View {
    weak var window: NSWindow?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                window?.close()
            } label: {
                Circle()
                    .fill(Color(hex: 0xFF5F57))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .help("닫기")

            Button {
                window?.miniaturize(nil)
            } label: {
                Circle()
                    .fill(Color(hex: 0xFEBB2E))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .help("최소화")
        }
        .padding(.leading, 18)
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

struct NotionPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.button)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                configuration.isPressed ? NotionDesign.Colors.primaryPressed : NotionDesign.Colors.primary,
                in: RoundedRectangle(cornerRadius: NotionDesign.Radius.medium)
            )
    }
}

struct NotionIconButtonStyle: ButtonStyle {
    var tint: Color = NotionDesign.Colors.charcoal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.captionBold)
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(
                configuration.isPressed ? NotionDesign.Colors.hairline : NotionDesign.Colors.surface,
                in: RoundedRectangle(cornerRadius: NotionDesign.Radius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.medium)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
    }
}

struct NotionTag: View {
    let text: String
    var tint: Color = NotionDesign.Colors.lavender
    var foreground: Color = NotionDesign.Colors.primary

    var body: some View {
        Text(text)
            .font(NotionDesign.Fonts.microBold)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(tint, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
    }
}

extension View {
    func notionCard() -> some View {
        modifier(NotionCardModifier())
    }

    func floatingWidgetSurface<S: InsettableShape>(
        _ shape: S,
        shadowColor: Color = NotionDesign.Shadows.widget,
        backgroundColor: Color? = nil
    ) -> some View {
        modifier(FloatingWidgetSurfaceModifier(shape: shape, shadowColor: shadowColor, backgroundColor: backgroundColor))
    }
}
