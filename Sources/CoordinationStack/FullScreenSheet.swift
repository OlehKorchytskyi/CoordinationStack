import SwiftUI

public extension EnvironmentValues {
    @Entry var fullScreenSheet = SheetProxy(supported: false, sheet: { _ in })
}
