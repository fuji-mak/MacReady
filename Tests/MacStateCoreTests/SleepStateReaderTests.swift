import XCTest
@testable import MacStateCore

final class SleepStateReaderTests: XCTestCase {
    @MainActor
    func testIsDisabledDoesNotRunMainRunLoopCallbacks() {
        var fired = false
        let timer = Timer(timeInterval: 0.01, repeats: false) { _ in fired = true }
        RunLoop.main.add(timer, forMode: .default)
        _ = SleepStateReader.isDisabled()
        XCTAssertFalse(fired)
        timer.invalidate()
    }
}
