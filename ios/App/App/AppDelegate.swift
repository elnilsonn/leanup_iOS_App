import UIKit
import Capacitor

// UIView que detecta cambios de dark/light mode y actualiza el gradiente
private class GradientBackgroundView: UIView {

    let gradientLayer = CAGradientLayer()
    private var animating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        gradientLayer.frame = bounds
        applyColors(for: traitCollection)
        gradientLayer.locations = [0.0, 0.55, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.1, y: 0.0)
        gradientLayer.endPoint   = CGPoint(x: 0.9, y: 1.0)
        gradientLayer.type = .axial
        layer.addSublayer(gradientLayer)
        startAnimation()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        gradientLayer.removeAnimation(forKey: "gradientAnimation")
        applyColors(for: traitCollection)
        startAnimation()
    }

    private func applyColors(for traits: UITraitCollection) {
        if traits.userInterfaceStyle == .dark {
            gradientLayer.colors = [
                UIColor(red: 13/255, green: 20/255, blue: 32/255, alpha: 1.0).cgColor,
                UIColor(red: 19/255, green: 30/255, blue: 48/255, alpha: 1.0).cgColor,
                UIColor(red: 26/255, green: 40/255, blue: 64/255, alpha: 1.0).cgColor
            ]
        } else {
            gradientLayer.colors = [
                UIColor(red: 0/255, green: 27/255,  blue: 80/255,  alpha: 1.0).cgColor,
                UIColor(red: 0/255, green: 70/255,  blue: 173/255, alpha: 1.0).cgColor,
                UIColor(red: 0/255, green: 157/255, blue: 196/255, alpha: 0.85).cgColor
            ]
        }
    }

    func startAnimation() {
        let toColors: [CGColor]
        if traitCollection.userInterfaceStyle == .dark {
            toColors = [
                UIColor(red: 18/255, green: 28/255, blue: 44/255, alpha: 1.0).cgColor,
                UIColor(red: 26/255, green: 38/255, blue: 60/255, alpha: 1.0).cgColor,
                UIColor(red: 32/255, green: 48/255, blue: 76/255, alpha: 1.0).cgColor
            ]
        } else {
            toColors = [
                UIColor(red: 0/255,  green: 46/255,  blue: 100/255, alpha: 1.0).cgColor,
                UIColor(red: 0/255,  green: 90/255,  blue: 200/255, alpha: 1.0).cgColor,
                UIColor(red: 0/255,  green: 120/255, blue: 150/255, alpha: 0.9).cgColor
            ]
        }
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer.colors
        animation.toValue = toColors
        animation.duration = 6.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: "gradientAnimation")
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

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

        let bg = GradientBackgroundView(frame: window.bounds)
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.insertSubview(bg, at: 0)
        window.backgroundColor = UIColor(red: 0/255, green: 27/255, blue: 80/255, alpha: 1.0)
    }

    // MARK: - WKWebView transparente

    func applicationDidBecomeActive(_ application: UIApplication) {
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
