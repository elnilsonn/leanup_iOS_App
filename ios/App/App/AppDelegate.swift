import UIKit
import Capacitor
import SwiftUI
import WebKit

// MARK: - Weak message-handler proxy (prevents WKWebView retain cycle)
private class WeakMsgHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

// MARK: - Tab model
private struct LUTab: Identifiable, Equatable {
    let id: String; let icon: String; let label: String
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Liquid Glass Tab Bar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@available(iOS 15.0, *)
private struct LiquidGlassTabBar: View {
    @Binding var active: String

    // Gesture state — single unified recognizer handles tap AND swipe
    @State private var pressingTab: String? = nil
    @State private var gestureStartX: CGFloat? = nil
    @State private var isDragging = false
    @State private var bubbleCenterX: CGFloat = 0
    @State private var hasAppeared = false

    @Environment(\.colorScheme) private var scheme

    private let dragThreshold: CGFloat = 8  // pt before a touch becomes a drag
    private let innerPad: CGFloat = 10
    private let tabs: [LUTab] = [
        LUTab(id: "dashboard", icon: "house.fill",            label: "Inicio"),
        LUTab(id: "malla",     icon: "list.bullet.clipboard", label: "Malla"),
        LUTab(id: "perfil",    icon: "person.fill",           label: "Perfil"),
        LUTab(id: "config",    icon: "gearshape.fill",        label: "Config"),
    ]
    var onSelect: (String) -> Void

    private var activeIndex: Int {
        tabs.firstIndex(where: { $0.id == active }) ?? 0
    }

    private func tabCenter(_ idx: Int, contentW: CGFloat) -> CGFloat {
        let tabW = contentW / CGFloat(tabs.count)
        return tabW * (CGFloat(idx) + 0.5)
    }

    // MARK: Body
    var body: some View {
        GeometryReader { geo in
            let totalW   = geo.size.width
            let contentW = totalW - innerPad * 2
            let tabW     = contentW / CGFloat(tabs.count)
            let bubbleW  = tabW - 8
            // Compute correct position from GeometryReader on EVERY render
            let computedCenter = tabCenter(activeIndex, contentW: contentW)

            barView(bubbleW: bubbleW, computedCenter: computedCenter)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in onDragChanged(v, contentW: contentW, tabW: tabW) }
                        .onEnded   { v in onDragEnded(v, contentW: contentW, tabW: tabW)   }
                )
                .onAppear {
                    guard !hasAppeared else { return }
                    bubbleCenterX = computedCenter
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        bubbleCenterX = computedCenter
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasAppeared = true
                        }
                    }
                }
        }
        .frame(height: 58)
        .padding(.horizontal, 16)
    }

    // MARK: Unified drag/tap handler — onChanged
    private func onDragChanged(_ v: DragGesture.Value, contentW: CGFloat, tabW: CGFloat) {
        if gestureStartX == nil { gestureStartX = v.location.x }

        let dx = v.location.x - (gestureStartX ?? v.location.x)

        if !isDragging && abs(dx) > dragThreshold {
            isDragging = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                pressingTab = nil
            }
        }

        if isDragging {
            // Bubble follows finger directly — no animation for instant tracking
            let contentX = v.location.x - innerPad
            let halfTab  = tabW / 2
            bubbleCenterX = max(halfTab, min(contentX, contentW - halfTab))
        } else {
            let contentX = v.location.x - innerPad
            let idx = clamp(Int(contentX / tabW), in: 0..<tabs.count)
            let tabId = tabs[idx].id
            if pressingTab != tabId {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                    pressingTab = tabId
                }
            }
        }
    }

    // MARK: Unified drag/tap handler — onEnded
    private func onDragEnded(_ v: DragGesture.Value, contentW: CGFloat, tabW: CGFloat) {
        let startX = gestureStartX ?? v.location.x
        let dx     = abs(v.location.x - startX)

        gestureStartX = nil
        isDragging    = false

        let idx: Int
        if dx < dragThreshold {
            let contentX = startX - innerPad
            idx = clamp(Int(contentX / tabW), in: 0..<tabs.count)
        } else {
            let contentX = v.location.x - innerPad
            idx = clamp(Int(contentX / tabW), in: 0..<tabs.count)
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            active = tabs[idx].id
            pressingTab = nil
            bubbleCenterX = tabCenter(idx, contentW: contentW)
        }
        onSelect(tabs[idx].id)
    }

    // MARK: Bar container (iOS 26 vs fallback)
    @ViewBuilder
    private func barView(bubbleW: CGFloat, computedCenter: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            tabContent(bubbleW: bubbleW, computedCenter: computedCenter)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .glassEffect(.regular.interactive(true), in: .capsule)
        } else {
            tabContent(bubbleW: bubbleW, computedCenter: computedCenter)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background { fallbackBg }
        }
    }

    // MARK: Tab content — single bubble positioned via continuous offset + icons
    @ViewBuilder
    private func tabContent(bubbleW: CGFloat, computedCenter: CGFloat) -> some View {
        ZStack {
            // Bubble — follows finger directly during drag, springs to tab on release
            // Before hasAppeared, use computedCenter (from GeometryReader) to avoid wrong position
            Group {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .fill(scheme == .dark
                              ? Color.white.opacity(0.12)
                              : Color.white.opacity(0.72))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        .frame(width: bubbleW, height: 44)
                } else {
                    activeTabBubble(width: bubbleW)
                }
            }
            .position(x: hasAppeared ? bubbleCenterX : computedCenter, y: 26)
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(pressingTab != nil && pressingTab == active ? 1.10 : 1.0)

            // Tab icons — always based on `active`, NOT drag state (prevents flicker)
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    let isActive   = active == tab.id
                    let isPressing = pressingTab == tab.id
                    tabLabel(tab, isActive: isActive, isPressing: isPressing)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .contentShape(Rectangle())
                        .accessibilityLabel(tab.label)
                        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { onSelect(tab.id) }
                }
            }
        }
    }

    // MARK: Active-tab highlight bubble (fallback for iOS < 26)
    @ViewBuilder
    private func activeTabBubble(width: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(scheme == .dark
                      ? Color.white.opacity(0.14)
                      : Color.white.opacity(0.88))
                .background(.thinMaterial, in: Capsule())
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(scheme == .dark ? 0.30 : 0.70), location: 0),
                    .init(color: .white.opacity(scheme == .dark ? 0.06 : 0.18), location: 0.35),
                    .init(color: .clear, location: 0.65),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(scheme == .dark ? 0.45 : 0.90),
                            .white.opacity(scheme == .dark ? 0.08 : 0.25),
                            .white.opacity(scheme == .dark ? 0.25 : 0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
        .frame(width: width, height: 44)
        .shadow(color: .white.opacity(scheme == .dark ? 0.12 : 0.45), radius: 4, y: -1)
        .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.12), radius: 10, y: 3)
    }

    // MARK: Tab icon + label
    @ViewBuilder
    private func tabLabel(_ tab: LUTab, isActive: Bool, isPressing: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: isActive ? 22 : 20, weight: .medium))
            Text(tab.label)
                .font(.system(size: 10, weight: isActive ? .bold : .semibold))
        }
        .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.48))
        // Combine scale effects: press overrides active-scale
        .scaleEffect(isPressing ? 1.06 : (isActive ? 1.04 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isActive)
        .animation(.spring(response: 0.15, dampingFraction: 0.65), value: isPressing)
    }

    // MARK: Frosted bar background — iOS 15-25 fallback
    @ViewBuilder
    private var fallbackBg: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.50)

            Capsule()
                .fill(scheme == .dark
                      ? Color(red: 0.05, green: 0.09, blue: 0.16).opacity(0.22)
                      : Color.white.opacity(0.14))

            // Minimal specular top-edge highlight
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(scheme == .dark ? 0.08 : 0.30), location: 0),
                    .init(color: .clear, location: 0.40),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(Capsule())

            // Thin rim stroke
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(scheme == .dark ? 0.14 : 0.50),
                            .white.opacity(scheme == .dark ? 0.03 : 0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.30 : 0.07), radius: 16, y: 4)
        .shadow(color: .white.opacity(scheme == .dark ? 0.0 : 0.20), radius: 1, y: -0.5)
    }

    private func clamp(_ v: Int, in r: Range<Int>) -> Int { min(max(v, r.lowerBound), r.upperBound - 1) }
}

