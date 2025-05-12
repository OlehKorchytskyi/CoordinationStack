import SwiftUI

/**
 A container view that manages coordinated navigation and presentation (push, pop, sheets, full-screen covers, and popups) for its child content.
 
 Use **CoordinationStack** as a replacement for **NavigationStack**.

 Example:
 ```swift
 CoordinationStack {
     ContentView()
 }
 ```
 
 Child View Usage:
 ```swift
 struct ContentView: View {
     @Environment(\.push) private var push
     @Environment(\.sheet) private var sheet
     @Environment(\.popup) private var popup
 
     @Environment(\.fullScreenSheet) private var fullScreenSheet // presents full-screen sheet
     @Environment(\.pop) private var pop // pops the current view in the navigation stack (goes back)
     @Environment(\.dismissRoot) // dismisses view at the navigation stack level

     var body: some View {
         VStack {
             Button("Push Detail") {
                 push {
                    DetailView()
                 }
             }
             Button("Show Modal") {
                 sheet {
                     ModalView()
                 }
             }
             Button("Show Popup") {
                 popup { container in
                     PopupContent()
                 }
             }
         }
     }
 }
 ```
 */
public struct CoordinationStack<Root: View>: View {
    
    @ViewBuilder let root: () -> Root

    /// Creates a `CoordinationStack` that wraps the provided root view for coordinated presentation.
    /// - Parameter root: A closure returning the root view.
    public init(@ViewBuilder _ root: @escaping () -> Root) {
        self.root = root
    }
    
    @Environment(\.currentCoordinator) private var currentCoordinator
    
