import Combine
import SettingsModel

final class MockForegroundNotifier: ForegroundNotifier {
    private let subject = PassthroughSubject<Void, Never>()

    nonisolated var willEnterForeground: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    nonisolated func sendWillEnterForeground() {
        subject.send()
    }
}
