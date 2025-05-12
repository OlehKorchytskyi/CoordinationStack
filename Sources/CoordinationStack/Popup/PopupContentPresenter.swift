import SwiftUI


public struct PopupContentPresenter<Content: View>: View {
    
    public let dimmed: Bool
    public let backgroundTapCancels: Bool
    
    @ViewBuilder
    public let content: (PopupContentPresenterProxy) -> Content
    
    public let animatingPresentation: (@MainActor () -> Void)?
    public let animatingDismissal: (@MainActor () -> Void)?
    
    public let onCancel: (@MainActor () -> Void)?
    public let onDismiss: (@MainActor () -> Void)?
    
    public init(
        dimmed: Bool,
        backgroundTapCancels: Bool = false,
        @ViewBuilder _ content: @escaping (PopupContentPresenterProxy) -> Content,
        animatingPresentation: (@MainActor () -> Void)? = nil,
        animatingDismissal: (@MainActor () -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil,
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        self.dimmed = dimmed
        self.backgroundTapCancels = backgroundTapCancels
        self.content = content
        self.animatingPresentation = animatingPresentation
        self.animatingDismissal = animatingDismissal
        self.onCancel = onCancel
        self.onDismiss = onDismiss
    }
    
    @State private var postDismissalAction: (@MainActor () -> Void)? = nil
    
    @Environment(\.popup) private var popup
    
    @State private var isContentPresented = false
    @State private var isCanceled = false
    
    public var body: some View {
        GeometryReader { container in
            if dimmed {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture {
                        if backgroundTapCancels {
                            cancel(nil)
                        }
                    }
            }
            
            if isContentPresented {
                content(proxy(for: container))
                    // Inserting presenter proxy to add support
                    // for child views to dismiss popup on its own
                    .environment(\.popupPresenter, proxy(for: container))
            }
        }
        .onAppear {
            withAnimation(presentAnimation) {
                isContentPresented = true
                animatingPresentation?()
            }
        }
        .preference(key: PopupDismissalOverrideKey.self, value: .overridden { dismiss in
            if #available(iOS 17.0, *) {
                withAnimation(dismissAnimation, completionCriteria: .logicallyComplete) {
                    isContentPresented = false
                    animatingDismissal?()
                } completion: {
                    dismiss()
                    if isCanceled {
                        onCancel?()
                    }
                    onDismiss?()
                    postDismissalAction?()
                }
            } else {
                withAnimation(dismissAnimation) {
                    isContentPresented = false
                    animatingDismissal?()
                }
                
                Task {
                    try await Task.sleep(for: .seconds(0.5))
                    dismiss()
                    if isCanceled {
                        onCancel?()
                    }
                    onDismiss?()
                    postDismissalAction?()
                }
            }
        })
    }

    private func proxy(for container: GeometryProxy) -> PopupContentPresenterProxy {
        PopupContentPresenterProxy(container: container) { postAction in
            cancel(postAction)
        } dismissAction: { postAction in
            dismiss(postAction)
        }

    }
    
    private func cancel(_ postAction: PopupContentPresenterProxy.PostDismissAction?) {
        isCanceled = true
        postDismissalAction = postAction
        popup.dismiss(nil)
    }
    
    private func dismiss(_ postAction: PopupContentPresenterProxy.PostDismissAction?) {
        isCanceled = false
        postDismissalAction = postAction
        popup.dismiss(nil)
    }
    
    private let presentAnimation: Animation = .smooth(duration: 0.34, extraBounce: 0.45)
    private let dismissAnimation: Animation = .smooth(duration: 0.25)
    
}

@MainActor
@dynamicMemberLookup
public struct PopupContentPresenterProxy {
    
    let container: GeometryProxy
    
    public typealias PostDismissAction = @MainActor () -> Void
    
    private let cancelAction: (PostDismissAction?) -> Void
    private let dismissAction: (PostDismissAction?) -> Void
    
    init(
        container: GeometryProxy,
        cancelAction: @escaping (PostDismissAction?) -> Void,
        dismissAction: @escaping (PostDismissAction?) -> Void
    ) {
        self.container = container
        self.cancelAction = cancelAction
        self.dismissAction = dismissAction
    }
    
    public func cancel(_ completion: PostDismissAction? = nil) {
        cancelAction(completion)
    }
    
    public func dismiss(_ completion: PostDismissAction? = nil) {
        dismissAction(completion)
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<GeometryProxy, T>) -> T {
        container[keyPath: keyPath]
    }
    
}

public extension EnvironmentValues {
    @Entry var popupPresenter: PopupContentPresenterProxy?
}
