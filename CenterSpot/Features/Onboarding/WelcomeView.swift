import SwiftUI

/// The welcome on first launch, and again after Show tips again (D-58, D-78, mockup `onboarding-*--bc`): three pages,
/// each with the real example move playing above a title and one line, all on the centre line (D-81). Skip goes to the library; Start, on the last
/// page, opens the example move, where the first tip waits. At the accessibility text sizes the picture steps aside
/// and the words scroll, with Skip, the dots and the button pinned (mockup `onboarding-1--ax5`).
struct WelcomeView: View {
    /// The example move the pictures play.
    let tactic: Tactic
    var onSkip: () -> Void
    var onStart: () -> Void

    @State private var page = 1
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The picture's height on a phone; on an iPad it grows into the room the page has (Chime, 8 Nov).
    static let artHeight: CGFloat = 404
    /// What the title and its line need under the picture on an iPad, kept clear when the picture grows.
    static let wideTextRoom: CGFloat = 240
    /// On an iPad the button and the words keep a readable width instead of running edge to edge.
    static let wideButtonWidth: CGFloat = 480
    static let wideTextWidth: CGFloat = 640
    private var isWide: Bool { sizeClass == .regular }

    struct Page {
        let title: String
        let body: String
        /// What VoiceOver reads for the picture; the picture itself is decoration.
        let picture: String
    }

    static let pages = [
        Page(title: "Draw the move, not just the shape",
             body: "Place your players, then add steps. Each step is one moment of the move.",
             picture: "A pitch showing a five-step move"),
        Page(title: "Press Play. Watch it move",
             body: "Players run from step to step, and the Broadcast camera follows the ball.",
             picture: "The move playing in the tilted Broadcast camera"),
        Page(title: "Share it as a 9:16 clip",
             body: "One tap makes a vertical video for the team chat, with your title on top.",
             picture: "A vertical video of the move in the Broadcast camera, with its title at the top"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .font(Tokens.Typeface.headline)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .frame(minWidth: Tokens.Size.touch, minHeight: Tokens.Size.touch)
                    .padding(.horizontal, Tokens.Space.s2)
                    .accessibilityShowsLargeContentViewer { Text("Skip") }
                    .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, Tokens.Space.s2)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            TabView(selection: $page) {
                ForEach(1...Self.pages.count, id: \.self) { number in
                    pageView(number).tag(number)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots
                .padding(.vertical, Tokens.Space.s4)
            Button(page < Self.pages.count ? "Next" : "Start") {
                if page < Self.pages.count { turn(to: page + 1) } else { onStart() }
            }
            .buttonStyle(PrimaryCapsuleStyle())
            .frame(maxWidth: isWide ? Self.wideButtonWidth : .infinity)
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.bottom, Tokens.Space.s4)
            .accessibilityIdentifier(page < Self.pages.count ? "onboarding.next" : "onboarding.start")
        }
        .background(Tokens.Colour.bg.color.ignoresSafeArea())
    }

    private func pageView(_ number: Int) -> some View {
        let content = Self.pages[number - 1]
        return GeometryReader { proxy in
            // Grows with the height left over, but never wider than the page: the widest picture (page 2's camera)
            // sets the cap, so the boards and the clip stay inside a narrow, tall iPad window too.
            let byWidth = Self.artHeight * proxy.size.width / WelcomeArt.broadcastSize.width
            let height = isWide ? max(Self.artHeight, min(proxy.size.height - Self.wideTextRoom, byWidth)) : Self.artHeight
            pageBody(number, content: content, artHeight: height)
        }
        .accessibilityIdentifier("onboarding.page")
    }

    private func pageBody(_ number: Int, content: Page, artHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                WelcomeArt(page: number, tactic: tactic, isActive: page == number, scale: artHeight / Self.artHeight,
                           wide: isWide)
                    .frame(maxWidth: .infinity, minHeight: artHeight, maxHeight: artHeight)
                    .accessibilityElement()
                    .accessibilityLabel(content.picture)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("onboarding.art.\(number)")
                    .padding(.bottom, Tokens.Space.s5)
            }
            ScrollView {
                VStack(spacing: Tokens.Space.s2) {
                    Text(content.title)
                        .font(Tokens.Typeface.largeTitle)
                        .foregroundStyle(Tokens.Colour.text.color)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboarding.title")
                    Text(content.body)
                        .font(Tokens.Typeface.body)
                        .foregroundStyle(Tokens.Colour.muted.color)
                        .accessibilityIdentifier("onboarding.body")
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: isWide ? Self.wideTextWidth : .infinity)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Tokens.Space.s5)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The active page is a wider white dot, so the page shows by shape as well as colour. One adjustable element for
    /// VoiceOver ("Page 1 of 3"); a tap on its left or right half goes back or on.
    private var dots: some View {
        HStack(spacing: Tokens.Space.s2) {
            ForEach(1...Self.pages.count, id: \.self) { number in
                Capsule()
                    .fill(number == page ? Tokens.Colour.text.color : Tokens.Colour.muted.color)
                    .frame(width: number == page ? 24 : 8, height: 8)
            }
        }
        .frame(minWidth: 120, minHeight: Tokens.Size.touch)
        .contentShape(Rectangle())
        .onTapGesture { location in turn(to: page + (location.x < 60 ? -1 : 1)) }
        .accessibilityElement()
        .accessibilityLabel("Page \(page) of \(Self.pages.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: turn(to: page + 1)
            case .decrement: turn(to: page - 1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("onboarding.dots")
    }

    private func turn(to number: Int) {
        let target = min(max(number, 1), Self.pages.count)
        withAnimation(reduceMotion ? nil : Tokens.Motion.ease(0.32)) { page = target }
    }
}
