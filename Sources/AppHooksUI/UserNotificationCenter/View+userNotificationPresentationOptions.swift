import SwiftUI
import UserNotifications

extension View {
    /// Registers an asynchronous foreground-notification presentation policy
    /// for the lifetime of this view.
    @MainActor
    public func userNotificationPresentationOptions(
        _ presentationOptions: @escaping @Sendable (UNNotification) async -> UNNotificationPresentationOptions
    ) -> some View {
        modifier(PresentUserNotificationViewModifier(presentationOptions))
    }

    /// Registers a fixed foreground-notification presentation policy for the
    /// lifetime of this view.
    @MainActor
    public func userNotificationPresentationOptions(
        _ options: UNNotificationPresentationOptions
    ) -> some View {
        modifier(PresentUserNotificationViewModifier { _ in options })
    }
}

@MainActor
private struct PresentUserNotificationViewModifier: ViewModifier {
    @EnvironmentObject private var delegate: ApplicationDelegate
    @State private var registrationID: UUID?

    private let policyRevision = UUID()
    let presentationOptions: @Sendable (UNNotification) async -> UNNotificationPresentationOptions

    init(_ presentationOptions: @escaping @Sendable (UNNotification) async -> UNNotificationPresentationOptions) {
        self.presentationOptions = presentationOptions
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard registrationID == nil else { return }
                registrationID = delegate.userNotificationCenter.registerPresentationHandler(presentationOptions)
            }
            .onChange(of: policyRevision) {
                guard let registrationID else { return }
                delegate.userNotificationCenter.updatePresentationHandler(registrationID, presentationOptions)
            }
            .onDisappear {
                guard let registrationID else { return }
                delegate.userNotificationCenter.unregisterPresentationHandler(registrationID)
                self.registrationID = nil
            }
    }
}
