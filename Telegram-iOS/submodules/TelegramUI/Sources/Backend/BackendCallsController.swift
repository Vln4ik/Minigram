import UIKit
import Display
import TelegramPresentationData

final class BackendCallsController: ViewController {
    private let presentationData: PresentationData
    private let api: BackendAPI
    private let session: BackendSession

    private let stackView = UIStackView()
    private let callIdField = UITextField()
    private let startButton = UIButton(type: .system)
    private let joinButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    var onLogout: (() -> Void)?

    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.api = BackendAPI.shared
        self.session = BackendSession.shared
        super.init(navigationBarPresentationData: nil)
        self.title = "Calls"
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        configureTextField(callIdField, placeholder: "Call ID", keyboard: .default)

        startButton.setTitle("Start Call", for: .normal)
        startButton.titleLabel?.font = Font.medium(17)
        startButton.tintColor = presentationData.theme.rootController.navigationBar.accentTextColor
        startButton.addTarget(self, action: #selector(startCallTapped), for: .touchUpInside)

        joinButton.setTitle("Join Call", for: .normal)
        joinButton.titleLabel?.font = Font.medium(17)
        joinButton.tintColor = presentationData.theme.rootController.navigationBar.accentTextColor
        joinButton.addTarget(self, action: #selector(joinCallTapped), for: .touchUpInside)

        statusLabel.font = Font.regular(14)
        statusLabel.textColor = presentationData.theme.list.itemSecondaryTextColor
        statusLabel.numberOfLines = 0

        stackView.addArrangedSubview(callIdField)
        stackView.addArrangedSubview(startButton)
        stackView.addArrangedSubview(joinButton)
        stackView.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutTapped))

        updateState(message: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateState(message: nil)
    }

    private func configureTextField(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType) {
        field.borderStyle = .roundedRect
        field.font = Font.regular(17)
        field.keyboardType = keyboard
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.placeholder = placeholder
        field.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        field.textColor = presentationData.theme.list.itemPrimaryTextColor
    }

    private func updateState(message: String?) {
        let authorized = session.isAuthorized
        startButton.isEnabled = authorized
        joinButton.isEnabled = authorized
        if let message {
            statusLabel.text = message
        } else if authorized {
            let name = session.user?.displayName ?? "user"
            statusLabel.text = "Signed in as \(name)."
        } else {
            statusLabel.text = "Authorize with your bot code to start calls."
        }
    }

    @objc private func logoutTapped() {
        session.clear()
        onLogout?()
    }

    @objc private func startCallTapped() {
        guard session.isAuthorized else {
            updateState(message: "Authorize first.")
            return
        }
        startButton.isEnabled = false
        joinButton.isEnabled = false
        updateState(message: "Starting call...")

        Task { @MainActor in
            do {
                let join = try await api.createCall()
                callIdField.text = join.callId
                openCall(join)
                updateState(message: "Call created: \(join.callId)")
            } catch {
                updateState(message: "Failed to start call.")
            }
        }
    }

    @objc private func joinCallTapped() {
        guard session.isAuthorized else {
            updateState(message: "Authorize first.")
            return
        }
        let callId = callIdField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !callId.isEmpty else {
            updateState(message: "Enter a Call ID.")
            return
        }
        startButton.isEnabled = false
        joinButton.isEnabled = false
        updateState(message: "Joining call...")

        Task { @MainActor in
            do {
                let join = try await api.joinCall(callId: callId)
                openCall(join)
                updateState(message: "Joined call: \(join.callId)")
            } catch {
                updateState(message: "Failed to join call.")
            }
        }
    }

    private func openCall(_ join: BackendCallJoin) {
        let controller = MinigramCallRoomController(presentationData: presentationData, join: join)
        navigationController?.pushViewController(controller, animated: true)
    }
}
