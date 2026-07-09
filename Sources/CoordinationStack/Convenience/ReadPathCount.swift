import SwiftUI

extension View {
    /// Calls `onPathCountChange` when a nested `CoordinationStack` publishes a new navigation path count.
    ///
    /// Attach this modifier above the `CoordinationStack` you want to observe.
    /// The reported value is `nil` when there is no nested `CoordinationStack`.
    ///
    /// ```swift
    /// VStack {
    ///     CoordinationStack {
    ///         RootView()
    ///     }
    /// }
    /// .coordinationStackPathCountChanged { count in
    ///     print(count)
    /// }
    /// ```
    public func coordinationStackPathCountChanged(_ onPathCountChange: @escaping @MainActor (_ count: Int?) -> Void) -> some View {
        onPreferenceChange(CoordinationStackPathCountKey.self) { count in
            onPathCountChange(count)
        }
    }
}
