import SwiftUI


struct ComponentEventHandlerRegistry: Sendable, Equatable {
    
    typealias EventHandler = @MainActor (ComponentEvent, NavigateProxy) -> Void
    var registry: [ObjectIdentifier : EventHandler] = [:]
    
    @MainActor
    func handleEvent<Event: ComponentEvent>(_ event: Event, using navigate: NavigateProxy) {
        if let dedicatedHandler = registry[ObjectIdentifier(Event.self)] {
            dedicatedHandler(event, navigate)
        } else {
            assertionFailure("""
            ⚠️ Unhandled component event \(String(describing: event)). Use view modifier to navigation events:
            <view>.handleComponentEvent(for: \(String(describing: Event.self)).self) { event, navigate in
                switch event {
                    
                }
            }
            
            """)
        }
    }
    
    mutating func support<Event: ComponentEvent>(event: Event.Type, _ handler: @escaping EventHandler) {
        registry[ObjectIdentifier(Event.self)] = handler
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.registry.keys == rhs.registry.keys
    }
}

extension ComponentEventHandlerRegistry {
    static let unhandled = ComponentEventHandlerRegistry()
}

extension EnvironmentValues {
    @Entry var componentEventHandlerRegistry: ComponentEventHandlerRegistry = .unhandled
}


struct _ComponentEventHandlerModifier<Event: ComponentEvent>: ViewModifier {
    
    let handleComponentEvent: @MainActor (ComponentEvent, NavigateProxy) -> Void
    
    func body(content: Content) -> some View {
        content
            .transformEnvironment(\.componentEventHandlerRegistry) { eventHandler in
                eventHandler.support(event: Event.self, handleComponentEvent)
            }
            .transformPreference(NestedComponentEventHandlerRegistryKey.self) { preference in
                preference.support(event: Event.self, handleComponentEvent)
            }
    }
}


public extension View {
    func handleComponentEvent<Event: ComponentEvent>(
        for eventType: Event.Type,
        _ eventHandler: @escaping @MainActor (Event, any Navigation) -> Void
    ) -> some View {
        modifier(_ComponentEventHandlerModifier<Event>(handleComponentEvent: { event, navigate in
            if let event = event as? Event {
                eventHandler(event, navigate)
            } else {
                assertionFailure("""
                ⚠️ Component event type mismatch. 
                Expected: \(String(describing: Event.self)) 
                Received: \(String(describing: type(of: event)))
                """)
            }
        }))
    }
}

enum NestedComponentEventHandlerRegistryKey: PreferenceKey {
    static let defaultValue: ComponentEventHandlerRegistry = .unhandled
    
    static func reduce(value: inout ComponentEventHandlerRegistry, nextValue: () -> ComponentEventHandlerRegistry) {
        value.registry.merge(nextValue().registry, uniquingKeysWith: { current, _ /*new*/ in current })
    }
}
