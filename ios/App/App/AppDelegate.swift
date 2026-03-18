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

// MARK: - Liquid Glass Tab Bar ────────────────────────────────────────────────
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

    // Bubble follows drag; otherwise shows persisted active tab
    private var shown: String {
        draggedIndex.map { tabs[$0].id } ?? active
    }

    var body: some View {
        GeometryReader { geo in
            let tabW = geo.size.width / CGFloat(tabs.count)
            barView()
                // ── 3. Drag-to-slide gesture ─────────────────────────────
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
        // ── 4. Position closer to bottom (reduced height) ─────────────────
        .frame(height: 58)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func barView() -> some View {
        if #available(iOS 26.0, *) {
            // ── iOS 26: real Liquid Glass ─────────────────────────────────
            GlassEffectContainer {
                buttons()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .glassEffect(in: Capsule())
            }
        } else {
            // ── iOS 15-25: material fallback ──────────────────────────────
            buttons()
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background { fallbackBg }
        }
    }

    @ViewBuilder
    private func buttons() -> some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                        active = tab.id
                        draggedIndex = nil
                    }
                    onSelect(tab.id)
                } label: {
                    ZStack {
                        if shown == tab.id { bubble }  // sliding indicator
                        label(tab)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Sliding bubble
    @ViewBuilder
    private var bubble: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(in: Capsule())
                .frame(width: 60, height: 42)
                .matchedGeometryEffect(id: "bubble", in: ns)
        } else {
            // ── 8. Dark mode bubble ───────────────────────────────────────
            Capsule()
                .fill(scheme == .dark
                      ? Color.white.opacity(0.18)
                      : Color.white.opacity(0.75))
                .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                .frame(width: 60, height: 42)
                .matchedGeometryEffect(id: "bubble", in: ns)
        }
    }

    // Tab icon + label
    @ViewBuilder
    private func label(_ tab: LUTab) -> some View {
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: 20, weight: .medium))
            Text(tab.label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(shown == tab.id ? Color.primary : Color.secondary)
    }

    // ── 8. Dark/light glass background (iOS 15-25 fallback) ──────────────
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

// MARK: - Tab Bar Host ─────────────────────────────────────────────────────────
@available(iOS 15.0, *)
private struct TabBarHost: View {
    @State private var active = "dashboard"
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LiquidGlassTabBar(active: $active, onSelect: onSelect)
                // ── 4. Minimal gap above home indicator ───────────────────
                .padding(.bottom, 4)
        }
        .background(Color.clear)
    }
}

// MARK: - Floating Glass Back Button (item 9) ─────────────────────────────────
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

