import UIKit
import Capacitor
import SwiftUI
import WebKit

// MARK: - Tab Model
private struct LUTab: Identifiable, Equatable {
    let id: String
    let icon: String
    let label: String
}

// MARK: - Liquid Glass Tab Bar (SwiftUI)
@available(iOS 15.0, *)
private struct LiquidGlassTabBar: View {
    @Binding var active: String
    @Namespace private var ns

    private let tabs: [LUTab] = [
        LUTab(id: "dashboard",   icon: "house.fill",              label: "Inicio"),
        LUTab(id: "malla",       icon: "list.bullet.clipboard",   label: "Malla"),
        LUTab(id: "profesional", icon: "person.fill",             label: "Perfil"),
        LUTab(id: "more",        icon: "ellipsis",                label: "Más"),
    ]

    var onSelect: (String) -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            ios26Bar
        } else {
            fallbackBar
        }
    }

    // MARK: iOS 26+ – Real Liquid Glass
    @available(iOS 26.0, *)
    private var ios26Bar: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                            active = tab.id
                        }
                        onSelect(tab.id)
                    } label: {
                        ZStack {
                            // Sliding glass bubble
                            if active == tab.id {
                                Color.clear
                                    .glassEffect(in: Capsule())
                                    .frame(width: 64, height: 46)
                                    .matchedGeometryEffect(id: "bubble", in: ns)
                            }
                            tabContent(tab)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .glassEffect(in: Capsule())
            .padding(.horizontal, 16)
        }
    }

    // MARK: iOS 15-25 – Ultra-Thin Material fallback
    private var fallbackBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                        active = tab.id
                    }
                    onSelect(tab.id)
                } label: {
                    ZStack {
                        // Sliding glass bubble (material fallback)
                        if active == tab.id {
                            Capsule()
                                .fill(.thinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                                .frame(width: 64, height: 46)
                                .matchedGeometryEffect(id: "bubble", in: ns)
                        }
                        tabContent(tab)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(Capsule())
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.14), radius: 28, y: 8)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func tabContent(_ tab: LUTab) -> some View {
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: 21, weight: .medium))
            Text(tab.label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(active == tab.id ? Color.primary : Color.secondary)
    }
}

// MARK: - Tab Bar Host (manages state)
@available(iOS 15.0, *)
private struct TabBarHost: View {
    @State private var active = "dashboard"
    var onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LiquidGlassTabBar(active: $active, onSelect: onSelect)
                .padding(.bottom, 10)
        }
        .background(Color.clear)
    }
}

// MARK: - AppDelegate
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private weak var capacitorWebView: WKWebView?
    private var tabBarVC: UIViewController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Capacitor loads the WebView lazily; retry until ready
        scheduleTabBarMount(attempt: 0)
        return true
    }

    // MARK: - Setup

    private func scheduleTabBarMount(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if let rootVC = self.window?.rootViewController,
               let wv = self.firstWebView(in: rootVC.view) {
                self.capacitorWebView = wv
                self.injectHideCSS(into: wv)
                self.mountTabBar(on: rootVC)
            } else if attempt < 15 {
                self.scheduleTabBarMount(attempt: attempt + 1)
            }
        }
    }

    private func injectHideCSS(into wv: WKWebView) {
        // Inject immediately and again after 1 s in case the page reloads
        let js = """
        (function() {
            if (document.getElementById('lu-native-ui')) return;
            var s = document.createElement('style');
            s.id = 'lu-native-ui';
            s.textContent =
                '.bottom-nav { display: none !important; }' +
                '#mainContent { padding-bottom: calc(env(safe-area-inset-bottom) + 92px) !important; }';
            (document.head || document.documentElement).appendChild(s);
        })();
        """
        wv.evaluateJavaScript(js)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            wv.evaluateJavaScript(js)
        }
    }

    private func mountTabBar(on rootVC: UIViewController) {
        guard tabBarVC == nil else { return } // Already mounted

        guard #available(iOS 15.0, *) else { return }

        let host = UIHostingController(
            rootView: TabBarHost { [weak self] tabId in
                self?.webNavigate(to: tabId)
            }
        )
        host.view.backgroundColor = .clear
        host.view.isOpaque = false

        rootVC.addChild(host)
        rootVC.view.addSubview(host.view)
        host.didMove(toParent: rootVC)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: rootVC.view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: rootVC.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: rootVC.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: rootVC.view.bottomAnchor),
        ])

        tabBarVC = host
    }

    // MARK: - Helpers

    private func firstWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for sub in view.subviews {
            if let found = firstWebView(in: sub) { return found }
        }
        return nil
    }

    private func webNavigate(to tabId: String) {
        let js: String
        switch tabId {
        case "dashboard":   js = "showView('dashboard',null);setBottomNav('dashboard');"
        case "malla":       js = "showView('malla',null);setBottomNav('malla');"
        case "profesional": js = "showView('profesional',null);setBottomNav('profesional');"
        case "more":        js = "toggleMoreMenu();"
        default:            return
        }
        capacitorWebView?.evaluateJavaScript(js)
    }

    // MARK: - Capacitor URL / Activity handling

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return ApplicationDelegateProxy.shared.application(
            application,
            continue: userActivity,
            restorationHandler: restorationHandler
        )
    }
}
