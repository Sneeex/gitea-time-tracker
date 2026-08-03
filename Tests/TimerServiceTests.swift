import Testing
import Foundation
@testable import GiteaTimeTracker

struct TimerServiceTests {

    @Test @MainActor func testStartAndDismissActiveIssue() {
        let service = TimerService.shared
        let dummyIssue = GiteaIssue(
            id: 999,
            number: 1,
            title: "Test Issue",
            state: "open",
            repository: nil
        )

        service.start(issue: dummyIssue)
        #expect(service.activeIssue?.id == 999)
        #expect(service.state == .running)

        service.dismissActiveIssue()
        #expect(service.activeIssue == nil)
        #expect(service.state == .stopped)
        #expect(service.elapsedSeconds == 0)
    }
}
