import Foundation
import XCTest

#if os(iOS)
let isIOS = true
#elseif os(tvOS)
let isIOS = false
#endif

let isSimulator = ProcessInfo().environment["SIMULATOR_UDID"] != nil

class SnapshotHelper: NSObject {
    static let shared = SnapshotHelper()

    func snapshot(_ name: String, delay: Int = 0, waitForLoadingIndicator: Bool = true) {
        if waitForLoadingIndicator {
            waitForLoadingIndicatorToDisappear()
        }

        sleep(UInt32(delay))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        attachment.name = name

        XCTestCase.currentTestCase?.add(attachment)
    }

    private func waitForLoadingIndicatorToDisappear() {
        let networkLoadingIndicator = XCUIApplication().statusBars.networkLoadingIndicators.element
        while networkLoadingIndicator.exists {
            sleep(1)
        }
    }
}

extension XCUIElement {
    var networkLoadingIndicators: XCUIElementQuery {
        if #available(iOS 13.0, tvOS 13.0, *) {
            return XCUIApplication().otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] 'network'"))
        }
        return statusBars.matchingIdentifiers(XCUIIdentifier.networkLoadingIndicator.rawValue)
    }
}

extension XCUIElementQuery {
    func matchingIdentifiers(_ identifiers: [String]) -> XCUIElementQuery {
        var query = self
        for identifier in identifiers {
            query = query.matching(NSPredicate(format: "identifier == %@", identifier))
        }
        return query
    }

    func matchingIdentifiers(_ identifier: String) -> XCUIElementQuery {
        return matching(NSPredicate(format: "identifier == %@", identifier))
    }
}

func snapshot(_ name: String, delay: Int = 0, waitForLoadingIndicator: Bool = true) {
    SnapshotHelper.shared.snapshot(name, delay: delay, waitForLoadingIndicator: waitForLoadingIndicator)
}

extension XCUIApplication {
    func statusBars: XCUIElementQuery {
        return otherElements.matching(NSPredicate(format: "type == 'XCUIElementTypeStatusBar'"))
    }

    @available(iOS 13.0, tvOS 13.0, *)
    var networkLoadingIndicators: XCUIElementQuery {
        return otherElements.matching(NSPredicate(format: "identifier CONTAINS[c] 'network'"))
    }
}

extension XCUIElement {
    var statusBars: XCUIElementQuery {
        if let app = self as? XCUIApplication {
            return app.statusBars
        }
        return XCUIApplication().statusBars
    }
}
