// Normalization used ONLY for matching quotes against the source.
//
// The model copies text through tokenization, so "verbatim" quotes come back with curly
// quotes straightened, line breaks turned into spaces, hyphenation undone, and so on.
// Both sides are folded the same way before comparing, and every normalized character
// remembers which original character it came from, so a match can be highlighted in the
// untouched source.

public struct NormalizedText: Sendable {
    /// Folded, lowercased characters used for matching.
    public let chars: [Character]
    /// originalIndex[i] is the character offset in the original text that chars[i] came from.
    public let originalIndex: [Int]

    public var string: String { String(chars) }
    public var count: Int { chars.count }

    /// Map a range of normalized characters back to original character offsets.
    public func originalRange(_ normalized: Range<Int>) -> Range<Int> {
        originalIndex[normalized.lowerBound] ..< (originalIndex[normalized.upperBound - 1] + 1)
    }
}

public enum TextNormalizer {
    public static func normalize(_ text: String) -> NormalizedText {
        let src = Array(text)
        var out: [Character] = []
        var map: [Int] = []
        out.reserveCapacity(src.count)
        map.reserveCapacity(src.count)

        var lastWasSpace = true  // also trims leading whitespace
        var i = 0
        while i < src.count {
            let c = src[i]

            if isHyphen(c) {
                // Line-break hyphenation ("rent-\nal") is joined with no space.
                var j = i + 1
                while j < src.count, src[j] == " " || src[j] == "\t" { j += 1 }
                if j < src.count, src[j].isNewline {
                    var k = j + 1
                    while k < src.count, src[k].isWhitespace { k += 1 }
                    if k < src.count, src[k].isLowercase {
                        i = k
                        continue
                    }
                }
                // Every other hyphen or dash is dropped, so "self-contained", "self\ncontained"
                // (after de-hyphenation) and a model's "self-contained" all compare equal.
                i += 1
                continue
            }

            if c.isWhitespace {
                if !lastWasSpace {
                    out.append(" ")
                    map.append(i)
                    lastWasSpace = true
                }
                i += 1
                continue
            }

            for folded in fold(c) {
                out.append(folded)
                map.append(i)
            }
            lastWasSpace = false
            i += 1
        }
        if out.last == " " {
            out.removeLast()
            map.removeLast()
        }
        return NormalizedText(chars: out, originalIndex: map)
    }

    static func isHyphen(_ c: Character) -> Bool {
        switch c {
        case "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2212}", "\u{00AD}":
            return true
        default:
            return false
        }
    }

    static func fold(_ c: Character) -> [Character] {
        switch c {
        case "\u{2018}", "\u{2019}", "\u{201A}", "\u{2032}", "`": return ["'"]
        case "\u{201C}", "\u{201D}", "\u{201E}", "\u{2033}": return ["\""]
        case "\u{FB00}": return ["f", "f"]
        case "\u{FB01}": return ["f", "i"]
        case "\u{FB02}": return ["f", "l"]
        case "\u{2026}": return [".", ".", "."]
        default: return Array(String(c).lowercased())
        }
    }
}
