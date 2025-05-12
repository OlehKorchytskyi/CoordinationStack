import SwiftUI


public struct DismissRootProxy: Sendable {
    public internal(set) var supported: Bool = true
    public let dismiss: @MainActor @Sendable () -> Void
    
    @MainActor
    public func callAsFunction() {
        guard supported else {
            assertionFailure("⚠️ Using DismissRootProxy outside of the CoordinationStack")
            return
        }
        dismiss()
    }
}

extension DismissRootProxy {
    static let unsupported = DismissRootProxy(
        supported: false,
        dismiss: { }
    )
}

public extension EnvironmentValues {
    @Entry var dismissRoot: DismissRootProxy = .unsupported
}
