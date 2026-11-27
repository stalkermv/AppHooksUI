#if os(iOS)
import SwiftUI
import UIKit
import AppHooksUI

struct RemoteNotificationProbeView: View {
    @EnvironmentObject private var delegate: ApplicationDelegate
    @State private var primaryMounted = true
    @State private var secondaryMounted = false
    @State private var tertiaryMounted = false
    @State private var secondaryResult: RemoteNotificationResult = .newData
    @State private var completionCount = 0
    @State private var completionResult = "none"
    @State private var handledBy = "none"

    var body: some View {
        let currentSecondaryResult = secondaryResult

        VStack(spacing: 8) {
            Text(completionResult)
                .accessibilityLabel(completionResult)
                .accessibilityIdentifier("remoteCompletionResult")
            Text("\(completionCount)")
                .accessibilityLabel("\(completionCount)")
                .accessibilityIdentifier("remoteCompletionCount")
            Text(handledBy)
                .accessibilityLabel(handledBy)
                .accessibilityIdentifier("remoteHandler")
            Button("Toggle primary") { primaryMounted.toggle() }
                .accessibilityIdentifier("remoteTogglePrimary")
            Button("Toggle secondary") { secondaryMounted.toggle() }
                .accessibilityIdentifier("remoteToggleSecondary")
            Button("Toggle tertiary") { tertiaryMounted.toggle() }
                .accessibilityIdentifier("remoteToggleTertiary")
            Button("Refresh secondary") {
                secondaryResult = secondaryResult == .newData ? .failed : .newData
            }
            .accessibilityIdentifier("remoteRefreshSecondary")
            Button("Send remote notification") { send() }
                .accessibilityIdentifier("remoteSendNotification")
            if primaryMounted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onReceiveRemoteNotification { _ in
                        handledBy = "primary"
                        return .failed
                    }
            }
            if secondaryMounted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onReceiveRemoteNotification { [currentSecondaryResult] _ in
                        handledBy = "secondary"
                        return currentSecondaryResult
                    }
            }
            if tertiaryMounted {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onReceiveRemoteNotification { _ in
                        handledBy = "tertiary"
                        return .noData
                    }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func send() {
        delegate.application(
            UIApplication.shared,
            didReceiveRemoteNotification: ["probe": "remote"],
            fetchCompletionHandler: { result in
                completionCount += 1
                switch result {
                case .noData:
                    completionResult = "noData"
                case .newData:
                    completionResult = "newData"
                case .failed:
                    completionResult = "failed"
                @unknown default:
                    completionResult = "unknown"
                }
            }
        )
    }
}
#endif
