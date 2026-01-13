import UIKit
import Display
import TelegramPresentationData

final class BackendTabBarController: UITabBarController {
    private let presentationData: PresentationData
    private let session: BackendSession

    var onLogout: (() -> Void)?

    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.session = BackendSession.shared
        super.init(nibName: nil, bundle: nil)
        setupControllers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupControllers() {
        let theme = NavigationControllerTheme(presentationTheme: presentationData.theme)

        let chatsController = BackendChatListController(presentationData: presentationData)
        chatsController.onLogout = { [weak self] in
            self?.handleLogout()
        }
        let chatsNavigation = NavigationController(mode: .single, theme: theme)
        chatsNavigation.setViewControllers([chatsController], animated: false)
        chatsNavigation.tabBarItem = UITabBarItem(title: "Chats", image: UIImage(systemName: "bubble.left.and.bubble.right"), tag: 0)

        let callsController = BackendCallsController(presentationData: presentationData)
        callsController.onLogout = { [weak self] in
            self?.handleLogout()
        }
        let callsNavigation = NavigationController(mode: .single, theme: theme)
        callsNavigation.setViewControllers([callsController], animated: false)
        callsNavigation.tabBarItem = UITabBarItem(title: "Calls", image: UIImage(systemName: "phone"), tag: 1)

        viewControllers = [chatsNavigation, callsNavigation]
        tabBar.tintColor = presentationData.theme.rootController.navigationBar.accentTextColor
    }

    private func handleLogout() {
        session.clear()
        onLogout?()
    }
}
