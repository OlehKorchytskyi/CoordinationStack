import SwiftUI


public struct CoordinatorProxy: Sendable {
    public let push: PushProxy
    public let pop: PopProxy
    public let sheet: SheetProxy
    public let fullScreenSheet: SheetProxy
    public let popup: PopupProxy
    public let dismissRoot: DismissRootProxy
}

extension CoordinatorProxy {
    static let unsupported = CoordinatorProxy(
        push: .unsupported,
        pop: .unsupported,
        sheet: .unsupported,
        fullScreenSheet: .unsupported,
        popup: .unsupported,
        dismissRoot: .unsupported
    )
}
