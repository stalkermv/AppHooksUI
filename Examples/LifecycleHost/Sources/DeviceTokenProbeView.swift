#if os(iOS)
import SwiftUI
import UIKit
import AppHooksUI

private enum DeviceTokenProbeError: Error, LocalizedError {
    case registrationFailed(code: Int)

    var errorDescription: String? {
        switch self {
        case let .registrationFailed(code):
            "registrationFailed:\(code)"
        }
    }
}

@MainActor
struct DeviceTokenProbeView: View {
    @EnvironmentObject private var delegate: ApplicationDelegate
    @State private var primaryMounted = false
    @State private var secondaryMounted = false
    @State private var primaryStage = "unmounted"
    @State private var secondaryStage = "unmounted"
    @State private var primaryCount = 0
    @State private var secondaryCount = 0
    @State private var primaryPayload = "none"
    @State private var secondaryPayload = "none"
    @State private var primaryError = "none"
    @State private var secondaryError = "none"
    @State private var primaryMainThread = "none"
    @State private var secondaryMainThread = "none"

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("ready")
                    .accessibilityLabel("ready")
                    .accessibilityIdentifier("deviceTokenProbeReady")
                Button("Toggle primary") { primaryMounted.toggle() }
                    .accessibilityIdentifier("deviceTokenTogglePrimary")
                Button("Toggle secondary") { secondaryMounted.toggle() }
                    .accessibilityIdentifier("deviceTokenToggleSecondary")
                Button("Send pre-mount token") {
                    sendToken(Data([0x10, 0x11]))
                }
                .accessibilityIdentifier("deviceTokenSendPreMount")
                Button("Send latest pre-mount token") {
                    sendToken(Data([0x20, 0x21]))
                }
                .accessibilityIdentifier("deviceTokenSendLatestPreMount")
                Button("Send live token") {
                    sendToken(Data([0x30, 0x31]))
                }
                .accessibilityIdentifier("deviceTokenSendLive")
                Button("Send registration failure") {
                    sendFailure()
                }
                .accessibilityIdentifier("deviceTokenSendFailure")
                Button("Send remount token") {
                    sendToken(Data([0x40, 0x41]))
                }
                .accessibilityIdentifier("deviceTokenSendRemount")
                Group {
                    Text(primaryStage)
                        .accessibilityLabel(primaryStage)
                        .accessibilityIdentifier("deviceTokenPrimaryStage")
                    Text("\(primaryCount)")
                        .accessibilityLabel("\(primaryCount)")
                        .accessibilityIdentifier("deviceTokenPrimaryCount")
                    Text(primaryPayload)
                        .accessibilityLabel(primaryPayload)
                        .accessibilityIdentifier("deviceTokenPrimaryPayload")
                    Text(primaryError)
                        .accessibilityLabel(primaryError)
                        .accessibilityIdentifier("deviceTokenPrimaryError")
                    Text(primaryMainThread)
                        .accessibilityLabel(primaryMainThread)
                        .accessibilityIdentifier("deviceTokenPrimaryMainThread")
                }
                Group {
                    Text(secondaryStage)
                        .accessibilityLabel(secondaryStage)
                        .accessibilityIdentifier("deviceTokenSecondaryStage")
                    Text("\(secondaryCount)")
                        .accessibilityLabel("\(secondaryCount)")
                        .accessibilityIdentifier("deviceTokenSecondaryCount")
                    Text(secondaryPayload)
                        .accessibilityLabel(secondaryPayload)
                        .accessibilityIdentifier("deviceTokenSecondaryPayload")
                    Text(secondaryError)
                        .accessibilityLabel(secondaryError)
                        .accessibilityIdentifier("deviceTokenSecondaryError")
                    Text(secondaryMainThread)
                        .accessibilityLabel(secondaryMainThread)
                        .accessibilityIdentifier("deviceTokenSecondaryMainThread")
                }
                if primaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onRegisterDeviceToken { result in
                            primaryCount += 1
                            primaryMainThread = Thread.isMainThread ? "true" : "false"
                            switch result {
                            case let .success(token):
                                primaryPayload = token.base64EncodedString()
                                primaryError = "none"
                            case let .failure(error):
                                primaryPayload = "none"
                                if let probeError = error as? DeviceTokenProbeError,
                                   case let .registrationFailed(code) = probeError {
                                    primaryError = "registrationFailed:\(code)"
                                } else {
                                    primaryError = "unexpected \(type(of: error)): \(error)"
                                }
                            }
                        }
                        .onAppear { primaryStage = "mounted" }
                        .onDisappear { primaryStage = "unmounted" }
                }
                if secondaryMounted {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onRegisterDeviceToken { result in
                            secondaryCount += 1
                            secondaryMainThread = Thread.isMainThread ? "true" : "false"
                            switch result {
                            case let .success(token):
                                secondaryPayload = token.base64EncodedString()
                                secondaryError = "none"
                            case let .failure(error):
                                secondaryPayload = "none"
                                if let probeError = error as? DeviceTokenProbeError,
                                   case let .registrationFailed(code) = probeError {
                                    secondaryError = "registrationFailed:\(code)"
                                } else {
                                    secondaryError = "unexpected \(type(of: error)): \(error)"
                                }
                            }
                        }
                        .onAppear { secondaryStage = "mounted" }
                        .onDisappear { secondaryStage = "unmounted" }
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
    }

    private func sendToken(_ token: Data) {
        delegate.application(
            UIApplication.shared,
            didRegisterForRemoteNotificationsWithDeviceToken: token
        )
    }

    private func sendFailure() {
        delegate.application(
            UIApplication.shared,
            didFailToRegisterForRemoteNotificationsWithError:
                DeviceTokenProbeError.registrationFailed(code: 17)
        )
    }
}
#endif
