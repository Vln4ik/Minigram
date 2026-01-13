import UIKit
import Display
import TelegramPresentationData

final class BackendLoginController: ViewController {
    private let presentationData: PresentationData
    private let api: BackendAPI
    private let session: BackendSession

    private let stackView = UIStackView()
    private let codeField = UITextField()
    private let nameField = UITextField()
    private let actionButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    var onAuthorized: (() -> Void)?

    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.api = BackendAPI.shared
        self.session = BackendSession.shared
        super.init(navigationBarPresentationData: nil)
        self.title = "Log In"
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

        configureTextField(codeField, placeholder: "Bot code", keyboard: .numberPad)
        configureTextField(nameField, placeholder: "Name", keyboard: .default)

        actionButton.setTitle("Authorize", for: .normal)
        actionButton.titleLabel?.font = Font.medium(17)
        actionButton.tintColor = presentationData.theme.rootController.navigationBar.accentTextColor
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        errorLabel.font = Font.regular(14)
        errorLabel.textColor = presentationData.theme.list.itemDestructiveColor
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        stackView.addArrangedSubview(codeField)
        stackView.addArrangedSubview(nameField)
        stackView.addArrangedSubview(actionButton)
        stackView.addArrangedSubview(errorLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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

    @objc private func actionTapped() {
        errorLabel.isHidden = true
        actionButton.isEnabled = false

        let code = codeField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !code.isEmpty else {
            showError("Code required")
            return
        }
        Task { @MainActor in
            do {
                let auth = try await api.authorizeBot(code: code, name: name)
                session.update(from: auth)
                onAuthorized?()
            } catch {
                showError("Failed to authorize")
            }
            actionButton.isEnabled = true
        }
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
        actionButton.isEnabled = true
    }
}
