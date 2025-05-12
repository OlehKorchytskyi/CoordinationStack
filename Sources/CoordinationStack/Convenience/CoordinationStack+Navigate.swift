import SwiftUI

extension CoordinationStack {
    @_disfavoredOverload
    public init<Content: View>(@ViewBuilder _ content: @escaping (NavigationProxy) -> Content) where Root == _ExposedNavigationProxyView<Content> {
        self = CoordinationStack {
            _ExposedNavigationProxyView(content: content)
        }
    }
}

public struct _ExposedNavigationProxyView<Content: View>: View {
    
    let content: (NavigationProxy) -> Content
    
    @Environment(\.navigate) var navigate
    
    public var body: some View {
        content(navigate)
    }
}
