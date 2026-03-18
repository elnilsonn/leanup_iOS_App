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
    @State private var draggedIndex: Int? = nil
    @Environment(\.colorScheme) private var scheme

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

    var body: some View {
        GeometryReader { geo in
            let totalW  = geo.size.width
            let tabW    = totalW / CGFloat(tabs.count)
            let innerPad: CGFloat = 10
            let bubbleW = (totalW - innerPad * 2) / CGFloat(tabs.count) - 8

            barView(bubbleW: bubbleW)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { v in
                            let idx = clamp(Int(v.location.x / tabW), in: 0..<tabs.count)
                            withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                                draggedIndex = idx
                            }
                        }
                        .onEnded { v in
                            let idx = clamp(Int(v.location.x / tabW), in: 0..<tabs.count)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                                active = tabs[idx].id
                                draggedIndex = nil
                            }
                            onSelect(tabs[idx].id)
                        }
                )
        }
        .frame(height: 58)
        .padding(.horizontal, 16)
    }

    // MARK: Bar container (iOS 26 vs fallback)
    @ViewBuilder
    private func barView(bubbleW: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                buttons(bubbleW: bubbleW)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .glassEffect(in: Capsule())
            }
        } else {
            buttons(bubbleW: bubbleW)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background { fallbackBg }
        }
    }

    // MARK: Tab buttons
    @ViewBuilder
    private func buttons(bubbleW: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                let isActive = shown == tab.id
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                        active = tab.id
                        draggedIndex = nil
                    }
                    onSelect(tab.id)
                } label: {
                    ZStack {
                        if isActive {
                            glassBubble(width: bubbleW)
                                .matchedGeometryEffect(id: "bubble", in: ns)
                        }
                        tabLabel(tab, isActive: isActive)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── 2. WhatsApp-style glass bubble with specular highlight ──────────
    @ViewBuilder
    private func glassBubble(width: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(in: Capsule())
                .frame(width: width, height: 44)
        } else {
            ZStack {
                // Base translucent fill
                Capsule()
                    .fill(scheme == .dark
                          ? Color.white.opacity(0.14)
                          : Color.white.opacity(0.88))
                    .background(.thinMaterial, in: Capsule())

                // Specular highlight at top (like light catching a glass lens)
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

                // Edge rim highlight (refraction at glass boundary)
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
            // Top white glow (light catching the top of the bubble)
            .shadow(color: .white.opacity(scheme == .dark ? 0.12 : 0.45), radius: 4, y: -1)
            // Bottom depth shadow
            .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.12), radius: 10, y: 3)
        }
    }

    // Tab icon + label (slightly scales when active)
    @ViewBuilder
    private func tabLabel(_ tab: LUTab, isActive: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: isActive ? 22 : 20, weight: .medium))
            Text(tab.label)
                .font(.system(size: 10, weight: isActive ? .bold : .semibold))
        }
        .foregroundStyle(isActive ? Color.primary : Color.secondary)
        .scaleEffect(isActive ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
    }

    // Dark/light glass bar background (iOS 15-25)
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

// MARK: - Floating Glass Back Button (item 9)
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
                .background { backBg }
        }
        .buttonStyle(.plain)
    }
    @ViewBuilder
    private var backBg: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(in: Circle())
        } else {
            Circle()
                .fill(scheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.72))
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
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

            // ── 1. Float glass buttons out of hidden topbar ─────────────────
            function floatButtons() {
                var sv = document.getElementById('glassSaveBtn');
                var rs = document.getElementById('glassResetBtn');
                if (!sv || !rs || sv.dataset.f) return;
                sv.dataset.f = rs.dataset.f = '1';
                document.body.appendChild(rs);
                document.body.appendChild(sv);
                var t = 'calc(env(safe-area-inset-top) + 10px)';
                sv.style.cssText += ';position:fixed;top:'+t+';right:16px;z-index:600;display:flex';
                rs.style.cssText += ';position:fixed;top:'+t+';right:62px;z-index:600';
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', floatButtons)
                : floatButtons();

            // ── 2. Top gradient (iOS Settings-style transparent status area) ─
            function addGradients() {
                if (document.getElementById('lu-top-fade')) return;
                var topF = document.createElement('div');
                topF.id = 'lu-top-fade';
                topF.style.cssText = [
                    'position:fixed','top:0','left:0','right:0',
                    'height:calc(env(safe-area-inset-top) + 40px)',
                    'background:linear-gradient(to bottom, var(--bg) 55%, transparent)',
                    'pointer-events:none','z-index:500'
                ].join(';');
                document.body.appendChild(topF);

                // 3. Bottom gradient (just above tab bar)
                var botF = document.createElement('div');
                botF.id = 'lu-bottom-fade';
                botF.style.cssText = [
                    'position:fixed','left:0','right:0',
                    'bottom:calc(env(safe-area-inset-bottom) + 60px)',
                    'height:48px',
                    'background:linear-gradient(to bottom, transparent, var(--bg))',
                    'pointer-events:none','z-index:100'
                ].join(';');
                document.body.appendChild(botF);
            }
            document.readyState === 'loading'
                ? document.addEventListener('DOMContentLoaded', addGradients)
                : addGradients();

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
            rootView: GlassBackButton {
                self.capacitorWebView?.evaluateJavaScript("mobileClosePanelOrBack()")
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
