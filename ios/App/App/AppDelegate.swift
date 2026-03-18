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
    @Namespace private var ns

    // Gesture state — single unified recognizer handles tap AND swipe
    @State private var draggedIndex: Int? = nil
    @State private var pressingTab: String? = nil
    @State private var gestureStartX: CGFloat? = nil
    @State private var isDragging = false

    @Environment(\.colorScheme) private var scheme

    private let dragThreshold: CGFloat = 8  // pt before a touch becomes a drag
    private let tabs: [LUTab] = [
        LUTab(id: "dashboard",   icon: "house.fill",            label: "Inicio"),
        LUTab(id: "malla",       icon: "list.bullet.clipboard", label: "Malla"),
        LUTab(id: "profesional", icon: "person.fill",           label: "Perfil"),
        LUTab(id: "more",        icon: "ellipsis",              label: "Más"),
    ]
    var onSelect: (String) -> Void

    private var shown: String {
        draggedIndex.map { tabs[$0].id } ?? active
    }

    // MARK: Body
    var body: some View {
        GeometryReader { geo in
            let totalW  = geo.size.width
            let tabW    = totalW / CGFloat(tabs.count)
            let innerPad: CGFloat = 10
            let bubbleW = (totalW - innerPad * 2) / CGFloat(tabs.count) - 8

            barView(bubbleW: bubbleW)
                // highPriorityGesture: takes over from any child Button taps
                // so we have one clean unified recognizer for the whole bar.
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in onDragChanged(v, tabW: tabW) }
                        .onEnded   { v in onDragEnded(v, tabW: tabW)   }
                )
        }
        .frame(height: 58)
        .padding(.horizontal, 16)
    }

    // MARK: Unified drag/tap handler — onChanged
    private func onDragChanged(_ v: DragGesture.Value, tabW: CGFloat) {
        // Record where the touch started
        if gestureStartX == nil { gestureStartX = v.location.x }

        let dx = v.location.x - (gestureStartX ?? v.location.x)

        // Promote to drag once threshold is exceeded
        if !isDragging && abs(dx) > dragThreshold {
            isDragging = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                pressingTab = nil   // clear press highlight when drag begins
            }
        }

        let idx = clamp(Int(v.location.x / tabW), in: 0..<tabs.count)

        if isDragging {
            // Dragging — show destination preview with haptic tick each step
            if draggedIndex != idx {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    draggedIndex = idx
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            // Still a press — highlight the touched tab
            let tabId = tabs[idx].id
            if pressingTab != tabId {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                    pressingTab = tabId
                }
            }
        }
    }

    // MARK: Unified drag/tap handler — onEnded
    private func onDragEnded(_ v: DragGesture.Value, tabW: CGFloat) {
        let startX = gestureStartX ?? v.location.x
        let dx     = abs(v.location.x - startX)

        // Reset tracking state
        gestureStartX = nil
        isDragging    = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            draggedIndex = nil
            pressingTab  = nil
        }

        if dx < dragThreshold {
            // It was a tap — use the START position (finger didn't move)
            let idx = clamp(Int(startX / tabW), in: 0..<tabs.count)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                active = tabs[idx].id
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSelect(tabs[idx].id)
        } else {
            // It was a swipe — snap to wherever the finger stopped
            let idx = clamp(Int(v.location.x / tabW), in: 0..<tabs.count)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                active = tabs[idx].id
            }
            onSelect(tabs[idx].id)
        }
    }

    // MARK: Bar container (iOS 26 vs fallback)
    @ViewBuilder
    private func barView(bubbleW: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            // Single glass surface for the whole bar.
            // The active-tab bubble must NOT be glass (no nested glass).
            tabCells(bubbleW: bubbleW)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .glassEffect(in: Capsule())
        } else {
            tabCells(bubbleW: bubbleW)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background { fallbackBg }
        }
    }

    // MARK: Tab cells — plain ZStack rows; gesture lives at bar level
    @ViewBuilder
    private func tabCells(bubbleW: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isActive   = shown == tab.id
                let isPressing = pressingTab == tab.id

                ZStack {
                    if isActive {
                        activeTabBubble(width: bubbleW)
                            .matchedGeometryEffect(id: "bubble", in: ns)
                            .scaleEffect(isPressing ? 1.16 : 1.0)
                            .animation(
                                isPressing
                                    ? .spring(response: 0.15, dampingFraction: 0.6)
                                    : .spring(response: 0.3,  dampingFraction: 0.82),
                                value: isPressing
                            )
                    }
                    tabLabel(tab, isActive: isActive, isPressing: isPressing)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
                // Accessibility: screen readers can still activate each tab
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                .accessibilityAction { onSelect(tab.id) }
            }
        }
    }

    // MARK: Active-tab highlight bubble
    @ViewBuilder
    private func activeTabBubble(width: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            // Simple filled highlight inside the glass bar — NOT glass itself
            // (rule: never nest glass inside glass)
            Capsule()
                .fill(.primary.opacity(scheme == .dark ? 0.18 : 0.10))
                .frame(width: width, height: 44)
        } else {
            ZStack {
                Capsule()
                    .fill(scheme == .dark
                          ? Color.white.opacity(0.14)
                          : Color.white.opacity(0.88))
                    .background(.thinMaterial, in: Capsule())

                // Specular top highlight
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

                // Rim highlight
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
        .foregroundStyle(isActive ? Color.primary : Color.secondary)
        // Combine scale effects: press overrides active-scale
        .scaleEffect(isPressing ? 1.06 : (isActive ? 1.04 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isActive)
        .animation(.spring(response: 0.15, dampingFraction: 0.65), value: isPressing)
    }

    // MARK: Fallback glass bar background (iOS 15–25)
    @ViewBuilder
    private var fallbackBg: some View {
        Capsule()
            .fill(scheme == .dark
                  ? Color(red: 0.07, green: 0.12, blue: 0.20).opacity(0.88)
                  : Color.white.opacity(0.70))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(scheme == .dark ? 0.07 : 0.28), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).clipShape(Capsule())
            )
            .overlay(Capsule().stroke(
                scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.45),
                lineWidth: 0.5
            ))
            .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.14), radius: 26, y: 8)
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
            content.glassEffect(in: Circle())
        } else {
            content
                .background {
                    Circle()
                        .fill(scheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.72))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
                }
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - AppDelegate
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKScriptMessageHandler {

    var window: UIWindow?
    private weak var capacitorWebView: WKWebView?
    private weak var rootVC: UIViewController?

    private var tabBarVC: UIViewController?
    private var backButtonVC: UIViewController?
    private var tabBarHeightConstraint: NSLayoutConstraint?
    private var isCollapsed = false
    private var messageHandlerAdded = false

    private var isPanelOpen = false {
        didSet { animateBackButton(visible: isPanelOpen) }
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

            self.injectEnhancements(into: wv)
            self.mountTabBar(on: rootVC)
            self.mountBackButton(on: rootVC)
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

            // ── 1. Native floating glass buttons (created fresh, no topbar dependency) ──
            function glassStyle(isDark) {
                var t = 'calc(env(safe-area-inset-top) + 8px)';
                var bg = isDark
                    ? 'rgba(255,255,255,0.10)'
                    : 'rgba(255,255,255,0.65)';
                var border = isDark
                    ? '0.5px solid rgba(255,255,255,0.18)'
                    : '0.5px solid rgba(255,255,255,0.80)';
                var shadow = isDark
                    ? '0 4px 24px rgba(0,0,0,0.45),inset 0 1px 0 rgba(255,255,255,0.14)'
                    : '0 4px 20px rgba(0,0,0,0.12),inset 0 1px 0 rgba(255,255,255,0.75)';
                return [
                    'position:fixed','top:'+t,'z-index:600',
                    'width:52px','height:52px','border-radius:50%',
                    'display:flex','align-items:center','justify-content:center',
                    'cursor:pointer',
                    'background:'+bg,
                    'backdrop-filter:blur(28px) saturate(180%)',
                    '-webkit-backdrop-filter:blur(28px) saturate(180%)',
                    'border:'+border,
                    'box-shadow:'+shadow,
                    'transition:background 0.2s,box-shadow 0.2s'
                ].join(';');
            }

            function updateBtnStyle(btn, isDark, extraRight) {
                var base = glassStyle(isDark);
                btn.style.cssText = base + ';right:' + extraRight;
            }

            function floatButtons() {
                if (document.getElementById('lu-save-btn')) return;
                var isDark = document.body.classList.contains('dark');
                var iconColor = isDark ? '#009DC4' : '#0046AD';

                // Save button
                var sv = document.createElement('button');
                sv.id = 'lu-save-btn';
                sv.type = 'button';
                sv.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="'+iconColor+'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>';
                sv.onclick = function() {
                    if (typeof saveData === 'function') saveData();
                };
                updateBtnStyle(sv, isDark, '16px');
                document.body.appendChild(sv);

                // Reset button
                var rs = document.createElement('button');
                rs.id = 'lu-reset-btn';
                rs.type = 'button';
                rs.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="'+iconColor+'" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-3.51"/></svg>';
                rs.onclick = function() {
                    if (typeof resetChanges === 'function') resetChanges();
                };
                rs.style.opacity = '0.4';
                updateBtnStyle(rs, isDark, '76px');
                rs.style.opacity = '0.4';
                rs.style.pointerEvents = 'none';
                document.body.appendChild(rs);

                // Keep original hidden buttons in sync (saveData checks them by id)
                var origSv = document.getElementById('glassSaveBtn');
                var origRs = document.getElementById('glassResetBtn');
                if (origSv) origSv.style.display = 'none';
                if (origRs) origRs.style.display = 'none';

                // Expose helpers so saveData/resetChanges can still control state
                window.__lu_setSaveState = function(saved) {
                    if (saved) {
                        sv.style.color = 'var(--success)';
                        rs.style.opacity = '0.4';
                        rs.style.pointerEvents = 'none';
                    } else {
                        sv.style.color = '';
                        rs.style.opacity = '1';
                        rs.style.pointerEvents = 'auto';
                    }
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', floatButtons)
                : floatButtons();

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

                // Also update floating buttons color
                var sv = document.getElementById('lu-save-btn');
                var rs = document.getElementById('lu-reset-btn');
                if (sv) updateBtnStyle(sv, isDark, '16px');
                if (rs) {
                    var wasDisabled = rs.style.pointerEvents === 'none';
                    updateBtnStyle(rs, isDark, '76px');
                    if (wasDisabled) { rs.style.opacity='0.4'; rs.style.pointerEvents='none'; }
                }
                var iconColor = isDark ? '#009DC4' : '#0046AD';
                [sv, rs].forEach(function(b) {
                    if (b) b.querySelectorAll('svg').forEach(function(s) {
                        s.setAttribute('stroke', iconColor);
                    });
                });
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
                    var sv = document.getElementById('lu-save-btn');
                    var rs = document.getElementById('lu-reset-btn');
                    // Green success flash on save button
                    if (sv) {
                        var isDark = document.body.classList.contains('dark');
                        sv.style.background = 'rgba(0,168,107,0.22)';
                        var svgEl = sv.querySelector('svg');
                        if (svgEl) svgEl.setAttribute('stroke', '#00a86b');
                        setTimeout(function() {
                            updateBtnStyle(sv, isDark, '16px');
                            if (svgEl) svgEl.setAttribute('stroke', isDark ? '#009DC4' : '#0046AD');
                        }, 1500);
                    }
                    if (rs) { rs.style.opacity='0.4'; rs.style.pointerEvents='none'; }
                };

                window.resetChanges = function() {
                    _reset.apply(this, arguments);
                    var rs = document.getElementById('lu-reset-btn');
                    if (rs) { rs.style.opacity='0.4'; rs.style.pointerEvents='none'; }
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchSaveReset)
                : patchSaveReset();

            // ── 3b. Patch markUnsaved to enable lu-reset-btn ────────────────
            // The HTML uses markUnsaved() (NOT markDirty) — patch the right fn.
            function patchMarkUnsaved() {
                if (window.__lu_mu_patched) return;
                if (typeof markUnsaved !== 'function') { setTimeout(patchMarkUnsaved, 250); return; }
                window.__lu_mu_patched = true;
                var _mu = window.markUnsaved;
                window.markUnsaved = function() {
                    _mu.apply(this, arguments);
                    var rs = document.getElementById('lu-reset-btn');
                    if (rs) { rs.style.opacity='1'; rs.style.pointerEvents='auto'; }
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchMarkUnsaved)
                : patchMarkUnsaved();

            // ── 3c. Auto-save on background — prevents data loss ─────────────
            // Mobile apps must preserve state when the user switches apps.
            // This saves silently to localStorage without changing the UI state.
            function autoSave() {
                try {
                    if (typeof materias === 'undefined') return;
                    var notas = {};
                    materias.forEach(function(m) { if (m.nota !== null) notas[m.id] = m.nota; });
                    localStorage.setItem('leanup_v4', JSON.stringify({
                        notas: notas,
                        electivosSeleccionados: typeof electivosSeleccionados !== 'undefined'
                            ? electivosSeleccionados : {},
                        electivosNotas: typeof electivosNotas !== 'undefined'
                            ? electivosNotas : {},
                        username: typeof username !== 'undefined' ? username : '',
                        darkMode: typeof darkMode !== 'undefined' ? darkMode : false
                    }));
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

            // ── 9. Panel open / close → native back button ──────────────────
            function patchPanel() {
                if (window.__lu_panel) return;
                if (typeof mobileOpenPanel !== 'function') {
                    setTimeout(patchPanel, 250); return;
                }
                window.__lu_panel = true;
                var _open  = window.mobileOpenPanel;
                var _close = window.mobileClosePanelOrBack;
                window.mobileOpenPanel = function() {
                    _open.apply(this, arguments);
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'panelOpen' });
                };
                window.mobileClosePanelOrBack = function() {
                    _close.apply(this, arguments);
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'panelClose' });
                };
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', patchPanel)
                : patchPanel();

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

            // ── 8. Dark mode sync → native UI ───────────────────────────────
            function patchDark() {
                if (window.__lu_dark) return;
                if (typeof toggleDark !== 'function') { setTimeout(patchDark, 250); return; }
                window.__lu_dark = true;
                var _td = window.toggleDark;
                window.toggleDark = function(on) {
                    _td.apply(this, arguments);
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'darkMode', on: on });
                };
                try {
                    var saved = localStorage.getItem('leanup_v4');
                    if (saved) {
                        var d = JSON.parse(saved);
                        if (d.darkMode) {
                            window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'darkMode', on: true });
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
                self?.capacitorWebView?.evaluateJavaScript("mobileClosePanelOrBack()")
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

    private func configure(overlayVC: UIViewController) {
        overlayVC.view.backgroundColor = .clear
        overlayVC.view.isOpaque = false
    }

    // MARK: Back button animation
    private func animateBackButton(visible: Bool) {
        guard let bvc = backButtonVC else { return }
        DispatchQueue.main.async {
            if visible { bvc.view.isHidden = false }
            UIView.animate(
                withDuration: 0.25, delay: 0,
                usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5
            ) {
                bvc.view.alpha = visible ? 1 : 0
            } completion: { _ in
                if !visible { bvc.view.isHidden = true }
            }
        }
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
                let on = body["on"] as? Bool ?? false
                self.window?.overrideUserInterfaceStyle = on ? .dark : .light
            default: break
            }
        }
    }

    // MARK: Scroll collapse
    private func handleScroll(delta: CGFloat, scrollTop: CGFloat) {
        let shouldCollapse = delta > 0 && scrollTop > 60
        let shouldExpand   = delta < 0 || scrollTop < 20
        if shouldCollapse && !isCollapsed {
            isCollapsed = true
            setTabBarHeight(56)
        } else if shouldExpand && isCollapsed {
            isCollapsed = false
            setTabBarHeight(105)
        }
    }

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
        if id == "more" { showMoreSheet() } else { webGo(id) }
    }

    private func showMoreSheet() {
        guard let rootVC else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(.init(title: "Salida Laboral",  style: .default) { [weak self] _ in self?.webGo("salida") })
        sheet.addAction(.init(title: "Portafolio",      style: .default) { [weak self] _ in self?.webGo("portafolio") })
        sheet.addAction(.init(title: "Configuración",   style: .default) { [weak self] _ in self?.webGo("config") })
        sheet.addAction(.init(title: "Cancelar",        style: .cancel))
        rootVC.present(sheet, animated: true)
    }

    private func webGo(_ id: String) {
        let js: String
        switch id {
        case "dashboard":   js = "showView('dashboard',null);setBottomNav('dashboard');"
        case "malla":       js = "showView('malla',null);setBottomNav('malla');"
        case "profesional": js = "showView('profesional',null);setBottomNav('profesional');"
        case "salida":      js = "showView('salida',null);setBottomNav('salida');"
        case "portafolio":  js = "showView('portafolio',null);setBottomNav('portafolio');"
        case "config":      js = "showViewGear();"
        default:            return
        }
        capacitorWebView?.evaluateJavaScript(js)
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
