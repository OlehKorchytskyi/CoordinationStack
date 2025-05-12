import SwiftUI


struct CoordinatorProxy: Sendable {
    let push: PushProxy
    let pop: PopProxy
    let sheet: SheetProxy
    let fullScreenSheet: SheetProxy
    let popup: PopupProxy
    let dismissRoot: DismissRootProxy
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
