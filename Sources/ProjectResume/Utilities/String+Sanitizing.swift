import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var expandedPath: String {
        (self as NSString).expandingTildeInPath
    }

    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}

extension Array where Element == String {
    func normalizedEntries() -> [String] {
        compactMap { value in
            let trimmedValue = value.trimmed
            return trimmedValue.isEmpty ? nil : trimmedValue
        }
    }

    func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
