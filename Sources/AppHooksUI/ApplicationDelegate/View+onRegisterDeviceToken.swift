import SwiftUI

#if os(iOS)
extension View {
    /// Handles the APNs device token or registration error.
    ///
    /// A result that arrives before any view subscribes is kept and delivered
    /// once, to the first subscriber.
    @MainActor
    public func onRegisterDeviceToken(
        _ handler: @escaping @MainActor (Result<Data, Error>) -> Void
    ) -> some View {
        modifier(ReceiveDeviceTokenViewModifier(handler: handler))
    }
}

@MainActor
private struct ReceiveDeviceTokenViewModifier: ViewModifier {
    @EnvironmentObject private var appDelegate: ApplicationDelegate
    let handler: @MainActor (Result<Data, Error>) -> Void

    func body(content: Content) -> some View {
        content.onReceive(appDelegate.deviceTokenEvents, perform: handler)
    }
}
#endif
