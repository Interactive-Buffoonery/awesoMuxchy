import Foundation

public struct SidebarFuzzyMatch: Equatable, Sendable {
    public let score: Int
    /// UTF-8 byte ranges anchored to the original haystack. GTK/Pango consumes
    /// byte offsets, so keeping that boundary here avoids a second unsafe index
    /// conversion in the view layer.
    public let ranges: [Range<Int>]

    public init(score: Int, ranges: [Range<Int>]) {
        self.score = score
        self.ranges = ranges
    }
}

/// Pure sidebar fuzzy matching ported from the pinned project-owned macOS
/// implementation. Every query character must occur in order; scoring favors
/// word boundaries and contiguous runs while bounding long-gap penalties.
public enum SidebarFuzzyMatcher {
    public static let maximumQueryLength = 1_024
    public static let maximumGapPenalty = 6

    public static func match(query: String, in haystack: String) -> SidebarFuzzyMatch? {
        guard !query.isEmpty, query.count <= maximumQueryLength else { return nil }
        let foldedQuery = Array(query).map(fold)
        guard !foldedQuery.isEmpty else { return nil }

        var best: ScoredMatch?
        var cursor = haystack.startIndex
        while cursor < haystack.endIndex {
            if fold(haystack[cursor]) == foldedQuery[0],
               let candidate = score(
                   haystack: haystack, foldedQuery: foldedQuery, startIndex: cursor
               ), best.map({ candidate.score > $0.score }) ?? true
            {
                best = candidate
            }
            cursor = haystack.index(after: cursor)
        }
        guard let best else { return nil }
        return SidebarFuzzyMatch(
            score: best.score,
            ranges: best.ranges.map { range in
                let lower = haystack.utf8.distance(
                    from: haystack.utf8.startIndex, to: range.lowerBound
                )
                let upper = haystack.utf8.distance(
                    from: haystack.utf8.startIndex, to: range.upperBound
                )
                return lower..<upper
            }
        )
    }

    private struct ScoredMatch {
        let score: Int
        let ranges: [Range<String.Index>]
    }

    private static func score(
        haystack: String,
        foldedQuery: [Character],
        startIndex: String.Index
    ) -> ScoredMatch? {
        var queryIndex = 0
        var ranges: [Range<String.Index>] = []
        var total = 0
        var previousMatchEnd: String.Index?
        var previousCharacter: Character? = startIndex > haystack.startIndex
            ? haystack[haystack.index(before: startIndex)] : nil
        var contiguousRun = 0
        var cursor = startIndex

        while cursor < haystack.endIndex && queryIndex < foldedQuery.count {
            let character = haystack[cursor]
            let next = haystack.index(after: cursor)
            if fold(character) == foldedQuery[queryIndex] {
                ranges.append(cursor..<next)
                var bonus = 1
                if isWordBoundary(previous: previousCharacter, current: character) {
                    bonus += 8
                }
                if let previousMatchEnd, previousMatchEnd == cursor {
                    contiguousRun += 1
                    bonus += 2 * contiguousRun
                } else {
                    contiguousRun = 0
                    if let previousMatchEnd {
                        let gap = haystack.distance(from: previousMatchEnd, to: cursor)
                        bonus -= min(gap, maximumGapPenalty)
                    }
                }
                total += bonus
                previousMatchEnd = next
                queryIndex += 1
            }
            previousCharacter = character
            cursor = next
        }

        guard queryIndex == foldedQuery.count else { return nil }
        return ScoredMatch(score: total, ranges: ranges)
    }

    private static func fold(_ character: Character) -> Character {
        if character.isASCII { return Character(character.lowercased()) }
        return String(character)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .first ?? character
    }

    private static let separators: Set<Character> = ["/", "_", " ", "~", ".", "-", "\\"]

    private static func isWordBoundary(previous: Character?, current: Character) -> Bool {
        guard let previous else { return true }
        return separators.contains(previous) || (previous.isLowercase && current.isUppercase)
    }
}
