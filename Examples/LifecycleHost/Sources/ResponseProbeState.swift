import UserNotifications

struct ResponseObservation {
    var stage = "unmounted"
    var count = 0
    var requestID = "none"
    var actionIdentifier = "none"
    var mainThread = "none"
}

struct ResponseProbeState {
    struct Acknowledgement {
        var returnCount = 0
        var observedCount = 0
        var requestID = "none"
        var actionIdentifier = "none"
        var mainThread = "none"
        var actionsBeforeReturn = 0
        var actionsAtReturn = 0
    }

    var authorization = "starting"
    var status = "starting"
    var scheduledRequestID = "none"
    var requestNumber = 0
    var capturedResponses: [UNNotificationResponse] = []
    var captureMounted = true
    var primaryMounted = false
    var secondaryMounted = false
    var capture = ResponseObservation()
    var primary = ResponseObservation()
    var secondary = ResponseObservation()
    var acknowledgement = Acknowledgement()
    var consumerReceiptCount = 0
}