// MARK: - Tab Bar Host
@available(iOS 15.0, *)
private struct TabBarHost: View {
    @State private var active = "dashboard"
    var onSelect: (String) -> Void
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LiquidGlassTabBar(active: $active, onSelect: onSelect)
                .padding(.bottom, 4)
        }
        .background(Color.clear)
    }
}

// MARK: - Floating Glass Back Button
@available(iOS 15.0, *)
private struct GlassBackButton: View {
    var onTap: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .modifier(GlassCircleModifier(scheme: scheme))
    }
}

// Apply .glassEffect() LAST, per iOS 26 best practices
@available(iOS 15.0, *)
private struct GlassCircleModifier: ViewModifier {
    let scheme: ColorScheme

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(true), in: .circle)
        } else {
            content
                .background {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(scheme == .dark
                            ? Color.white.opacity(0.10)
                            : Color.white.opacity(0.45))
                        // Specular highlight
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(scheme == .dark ? 0.15 : 0.55), location: 0),
                                .init(color: .clear, location: 0.45),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ).clipShape(Circle())
                        // Rim
                        Circle().stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(scheme == .dark ? 0.22 : 0.65),
                                    .white.opacity(scheme == .dark ? 0.05 : 0.18),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    }
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.12), radius: 12, y: 3)
                    .shadow(color: .white.opacity(scheme == .dark ? 0.0 : 0.25), radius: 1, y: -0.5)
                }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Native Float Buttons (Save / Reset)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Shared state updated from AppDelegate, observed by SwiftUI
private class FloatButtonsState: ObservableObject {
    @Published var resetEnabled: Bool = false
    @Published var saveFlash: Bool    = false
}

@available(iOS 15.0, *)
private struct GlassFloatButtons: View {
    @ObservedObject var state: FloatButtonsState
    var onSave:  () -> Void
    var onReset: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Reset — left of save
            GlassCircleAction(
                icon: "arrow.counterclockwise",
                dimmed: !state.resetEnabled
            ) { onReset() }

            // Save — rightmost
            GlassCircleAction(
                icon: state.saveFlash ? "checkmark" : "square.and.arrow.down",
                accentGreen: state.saveFlash,
                dimmed: false
            ) { onSave() }
        }
    }
}

/// One circular glass action button — press scale + haptic + glass
@available(iOS 15.0, *)
private struct GlassCircleAction: View {
    let icon:        String
    var accentGreen: Bool = false
    let dimmed:      Bool
    let action:      () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var pressing = false

