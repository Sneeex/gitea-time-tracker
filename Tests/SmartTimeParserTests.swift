import Testing
@testable import GiteaTimeTracker

struct SmartTimeParserTests {

    @Test func testParseMinutes() {
        #expect(SmartTimeParser.parseToSeconds("45") == 2700)
        #expect(SmartTimeParser.parseToSeconds("45m") == 2700)
        #expect(SmartTimeParser.parseToSeconds(" 30 m ") == 1800)
    }

    @Test func testParseHours() {
        #expect(SmartTimeParser.parseToSeconds("2h") == 7200)
        #expect(SmartTimeParser.parseToSeconds("1.5h") == 5400)
        #expect(SmartTimeParser.parseToSeconds("1,5h") == 5400)
    }

    @Test func testParseCombination() {
        #expect(SmartTimeParser.parseToSeconds("1h 30m") == 5400)
        #expect(SmartTimeParser.parseToSeconds("2h 15m 30s") == 8130)
    }

    @Test func testParseColonFormat() {
        #expect(SmartTimeParser.parseToSeconds("01:30") == 5400)
        #expect(SmartTimeParser.parseToSeconds("01:30:15") == 5415)
    }

    @Test func testFormatters() {
        #expect(SmartTimeParser.formatTimerString(3665) == "01:01:05")
        #expect(SmartTimeParser.formatHumanReadable(5400) == "1h 30m")
        #expect(SmartTimeParser.formatHumanReadable(1800) == "30m")
        #expect(SmartTimeParser.formatHumanReadable(45) == "45s")
    }
}
