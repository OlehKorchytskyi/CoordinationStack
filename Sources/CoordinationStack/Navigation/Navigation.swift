import SwiftUI


public protocol GlobalDestination { }
public protocol ComponentEvent { }

public protocol Navigation {
    @MainActor func global(destination: some GlobalDestination, style: NavigationPresenter.Style)
}

public protocol EmitsNavigationEvent {
    @MainActor func after(event componentEvent: some ComponentEvent)
}

protocol NavigationExtra {
    @MainActor func pop(toRoot: Bool)
    @MainActor func dismissRoot()
}

public struct NavigationProxy: Sendable, Navigation, EmitsNavigationEvent, NavigationExtra {
    
    let coordinator: CoordinatorProxy
    let navigate: NavigateProxy
    let emitEvent: EmitNavigationEventProxy
    
    
    // MARK: Navigation
    @MainActor
    public func global(destination: some GlobalDestination, style: NavigationPresenter.Style) {
        navigate.global(destination: destination, style: style)
    }
    
    // MARK: EmitNavigationEvent
    @MainActor
    public func after(event componentEvent: some ComponentEvent) {
        emitEvent.after(event: componentEvent)
    }
    
    // MARK: NavigationExtra
    @MainActor
    public func pop(toRoot: Bool = false) {
        coordinator.pop(toRoot: toRoot)
    }
    
    @MainActor
    public func dismissRoot() {
        coordinator.dismissRoot()
    }
}

public struct NavigateProxy: Sendable, Navigation {
    
    let globalDestination: @MainActor @Sendable (GlobalDestination, NavigationPresenter.Style) -> Void
    
    @MainActor
    public func global(destination: some GlobalDestination, style: NavigationPresenter.Style) {
        self.globalDestination(destination, style)
    }
}

public struct EmitNavigationEventProxy: Sendable, EmitsNavigationEvent {
    
    let componentEvent: @MainActor @Sendable (ComponentEvent) -> Void
    
    @MainActor
    public func after(event componentEvent: some ComponentEvent) {
        self.componentEvent(componentEvent)
    }
}

public struct NavigationPresenter: Sendable {
    
    public enum Style: Sendable {
        case push
        case sheet
        case fullScreenSheet
    }
    
    let style: Style
    let coordinator: CoordinatorProxy
    
    @MainActor
    public func present<Destination: View>(@ViewBuilder _ destination: @escaping @MainActor () -> Destination) {
        switch style {
        case .push:
            coordinator.push(destination)
        case .sheet:
            coordinator.sheet(destination)
        case .fullScreenSheet:
            coordinator.fullScreenSheet(destination)
        }
    }
    
    @MainActor
    public func callAsFunction<Destination: View>(@ViewBuilder _ destination: @escaping @MainActor () -> Destination) {
        present(destination)
    }
}

extension NavigateProxy {
    static let unsupported = NavigateProxy { destination, _ in
        assertionFailure("⚠️ Using NavigateProxy, to navigate \(String(describing: destination)) global destination, outside of the CoordinationStack.")
    }
}

extension EmitNavigationEventProxy {
    static let unsupported = EmitNavigationEventProxy { event in
        assertionFailure("⚠️ Using EmitNavigationEventProxy, to report component event \(String(describing: event)), outside of the CoordinationStack.")
    }
}

extension NavigationProxy {
    public static let unsupported = NavigationProxy(
        coordinator: .unsupported,
        navigate: .unsupported,
        emitEvent: .unsupported
    )
}

public extension EnvironmentValues {
    @Entry var navigate: NavigationProxy = .unsupported
}
