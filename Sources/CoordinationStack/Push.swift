import SwiftUI


public struct PushProxy: @unchecked Sendable {
    
    public private(set) var supported: Bool = true
    public var path: Binding<NavigationPath>
    
    @MainActor
    private func callAsFunction<ID: Hashable, Destination: View>(id: ID, @ViewBuilder destination: () -> Destination) {
        guard supported else {
            assertionFailure("⚠️ Using PushProxy outside of the CoordinationStack")
            return
        }
        
        let view = AnyView(destination())
        
        let destination = PushProxy.Destination(id: id, root: view)
        
        path.wrappedValue.append(destination)
    }
    
    @MainActor
    public func callAsFunction<Destination: View>(@ViewBuilder _ destination: () -> Destination) {
        callAsFunction(id: UUID(), destination: destination)
    }
}

extension PushProxy {
    public struct Destination: Identifiable, Hashable {
        
        public let id: AnyHashable
        let root: AnyView
        
        public static func == (lhs: PushProxy.Destination, rhs: PushProxy.Destination) -> Bool {
            lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
}

extension PushProxy {
    static let unsupported = PushProxy(supported: false, path: .constant(NavigationPath()))
}

public extension EnvironmentValues {
    @Entry var push: PushProxy = .unsupported
}

