import BackgroundTasks

/// Keeps the nudge text fresh when the app has not been opened for a while.
enum BackgroundRefresh {
    static var identifier: String {
        (Bundle.main.bundleIdentifier ?? "com.paradimn.pressed") + ".refresh"
    }

    /// Call before the app finishes launching.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            schedule()
            let work = Task { @MainActor in
                CardStore.shared.ingestInbox()
                await NudgeScheduler.rebuild()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = {
                work.cancel()
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
