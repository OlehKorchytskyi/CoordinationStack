import SwiftUI


struct NavigationHandlerRegistry: Sendable, Equatable {
    
    typealias NavigationHandler = @MainActor (GlobalDestination, NavigationPresenter) -> Void
    var registry: [ObjectIdentifier : NavigationHandler] = [:]
    
    func canNavigate<Destination: GlobalDestination>(_ destination: Destination, using presenter: NavigationPresenter) -> Bool {
        registry[ObjectIdentifier(Destination.self)] != nil
    }
    
    @MainActor
    func navigate<Destination: GlobalDestination>(_ destination: Destination, using presenter: NavigationPresenter) {
        if let dedicatedHandler = registry[ObjectIdentifier(Destination.self)] {
            dedicatedHandler(destination, presenter)
        } else {
            assertionFailure("""
            ⚠️ Unhandled navigation request for \(String(describing: destination)). Use view modifier to handle global navigation: 
            <view>.navigateGlobalDestination(for: \(String(describing: Destination.self)).self) { destination, presenter in
                switch destination {
                    
                }
            }
            
            """)
        }
    }
    
    mutating func support<Destination: GlobalDestination>(destination: Destination.Type, _ handler: @escaping NavigationHandler) {
        registry[ObjectIdentifier(Destination.self)] = handler
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.registry.keys == rhs.registry.keys
    }
}

extension NavigationHandlerRegistry {
    static let unhandled = NavigationHandlerRegistry()
}

extension EnvironmentValues {
    @Entry var navigationHandlerRegistry: NavigationHandlerRegistry = .unhandled
}

struct _NavigationControllerModifier<Destination: GlobalDestination>: ViewModifier {
    
    let navigateDestination: @MainActor (GlobalDestination, NavigationPresenter) -> Void
    
    func body(content: Content) -> some View {
        content
            .transformEnvironment(\.navigationHandlerRegistry) { navigationHandlerRegistry in
                navigationHandlerRegistry.support(destination: Destination.self, navigateDestination)
            }
            .transformPreference(NestedNavigationHandlerRegistryKey.self) { preference in
                preference.support(destination: Destination.self, navigateDestination)
            }
    }
}

public extension View {
    func navigateGlobalDestination<Destination: GlobalDestination>(
        for destinationType: Destination.Type,
        _ navigate: @escaping @MainActor (Destination, NavigationPresenter) -> Void
    ) -> some View {
        modifier(_NavigationControllerModifier<Destination>(navigateDestination: { destination, presenter in
            if let destination = destination as? Destination {
                navigate(destination, presenter)
            } else {
                assertionFailure("""
                ⚠️ Global destination type mismatch. 
                Expected: \(String(describing: Destination.self)) 
                Received: \(String(describing: type(of: destination)))
                """)
            }
        }))
    }
}

enum NestedNavigationHandlerRegistryKey: PreferenceKey {
    static let defaultValue: NavigationHandlerRegistry = .unhandled
    
    static func reduce(value: inout NavigationHandlerRegistry, nextValue: () -> NavigationHandlerRegistry) {
        value.registry.merge(nextValue().registry, uniquingKeysWith: { current, _ /*new*/ in current })
    }
}
