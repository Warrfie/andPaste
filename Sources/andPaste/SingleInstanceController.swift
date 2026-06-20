import AppKit
import Foundation

@MainActor
final class SingleInstanceController {
    private static let lockFileName = "com.warrfie.andpaste.lock"
    private static let showHistoryNotificationName = Notification.Name("com.warrfie.andpaste.showHistory")

    private var lockFileDescriptor: Int32 = -1
    private var observer: NSObjectProtocol?

    func becomePrimary(onShowHistoryRequest: @escaping () -> Void) -> Bool {
        let lockURL = FileManager.default.temporaryDirectory.appendingPathComponent(Self.lockFileName)
        lockFileDescriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFileDescriptor >= 0 else {
            AppLog.write("Single-instance lock open failed; errno=\(errno); continuing as primary")
            return true
        }

        guard flock(lockFileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            AppLog.write("Single-instance lock already held; notifying primary")
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            notifyPrimaryInstance()
            return false
        }
        AppLog.write("Single-instance lock acquired")

        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.showHistoryNotificationName,
            object: nil,
            queue: .main
        ) { _ in
            onShowHistoryRequest()
        }
        return true
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
        }

        if lockFileDescriptor >= 0 {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
    }

    private func notifyPrimaryInstance() {
        AppLog.write("Posting show-history notification to primary instance")
        DistributedNotificationCenter.default().postNotificationName(
            Self.showHistoryNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

}
