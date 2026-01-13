import Foundation
import UIKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import SwiftSignalKit

private enum MinigramCallsPlaceholderSection: Int32 {
    case info
}

private enum MinigramCallsPlaceholderEntry: ItemListNodeEntry {
    case header(PresentationTheme, String)
    case info(String)

    var section: ItemListSectionId {
        switch self {
        case .header, .info:
            return ItemListSectionId(MinigramCallsPlaceholderSection.info.rawValue)
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .info:
            return 1
        }
    }

    static func == (lhs: MinigramCallsPlaceholderEntry, rhs: MinigramCallsPlaceholderEntry) -> Bool {
        switch lhs {
        case let .header(lhsTheme, lhsText):
            if case let .header(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .info(lhsText):
            if case let .info(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        }
    }

    static func < (lhs: MinigramCallsPlaceholderEntry, rhs: MinigramCallsPlaceholderEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func minigramCallsPlaceholderEntries(presentationData: PresentationData) -> [MinigramCallsPlaceholderEntry] {
    return [
        .header(presentationData.theme, "Minigram Calls"),
        .info("Calls are coming soon. Use the standard Telegram Calls tab for now."),
    ]
}

final class MinigramCallsPlaceholderController: ItemListController {
    init(context: AccountContext) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let updatedPresentationData = context.sharedContext.presentationData
        |> map(ItemListPresentationData.init)

        let state = context.sharedContext.presentationData
        |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let entries = minigramCallsPlaceholderEntries(presentationData: presentationData)
            let tabBarItem = ItemListControllerTabBarItem(
                title: "Minigram Calls",
                image: UIImage(bundleImageName: "Chat List/Tabs/IconCalls"),
                selectedImage: UIImage(bundleImageName: "Chat List/Tabs/IconCalls")
            )
            let controllerState = ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text("Minigram Calls"),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                tabBarItem: tabBarItem,
                animateChanges: false
            )
            let listState = ItemListNodeState(
                presentationData: ItemListPresentationData(presentationData),
                entries: entries,
                style: .blocks,
                emptyStateItem: nil,
                crossfadeState: false,
                animateChanges: false,
                scrollEnabled: true
            )
            return (controllerState, (listState, ()))
        }

        super.init(
            presentationData: ItemListPresentationData(presentationData),
            updatedPresentationData: updatedPresentationData,
            state: state,
            tabBarItem: nil,
            hideNavigationBarBackground: false
        )

        let icon = UIImage(bundleImageName: "Chat List/Tabs/IconCalls")
        self.tabBarItem.title = "Minigram Calls"
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
        if !presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabCalls"
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
