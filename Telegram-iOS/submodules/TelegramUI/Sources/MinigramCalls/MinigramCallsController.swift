import Foundation
import UIKit
import Display
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import AccountContext
import SwiftSignalKit
import AppBundle

private struct MinigramCallsState: Equatable {
    var code: String
    var name: String
    var callId: String
    var isAuthorized: Bool
    var isAuthorizing: Bool
    var isCalling: Bool
    var isJoining: Bool
    var authStatus: String?
    var callStatus: String?
}

private struct MinigramCallsArguments {
    let context: AccountContext
    let updateCode: (String) -> Void
    let updateName: (String) -> Void
    let updateCallId: (String) -> Void
    let authorize: () -> Void
    let startCall: () -> Void
    let joinCall: () -> Void
    let logout: () -> Void
}

private enum MinigramCallsSection: Int32 {
    case auth
    case calls
}

private enum MinigramCallsEntry: ItemListNodeEntry {
    case authHeader(PresentationTheme, String)
    case authCode(PresentationTheme, String, String)
    case authName(PresentationTheme, String, String)
    case authAction(String, Bool)
    case authStatus(String)
    case authLogout(String, Bool)
    case callsHeader(PresentationTheme, String)
    case callId(PresentationTheme, String, String)
    case startCall(String, Bool)
    case joinCall(String, Bool)
    case callsStatus(String)

    var section: ItemListSectionId {
        switch self {
        case .authHeader, .authCode, .authName, .authAction, .authStatus, .authLogout:
            return ItemListSectionId(MinigramCallsSection.auth.rawValue)
        case .callsHeader, .callId, .startCall, .joinCall, .callsStatus:
            return ItemListSectionId(MinigramCallsSection.calls.rawValue)
        }
    }

    var stableId: Int32 {
        switch self {
        case .authHeader:
            return 0
        case .authCode:
            return 1
        case .authName:
            return 2
        case .authAction:
            return 3
        case .authStatus:
            return 4
        case .authLogout:
            return 5
        case .callsHeader:
            return 10
        case .callId:
            return 11
        case .startCall:
            return 12
        case .joinCall:
            return 13
        case .callsStatus:
            return 14
        }
    }