// MARK: - AppDelegate ─────────────────────────────────────────────────────────
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKScriptMessageHandler {

    var window: UIWindow?
    private weak var capacitorWebView: WKWebView?
    private weak var rootVC: UIViewController?

    private var tabBarVC: UIViewController?
    private var backButtonVC: UIViewController?
    private var tabBarHeightConstraint: NSLayoutConstraint?

    // ── 5. Scroll-collapse state ──────────────────────────────────────────
    private var isCollapsed = false

    // ── 9. Detail-panel back-button state ────────────────────────────────
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
            self.rootVC  = rootVC
            self.capacitorWebView = wv
            self.injectEnhancements(into: wv)
            self.mountTabBar(on: rootVC)
            self.mountBackButton(on: rootVC)
        }
    }

    // MARK: CSS + JS injections ────────────────────────────────────────────
    private func injectEnhancements(into wv: WKWebView) {
        // Register message handler (weak proxy avoids retain cycle)
        wv.configuration.userContentController.add(WeakMsgHandler(self), name: "nativeUI")

        let js = """
        (function() {
            // Guard: run only once per page
            if (window.__lu_init) return;
            window.__lu_init = true;

            // ── CSS injections ─────────────────────────────────────────────
            var s = document.createElement('style');
            s.id = 'lu-ni';
            s.textContent = `
                /* 1. Hide web bottom nav */
                .bottom-nav { display: none !important; }

                /* Extra scroll padding for native tab bar */
                #mainContent { padding-bottom: calc(env(safe-area-inset-bottom) + 88px) !important; }

                /* 7. Hide topbar title text; show glass action buttons */
                .topbar-title { display: none !important; }
                .topbar-glass-btn { display: flex !important; }
                @media (max-width: 768px) {
                    #saveBtn, #resetBtn { display: none !important; }
                }

                /* 2. Subtle gradient fade at the bottom of the scroll area */
                .content { position: relative; }
                #mainContent::after {
                    content: '';
                    position: sticky;
                    bottom: 0;
                    left: 0; right: 0;
                    display: block;
                    height: 36px;
                    margin-top: -36px;
                    background: linear-gradient(to top, var(--bg) 20%, transparent);
                    pointer-events: none;
                    z-index: 10;
                }

                /* 10. Confirm button style (added by JS below) */
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

            // ── 10. Add ✓ confirm button to nota-widget elements ───────────
            function addConfirm(widget) {
                if (widget.dataset.lu) return;
                widget.dataset.lu = '1';
                var inp = widget.querySelector('.nota-inp');
                if (!inp) return;
                var rawId = inp.id.replace('ni-', '');
                var btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'nota-btn nota-confirm-btn';
                btn.setAttribute('tabindex', '-1');
                btn.textContent = '✓';
                btn.addEventListener('pointerdown', function(e) {
                    e.preventDefault(); e.stopPropagation();
                    if (typeof saveNota === 'function') saveNota(parseInt(rawId, 10));
                });
                widget.appendChild(btn);
            }
            var mo = new MutationObserver(function() {
                document.querySelectorAll('.nota-widget').forEach(addConfirm);
            });
            mo.observe(document.documentElement, { childList: true, subtree: true });
            document.querySelectorAll('.nota-widget').forEach(addConfirm);

            // ── 9. Intercept panel open / close → notify native ────────────
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

            // ── 5. Scroll events → native tab-bar collapse ────────────────
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

            // ── 8. Dark mode sync → native UI ─────────────────────────────
            function patchDark() {
                if (window.__lu_dark) return;
                if (typeof toggleDark !== 'function') { setTimeout(patchDark, 250); return; }
                window.__lu_dark = true;
                var _td = window.toggleDark;
                window.toggleDark = function(on) {
                    _td.apply(this, arguments);
                    window.webkit?.messageHandlers?.nativeUI?.postMessage({ event: 'darkMode', on: on });
                };
                // Sync initial state from saved data
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
        // Re-inject 1.5 s later in case page was still loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            wv.evaluateJavaScript(js)
        }
    }

    // MARK: Mount tab bar ─────────────────────────────────────────────────
    private func mountTabBar(on rootVC: UIViewController) {
        guard tabBarVC == nil, #available(iOS 15.0, *) else { return }

        let host = UIHostingController(
            rootView: TabBarHost { [weak self] tabId in
                self?.handleTab(tabId)
            }
        )
        configure(overlayVC: host)

        rootVC.addChild(host)
        rootVC.view.addSubview(host.view)
        host.didMove(toParent: rootVC)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        // ── 4. Only covers bottom area → touches above pass to WebView ──
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

    // MARK: Mount back button (item 9) ────────────────────────────────────
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

    // MARK: Back button animation ─────────────────────────────────────────
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

    // MARK: WKScriptMessageHandler ────────────────────────────────────────
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

            // ── 5. Scroll → collapse / expand tab bar ─────────────────────
            case "scroll":
                let delta = body["delta"] as? CGFloat ?? 0
                let top   = body["top"]   as? CGFloat ?? 0
                self.handleScroll(delta: delta, scrollTop: top)

            // ── 9. Detail panel open / close ──────────────────────────────
            case "panelOpen":  self.isPanelOpen = true
            case "panelClose": self.isPanelOpen = false

            // ── 8. Dark mode sync ──────────────────────────────────────────
            case "darkMode":
                let on = body["on"] as? Bool ?? false
                // Override the entire app's colour scheme so SwiftUI matches
                self.window?.overrideUserInterfaceStyle = on ? .dark : .light

            default: break
            }
        }
    }

    // MARK: 5. Scroll collapse ────────────────────────────────────────────
    private func handleScroll(delta: CGFloat, scrollTop: CGFloat) {
        let shouldCollapse = delta > 0 && scrollTop > 60
        let shouldExpand   = delta < 0 || scrollTop < 20
        if shouldCollapse && !isCollapsed {
            isCollapsed = true
            setTabBarHeight(56)        // compact: just icons
        } else if shouldExpand && isCollapsed {
            isCollapsed = false
            setTabBarHeight(105)       // full height
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

    // MARK: Tab navigation ────────────────────────────────────────────────
    private func handleTab(_ id: String) {
        if id == "more" {
            // ── 6. Más: native action sheet ───────────────────────────────
            showMoreSheet()
        } else {
            webGo(id)
        }
    }

    // ── 6. Native sheet for Más ───────────────────────────────────────────
    private func showMoreSheet() {
        guard let rootVC else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(.init(title: "Salida Laboral", style: .default) { [weak self] _ in
            self?.webGo("salida") })
        sheet.addAction(.init(title: "Portafolio", style: .default) { [weak self] _ in
            self?.webGo("portafolio") })
        sheet.addAction(.init(title: "Configuración", style: .default) { [weak self] _ in
            self?.webGo("config") })
        sheet.addAction(.init(title: "Cancelar", style: .cancel))
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

    // MARK: Helpers ───────────────────────────────────────────────────────
    private func firstWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for sub in view.subviews {
            if let found = firstWebView(in: sub) { return found }
        }
        return nil
    }

    // MARK: Capacitor URL / Activity handling ─────────────────────────────
    func application(
        _ app: UIApplication,
        open url: URL,
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
