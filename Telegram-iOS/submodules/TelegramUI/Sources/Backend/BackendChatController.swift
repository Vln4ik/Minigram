import UIKit
import Display
import TelegramPresentationData

final class BackendChatController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let presentationData: PresentationData
    private let api: BackendAPI
    private let session: BackendSession
    private let chat: BackendChat

    private var messages: [BackendMessage] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    private let messageField = UITextField()
    private let sendButton = UIButton(type: .system)

    private var inputBottomConstraint: NSLayoutConstraint?

    init(presentationData: PresentationData, chat: BackendChat) {
        self.presentationData = presentationData
        self.api = BackendAPI.shared
        self.session = BackendSession.shared
        self.chat = chat
        super.init(navigationBarPresentationData: nil)
        self.title = chat.title ?? (chat.kind == "group" ? "Group" : "Chat")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = presentationData.theme.chatList.backgroundColor

        setupTableView()
        setupInputBar()
        registerKeyboardNotifications()

        loadMessages()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = presentationData.theme.chatList.backgroundColor
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(BackendMessageCell.self, forCellReuseIdentifier: "MessageCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
    }

    private func setupInputBar() {
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor

        messageField.translatesAutoresizingMaskIntoConstraints = false
        messageField.borderStyle = .roundedRect
        messageField.font = Font.regular(16)
        messageField.placeholder = "Message"
        messageField.autocorrectionType = .yes
        messageField.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        messageField.textColor = presentationData.theme.list.itemPrimaryTextColor

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = Font.medium(16)
        sendButton.tintColor = presentationData.theme.rootController.navigationBar.accentTextColor
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        inputContainer.addSubview(messageField)
        inputContainer.addSubview(sendButton)
        view.addSubview(inputContainer)

        let bottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            inputContainer.heightAnchor.constraint(equalToConstant: 56),

            messageField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            messageField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            messageField.heightAnchor.constraint(equalToConstant: 36),

            sendButton.leadingAnchor.constraint(equalTo: messageField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60)
        ])

        tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor).isActive = true
    }

    private func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardWillChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber
        else {
            return
        }
        let keyboardFrame = frameValue.cgRectValue
        let converted = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - converted.minY)
        inputBottomConstraint?.constant = -overlap

        UIView.animate(withDuration: duration.doubleValue) {
            self.view.layoutIfNeeded()
        }
    }

    private func loadMessages() {
        Task { @MainActor in
            do {
                let messages = try await api.listMessages(chatId: chat.id)
                self.messages = messages.sorted(by: { $0.createdAt < $1.createdAt })
                tableView.reloadData()
                scrollToBottom()
            } catch {
                presentError("Failed to load messages")
            }
        }
    }

    @objc private func sendTapped() {
        let text = messageField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            return
        }
        messageField.text = ""
        Task { @MainActor in
            do {
                let message = try await api.sendMessage(chatId: chat.id, body: text)
                messages.append(message)
                tableView.reloadData()
                scrollToBottom()
            } catch {
                presentError("Failed to send message")
            }
        }
    }

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let index = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: index, at: .bottom, animated: true)
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as? BackendMessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        let isOutgoing = message.senderId == session.user?.id
        cell.configure(message: message, isOutgoing: isOutgoing, presentationData: presentationData)
        return cell
    }
}

private final class BackendMessageCell: UITableViewCell {
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0

        bubbleView.addSubview(messageLabel)
        contentView.addSubview(bubbleView)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),

            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(message: BackendMessage, isOutgoing: Bool, presentationData: PresentationData) {
        let text = message.body ?? "[media]"
        messageLabel.text = text
        messageLabel.font = Font.regular(16)

        let chatTheme = presentationData.theme.chat.message
        let bubbleComponents = isOutgoing ? chatTheme.outgoing.bubble.withoutWallpaper : chatTheme.incoming.bubble.withoutWallpaper
        let fillColor = bubbleComponents.fill.first ?? presentationData.theme.list.itemBlocksBackgroundColor
        bubbleView.backgroundColor = fillColor
        messageLabel.textColor = isOutgoing ? chatTheme.outgoing.primaryTextColor : chatTheme.incoming.primaryTextColor

        if isOutgoing {
            leadingConstraint?.isActive = false
            trailingConstraint?.isActive = true
        } else {
            trailingConstraint?.isActive = false
            leadingConstraint?.isActive = true
        }
    }
}
