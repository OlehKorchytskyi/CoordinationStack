import SwiftUI

public struct PopupProxy: Sendable {
    public let supported: Bool
    
    public let popup: @MainActor @Sendable (Popup) -> Void
    
    public typealias DismissCallback = @MainActor () -> Void
    private let dismissPopup: @MainActor @Sendable (DismissCallback?) -> Void
    
    fileprivate init(
        supported: Bool,
        popup: @escaping @MainActor @Sendable (Popup) -> Void,
        dismissPopup: @escaping @MainActor @Sendable (DismissCallback?) -> Void
    ) {
        self.supported = supported
        self.popup = popup
        self.dismissPopup = dismissPopup
    }
    
    init(
        popup: @escaping @MainActor @Sendable (Popup) -> Void,
        dismissPopup: @escaping @MainActor @Sendable (DismissCallback?) -> Void
    ) {
        self.supported = true
        self.popup = popup
        self.dismissPopup = dismissPopup
    }

    
    @MainActor
    private func callAsFunction<ID: Hashable, Popup: View>(
        id: ID,
        @ViewBuilder body: @escaping @MainActor (GeometryProxy) -> Popup,
        task: (@MainActor @Sendable () async -> Void)? = nil
    ) {
        guard supported else {
            assertionFailure("⚠️ Using PopupProxy outside of the CoordinationStack")
            return
        }
        
        let opaqueTask: (@MainActor @Sendable () async -> Void)? = if let task {
            { await task() }
        } else {
            nil
        }
        
        popup(PopupProxy.Popup(id: id, task: opaqueTask) {
            AnyView(body($0))
        })
    }
    
    @MainActor
    public func callAsFunction<Popup: View>(
        @ViewBuilder _ body: @escaping @MainActor (GeometryProxy) -> Popup,
        task: (@MainActor @Sendable () async -> Void)? = nil
    ) {
        let opaqueTask: (@MainActor @Sendable () async -> Void)? = if let task {
            { await task() }
        } else {
            nil
        }
        
        callAsFunction(id: UUID(), body: { body($0) }, task: opaqueTask)
    }
    
    @MainActor public func dismiss(_ completion: DismissCallback?) {
        guard supported else {
            assertionFailure("⚠️ Using PopupProxy outside of the CoordinationStack")
            return
        }
        
        dismissPopup(completion)
    }
}

extension PopupProxy {
    public struct Popup: Identifiable {
        public let id: AnyHashable
        public let task: (@MainActor @Sendable () async -> Void)?
        @ViewBuilder public let body: @MainActor (GeometryProxy) -> AnyView
    }
}

extension PopupProxy {
    static let unsupported = PopupProxy(
        supported: false,
        popup: { _ in },
        dismissPopup: { _ in }
    )
}

public extension EnvironmentValues {
    @Entry var popup: PopupProxy = .unsupported
}
