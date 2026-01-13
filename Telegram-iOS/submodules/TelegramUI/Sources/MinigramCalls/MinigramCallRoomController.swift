import Foundation
import UIKit
import Display
import TelegramPresentationData

final class MinigramCallRoomController: ViewController {
    private let presentationData: PresentationData
    private let join: BackendCallJoin
    private let statusLabel = UILabel()

    init(presentationData: PresentationData, join: BackendCallJoin) {
        self.presentationData = presentationData
        self.join = join
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData, style: .glass))
        self.title = "Minigram Calls"
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = presentationData.theme.list.itemPrimaryTextColor
        statusLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .medium)
        statusLabel.text = "Calls are coming soon.\nCall ID: \(join.callId)"

        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24.0),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24.0),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeTapped))
    }

    @objc private func closeTapped() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