    static func == (lhs: MinigramCallsEntry, rhs: MinigramCallsEntry) -> Bool {
        switch lhs {
        case let .authHeader(lhsTheme, lhsText):
            if case let .authHeader(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .authCode(lhsTheme, lhsText, lhsPlaceholder):
            if case let .authCode(rhsTheme, rhsText, rhsPlaceholder) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText && lhsPlaceholder == rhsPlaceholder
            }
            return false
        case let .authName(lhsTheme, lhsText, lhsPlaceholder):
            if case let .authName(rhsTheme, rhsText, rhsPlaceholder) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText && lhsPlaceholder == rhsPlaceholder
            }
            return false
        case let .authAction(lhsTitle, lhsEnabled):
            if case let .authAction(rhsTitle, rhsEnabled) = rhs {
                return lhsTitle == rhsTitle && lhsEnabled == rhsEnabled
            }
            return false
        case let .authStatus(lhsText):
            if case let .authStatus(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        case let .authLogout(lhsTitle, lhsEnabled):
            if case let .authLogout(rhsTitle, rhsEnabled) = rhs {
                return lhsTitle == rhsTitle && lhsEnabled == rhsEnabled
            }
            return false
        case let .callsHeader(lhsTheme, lhsText):
            if case let .callsHeader(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .callId(lhsTheme, lhsText, lhsPlaceholder):
            if case let .callId(rhsTheme, rhsText, rhsPlaceholder) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText && lhsPlaceholder == rhsPlaceholder
            }
            return false
        case let .startCall(lhsTitle, lhsEnabled):
            if case let .startCall(rhsTitle, rhsEnabled) = rhs {
                return lhsTitle == rhsTitle && lhsEnabled == rhsEnabled
            }
            return false
        case let .joinCall(lhsTitle, lhsEnabled):
            if case let .joinCall(rhsTitle, rhsEnabled) = rhs {
                return lhsTitle == rhsTitle && lhsEnabled == rhsEnabled
            }
            return false
        case let .callsStatus(lhsText):
            if case let .callsStatus(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        }
    }

    static func < (lhs: MinigramCallsEntry, rhs: MinigramCallsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MinigramCallsArguments
        switch self {
        case let .authHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .authCode(theme, text, placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: "Code", textColor: theme.list.itemPrimaryTextColor),
                text: text,
                placeholder: placeholder,
                type: .number,
                returnKeyType: .done,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { arguments.updateCode($0) },
                action: {}
            )
        case let .authName(theme, text, placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: "Name", textColor: theme.list.itemPrimaryTextColor),
                text: text,
                placeholder: placeholder,
                type: .regular(capitalization: true, autocorrection: false),
                returnKeyType: .done,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { arguments.updateName($0) },
                action: {}
            )
        case let .authAction(title, enabled):
            let item = ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if enabled {
                    arguments.authorize()
                }
            })
            item.selectable = enabled
            return item
        case let .authStatus(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .authLogout(title, enabled):
            let item = ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .destructive : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if enabled {
                    arguments.logout()
                }
            })
            item.selectable = enabled
            return item
        case let .callsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .callId(theme, text, placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: "Call ID", textColor: theme.list.itemPrimaryTextColor),
                text: text,
                placeholder: placeholder,
                type: .regular(capitalization: false, autocorrection: false),
                returnKeyType: .done,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { arguments.updateCallId($0) },
                action: {}
            )
        case let .startCall(title, enabled):
            let item = ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if enabled {
                    arguments.startCall()
                }
            })
            item.selectable = enabled
            return item
        case let .joinCall(title, enabled):
            let item = ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if enabled {
                    arguments.joinCall()
                }
            })
            item.selectable = enabled
            return item
        case let .callsStatus(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func minigramCallsEntries(presentationData: PresentationData, state: MinigramCallsState) -> [MinigramCallsEntry] {
    let theme = presentationData.theme
    let authStatus: String
    if state.isAuthorizing {
        authStatus = "Authorizing..."
    } else if state.isAuthorized {
        if let name = state.authStatus, !name.isEmpty {
            authStatus = name
        } else {
            authStatus = "Authorized"
        }
    } else {
        authStatus = state.authStatus ?? "Enter the code from the Telegram bot to authorize."
    }

    let callStatus: String
    if state.isCalling {
        callStatus = "Starting call..."
    } else if state.isJoining {
        callStatus = "Joining call..."
    } else {
        callStatus = state.callStatus ?? "Create a call or paste a Call ID to join."
    }

    var entries: [MinigramCallsEntry] = []
    entries.append(.authHeader(theme, "Authorization"))
    entries.append(.authCode(theme, state.code, "Bot code"))
    entries.append(.authName(theme, state.name, "Display name"))
    entries.append(.authAction("Authorize", !state.isAuthorizing))
    entries.append(.authStatus(authStatus))
    if state.isAuthorized {
        entries.append(.authLogout("Sign Out", !state.isAuthorizing))
    }
    entries.append(.callsHeader(theme, "Calls"))
    entries.append(.callId(theme, state.callId, "Paste Call ID"))
    let callsEnabled = state.isAuthorized && !state.isCalling && !state.isJoining
    entries.append(.startCall("Start Call", callsEnabled))
    entries.append(.joinCall("Join Call", callsEnabled))
    entries.append(.callsStatus(callStatus))
    return entries
}

final class MinigramCallsController: ItemListController {
    private let context: AccountContext
    private let api: BackendAPI
    private let session: BackendSession
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?

    private let statePromise: ValuePromise<MinigramCallsState>
    private let stateValue: Atomic<MinigramCallsState>

    init(context: AccountContext) {
        self.context = context
        self.api = BackendAPI.shared
        self.session = BackendSession.shared
        let currentPresentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = currentPresentationData

        let initialAuthorized = session.isAuthorized
        let initialName = session.user?.displayName ?? ""
        let initialState = MinigramCallsState(
            code: "",
            name: initialName,
            callId: "",
            isAuthorized: initialAuthorized,
            isAuthorizing: false,
            isCalling: false,
            isJoining: false,
            authStatus: initialAuthorized ? "Authorized as \(initialName)" : nil,
            callStatus: nil
        )
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)
        self.stateValue = Atomic(value: initialState)

        weak var weakSelf: MinigramCallsController?
        let arguments = MinigramCallsArguments(
            context: context,
            updateCode: { value in
                weakSelf?.updateState { $0.code = value }
            },
            updateName: { value in
                weakSelf?.updateState { $0.name = value }
            },
            updateCallId: { value in
                weakSelf?.updateState { $0.callId = value }
            },
            authorize: {
                weakSelf?.authorize()
            },
            startCall: {
                weakSelf?.startCall()
            },
            joinCall: {
                weakSelf?.joinCall()
            },
            logout: {
                weakSelf?.logout()
            }
        )

        let updatedPresentationData = context.sharedContext.presentationData
        |> map(ItemListPresentationData.init)

        let signal = combineLatest(context.sharedContext.presentationData |> deliverOnMainQueue, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let entries = minigramCallsEntries(presentationData: presentationData, state: state)
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(presentationData.strings.Calls_TabTitle),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: nil,
                animateChanges: false
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: entries,
                style: .blocks
            )
            return (controllerState, (listState, arguments))
        }

        super.init(
            presentationData: ItemListPresentationData(currentPresentationData),
            updatedPresentationData: updatedPresentationData,
            state: signal,
            tabBarItem: nil,
            hideNavigationBarBackground: false
        )
        weakSelf = self

        self.tabBarItemContextActionType = .always
        self.updateTabBarItem()

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            let previousTheme = self.presentationData.theme
            let previousStrings = self.presentationData.strings
            self.presentationData = presentationData
            if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                self.updateTabBarItem()
            }
        })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
    }

    private func updateTabBarItem() {
        let icon = UIImage(bundleImageName: "Chat List/Tabs/IconCalls")
        self.tabBarItem.title = presentationData.strings.Calls_TabTitle
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
        if !presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabCalls"
        } else {
            self.tabBarItem.animationName = nil
        }
    }

    private func updateState(_ f: (inout MinigramCallsState) -> Void) {
        let updated = self.stateValue.modify { current in
            var updated = current
            f(&updated)
            return updated
        }
        self.statePromise.set(updated)
    }

    private func authorize() {
        let state = self.stateValue.with { $0 }
        let code = state.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.isEmpty {
            presentError("Enter the bot code first.")
            return
        }
        if state.isAuthorizing {
            return
        }
        updateState {
            $0.isAuthorizing = true
            $0.authStatus = "Authorizing..."
        }
        Task { @MainActor in
            do {
                let auth = try await api.authorizeBot(code: code, name: name)
                session.update(from: auth)
                updateState {
                    $0.isAuthorizing = false
                    $0.isAuthorized = true
                    $0.name = auth.user.displayName
                    $0.authStatus = "Authorized as \(auth.user.displayName)"
                }
            } catch {
                updateState {
                    $0.isAuthorizing = false
                    $0.authStatus = "Authorization failed."
                }
                presentError("Authorization failed.")
            }
        }
    }

    private func startCall() {
        let state = self.stateValue.with { $0 }
        guard session.isAuthorized else {
            presentError("Authorize first.")
            return
        }
        if state.isCalling || state.isJoining {
            return
        }
        updateState {
            $0.isCalling = true
            $0.callStatus = "Starting call..."
        }
        Task { @MainActor in
            do {
                let join = try await api.createCall()
                updateState {
                    $0.isCalling = false
                    $0.callId = join.callId
                    $0.callStatus = "Call ID: \(join.callId)"
                }
                openCallRoom(join)
            } catch {
                updateState {
                    $0.isCalling = false
                    $0.callStatus = "Failed to start call."
                }
                presentError("Failed to start call.")
            }
        }
    }

    private func joinCall() {
        let state = self.stateValue.with { $0 }
        guard session.isAuthorized else {
            presentError("Authorize first.")
            return
        }
        if state.isCalling || state.isJoining {
            return
        }
        let callId = state.callId.trimmingCharacters(in: .whitespacesAndNewlines)
        if callId.isEmpty {
            presentError("Enter a Call ID.")
            return
        }
        updateState {
            $0.isJoining = true
            $0.callStatus = "Joining call..."
        }
        Task { @MainActor in
            do {
                let join = try await api.joinCall(callId: callId)
                updateState {
                    $0.isJoining = false
                    $0.callStatus = "Joined call \(join.callId)"
                }
                openCallRoom(join)
            } catch {
                updateState {
                    $0.isJoining = false
                    $0.callStatus = "Failed to join call."
                }
                presentError("Failed to join call.")
            }
        }
    }

    private func logout() {
        session.clear()
        updateState {
            $0.isAuthorized = false
            $0.authStatus = "Signed out."
        }
    }

    private func openCallRoom(_ join: BackendCallJoin) {
        let controller = MinigramCallRoomController(presentationData: presentationData, join: join)
        (self.navigationController as? NavigationController)?.pushViewController(controller)
    }

    private func presentError(_ text: String) {
        let controller = textAlertController(context: context, title: nil, text: text, actions: [
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
        ])
        self.present(controller, in: .window(.root))
    }
}
