import Testing
@testable import Passenger

/// tourist-trap-flag TRD §9 row 1b/7a: every output of `FlagCopy` +
/// `HoodSpeech` over all 12 (`TouristFlag` × `HeatBand?`) inputs, checked for
/// banned tag values and for the D5 Hood-sheet three distinct strings.
@Suite("FlagCopy / HoodSpeech")
struct FlagCopyTests {
    private static let allFlags: [TouristFlag] = TouristFlag.allCases
    private static let allBands: [HeatBand?] = [nil, .quiet, .moderate, .busy]

    // MARK: - §4.2's table, verbatim

    @Test("centroidLabel renders only when flagged")
    func centroidLabelOnlyWhenFlagged() {
        #expect(FlagCopy.centroidLabel(flag: .flagged, band: nil) == "Tourist-heavy spot")
        #expect(FlagCopy.centroidLabel(flag: .flagged, band: .quiet) == "Tourist-heavy spot")
        #expect(FlagCopy.centroidLabel(flag: .flagged, band: .busy) == "Busy and tourist-heavy")
        #expect(FlagCopy.centroidLabel(flag: .notFlagged, band: .busy) == nil)
        #expect(FlagCopy.centroidLabel(flag: .unrated, band: .busy) == nil)
    }

    @Test("hoodSheetLine has three distinct strings, always present (D5, row 4c)")
    func hoodSheetLineHasThreeDistinctStrings() {
        let flagged = FlagCopy.hoodSheetLine(flag: .flagged)
        let notFlagged = FlagCopy.hoodSheetLine(flag: .notFlagged)
        let unrated = FlagCopy.hoodSheetLine(flag: .unrated)

        #expect(flagged == "Tourist-heavy spot")
        #expect(notFlagged == "Not a tourist-heavy spot")
        #expect(unrated == "No local rating yet")
        #expect(Set([flagged, notFlagged, unrated]).count == 3)
    }

    // MARK: - HoodSpeech: total over 3×4 inputs, req 7

    @Test("HoodSpeech.label is non-empty and states the flag for every one of the 12 inputs")
    func labelIsNonEmptyForEveryInput() {
        for flag in Self.allFlags {
            for band in Self.allBands {
                let label = HoodSpeech.label(name: "Test Hood", band: band, flag: flag)
                #expect(!label.isEmpty)
                #expect(label.hasPrefix("Test Hood"))
            }
        }
    }

    @Test("busy+flagged is its own combined sentence, not a concatenation of the two other forms — req 7 bullet 2")
    func busyFlaggedIsCombinedNotConcatenated() {
        let label = HoodSpeech.label(name: "Florentin", band: .busy, flag: .flagged)
        #expect(label == "Florentin, busy and tourist-heavy — worth a second look")
        // Not the plain-flagged clause and not the busy word said twice.
        #expect(!label.contains("tourist-heavy spot"))
    }

    @Test("no-data extends the existing no-data branch rather than replacing it")
    func noDataExtendsExistingBranch() {
        let label = HoodSpeech.label(name: "Bavli", band: nil, flag: .unrated)
        #expect(label == "Bavli, no data right now, no local rating yet")
    }

    @Test("not-flagged and unrated read differently even at the same band — the sighted-silent gap VoiceOver must not have")
    func notFlaggedAndUnratedReadDifferently() {
        for band in Self.allBands {
            let notFlagged = HoodSpeech.label(name: "H", band: band, flag: .notFlagged)
            let unrated = HoodSpeech.label(name: "H", band: band, flag: .unrated)
            #expect(notFlagged != unrated)
        }
    }

    // MARK: - Banned tag values (§9 row 1b)

    /// Decision #37 replaced decision #18's graduated three-way vibe tag
    /// (**Local · Mix · Tourist**) with a boolean. This checks that none of
    /// `FlagCopy`/`HoodSpeech`'s outputs resurrect one of that retired
    /// scale's own tag *values* — checked as a **whole-string equality**,
    /// not a substring search: §4.2's own approved copy legitimately
    /// contains "local" inside a full sentence ("No local rating yet," D5),
    /// which is not the same thing as the output *being* the bare word
    /// "local" the way a standalone badge on the old scale would have been.
    /// "tourist trap" (decision #42's own rejected framing) is checked as a
    /// substring too, since no legitimate copy in this feature ever needs
    /// that exact phrase.
    @Test("no output equals a retired vibe-tag value, and none contains the rejected phrase \"tourist trap\"")
    func noBannedTagValues() {
        let bannedWholeValues: Set<String> = ["local", "very local", "mix", "mixed", "touristy", "super local", "tourist trap"]

        var allOutputs: [String] = [FlagCopy.placeLine, FlagCopy.toastQuestion, FlagCopy.toastYes, FlagCopy.toastNo]
        for flag in Self.allFlags {
            allOutputs.append(FlagCopy.hoodSheetLine(flag: flag))
            for band in Self.allBands {
                if let centroid = FlagCopy.centroidLabel(flag: flag, band: band) {
                    allOutputs.append(centroid)
                }
                allOutputs.append(HoodSpeech.label(name: "Hood", band: band, flag: flag))
            }
        }

        for output in allOutputs {
            let lowered = output.lowercased()
            #expect(!bannedWholeValues.contains(lowered), "\"\(output)\" is itself a retired vibe-tag value")
            #expect(!lowered.contains("tourist trap"), "\"\(output)\" contains the rejected phrase \"tourist trap\" (decision #42)")
        }
    }
}
