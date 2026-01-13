import UIKit
import Display
import TelegramPresentationData

final class BackendChatListController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let presentationData: PresentationData
    private let api: BackendAPI
    private let session: BackendSession

    private var chats: [BackendChat] = []

    private let tableView = UITableView(frame: .zero, style: .plain)

    var onLogout: (() -> Void)?

    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.api = BackendAPI.shared
        self.session = BackendSession.shared
        super.init(navigationBarPresentationData: nil)
        self.title = "Chats"
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = presentationData.theme.list.plainBackgroundColor

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = presentationData.theme.list.plainBackgroundColor
        tableView.separatorColor = presentationData.theme.list.itemPlainSeparatorColor
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 60
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let newButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newChatTapped))
        let logoutButton = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutTapped))
        navigationItem.rightBarButtonItem = newButton
        navigationItem.leftBarButtonItem = logoutButton

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshTriggered), for: .valueChanged)
        tableView.refreshControl = refresh

        loadChats()
    }

    @objc private func refreshTriggered() {
        loadChats()
    }

    @objc private func newChatTapped() {
        let alert = UIAlertController(title: "New Chat", message: "Enter user UUID", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "User UUID"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let self, let value = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return
            }
            Task { @MainActor in
                do {
                    let chat = try await self.api.createDirectChat(userId: value)
                    self.chats.insert(chat, at: 0)
                    self.tableView.reloadData()
                } catch {
                    self.presentError("Failed to create chat")
                }
            }
        }))
        present(alert, animated: true)
    }

    @objc private func logoutTapped() {
        session.clear()
        onLogout?()
    }

    private func loadChats() {
        Task { @MainActor in
            do {
                let chats = try await api.listChats()
                self.chats = chats
                tableView.reloadData()
            } catch {
                presentError("Failed to load chats")
            }
            tableView.refreshControl?.endRefreshing()
        }
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ChatCell")
        let chat = chats[indexPath.row]
        cell.textLabel?.text = chat.title ?? (chat.kind == "group" ? "Group" : "Direct")
        cell.textLabel?.font = Font.medium(17)
        cell.textLabel?.textColor = presentationData.theme.list.itemPrimaryTextColor
        cell.detailTextLabel?.text = chat.id
        cell.detailTextLabel?.font = Font.regular(12)
        cell.detailTextLabel?.textColor = presentationData.theme.list.itemSecondaryTextColor
        cell.backgroundColor = presentationData.theme.list.plainBackgroundColor
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chat = chats[indexPath.row]
        let controller = BackendChatController(presentationData: presentationData, chat: chat)
        navigationController?.pushViewController(controller, animated: true)
    }
}