    private var iconColor: Color {
        if accentGreen { return Color(red: 0, green: 0.66, blue: 0.42) }
        return scheme == .dark
            ? Color(red: 0, green: 0.61, blue: 0.77)   // unad-cyan
            : Color(red: 0, green: 0.27, blue: 0.68)   // unad-blue
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(iconColor.opacity(dimmed ? 0.28 : 1.0))
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .scaleEffect(pressing ? 0.84 : 1.0)
            .animation(
                pressing
                    ? .spring(response: 0.15, dampingFraction: 0.62)
                    : .spring(response: 0.30, dampingFraction: 0.78),
                value: pressing
            )
            .animation(.easeInOut(duration: 0.18), value: dimmed)
            .modifier(GlassCircleModifier(scheme: scheme))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressing { pressing = true } }
                    .onEnded { _ in
                        pressing = false
                        guard !dimmed else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        action()
                    }
            )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - AppDelegate
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {

    var window: UIWindow?
    private weak var capacitorWebView: WKWebView?
    private weak var rootVC: UIViewController?

    private var tabBarVC: UIViewController?
    private var backButtonVC: UIViewController?
    private var floatButtonsVC: UIViewController?
    private let floatButtonsState = FloatButtonsState()
    private var tabBarHeightConstraint: NSLayoutConstraint?
    private var isCollapsed = false
    private var messageHandlerAdded = false
    private var hasRestoredData = false
    private var edgePanGR: UIScreenEdgePanGestureRecognizer?

    private var isPanelOpen = false {
        didSet { updateBackButtonVisibility() }
    }
    private var isProfileSubViewOpen = false {
        didSet { updateBackButtonVisibility() }
    }

    private func updateBackButtonVisibility() {
        animateBackButton(visible: isPanelOpen || isProfileSubViewOpen)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        scheduleMount(attempt: 0)
        return true
    }

    // MARK: Retry until WebView ready
    private func scheduleMount(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            guard let rootVC = self.window?.rootViewController,
                  let wv = self.firstWebView(in: rootVC.view) else {
                if attempt < 15 { self.scheduleMount(attempt: attempt + 1) }
                return
            }
            self.rootVC = rootVC
            self.capacitorWebView = wv

            // ── Full-screen edge-to-edge (content behind status bar, like App Store) ──
            rootVC.edgesForExtendedLayout = .all
            rootVC.extendedLayoutIncludesOpaqueBars = true
            // Prevent the scroll view from automatically adding top inset for status bar
            wv.scrollView.contentInsetAdjustmentBehavior = .never
            // Fix: remove SUPERVIEW constraints that pin webview to safe area, then re-pin to bounds
            if let superview = wv.superview {
                let existing = superview.constraints.filter {
                    $0.firstItem === wv || $0.secondItem === wv
                }
                NSLayoutConstraint.deactivate(existing)
                wv.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    wv.topAnchor.constraint(equalTo: superview.topAnchor),
                    wv.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    wv.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    wv.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                ])
                superview.layoutIfNeeded()
            }

            wv.navigationDelegate = self
            wv.uiDelegate = self
            self.injectEnhancements(into: wv)
            self.mountTabBar(on: rootVC)
            self.mountBackButton(on: rootVC)
            self.mountFloatButtons(on: rootVC)
            self.addEdgeSwipe(to: wv)
            // Restore now in case page already finished loading before delegate was set
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                self.restoreFromUserDefaults(in: wv)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: CSS + JS injections
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private func injectEnhancements(into wv: WKWebView) {
        if !messageHandlerAdded {
            wv.configuration.userContentController.add(WeakMsgHandler(self), name: "nativeUI")
            messageHandlerAdded = true
        }

        let js = """
        (function() {
            if (window.__lu_init) return;
            window.__lu_init = true;

            // ── CSS ─────────────────────────────────────────────────────────
            var s = document.createElement('style');
            s.id = 'lu-ni';
            s.textContent = `
                /* Hide web bottom nav */
                .bottom-nav { display: none !important; }

                /* Content padding for native tab bar */
                #mainContent { padding-bottom: calc(env(safe-area-inset-bottom) + 88px) !important; }

                /* 1. Hide ENTIRE topbar — buttons will be moved to body */
                .topbar { display: none !important; }

                /* FIX 1: Remove any inherited top gap on the flex container */
                .main { padding-top: 0 !important; }

                /* Push content down inside each section (not a bar — just space within the scroll) */
                .view { padding-top: calc(env(safe-area-inset-top) + 12px) !important; }

                /* FIX 2: Large iOS-Settings-style glass buttons */
                .topbar-glass-btn {
                    width: 52px !important;
                    height: 52px !important;
                    border-radius: 50% !important;
                    font-size: 20px !important;
                }

                /* Override the detail-panel topbar-padding (was topbar 56px + safe) */
                @media (max-width: 768px) {
                    #detailPanel { padding-top: calc(env(safe-area-inset-top) + 12px) !important; }
                }

                /* ── Fix scroll-selection: remove tap flash, prevent text selection ── */
                * { -webkit-tap-highlight-color: transparent !important; }
                body, .mat-row, .per-header, .elec-opt, .bn-item, .stat-box,
                button, a, label, [onclick], .malla-acc-header, .perfil-hub-card,
                .cfg-card, .card, .stat-card, .toggle-row, .sal-card, .por-card,
                .li-card, .tl-item, .copy-btn, .small-btn, .change-btn, .nota-btn {
                    -webkit-user-select: none !important;
                    user-select: none !important;
                    -webkit-touch-callout: none !important;
                }
                input, textarea, .nota-inp, .cfg-inp, .search-inp {
                    -webkit-user-select: auto !important;
                    user-select: auto !important;
                }
                /* pan-y lets the browser scroll without triggering click on items */
                #mainContent { touch-action: pan-y !important; -webkit-overflow-scrolling: touch !important; }
                .mat-row, .elec-opt, .per-header, .malla-acc-header { touch-action: manipulation !important; }
                /* Allow horizontal swipe on theme selector (override parent pan-y) */
                .theme-selector { touch-action: none !important; }

                /* ── Disable :hover on touch-only devices (prevents "marking" while scrolling) ── */
                @media (hover: none) and (pointer: coarse) {
                    .mat-row:hover {
                        border-color: var(--border) !important;
                        border-left-color: transparent !important;
                        background: var(--bg2) !important;
                        transform: none !important;
                    }
                    .mat-row.selected:hover {
                        border-color: var(--unad-blue) !important;
                        border-left-color: var(--unad-gold) !important;
                        background: rgba(0,70,173,0.04) !important;
                        transform: translateX(2px) !important;
                    }
                    .per-header:hover,
                    .malla-acc-header:hover {
                        border-color: var(--border) !important;
                    }
                    .perfil-hub-card:hover {
                        border-color: var(--border) !important;
                        box-shadow: var(--shadow) !important;
                    }
                    .li-card:hover,
                    .sal-card:hover {
                        border-color: var(--border) !important;
                    }
                    .nav-item:hover {
                        background: transparent !important;
                        color: rgba(255,255,255,0.45) !important;
                    }
                    .nota-btn:hover {
                        border-color: var(--border2) !important;
                        color: var(--text2) !important;
                        background: var(--bg3) !important;
                    }
                    .copy-btn:hover,
                    .small-btn:hover,
                    .change-btn:hover {
                        border-color: var(--border) !important;
                        color: var(--text2) !important;
                    }
                    .elec-opt:hover .elec-name {
                        color: var(--text2) !important;
                    }
                    .cfg-gear-btn:hover {
                        background: rgba(255,255,255,0.04) !important;
                        border-color: rgba(255,255,255,0.1) !important;
                    }
                }

                /* Prevent active state flash during scroll — longer delay */
                .mat-row:active, .per-header:active, .elec-opt:active,
                .malla-acc-header:active, .perfil-hub-card:active,
                .sal-card:active, .por-card:active, .li-card:active {
                    transition-delay: 180ms !important;
                }

                /* ── Panel slide animation ── */
                #detailPanel { will-change: transform; }

                /* ── Suppress viewFadeIn during custom push/pop transitions ── */
                .view.lu-anim-skip { animation: none !important; transition: none !important; }

                /* 10. Confirm button styles */
                .nota-confirm-btn {
                    background: rgba(0,70,173,0.12) !important;
                    color: #0046AD !important;
                    border-color: rgba(0,70,173,0.25) !important;
                    font-size: 17px !important;
                    font-weight: 700 !important;
                    flex-shrink: 0;
                }
                body.dark .nota-confirm-btn {
                    background: rgba(0,157,196,0.15) !important;
                    color: #009DC4 !important;
                    border-color: rgba(0,157,196,0.25) !important;
                }
            `;
            (document.head || document.documentElement).appendChild(s);

            // ── 1. Hide original web buttons (replaced by native SwiftUI buttons) ──
            function hideWebButtons() {
                var origSv = document.getElementById('glassSaveBtn');
                var origRs = document.getElementById('glassResetBtn');
                if (origSv) origSv.style.display = 'none';
                if (origRs) origRs.style.display = 'none';
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', hideWebButtons)
                : hideWebButtons();

            // ── 2. Gradients — update color dynamically with dark mode ──────
            function getGradientColor(isDark) {
                return isDark
                    ? 'rgba(13,20,32,0.60)'
                    : 'rgba(240,244,250,0.55)';
            }
            function updateGradients() {
                var isDark = document.body.classList.contains('dark');
                var topF = document.getElementById('lu-top-fade');
                var botF = document.getElementById('lu-bottom-fade');
                var c = getGradientColor(isDark);
                var bgC = isDark ? 'rgba(13,20,32,1)' : 'rgba(240,244,250,1)';
                if (topF) topF.style.background = 'linear-gradient(to bottom, '+c+' 0%, transparent 100%)';
                if (botF) botF.style.background = 'linear-gradient(to bottom, transparent, '+bgC+')';
            }
            function addGradients() {
                if (document.getElementById('lu-top-fade')) return;
                var isDark = document.body.classList.contains('dark');
                var c = getGradientColor(isDark);
                var bgC = isDark ? 'rgba(13,20,32,1)' : 'rgba(240,244,250,1)';

                var topF = document.createElement('div');
                topF.id = 'lu-top-fade';
                topF.style.cssText = [
                    'position:fixed','top:0','left:0','right:0',
                    'height:calc(env(safe-area-inset-top) + 20px)',
                    'background:linear-gradient(to bottom, '+c+' 0%, transparent 100%)',
                    'pointer-events:none','z-index:500'
                ].join(';');
                document.body.appendChild(topF);

                var botF = document.createElement('div');
                botF.id = 'lu-bottom-fade';
                botF.style.cssText = [
                    'position:fixed','left:0','right:0','bottom:0',
                    'height:calc(env(safe-area-inset-bottom) + 100px)',
                    'background:linear-gradient(to bottom, transparent, '+bgC+')',
                    'pointer-events:none','z-index:100'
                ].join(';');
                document.body.appendChild(botF);

                // Watch body.dark changes → update gradients + buttons
                new MutationObserver(function(mutations) {
                    mutations.forEach(function(m) {
                        if (m.attributeName === 'class') updateGradients();
                    });
                }).observe(document.body, { attributes: true });
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', addGradients)
                : addGradients();

            // ── 3. Patch saveData/resetChanges to drive native buttons ──────
            function patchSaveReset() {
                if (window.__lu_sr_patched) return;
                if (typeof saveData !== 'function' || typeof resetChanges !== 'function') {
                    setTimeout(patchSaveReset, 250); return;
                }
                window.__lu_sr_patched = true;
                var _save  = window.saveData;
                var _reset = window.resetChanges;

                window.saveData = function() {
                    _save.apply(this, arguments);
                    // Backup to native UserDefaults — also triggers save flash on native button
                    try {
                        var raw = localStorage.getItem('leanup_v4');
                        if (raw) window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'save', data: raw });
                    } catch(e) {}
                };

                window.resetChanges = function() {
                    _reset.apply(this, arguments);
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchSaveReset)
                : patchSaveReset();

            // ── 3b. Patch markUnsaved → notify native reset button ──────────
            function patchMarkUnsaved() {
                if (window.__lu_mu_patched) return;
                if (typeof markUnsaved !== 'function') { setTimeout(patchMarkUnsaved, 250); return; }
                window.__lu_mu_patched = true;
                var _mu = window.markUnsaved;
                window.markUnsaved = function() {
                    _mu.apply(this, arguments);
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'markUnsaved' });
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchMarkUnsaved)
                : patchMarkUnsaved();

            // ── 3c. Auto-save — prevents data loss on force-quit ────────────
            // Saves to localStorage AND to native UserDefaults via message.
            // UserDefaults survives force-quit; localStorage may not always.
            function autoSave() {
                try {
                    if (typeof materias === 'undefined') return;
                    var notas = {};
                    materias.forEach(function(m) { if (m.nota !== null) notas[m.id] = m.nota; });
                    var json = JSON.stringify({
                        notas: notas,
                        electivosSeleccionados: typeof electivosSeleccionados !== 'undefined'
                            ? electivosSeleccionados : {},
                        electivosNotas: typeof electivosNotas !== 'undefined'
                            ? electivosNotas : {},
                        username: typeof username !== 'undefined' ? username : '',
                        darkMode: typeof darkMode !== 'undefined' ? darkMode : false,
                        themeMode: typeof themeMode !== 'undefined' ? themeMode : 'light'
                    });
                    localStorage.setItem('leanup_v4', json);
                    // Backup to native UserDefaults — survives force-quit
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'save', data: json });
                } catch(e) {}
            }
            document.addEventListener('visibilitychange', function() {
                if (document.visibilityState === 'hidden') autoSave();
            });
            window.addEventListener('pagehide', autoSave, { capture: true });

            // ── 4/10. Add ✓ confirm button — uses Enter simulation ─────────
            // Works for both regular (saveNota) AND elective (saveElecNota)
            // because it dispatches Enter on the input's own onkeydown handler.
            function addConfirm(widget) {
                if (widget.dataset.lu) return;
                widget.dataset.lu = '1';
                var inp = widget.querySelector('.nota-inp');
                if (!inp) return;
                var btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'nota-btn nota-confirm-btn';
                btn.setAttribute('tabindex', '-1');
                btn.textContent = '\\u2713';
                btn.addEventListener('pointerdown', function(e) {
                    e.preventDefault(); e.stopPropagation();
                    // Simulate Enter → triggers whatever save fn is in onkeydown
                    inp.dispatchEvent(new KeyboardEvent('keydown', {
                        key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
                        bubbles: true, cancelable: true
                    }));
                });
                widget.appendChild(btn);
            }
            var mo = new MutationObserver(function() {
                document.querySelectorAll('.nota-widget').forEach(addConfirm);
            });
            mo.observe(document.documentElement, { childList: true, subtree: true });
            document.querySelectorAll('.nota-widget').forEach(addConfirm);

            // ── 9. Panel open/close — iOS slide animation + native back btn ──
            function patchPanel() {
                if (window.__lu_panel) return;
                if (typeof mobileOpenPanel !== 'function') {
                    setTimeout(patchPanel, 250); return;
                }
                window.__lu_panel = true;
                var _open  = window.mobileOpenPanel;
                var _close = window.mobileClosePanelOrBack;

                window.mobileOpenPanel = function() {
                    // Prep for slide-in BEFORE the class is added
                    var dp = document.getElementById('detailPanel');
                    if (dp) { dp.style.transform = 'translateX(100%)'; dp.style.transition = 'none'; }
                    _open.apply(this, arguments);
                    // Animate in on the next two frames (ensures class is applied)
                    if (dp) {
                        requestAnimationFrame(function() {
                            requestAnimationFrame(function() {
                                dp.style.transition = 'transform 0.30s cubic-bezier(0.32,0.72,0,1)';
                                dp.style.transform  = 'translateX(0)';
                                setTimeout(function() { dp.style.transition = ''; dp.style.transform = ''; }, 320);
                            });
                        });
                    }
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'panelOpen' });
                };

                window.mobileClosePanelOrBack = function() {
                    var dp = document.getElementById('detailPanel');
                    if (dp && dp.classList.contains('mobile-open')) {
                        // Apple-style dismiss: 0.40s with Apple back-gesture curve
                        dp.style.transition = 'transform 0.40s cubic-bezier(0.32,0.72,0,1)';
                        dp.style.transform  = 'translateX(100%)';
                        var a = arguments;
                        setTimeout(function() {
                            dp.style.transition = '';
                            dp.style.transform  = '';
                            _close.apply(window, a);
                        }, 420);
                        window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'panelClose' });
                    } else {
                        _close.apply(this, arguments);
                    }
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchPanel)
                : patchPanel();

            // ── 9b. Patch showView — Apple push/pop with parallax via position:fixed ──
            // Both views use position:fixed during animation so they can overlap visually.
            // animation:none inline prevents CSS fadeSlideIn from re-triggering on cleanup.
            function patchShowView() {
                if (window.__lu_sv_patched) return;
                if (typeof showView !== 'function') { setTimeout(patchShowView, 250); return; }
                window.__lu_sv_patched = true;
                var _sv = window.showView;
                var profileSubViews = ['profesional', 'salida', 'portafolio'];
                var profileSubViewIds = ['view-profesional', 'view-salida', 'view-portafolio'];
                var _isSubViewActive = false;
                var _animating = false;

                function getBg() {
                    return document.body.classList.contains('dark') ? '#0d1420' : '#F0F4FA';
                }
                // Apple push/pop curve (matches UINavigationController)
                var appleCurve = 'cubic-bezier(0.28,0.11,0.32,1)';
                var pushDur = '0.45s';
                var popDur  = '0.42s';
                function fixedBase(bg) {
                    // Include .content's mobile padding (16px 14px) so layout doesn't shift
                    return 'display:block;position:fixed;top:0;left:0;right:0;bottom:0;overflow-y:auto;background:' + bg + ';animation:none;padding:16px 14px;';
                }
                // Dimming overlay on hub during push (Apple uses ~8% black overlay on the outgoing view)
                function addDim(el) {
                    var d = document.createElement('div');
                    d.className = 'lu-push-dim';
                    d.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0);transition:background ' + pushDur + ' ' + appleCurve + ';pointer-events:none;z-index:999;';
                    el.appendChild(d);
                    requestAnimationFrame(function(){ d.style.background = 'rgba(0,0,0,0.08)'; });
                    return d;
                }
                // Edge shadow on the incoming view (Apple nav transition has left-edge shadow)
                function addEdgeShadow(el) {
                    var s = document.createElement('div');
                    s.className = 'lu-edge-shadow';
                    s.style.cssText = 'position:absolute;top:0;left:-20px;width:20px;bottom:0;background:linear-gradient(to right,transparent,rgba(0,0,0,0.12));pointer-events:none;z-index:1000;';
                    el.appendChild(s);
                    return s;
                }
                function cleanupExtras() {
                    document.querySelectorAll('.lu-push-dim,.lu-edge-shadow').forEach(function(e){ e.remove(); });
                }

                window.showView = function(id, el) {
                    // Clear animation-skip class from previous transitions
                    document.querySelectorAll('.view.lu-anim-skip').forEach(function(v) { v.classList.remove('lu-anim-skip'); });

                    var isSubView = profileSubViews.indexOf(id) >= 0;
                    var goingToHub = (id === 'perfil-hub');

                    if (isSubView && !window.__lu_noSubViewAnim) {
                        // PUSH: new view slides in from right, hub parallax to left
                        if (_animating) return;
                        _animating = true;
                        var hubView = document.getElementById('view-perfil-hub');
                        var newView = document.getElementById('view-' + id);

                        if (newView && hubView) {
                            var bg = getBg();
                            var fb = fixedBase(bg);
                            // CRITICAL: Set BOTH views fixed BEFORE _sv() changes classes
                            // This prevents hub from flashing when it loses .active
                            hubView.style.cssText = fb + 'z-index:201;transform:translateX(0)';
                            newView.style.cssText = fb + 'z-index:202;transform:translateX(100%)';
                            _sv.apply(this, [id, el]);
                            addEdgeShadow(newView);
                            var dimEl = addDim(hubView);
                            void newView.offsetWidth;
                            var trans = 'transform ' + pushDur + ' ' + appleCurve;
                            newView.style.transition = trans;
                            newView.style.transform  = 'translateX(0)';
                            hubView.style.transition = trans;
                            hubView.style.transform  = 'translateX(-33%)';
                            setTimeout(function() {
                                cleanupExtras();
                                // Use lu-anim-skip class to prevent fadeSlideIn re-trigger
                                // Class will be removed on next showView() call
                                newView.classList.add('lu-anim-skip');
                                newView.style.cssText = '';
                                hubView.style.cssText = '';
                                _animating = false;
                            }, 470);
                        } else {
                            _sv.apply(this, [id, el]);
                            _animating = false;
                        }
                        _isSubViewActive = true;
                        window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'subViewOpen' });

                    } else if (isSubView) {
                        _sv.apply(this, arguments);
                        _isSubViewActive = true;

                    } else if (_isSubViewActive && !window.__lu_noSubViewAnim && goingToHub) {
                        // POP: current sub-view slides out right, hub parallax slides in from left
                        var curView = document.querySelector('.view.active');
                        var hubView2 = document.getElementById('view-perfil-hub');
                        _isSubViewActive = false;
                        if (curView && hubView2 && curView !== hubView2
                                && profileSubViewIds.indexOf(curView.id) >= 0) {
                            if (_animating) return;
                            _animating = true;
                            var bg2 = getBg();
                            var fb2 = fixedBase(bg2);
                            curView.style.cssText  = fb2 + 'z-index:202;transform:translateX(0)';
                            hubView2.style.cssText = fb2 + 'z-index:201;transform:translateX(-33%)';
                            addEdgeShadow(curView);
                            var dimEl2 = addDim(hubView2);
                            if (dimEl2) { dimEl2.style.background = 'rgba(0,0,0,0.08)'; dimEl2.style.transition = 'none'; }
                            void curView.offsetWidth;
                            var trans2 = 'transform ' + popDur + ' ' + appleCurve;
                            curView.style.transition  = trans2;
                            curView.style.transform   = 'translateX(100%)';
                            hubView2.style.transition = trans2;
                            hubView2.style.transform  = 'translateX(0)';
                            if (dimEl2) { requestAnimationFrame(function(){ dimEl2.style.transition = 'background ' + popDur + ' ' + appleCurve; dimEl2.style.background = 'rgba(0,0,0,0)'; }); }
                            var args = arguments;
                            setTimeout(function() {
                                cleanupExtras();
                                // Use lu-anim-skip class instead of fragile inline animation:none
                                hubView2.classList.add('lu-anim-skip');
                                _sv.apply(window, args);
                                curView.style.cssText = '';
                                hubView2.style.cssText = '';
                                _animating = false;
                            }, 440);
                        } else {
                            _sv.apply(this, arguments);
                        }
                        window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'subViewClose' });

                    } else {
                        _isSubViewActive = false;
                        _sv.apply(this, arguments);
                        if (!isSubView) {
                            window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'subViewClose' });
                        }
                    }
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchShowView)
                : patchShowView();

            // ── 9c. Patch showViewGear — close sub-view state ───────────────
            function patchShowViewGear() {
                if (window.__lu_svg_patched) return;
                if (typeof showViewGear !== 'function') { setTimeout(patchShowViewGear, 250); return; }
                window.__lu_svg_patched = true;
                var _svg = window.showViewGear;
                window.showViewGear = function() {
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'subViewClose' });
                    _svg.apply(this, arguments);
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchShowViewGear)
                : patchShowViewGear();

            // ── 6. Haptic feedback on web elements ──────────────────────────
            function h(s) {
                window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'haptic', style: s });
            }
            function addWebHaptics() {
                // Course rows — light haptic
                document.querySelectorAll('.mat-row').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('light'); }, true); }
                });
                // Elective option rows — light haptic
                document.querySelectorAll('.elec-opt, .elec-row').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('light'); }, true); }
                });
                // Accordion headers (all sections) — very light select haptic
                document.querySelectorAll('.per-header, .malla-acc-header').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('select'); }, true); }
                });
                // Edit/clear nota buttons (small-btn) — light haptic
                document.querySelectorAll('.small-btn').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('light'); }, true); }
                });
                // Nota confirm button — light haptic
                document.querySelectorAll('.nota-confirm-btn').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('pointerdown', function() { h('light'); }, true); }
                });
                // Nota +/- buttons — very light select haptic
                document.querySelectorAll('.nota-btn:not(.nota-confirm-btn)').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('select'); }, true); }
                });
                // Dark mode toggle
                var dt = document.getElementById('darkToggle');
                if (dt && !dt.dataset.luh) { dt.dataset.luh='1';
                    dt.addEventListener('change', function() { h('soft'); }, true); }
                // WhatsApp / email links
                document.querySelectorAll('a[href*="wa.me"], a[href*="whatsapp"], a[href*="mailto"]').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('medium'); }, true); }
                });
                // Copy / prompt buttons
                document.querySelectorAll('[onclick*="copy"], [onclick*="Copy"], .copy-btn, [onclick*="prompt"]').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('light'); }, true); }
                });
                // Perfil hub cards
                document.querySelectorAll('.perfil-hub-card').forEach(function(el) {
                    if (!el.dataset.luh) { el.dataset.luh='1';
                        el.addEventListener('click', function() { h('medium'); }, true); }
                });
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', addWebHaptics)
                : addWebHaptics();
            // Re-apply when new content renders (renderMalla, etc.)
            new MutationObserver(function() { addWebHaptics(); })
                .observe(document.documentElement, { childList: true, subtree: true });

            // ── 5. Scroll → native tab-bar collapse ─────────────────────────
            function setupScroll() {
                var mc = document.getElementById('mainContent');
                if (!mc) { setTimeout(setupScroll, 300); return; }
                mc.addEventListener('scroll', function() {
                    var delta = this.scrollTop - (this.__lt || 0);
                    this.__lt = this.scrollTop;
                    if (Math.abs(delta) > 5) {
                        window.webkit?.messageHandlers?.nativeUI?.postMessage({
                            event: 'scroll', delta: delta, top: this.scrollTop
                        });
                    }
                }, { passive: true });
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', setupScroll)
                : setupScroll();

            // ── 8a. Patch setTheme — add haptic on theme change ────────────
            function patchSetTheme() {
                if (window.__lu_st_patched) return;
                if (typeof setTheme !== 'function') { setTimeout(patchSetTheme, 250); return; }
                window.__lu_st_patched = true;
                var _st = window.setTheme;
                window.setTheme = function(mode) {
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'haptic', style: 'light' });
                    _st.apply(this, arguments);
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchSetTheme)
                : patchSetTheme();

            // ── 8. Dark mode sync → native UI ───────────────────────────────
            function patchDark() {
                if (window.__lu_dark) return;
                if (typeof toggleDark !== 'function') { setTimeout(patchDark, 250); return; }
                window.__lu_dark = true;
                // Sync initial theme state to native
                try {
                    var saved = localStorage.getItem('leanup_v4');
                    if (saved) {
                        var d = JSON.parse(saved);
                        var mode = d.themeMode || (d.darkMode ? 'dark' : 'light');
                        if (mode === 'system') {
                            window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'darkMode', on: false, mode: 'system' });
                        } else if (mode === 'dark') {
                            window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'darkMode', on: true, mode: 'dark' });
                        }
                    }
                } catch(e) {}
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchDark)
                : patchDark();
        })();
        """

        wv.evaluateJavaScript(js)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            wv.evaluateJavaScript(js)
        }
    }

    // MARK: Mount tab bar
    private func mountTabBar(on rootVC: UIViewController) {
        guard tabBarVC == nil, #available(iOS 15.0, *) else { return }
        let host = UIHostingController(
            rootView: TabBarHost { [weak self] tabId in self?.handleTab(tabId) }
        )
        configure(overlayVC: host)
        rootVC.addChild(host)
        rootVC.view.addSubview(host.view)
        host.didMove(toParent: rootVC)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        let hc = host.view.heightAnchor.constraint(equalToConstant: 105)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: rootVC.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: rootVC.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: rootVC.view.bottomAnchor),
            hc,
        ])
        tabBarHeightConstraint = hc
        tabBarVC = host
    }

    // MARK: Mount back button
    private func mountBackButton(on rootVC: UIViewController) {
        guard backButtonVC == nil, #available(iOS 15.0, *) else { return }
        let host = UIHostingController(
            rootView: GlassBackButton { [weak self] in
                guard let self else { return }
                if self.isPanelOpen {
                    self.capacitorWebView?.evaluateJavaScript("mobileClosePanelOrBack()")
                } else if self.isProfileSubViewOpen {
                    self.capacitorWebView?.evaluateJavaScript("showView('perfil-hub',null)")
                    self.isProfileSubViewOpen = false
                }
            }
        )
        configure(overlayVC: host)
        host.view.alpha = 0
        host.view.isHidden = true

        rootVC.addChild(host)
        rootVC.view.addSubview(host.view)
        host.didMove(toParent: rootVC)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(
                equalTo: rootVC.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            host.view.leadingAnchor.constraint(
                equalTo: rootVC.view.leadingAnchor, constant: 16),
            host.view.widthAnchor.constraint(equalToConstant: 44),
            host.view.heightAnchor.constraint(equalToConstant: 44),
        ])
        backButtonVC = host
    }

    // MARK: Mount float buttons (save + reset) — top-right, native glass
    private func mountFloatButtons(on rootVC: UIViewController) {
        guard floatButtonsVC == nil, #available(iOS 15.0, *) else { return }
        let state = floatButtonsState
        let host = UIHostingController(
            rootView: GlassFloatButtons(state: state) { [weak self] in
                self?.capacitorWebView?.evaluateJavaScript("saveData()")
            } onReset: { [weak self] in
                self?.capacitorWebView?.evaluateJavaScript("resetChanges()")
            }
        )
        configure(overlayVC: host)
        rootVC.addChild(host)
        rootVC.view.addSubview(host.view)
        host.didMove(toParent: rootVC)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(
                equalTo: rootVC.view.safeAreaLayoutGuide.topAnchor, constant: 8),
            host.view.trailingAnchor.constraint(
                equalTo: rootVC.view.trailingAnchor, constant: -16),
            host.view.widthAnchor.constraint(equalToConstant: 104),  // 48+8+48
            host.view.heightAnchor.constraint(equalToConstant: 48),
        ])
        floatButtonsVC = host
    }

    private func configure(overlayVC: UIViewController) {
        overlayVC.view.backgroundColor = .clear
        overlayVC.view.isOpaque = false
    }

    // MARK: Back button animation — stable scale + opacity + spring
    private var backButtonAnimWorkItem: DispatchWorkItem?

    private func animateBackButton(visible: Bool) {
        guard let bvc = backButtonVC else { return }
        // Cancel any in-flight animation to prevent stacking
        backButtonAnimWorkItem?.cancel()
        bvc.view.layer.removeAllAnimations()

        let work = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            if visible {
                bvc.view.isHidden = false
                bvc.view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                bvc.view.alpha = 0
            }
            UIView.animate(
                withDuration: visible ? 0.32 : 0.2, delay: 0,
                usingSpringWithDamping: visible ? 0.85 : 0.95,
                initialSpringVelocity: 0
            ) {
                bvc.view.alpha = visible ? 1 : 0
                bvc.view.transform = visible
                    ? .identity
                    : CGAffineTransform(scaleX: 0.5, y: 0.5)
            } completion: { _ in
                if !visible {
                    bvc.view.isHidden = true
                    bvc.view.transform = .identity
                }
            }
        }
        backButtonAnimWorkItem = work
        DispatchQueue.main.async(execute: work)
    }

    // MARK: WKScriptMessageHandler
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "nativeUI",
              let body = message.body as? [String: Any],
              let event = body["event"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch event {
            case "scroll":
                let delta = body["delta"] as? CGFloat ?? 0
                let top   = body["top"]   as? CGFloat ?? 0
                self.handleScroll(delta: delta, scrollTop: top)
            case "panelOpen":  self.isPanelOpen = true
            case "panelClose": self.isPanelOpen = false
            case "darkMode":
                let mode = body["mode"] as? String ?? ""
                if mode == "system" {
                    self.window?.overrideUserInterfaceStyle = .unspecified
                } else {
                    let on = body["on"] as? Bool ?? false
                    self.window?.overrideUserInterfaceStyle = on ? .dark : .light
                }
            case "save":
                // Backup web data to UserDefaults — survives force-quit
                if let data = body["data"] as? String {
                    let b64 = Data(data.utf8).base64EncodedString()
                    UserDefaults.standard.set(b64, forKey: "leanup_v4_backup")
                }
                // Flash save button green, disable reset
                self.floatButtonsState.saveFlash    = true
                self.floatButtonsState.resetEnabled = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.floatButtonsState.saveFlash = false
                }
            case "markUnsaved":
                self.floatButtonsState.resetEnabled = true
            case "subViewOpen":
                self.isProfileSubViewOpen = true
            case "subViewClose":
                self.isProfileSubViewOpen = false
            case "haptic":
                self.triggerHaptic(style: body["style"] as? String ?? "medium")
            default: break
            }
        }
    }

    // MARK: Scroll collapse (disabled — pill stays fixed)
    private func handleScroll(delta: CGFloat, scrollTop: CGFloat) { }

    private func setTabBarHeight(_ h: CGFloat) {
        guard let c = tabBarHeightConstraint, let r = rootVC else { return }
        UIView.animate(
            withDuration: 0.38, delay: 0,
            usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4
        ) {
            c.constant = h
            r.view.layoutIfNeeded()
        }
    }

    // MARK: Tab navigation
    private func handleTab(_ id: String) {
        // Dismiss keyboard if a web input is focused (e.g., nota editing)
        capacitorWebView?.evaluateJavaScript("document.activeElement?.blur()")

        // Close web panel if open (remove mobile-open class + body.panel-open)
        if isPanelOpen {
            isPanelOpen = false
            capacitorWebView?.evaluateJavaScript("""
                (function() {
                    var dp = document.getElementById('detailPanel');
                    if (dp) { dp.classList.remove('mobile-open'); dp.style.transition=''; dp.style.transform=''; }
                    document.body.classList.remove('panel-open');
                    document.querySelectorAll('.mat-row').forEach(function(r){ r.classList.remove('selected'); });
                })();
            """)
        }

        // Close profile sub-view state
        if isProfileSubViewOpen { isProfileSubViewOpen = false }

        webGo(id)
    }

    private func webGo(_ id: String) {
        let js: String
        switch id {
        case "dashboard": js = "showView('dashboard',null);"
        case "malla":     js = "showView('malla',null);"
        case "perfil":    js = "showView('perfil-hub',null);"
        case "config":    js = "showViewGear();"
        default:          return
        }
        capacitorWebView?.evaluateJavaScript(js)
    }

    // MARK: WKUIDelegate — native confirm() dialog so resetChanges() works
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(.init(title: "Reiniciar", style: .destructive) { _ in completionHandler(true) })
        rootVC?.present(alert, animated: true)
    }

    // MARK: WKNavigationDelegate — intercept mailto: and tel: URLs
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           ["mailto", "tel", "sms"].contains(scheme) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: WKNavigationDelegate — restore data AFTER page finishes loading
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasRestoredData else { return }
        hasRestoredData = true
        restoreFromUserDefaults(in: webView)
        // Re-inject enhancements (page may have reloaded)
        injectEnhancements(into: webView)
    }

    // MARK: Native data backup / restore
    /// Pushes UserDefaults backup into localStorage so loadData() picks it up
    /// even after localStorage is wiped by iOS. Retries until loadData exists.
    private func restoreFromUserDefaults(in wv: WKWebView) {
        guard let b64 = UserDefaults.standard.string(forKey: "leanup_v4_backup") else { return }
        let js = """
        (function restore() {
            try {
                if (window.__lu_restored) return;
                if (typeof loadData !== 'function') {
                    setTimeout(restore, 150);
                    return;
                }
                window.__lu_restored = true;
                // Correct UTF-8 decode: atob() returns Latin-1 bytes, TextDecoder converts to proper Unicode
                // Without this, accented chars in electiva group names (ó, é, etc.) become garbled
                // and electivosSeleccionados/electivosNotas keys don't match on restore.
                var bytes = Uint8Array.from(atob('\(b64)'), function(c) { return c.charCodeAt(0); });
                var json = new TextDecoder('utf-8').decode(bytes);
                localStorage.setItem('leanup_v4', json);
                loadData();
                if (typeof renderMalla       === 'function') renderMalla();
                if (typeof renderProfesional === 'function') renderProfesional();
                if (typeof renderSalida      === 'function') renderSalida();
                if (typeof renderPortafolio  === 'function') renderPortafolio();
                if (typeof updateAll         === 'function') updateAll();
            } catch(e) {}
        })();
        """
        wv.evaluateJavaScript(js)
    }

    // MARK: Haptic feedback
    private func triggerHaptic(style: String) {
        switch style {
        case "light":   UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "rigid":   UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case "soft":    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case "select":  UISelectionFeedbackGenerator().selectionChanged()
        case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
        default:        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: Edge swipe to dismiss panel (iOS back-gesture feel)
    private func addEdgeSwipe(to wv: WKWebView) {
        wv.allowsBackForwardNavigationGestures = false
        let gr = UIScreenEdgePanGestureRecognizer(
            target: self, action: #selector(handleEdgeSwipe(_:)))
        gr.edges = .left
        wv.addGestureRecognizer(gr)
        edgePanGR = gr
    }

    @objc private func handleEdgeSwipe(_ gr: UIScreenEdgePanGestureRecognizer) {
        guard let wv = capacitorWebView else { return }
        let tx      = max(0, gr.translation(in: gr.view).x)
        let vx      = gr.velocity(in: gr.view).x
        let screenW = UIScreen.main.bounds.width

        if isPanelOpen {
            // ── Panel dismiss (materia detail) ──
            switch gr.state {
            case .changed:
                wv.evaluateJavaScript("""
                    var dp = document.getElementById('detailPanel');
                    if (dp && dp.classList.contains('mobile-open')) {
                        dp.style.transition = 'none';
                        dp.style.transform  = 'translateX(\(tx)px)';
                    }
                """)
            case .ended:
                if vx > 400 || tx > screenW * 0.4 {
                    let dur = max(0.10, Double(screenW - tx) / Double(max(vx, 500)))
                    wv.evaluateJavaScript("""
                        (function() {
                            var dp = document.getElementById('detailPanel');
                            if (!dp) return;
                            dp.style.transition = 'transform \(String(format:"%.2f", dur))s cubic-bezier(0.32,0.72,0,1)';
                            dp.style.transform  = 'translateX(100%)';
                            setTimeout(function() {
                                dp.style.transition = ''; dp.style.transform = '';
                                dp.classList.remove('mobile-open');
                                document.body.classList.remove('panel-open');
                                document.querySelectorAll('.mat-row').forEach(function(r) { r.classList.remove('selected'); });
                                window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'panelClose' });
                            }, \(Int(dur * 1000)));
                        })();
                    """)
                } else {
                    snapPanelBack(wv: wv)
                }
            case .cancelled, .failed:
                snapPanelBack(wv: wv)
            default: break
            }

        } else if isProfileSubViewOpen {
            // ── Profile sub-view dismiss — both views fixed so they can overlay ──
            switch gr.state {
            case .began:
                // Set up fixed positioning on both views at gesture start (not every frame)
                // Hub MUST have display:block — it has no .active class (display:none from CSS)
                wv.evaluateJavaScript("""
                    (function() {
                        var v = document.querySelector('.view.active');
                        var hub = document.getElementById('view-perfil-hub');
                        if (!v || v === hub) return;
                        var isDark = document.body.classList.contains('dark');
                        var bg = isDark ? '#0d1420' : '#F0F4FA';
                        var base = 'display:block;position:fixed;top:0;left:0;right:0;bottom:0;overflow-y:auto;background:' + bg + ';animation:none;transition:none;padding:16px 14px;';
                        v.style.cssText = base + 'z-index:202;transform:translateX(0)';
                        hub.style.cssText = base + 'z-index:201;transform:translateX(-33%)';
                    })();
                """)
            case .changed:
                wv.evaluateJavaScript("""
                    (function() {
                        var v = document.querySelector('.view.active');
                        var hub = document.getElementById('view-perfil-hub');
                        if (!v || v === hub) return;
                        var progress = Math.min(1, \(tx) / \(screenW));
                        v.style.transform = 'translateX(\(tx)px)';
                        hub.style.transform = 'translateX(' + (-33 * (1 - progress)) + '%)';
                    })();
                """)
            case .ended:
                if vx > 400 || tx > screenW * 0.4 {
                    let dur = max(0.10, Double(screenW - tx) / Double(max(vx, 500)))
                    wv.evaluateJavaScript("""
                        (function() {
                            var v = document.querySelector('.view.active');
                            var hub = document.getElementById('view-perfil-hub');
                            if (!v || v === hub) return;
                            var d = '\(String(format:"%.2f", dur))s';
                            var c = 'cubic-bezier(0.28,0.11,0.32,1)';
                            v.style.transition = 'transform ' + d + ' ' + c;
                            v.style.transform = 'translateX(100%)';
                            hub.style.transition = 'transform ' + d + ' ' + c;
                            hub.style.transform = 'translateX(0)';
                            document.querySelectorAll('.lu-push-dim,.lu-edge-shadow').forEach(function(e){ e.remove(); });
                            setTimeout(function() {
                                hub.classList.add('lu-anim-skip');
                                window.__lu_noSubViewAnim = true;
                                showView('perfil-hub', null);
                                window.__lu_noSubViewAnim = false;
                                v.style.cssText = '';
                                hub.style.cssText = '';
                                window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'subViewClose' });
                            }, \(Int(dur * 1000)));
                        })();
                    """)
                    isProfileSubViewOpen = false
                } else {
                    snapViewBack(wv: wv)
                }
            case .cancelled, .failed:
                snapViewBack(wv: wv)
            default: break
            }
        }
    }

    private func snapPanelBack(wv: WKWebView) {
        wv.evaluateJavaScript("""
            var dp = document.getElementById('detailPanel');
            if (dp) {
                dp.style.transition = 'transform 0.25s cubic-bezier(0.32,0.72,0,1)';
                dp.style.transform  = 'translateX(0)';
                setTimeout(function() { dp.style.transition = ''; dp.style.transform = ''; }, 280);
            }
        """)
    }

    private func snapViewBack(wv: WKWebView) {
        // Snap both fixed-positioned views back to their original positions
        wv.evaluateJavaScript("""
            (function() {
                var v = document.querySelector('.view.active');
                var hub = document.getElementById('view-perfil-hub');
                if (!v || v === hub) return;
                var d = '0.30s', c = 'cubic-bezier(0.28,0.11,0.32,1)';
                v.style.transition = 'transform ' + d + ' ' + c;
                v.style.transform = 'translateX(0)';
                hub.style.transition = 'transform ' + d + ' ' + c;
                hub.style.transform = 'translateX(-33%)';
                setTimeout(function() {
                    v.classList.add('lu-anim-skip');
                    v.style.cssText = '';
                    hub.style.cssText = '';
                }, 320);
            })();
        """)
    }

    // MARK: Helpers
    private func firstWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for sub in view.subviews {
            if let found = firstWebView(in: sub) { return found }
        }
        return nil
    }

    // MARK: Capacitor URL / Activity handling
    func application(
        _ app: UIApplication, open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        ApplicationDelegateProxy.shared.application(
            application, continue: userActivity,
            restorationHandler: restorationHandler)
    }
}
