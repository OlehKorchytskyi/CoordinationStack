import SwiftUI


public struct PopProxy: @unchecked Sendable {
    public private(set) var supported: Bool = true
    public var path: Binding<NavigationPath>

    @MainActor
    public func callAsFunction(toRoot: Bool = false) {
        guard supported else {
            assertionFailure("⚠️ Using PopProxy outside of the CoordinationStack")
            return
        }
        
        while path.wrappedValue.count >= 1 {
            path.wrappedValue.removeLast()
            if toRoot == false { break }
        }
    }
    
    @MainActor public func toRoot() {
        self(toRoot: true)
    }
}

extension PopProxy {
    static let unsupported = PopProxy(supported: false, path: .constant(NavigationPath()))
}

public extension EnvironmentValues {
    @Entry var pop: PopProxy = .unsupported
}
