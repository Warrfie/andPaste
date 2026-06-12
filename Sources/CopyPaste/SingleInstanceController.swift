import AppKit
import Foundation

@MainActor
final class SingleInstanceController {
    private static let lockFileName = "com.warrfie.copypaste.lock"
    private static let showHistoryNotificationName = Notification.Name("com.warrfie.copypaste.showHistory")

    private var lockFileDescriptor: Int32 = -1
    private var observer: NSObjectProtocol?

    func becomePrimary(onShowHistoryRequest: @escaping () -> Void) -> Bool {
        let lockPath = NSTemporaryDirectory().appending(Self.lockFileName)
        lockFileDescriptor = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFileDescriptor >= 0 else { return true }

        guard flock(lockFileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            notifyPrimaryInstance()
            return false
        }

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
        DistributedNotificationCenter.default().postNotificationName(
            Self.showHistoryNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
