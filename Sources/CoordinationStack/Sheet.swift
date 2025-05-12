import SwiftUI


public struct SheetProxy: Sendable {
    public private(set) var supported: Bool = true
    public let sheet: @MainActor @Sendable (Destination?) -> Void

    @MainActor
    private func callAsFunction<ID: Hashable, Destination: View>(id: ID, @ViewBuilder destination: @escaping @MainActor () -> Destination) {
        guard supported else {
            assertionFailure("⚠️ Using SheetProxy outside of the CoordinationStack")
            return
        }
        
        let destination = SheetProxy.Destination(id: id) {
            AnyView(destination())
        }
        
        sheet(destination)
    }
    
    @MainActor
    public func callAsFunction<Destination: View>(@ViewBuilder _ destination: @escaping @MainActor () -> Destination) {
        self(id: UUID(), destination: { destination() })
    }
    
    @MainActor
    public func dismiss() {
        guard supported else {
            assertionFailure("⚠️ Using SheetProxy outside of the CoordinationStack")
            return
        }
        
        sheet(nil)
    }
}

extension SheetProxy {
    public struct Destination: Identifiable {
        public let id: AnyHashable
        @ViewBuilder public let root: @MainActor () -> AnyView
    }
}

extension SheetProxy {
    static let unsupported = SheetProxy(supported: false, sheet: { _ in })
}

public extension EnvironmentValues {
    @Entry var sheet: SheetProxy = .unsupported
}



