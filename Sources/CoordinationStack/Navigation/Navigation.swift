import SwiftUI


public protocol GlobalDestination { }
public protocol ComponentEvent { }

public protocol Navigation {
    @MainActor func global(destination: some GlobalDestination, style: NavigationPresenter.Style)
}

public protocol EmitNavigationEvent {
    @MainActor func after(event componentEvent: some ComponentEvent)
}

protocol NavigationExtra {
    @MainActor func pop(toRoot: Bool)
    @MainActor func dismissRoot()
}

public struct NavigationProxy: Sendable, Navigation, EmitNavigationEvent, NavigationExtra {
    
    let coordinator: CoordinatorProxy
    
    let globalDestination: @MainActor (GlobalDestination, NavigationPresenter.Style) -> Void
    let componentEvent: @MainActor (ComponentEvent) -> Void
    
    @MainActor
    public func global(destination: some GlobalDestination, style: NavigationPresenter.Style) {
        self.globalDestination(destination, style)
    }
    
    @MainActor
    public func after(event componentEvent: some ComponentEvent) {
        self.componentEvent(componentEvent)
    }
    
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
    
    let navigationProxy: NavigationProxy
    
    @MainActor
    public func global(destination: some GlobalDestination, style: NavigationPresenter.Style) {
        navigationProxy.global(destination: destination, style: style)
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

extension NavigationProxy {
    static let unsupported = NavigationProxy(coordinator: .unsupported) { destination,_ in
        assertionFailure("⚠️ Using NavigationProxy, to navigate \(String(describing: destination)) global destination, outside of the CoordinationStack.")
    } componentEvent: { event in
        assertionFailure("⚠️ Using NavigationProxy, to report component event \(String(describing: event)), outside of the CoordinationStack.")
    }
}

public extension EnvironmentValues {
    @Entry var navigate: NavigationProxy = .unsupported
}
