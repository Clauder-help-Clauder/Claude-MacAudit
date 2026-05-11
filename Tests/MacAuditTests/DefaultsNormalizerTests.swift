import Testing
@testable import MacAudit

@Test("DefaultsNormalizer passes through '1'")
func normalizerPassthrough1() {
    #expect(DefaultsNormalizer.normalize("1", expected: "1") == "1")
}

@Test("DefaultsNormalizer passes through '0'")
func normalizerPassthrough0() {
    #expect(DefaultsNormalizer.normalize("0", expected: "0") == "0")
}

@Test("DefaultsNormalizer normalizes 'true' to '1'")
func normalizerTrueTo1() {
    #expect(DefaultsNormalizer.normalize("true", expected: "1") == "1")
}

@Test("DefaultsNormalizer normalizes 'false' to '0'")
func normalizerFalseTo0() {
    #expect(DefaultsNormalizer.normalize("false", expected: "0") == "0")
}

@Test("DefaultsNormalizer normalizes Tahoe dict true to '1'")
func normalizerTahoeDictTrue() {
    #expect(DefaultsNormalizer.normalize("{ \"-bool\" = true; }", expected: "1") == "1")
}

@Test("DefaultsNormalizer normalizes Tahoe dict false to '0'")
func normalizerTahoeDictFalse() {
    #expect(DefaultsNormalizer.normalize("{ \"-bool\" = false; }", expected: "0") == "0")
}

@Test("DefaultsNormalizer passes through non-bool value")
func normalizerNonBoolPassthrough() {
    #expect(DefaultsNormalizer.normalize("scale", expected: "scale") == "scale")
}

@Test("DefaultsNormalizer passes through empty value")
func normalizerEmptyPassthrough() {
    #expect(DefaultsNormalizer.normalize("", expected: "1") == "")
}
