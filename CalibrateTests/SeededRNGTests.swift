import XCTest
@testable import Calibrate

final class SeededRNGTests: XCTestCase {

    // MARK: - Test 1: FNV-1a produces consistent hash for the same input

    func testFNV1aConsistentHashForSameInput() {
        let input = "2026-03-22"
        let hash1 = StableHash.fnv1a(input)
        let hash2 = StableHash.fnv1a(input)
        XCTAssertEqual(hash1, hash2, "FNV-1a must produce the same hash for the same input across calls.")
    }

    // MARK: - Test 2: FNV-1a produces different hashes for different inputs

    func testFNV1aDifferentInputsProduceDifferentHashes() {
        let hash1 = StableHash.fnv1a("2026-03-22")
        let hash2 = StableHash.fnv1a("2026-03-23")
        XCTAssertNotEqual(hash1, hash2, "FNV-1a must produce different hashes for different input strings.")
    }

    // MARK: - Test 3: SeededRNG same seed produces same sequence

    func testSeededRNGSameSeedProducesSameSequence() {
        let seed: UInt64 = 42
        var rng1 = SeededRandomNumberGenerator(seed: seed)
        var rng2 = SeededRandomNumberGenerator(seed: seed)

        let sequence1 = (0..<10).map { _ in rng1.next() }
        let sequence2 = (0..<10).map { _ in rng2.next() }

        XCTAssertEqual(sequence1, sequence2, "SeededRandomNumberGenerator with the same seed must produce an identical sequence.")
    }

    // MARK: - Test 4: SeededRNG different seeds produce different sequences

    func testSeededRNGDifferentSeedsProduceDifferentSequences() {
        var rng1 = SeededRandomNumberGenerator(seed: 1)
        var rng2 = SeededRandomNumberGenerator(seed: 2)

        let sequence1 = (0..<10).map { _ in rng1.next() }
        let sequence2 = (0..<10).map { _ in rng2.next() }

        XCTAssertNotEqual(sequence1, sequence2, "SeededRandomNumberGenerator with different seeds must produce different sequences.")
    }
}
