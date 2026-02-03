import UIKit
import WebKit
import Display
import TelegramPresentationData
import AccountContext

final class MinigramReelsController: ViewController, WKUIDelegate {
    private let presentationData: PresentationData
    private let webView: WKWebView

    init(context: AccountContext) {
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true
        if #available(iOS 13.0, *) {
            configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData, style: .glass))
        self.title = "Reels"

        let icon = UIImage(bundleImageName: "Chat List/Tabs/IconCamera")
        self.tabBarItem.title = "Reels"
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = presentationData.theme.list.plainBackgroundColor
        webView.scrollView.backgroundColor = presentationData.theme.list.plainBackgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadReels()
    }

    private func loadReels() {
        guard let url = URL(string: "https://www.instagram.com/explore/reels/") else {
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30.0)
        webView.load(request)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
