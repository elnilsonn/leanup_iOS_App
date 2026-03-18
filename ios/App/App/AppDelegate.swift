import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var gradientLayer: CAGradientLayer?
    private var gradientView: UIView?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupNativeBackground()
        return true
    }

    // MARK: - Fondo nativo con gradiente UNAD

    private func setupNativeBackground() {
        guard let window = window else { return }

        let bg = UIView(frame: window.bounds)
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let gradient = CAGradientLayer()
        gradient.frame = window.bounds
        gradient.colors = [
            UIColor(red: 0/255,   green: 27/255,  blue: 80/255,  alpha: 1.0).cgColor, // --unad-navy
            UIColor(red: 0/255,   green: 70/255,  blue: 173/255, alpha: 1.0).cgColor, // --unad-blue
            UIColor(red: 0/255,   green: 157/255, blue: 196/255, alpha: 0.85).cgColor // --unad-cyan
        ]
        gradient.locations = [0.0, 0.55, 1.0]
        gradient.startPoint = CGPoint(x: 0.1, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.9, y: 1.0)
        gradient.type = .axial

        bg.layer.addSublayer(gradient)
        window.insertSubview(bg, at: 0)
        window.backgroundColor = UIColor(red: 0/255, green: 27/255, blue: 80/255, alpha: 1.0)

        self.gradientLayer = gradient
        self.gradientView  = bg

        startGradientAnimation()
    }

    private func startGradientAnimation() {
        guard let gradient = gradientLayer else { return }

        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradient.colors
        animation.toValue = [
            UIColor(red: 0/255,  green: 46/255,  blue: 100/255, alpha: 1.0).cgColor,
            UIColor(red: 0/255,  green: 90/255,  blue: 200/255, alpha: 1.0).cgColor,
            UIColor(red: 0/255,  green: 120/255, blue: 150/255, alpha: 0.9).cgColor
        ]
        animation.duration = 6.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(animation, forKey: "gradientAnimation")
    }

    // MARK: - WKWebView transparente

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Intentar inmediatamente y con delay como fallback
        makeWebViewTransparent()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.makeWebViewTransparent()
        }
    }

    private func makeWebViewTransparent() {
        guard
            let rootVC = window?.rootViewController,
            let bridgeVC = findBridgeViewController(in: rootVC)
        else { return }

        bridgeVC.webView?.isOpaque = false
        bridgeVC.webView?.backgroundColor = .clear
        bridgeVC.webView?.scrollView.backgroundColor = .clear

        if #available(iOS 16.0, *) {
            bridgeVC.webView?.underPageBackgroundColor = .clear
        }
    }

    private func findBridgeViewController(in vc: UIViewController) -> CAPBridgeViewController? {
        if let bridge = vc as? CAPBridgeViewController { return bridge }
        for child in vc.children {
            if let found = findBridgeViewController(in: child) { return found }
        }
        return nil
    }

    // MARK: - Dark mode: adaptar gradiente nativo

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateGradientForColorScheme()
    }

    private func updateGradientForColorScheme() {
        guard let gradient = gradientLayer else { return }
        gradient.removeAnimation(forKey: "gradientAnimation")

        if traitCollection.userInterfaceStyle == .dark {
            gradient.colors = [
                UIColor(red: 13/255, green: 20/255, blue: 32/255, alpha: 1.0).cgColor,
                UIColor(red: 19/255, green: 30/255, blue: 48/255, alpha: 1.0).cgColor,
                UIColor(red: 26/255, green: 40/255, blue: 64/255, alpha: 1.0).cgColor
            ]
        } else {
            gradient.colors = [
                UIColor(red: 0/255, green: 27/255,  blue: 80/255,  alpha: 1.0).cgColor,
                UIColor(red: 0/255, green: 70/255,  blue: 173/255, alpha: 1.0).cgColor,
                UIColor(red: 0/255, green: 157/255, blue: 196/255, alpha: 0.85).cgColor
            ]
        }
        startGradientAnimation()
    }

    // MARK: - iOS 26+: placeholder para UIGlassEffect nativo (future-proof)

    @available(iOS 26.0, *)
    private func applyNativeGlassIfNeeded() {
        // En iOS 26+ con UIGlassEffect disponible.
        // La app es 100% WebView por ahora; el CSS glass hace el trabajo.
        // Esta función está lista para cuando se añadan vistas nativas.
    }

    // MARK: - Boilerplate Capacitor

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(
            application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
