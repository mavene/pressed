import Foundation

/// What we can learn from a page's HTML without running scripts.
struct PageInfo: Equatable {
    var title: String?
    var siteName: String?
    var imageURL: URL?
    var isRecipe: Bool
    /// From video duration meta tags (seconds rounded to minutes).
    var durationMinutes: Int?
    /// From visible text length, at about 220 words per minute. Nil for short pages.
    var readMinutes: Int?
}

enum PageParser {
    static let wordsPerMinute = 220.0

    static func parse(html: String, base: URL) -> PageInfo {
        let head = String(html.prefix(600_000))
        let metas = metaTags(in: head)

        func meta(_ keys: String...) -> String? {
            for key in keys {
                if let value = metas[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value
                }
            }
            return nil
        }

        let title = meta("og:title", "twitter:title") ?? titleTag(in: head)
        let siteName = meta("og:site_name")
        let image = meta("og:image", "og:image:url", "twitter:image")
            .flatMap { URL(string: $0, relativeTo: base)?.absoluteURL }

        return PageInfo(
            title: title.map { decode($0).trimmingCharacters(in: .whitespacesAndNewlines) },
            siteName: siteName.map { decode($0) },
            imageURL: image,
            isRecipe: hasRecipeJSONLD(in: head),
            durationMinutes: durationMinutes(from: metas),
            readMinutes: readMinutes(in: head)
        )
    }

    // MARK: Meta tags

    /// Maps lowercased `property` / `name` / `itemprop` to the tag's `content`. First one wins.
    static func metaTags(in html: String) -> [String: String] {
        var result: [String: String] = [:]
        guard let tagRegex = try? NSRegularExpression(pattern: "<meta\\s[^>]*>", options: [.caseInsensitive]),
              let attrRegex = try? NSRegularExpression(
                pattern: "([a-zA-Z_:-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')", options: []) else {
            return result
        }
        let ns = html as NSString
        for match in tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: match.range)
            let tagNS = tag as NSString
            var attrs: [String: String] = [:]
            for attr in attrRegex.matches(in: tag, range: NSRange(location: 0, length: tagNS.length)) {
                let key = tagNS.substring(with: attr.range(at: 1)).lowercased()
                let valueRange = attr.range(at: 2).location != NSNotFound ? attr.range(at: 2) : attr.range(at: 3)
                if valueRange.location != NSNotFound {
                    attrs[key] = tagNS.substring(with: valueRange)
                }
            }
            let rawName = attrs["property"] ?? attrs["name"] ?? attrs["itemprop"]
            if let name = rawName?.lowercased(), let content = attrs["content"], result[name] == nil {
                result[name] = decode(content)
            }
        }
        return result
    }

    static func titleTag(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
              match.range(at: 1).location != NSNotFound else { return nil }
        let text = decode(ns.substring(with: match.range(at: 1)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    // MARK: Recipe detection

    static func hasRecipeJSONLD(in html: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: "<script[^>]*type\\s*=\\s*[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return false
        }
        let ns = html as NSString
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            guard match.range(at: 1).location != NSNotFound else { continue }
            let body = ns.substring(with: match.range(at: 1))
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
                continue
            }
            if containsRecipe(json) { return true }
        }
        return false
    }

    static func containsRecipe(_ value: Any) -> Bool {
        if let dict = value as? [String: Any] {
            if let type = dict["@type"] {
                if let single = type as? String, single.lowercased() == "recipe" { return true }
                if let many = type as? [Any], many.contains(where: { ($0 as? String)?.lowercased() == "recipe" }) {
                    return true
                }
            }
            return dict.values.contains(where: { containsRecipe($0) })
        }
        if let array = value as? [Any] {
            return array.contains(where: { containsRecipe($0) })
        }
        return false
    }

    // MARK: Time estimates

    static func durationMinutes(from metas: [String: String]) -> Int? {
        for key in ["og:video:duration", "video:duration"] {
            if let raw = metas[key], let seconds = Double(raw), seconds > 0 {
                return max(1, Int((seconds / 60).rounded()))
            }
        }
        if let iso = metas["duration"], let seconds = iso8601Seconds(iso) {
            return max(1, Int((seconds / 60).rounded()))
        }
        return nil
    }

    /// "PT1H2M30S" -> 3750
    static func iso8601Seconds(_ text: String) -> Double? {
        let upper = text.uppercased()
        guard upper.hasPrefix("PT") else { return nil }
        var total = 0.0
        var number = ""
        for char in upper.dropFirst(2) {
            if char.isNumber || char == "." {
                number.append(char)
            } else {
                guard let value = Double(number) else { return nil }
                switch char {
                case "H": total += value * 3600
                case "M": total += value * 60
                case "S": total += value
                default: return nil
                }
                number = ""
            }
        }
        return total > 0 ? total : nil
    }

    static func readMinutes(in html: String) -> Int? {
        var text = html
        for pattern in ["<script[^>]*>.*?</script>", "<style[^>]*>.*?</style>", "<[^>]+>"] {
            guard let regex = try? NSRegularExpression(
                pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { continue }
            let range = NSRange(location: 0, length: (text as NSString).length)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        }
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        guard words >= 200 else { return nil }
        return max(1, Int((Double(words) / wordsPerMinute).rounded()))
    }

    // MARK: Entities

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        let table: [(String, String)] = [
            ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&apos;", "'"),
            ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&")
        ]
        for (entity, replacement) in table {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