    /// The view content, showing either the coordinated stack with navigation and presentation proxies
    /// or the root content when already within a coordination context.
    @ViewBuilder
    public var body: some View {
        if let _ = currentCoordinator {
            root()
        } else {
            coordinatedStack
                // Popups support
                .overlay(alignment: .top) {
                    popups
                }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var sheetItem: SheetProxy.Destination? = nil
    @State private var fullScreenSheetItem: SheetProxy.Destination? = nil
    
    private var coordinatedStack: some View {
        let coordinator = CoordinatorProxy(
            push: pushProxy,
            pop: popProxy,
            sheet: sheetProxy,
            fullScreenSheet: fullScreenCoverProxy,
            popup: popupProxy,
            dismissRoot: dismissRootProxy,
        )
        
        return navigationStack
            .coordinationContext(for: coordinator, navigation: navigationProxy)
            // Sheet navigation support
            .sheet(item: $sheetItem) { item in
                item.root()
                    // Breaking presenter's coordination context
                    .clearCoordinationContext()
                    // This helps to fix sheet appearance with correct detents,
                    // and also fixes preferences propagation
                    .id(item.id)
            }
            .fullScreenCover(item: $fullScreenSheetItem) { item in
                item.root()
                    // Breaking presenter's coordination context
                    .clearCoordinationContext()
                    // This helps to fix sheet appearance with correct detents,
                    // and also fixes preferences propagation
                    .id(item.id)
            }
    }
    
    private var dismissRootProxy: DismissRootProxy {
        DismissRootProxy { dismiss() }
    }
    
    // MARK: Navigation Stack
    
    @State private var path = NavigationPath()
    
    private var navigationStack: some View {
        NavigationStack(path: $path) {
            root()
                .navigationDestination(for: PushProxy.Destination.self) { destination in
                    destination.root()
                }
        }
        .onPreferenceChange(NestedNavigationHandlerRegistryKey.self) { [$nestedNavigationHandlerRegistry] registry in
            // Capturing state binding, for handling preference change, is the suggested approach by Apple engineers:
            // https://stackoverflow.com/a/79273163
            $nestedNavigationHandlerRegistry.wrappedValue = registry
        }
        .transformPreference(NestedNavigationHandlerRegistryKey.self) {
            // Clearing nested navigation handler registry, since we handled it
            $0 = .unhandled
        }
        .onPreferenceChange(NestedComponentEventHandlerRegistryKey.self) { [$nestedComponentEventHandlerRegistry] registry in
            // Capturing state binding, for handling preference change, is the suggested approach by Apple engineers:
            // https://stackoverflow.com/a/79273163
            $nestedComponentEventHandlerRegistry.wrappedValue = registry
        }
        .transformPreference(NestedComponentEventHandlerRegistryKey.self) {
            // Clearing nested navigation handler registry, since we handled it
            $0 = .unhandled
        }
    }
    
    @State private var nestedNavigationHandlerRegistry: NavigationHandlerRegistry = .unhandled
    @State private var nestedComponentEventHandlerRegistry: ComponentEventHandlerRegistry = .unhandled
    
    @Environment(\.navigationHandlerRegistry) private var navigationHandlerRegistry
    @Environment(\.componentEventHandlerRegistry) private var componentEventHandlerRegistry
    
    private var navigationProxy: NavigationProxy {
        let coordinator = CoordinatorProxy(
            push: pushProxy,
            pop: popProxy,
            sheet: sheetProxy,
            fullScreenSheet: fullScreenCoverProxy,
            popup: popupProxy,
            dismissRoot: dismissRootProxy
        )
        
        return NavigationProxy(coordinator: coordinator) { destination, style in
            let presenter = NavigationPresenter(style: style, coordinator: coordinator)
            
            if navigationHandlerRegistry.canNavigate(destination, using: presenter) {
                // Handling navigation using handler from outside (above) CoordinationStack
                navigationHandlerRegistry.navigate(destination, using: presenter)
            } else if nestedNavigationHandlerRegistry.canNavigate(destination, using: presenter) {
                // Handling navigation using nested handler from CoordinationStack stack
                nestedNavigationHandlerRegistry.navigate(destination, using: presenter)
            } else {
                assertionFailure("""
                ⚠️ Unhandled navigation request for \(String(describing: destination)). Use view modifier to handle global navigation: 
                <view>.navigateGlobalDestination(for: \(String(describing: type(of: destination))).self) { destination, presenter in
                    switch destination {
                        
                    }
                }
                
                """)
            }
        } componentEvent: { event in
            let navigationProxy = NavigateProxy(navigationProxy: self.navigationProxy)
            componentEventHandlerRegistry.handleEvent(event, using: navigationProxy)
        }
    }
    
    private var sheetProxy: SheetProxy {
        SheetProxy(sheet: { self.sheetItem = $0 })
    }
    
    private var fullScreenCoverProxy: SheetProxy {
        SheetProxy(sheet: { self.fullScreenSheetItem = $0 })
    }
    
    private var pushProxy: PushProxy {
        PushProxy(path: $path)
    }
    
    private var popProxy: PopProxy {
        PopProxy(path: $path)
    }
    
    // MARK: Popups
    @State private var popup: PopupProxy.Popup?
    @State private var dismissPopup: PopupDismissalOverride = .notOverridden
    
    private var popupProxy: PopupProxy {
        PopupProxy { newPopup in
            // Checking if there is already presented popup
            if let _ = popup {
                // Calling overwritten dismissal for currently presented popup
                dismissPopup.perform {
                    // Dismissing current
                    self.popup = nil
                    // presenting new one
                    self.popup = newPopup
                }
            } else {
                self.popup = newPopup
            }
        } dismissPopup: { completion in
            // Calling overwritten dismissal
            dismissPopup.perform {
                // Dismissing popup
                self.popup = nil
                completion?()
            }
        }
    }
    
    private var popups: some View {
        GeometryReader { container in
            if let popup {
                popup.body(container)
                    // Giving popup view just popup proxy
                    .environment(\.popup, popupProxy)
            }
        }
        // Performing task for current popup
        .task(id: popup?.id) {
            await popup?.task?()
        }
        // Breaking presenter's coordination context
        .clearCoordinationContext()
        // Supporting popup custom dismissal behaviour
        .onPreferenceChange(PopupDismissalOverrideKey.self) { [$dismissPopup] popupDismissal in
            // Capturing state binding, for handling preference change, is the suggested approach by Apple engineers:
            // https://stackoverflow.com/a/79273163
            
            // Capturing overriten popup dismissal
            $dismissPopup.wrappedValue = popupDismissal
        }
        .transformPreference(PopupDismissalOverrideKey.self) { popupDismissal in
            // Clearing overwritten popup dismissal, since we handled it
            popupDismissal = .notOverridden
        }
    }
}

extension EnvironmentValues {
    @Entry var currentCoordinator: CoordinatorProxy?
}


// MARK: - Helpers

private struct _WithCoordinationContext: ViewModifier {
    
    let coordinator: CoordinatorProxy
    let navigation: NavigationProxy
    
    func body(content: Content) -> some View {
        content
            .environment(\.fullScreenSheet, coordinator.fullScreenSheet)
            .environment(\.sheet, coordinator.sheet)
            .environment(\.popup, coordinator.popup)
            .environment(\.push, coordinator.push)
            .environment(\.pop, coordinator.pop)
            .environment(\.dismissRoot, coordinator.dismissRoot)
            .environment(\.navigate, navigation)
            .environment(\.currentCoordinator, coordinator)
    }
}

private struct _WithoutCoordinationContext: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.fullScreenSheet, .unsupported)
            .environment(\.sheet, .unsupported)
            .environment(\.popup, .unsupported)
            .environment(\.push, .unsupported)
            .environment(\.pop, .unsupported)
            .environment(\.dismissRoot, .unsupported)
            .environment(\.navigate, .unsupported)
            .environment(\.currentCoordinator, nil)
    }
}

private extension View {
    func coordinationContext(for coordinator: CoordinatorProxy, navigation: NavigationProxy) -> some View {
        modifier(_WithCoordinationContext(coordinator: coordinator, navigation: navigation))
    }
    
    func clearCoordinationContext() -> some View {
        modifier(_WithoutCoordinationContext())
    }
}
