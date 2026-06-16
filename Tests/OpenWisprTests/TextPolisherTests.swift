import XCTest
@testable import OpenWisprLib

final class TextPolisherTests: XCTestCase {

    // MARK: - Filler handling (two-tier)

    func testDisfluenciesStrippedByDefault() {
        XCTAssertEqual(TextPolisher.polish("um I think uh that works"), "I think that works")
    }

    func testOrdinaryWordsSurviveByDefault() {
        // "like", "actually" are ordinary English — never removed unless opted in.
        XCTAssertEqual(TextPolisher.polish("I like cats and dogs"), "I like cats and dogs")
        XCTAssertEqual(TextPolisher.polish("she literally jumped the fence"),
                       "She literally jumped the fence")
    }

    func testFillerWordsRemovedWhenEnabled() {
        XCTAssertEqual(TextPolisher.polish("I like basically finished", removeFillers: true),
                       "I finished")
    }

    // MARK: - Voice commands gated by spokenPunctuation

    func testVoiceCommandsOffByDefault() {
        XCTAssertEqual(TextPolisher.polish("add a comma here"), "Add a comma here")
    }

    func testVoiceCommandsWhenEnabled() {
        XCTAssertEqual(TextPolisher.polish("add a comma here", voiceCommands: true),
                       "Add a, here")
    }

    // MARK: - Dictionary

    func testDictionaryCorrectsProperNoun() {
        let dict = ["dyna trace": "Dynatrace"]
        XCTAssertEqual(TextPolisher.polish("we use dyna trace daily", dictionary: dict),
                       "We use Dynatrace daily")
    }

    func testDictionaryExpandsShorthandLongestFirst() {
        let dict = ["ai team": "AI Platform team", "ai": "AI"]
        XCTAssertEqual(TextPolisher.polish("ping the ai team", dictionary: dict),
                       "Ping the AI Platform team")
    }

    // MARK: - Number conversion

    func testCardinalsToDigits() {
        XCTAssertEqual(NumberWords.convert("I need two laptops"), "I need 2 laptops")
        XCTAssertEqual(NumberWords.convert("twenty three"), "23")
        XCTAssertEqual(NumberWords.convert("two hundred fifty"), "250")
        XCTAssertEqual(NumberWords.convert("two hundred and fifty three"), "253")
        XCTAssertEqual(NumberWords.convert("one thousand two hundred"), "1200")
    }

    func testNumberIdiomGuard() {
        XCTAssertEqual(NumberWords.convert("one of them left"), "one of them left")
        XCTAssertEqual(NumberWords.convert("no one was there"), "no one was there")
        XCTAssertEqual(NumberWords.convert("one another"), "one another")
    }

    func testMalformedRunsLeftAlone() {
        // "twenty thirty" is not a single number; it should not collapse to a value.
        XCTAssertEqual(NumberWords.convert("twenty thirty"), "twenty thirty")
    }

    func testNumberTrailingPunctuation() {
        XCTAssertEqual(NumberWords.convert("give me three, please"), "give me 3, please")
    }

    func testNonNumberTextUntouched() {
        XCTAssertEqual(NumberWords.convert("the quick brown fox"), "the quick brown fox")
    }

    func testPolishConvertsNumbersWhenEnabled() {
        XCTAssertEqual(TextPolisher.polish("i have two dogs", convertNumbers: true),
                       "I have 2 dogs")
    }
}
