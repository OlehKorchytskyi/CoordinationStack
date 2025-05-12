import SwiftUI


/// Used by popups to override popup.dismiss(). For example, popup can have specific closing animation, which it needs to play before dismissal.
public struct PopupDismissalOverride: Equatable, Sendable {
    
    /// Not overwritten popup dismissal does nothing and just calls dismissal closure to dismiss popup
    static let notOverridden = PopupDismissalOverride(dismissal: { $0() })
    
    // Overridden popup dismissal REQUIRED to call dismissal closure after they finished
    static func overridden(_ dismissal: @MainActor @Sendable @escaping (@escaping SuperCall) -> Void) -> PopupDismissalOverride {
        PopupDismissalOverride(dismissal: dismissal)
    }
    
    typealias SuperCall = @MainActor () -> Void
    private let dismissal: @MainActor @Sendable (@escaping SuperCall) -> Void
    
    private init(dismissal: @MainActor @escaping @Sendable (@escaping SuperCall) -> Void) {
        self.dismissal = dismissal
    }
    
    private let id = UUID()
    
    public static func == (lhs: PopupDismissalOverride, rhs: PopupDismissalOverride) -> Bool {
        lhs.id == rhs.id
    }
}

public extension PopupDismissalOverride {
    
    /// Call this from the root of Coordination stack and pass the closure which performs standard popup dismiss.
    /// Closure will be executed when popup finished closing.
    /// 
    /// - Parameter dismissAction: closure which dismisses popup;
    @MainActor func perform(dismissAction: @MainActor @escaping () -> Void) {
        dismissal(dismissAction)
    }
}

enum PopupDismissalOverrideKey: PreferenceKey {
    static let defaultValue: PopupDismissalOverride = .notOverridden
    
    static func reduce(value: inout PopupDismissalOverride, nextValue: () -> PopupDismissalOverride) {
        value = nextValue()
    }
}
