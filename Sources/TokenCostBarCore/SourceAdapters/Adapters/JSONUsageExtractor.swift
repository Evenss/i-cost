import Foundation

struct JSONUsageExtractor {
    let source: AgentSource

    func jsonObject(fromJSONLine line: String) -> Any? {
        guard let data = line.data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data)
    }

    func modelName(in object: Any) -> String? {
        firstModelString(in: object)
    }

    func event(fromJSONLine line: String, filePath: String, offset: Int64, fallbackDate: Date) -> UsageEvent? {
        guard let object = jsonObject(fromJSONLine: line) else {
            return nil
        }

        return events(fromJSONObject: object, filePath: filePath, offset: offset, fallbackDate: fallbackDate).first
    }

    func events(
        fromJSONObject object: Any,
        filePath: String,
        offset: Int64?,
        fallbackDate: Date,
        modelOverride: String? = nil,
        stableIDSeed: String? = nil
    ) -> [UsageEvent] {
        let candidates = usageCandidates(in: object)
        guard !candidates.isEmpty else { return [] }

        let model = modelOverride ?? modelName(in: object) ?? "unknown"
        let occurredAt = firstDate(in: object) ?? fallbackDate
        let explicitID = firstString(in: object, matching: KeyGroups.identifier)

        return candidates.enumerated().compactMap { index, candidate in
            let tokens = tokenUsage(from: candidate)
            guard tokens.total > 0 else { return nil }

            let candidateID = firstString(in: candidate, matching: KeyGroups.identifier)
            let fallbackSeed = stableIDSeed ?? "\(filePath):\(offset ?? 0)"
            let stableSource = candidateID ?? explicitID ?? "\(fallbackSeed):\(index):\(model):\(tokens.total)"
            let id = "\(source.rawValue):\(StableID.hash(stableSource))"

            return UsageEvent(
                id: id,
                source: source,
                occurredAt: occurredAt,
                modelRawName: model,
                inputTokens: tokens.input,
                cacheCreationInputTokens: tokens.cacheCreation,
                cacheCreationInputTokens1Hour: tokens.cacheCreation1Hour,
                cacheReadInputTokens: tokens.cacheRead,
                outputTokens: tokens.output,
                sourceFile: filePath,
                sourceOffset: offset
            )
        }
    }

    private func usageCandidates(in object: Any) -> [[String: Any]] {
        var candidates: [[String: Any]] = []

        func walk(_ value: Any, keyPath: String = "") {
            if let dictionary = value as? [String: Any] {
                if containsTokenKey(dictionary) {
                    if keyPath.contains("totaltokenusage") {
                        return
                    }
                    candidates.append(dictionary)
                    return
                }

                for (key, nested) in dictionary {
                    walk(nested, keyPath: keyPath + "." + normalizeKey(key))
                }
            } else if let array = value as? [Any] {
                for nested in array {
                    walk(nested, keyPath: keyPath)
                }
            }
        }

        walk(object)

        if candidates.isEmpty, let dictionary = object as? [String: Any], containsTokenKey(dictionary) {
            return [dictionary]
        }

        return candidates
    }

    private func tokenUsage(from dictionary: [String: Any]) -> TokenUsage {
        let rawInput = directInt(in: dictionary, matching: KeyGroups.inputTokens)
        let output = directInt(in: dictionary, matching: KeyGroups.outputTokens)
        let explicitCacheCreation = directInt(in: dictionary, matching: KeyGroups.cacheCreationTokens)
        let explicitCacheRead = directInt(in: dictionary, matching: KeyGroups.cacheReadTokens)
        let nestedCached = recursiveInt(in: dictionary, matching: KeyGroups.cachedTokens)
        let nestedCacheCreation = nestedInt(in: dictionary, matching: KeyGroups.cacheCreationTokens)
        // Anthropic may include both a top-level cache_creation total and per-iteration
        // details. The top-level object is authoritative; recursive lookup is only a
        // fallback for payloads where the TTL object itself is the usage candidate.
        let cacheCreationDetails = dictionary.first {
            normalizeKey($0.key) == KeyGroups.cacheCreationDetailsKey
        }?.value
        let cacheCreationContainer = cacheCreationDetails ?? dictionary
        let cacheCreation5Minutes = recursiveInt(
            in: cacheCreationContainer,
            matching: KeyGroups.cacheCreation5MinuteTokens
        )
        let cacheCreation1Hour = recursiveInt(
            in: cacheCreationContainer,
            matching: KeyGroups.cacheCreation1HourTokens
        )
        let hasCacheTTLBreakdown = cacheCreation5Minutes > 0 || cacheCreation1Hour > 0

        var input = rawInput
        let cacheCreation = hasCacheTTLBreakdown
            ? cacheCreation5Minutes
            : (explicitCacheCreation > 0 ? explicitCacheCreation : nestedCacheCreation)
        var cacheRead = explicitCacheRead

        if cacheRead == 0, nestedCached > 0 {
            cacheRead = nestedCached
            input = max(0, input - nestedCached)
        }

        // OpenAI reports cache writes inside input/prompt token details, where they are
        // already included in the total input count. Anthropic reports cache creation
        // beside input_tokens, so only nested cache-write counts are subtracted here.
        if !hasCacheTTLBreakdown, explicitCacheCreation == 0, nestedCacheCreation > 0 {
            input = max(0, input - nestedCacheCreation)
        }

        return TokenUsage(
            input: input,
            cacheCreation: cacheCreation,
            cacheCreation1Hour: cacheCreation1Hour,
            cacheRead: cacheRead,
            output: output
        )
    }

    private func containsTokenKey(_ dictionary: [String: Any]) -> Bool {
        dictionary.keys.contains { key in
            let normalized = normalizeKey(key)
            return KeyGroups.allTokenKeys.contains(normalized)
        }
    }

    private func directInt(in dictionary: [String: Any], matching keys: Set<String>) -> Int {
        for (key, value) in dictionary where keys.contains(normalizeKey(key)) {
            if let int = intValue(value) {
                return int
            }
        }
        return 0
    }

    private func recursiveInt(in object: Any, matching keys: Set<String>) -> Int {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary where keys.contains(normalizeKey(key)) {
                if let int = intValue(value) {
                    return int
                }
            }

            for value in dictionary.values {
                let result = recursiveInt(in: value, matching: keys)
                if result > 0 {
                    return result
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                let result = recursiveInt(in: value, matching: keys)
                if result > 0 {
                    return result
                }
            }
        }

        return 0
    }

    private func nestedInt(in dictionary: [String: Any], matching keys: Set<String>) -> Int {
        for value in dictionary.values {
            let result = recursiveInt(in: value, matching: keys)
            if result > 0 {
                return result
            }
        }

        return 0
    }

    private func firstString(in object: Any, matching keys: Set<String>) -> String? {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary where keys.contains(normalizeKey(key)) {
                if let string = value as? String, !string.isEmpty {
                    return string
                }
            }

            for value in dictionary.values {
                if let result = firstString(in: value, matching: keys) {
                    return result
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let result = firstString(in: value, matching: keys) {
                    return result
                }
            }
        }

        return nil
    }

    private func firstModelString(in object: Any, keyPath: String = "") -> String? {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                let normalizedKey = normalizeKey(key)
                let nextPath = keyPath.isEmpty ? normalizedKey : keyPath + "." + normalizedKey

                if KeyGroups.model.contains(normalizedKey),
                   !isSchemaPath(nextPath),
                   let string = value as? String,
                   !string.isEmpty {
                    return string
                }
            }

            for (key, value) in dictionary {
                let normalizedKey = normalizeKey(key)
                let nextPath = keyPath.isEmpty ? normalizedKey : keyPath + "." + normalizedKey

                if isSchemaPath(nextPath) {
                    continue
                }

                if let result = firstModelString(in: value, keyPath: nextPath) {
                    return result
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let result = firstModelString(in: value, keyPath: keyPath) {
                    return result
                }
            }
        }

        return nil
    }

    private func isSchemaPath(_ keyPath: String) -> Bool {
        keyPath.contains("inputschema")
            || keyPath.contains("properties")
            || keyPath.contains("dynamictools")
    }

    private func firstDate(in object: Any) -> Date? {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary where KeyGroups.date.contains(normalizeKey(key)) {
                if let date = dateValue(value) {
                    return date
                }
            }

            for value in dictionary.values {
                if let date = firstDate(in: value) {
                    return date
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let date = firstDate(in: value) {
                    return date
                }
            }
        }

        return nil
    }

    private func intValue(_ value: Any) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        if let string = value as? String {
            return Int(string)
        }

        return nil
    }

    private func dateValue(_ value: Any) -> Date? {
        if let string = value as? String {
            return DateFormats.date(from: string)
        }

        if let number = value as? NSNumber {
            let double = number.doubleValue
            if double > 1_000_000_000_000 {
                return Date(timeIntervalSince1970: double / 1000)
            }
            if double > 1_000_000_000 {
                return Date(timeIntervalSince1970: double)
            }
        }

        return nil
    }

    private func normalizeKey(_ key: String) -> String {
        key.lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

private struct TokenUsage {
    let input: Int
    let cacheCreation: Int
    let cacheCreation1Hour: Int
    let cacheRead: Int
    let output: Int

    var total: Int {
        input + cacheCreation + cacheCreation1Hour + cacheRead + output
    }
}

private enum KeyGroups {
    static let cacheCreationDetailsKey = "cachecreation"

    static let model: Set<String> = [
        "model",
        "modelname",
        "modelid",
        "modelslug"
    ]

    static let identifier: Set<String> = [
        "id",
        "uuid",
        "messageid",
        "requestid",
        "responseid"
    ]

    static let date: Set<String> = [
        "timestamp",
        "createdat",
        "created",
        "time",
        "datetime",
        "date"
    ]

    static let inputTokens: Set<String> = [
        "inputtokens",
        "prompttokens",
        "tokeninput",
        "tokensin"
    ]

    static let outputTokens: Set<String> = [
        "outputtokens",
        "completiontokens",
        "tokenoutput",
        "tokensout"
    ]

    static let cacheCreationTokens: Set<String> = [
        "cachecreationinputtokens",
        "cachecreatetokens",
        "cachewritetokens",
        "cachecreationtokens"
    ]

    static let cacheCreation5MinuteTokens: Set<String> = [
        "ephemeral5minputtokens"
    ]

    static let cacheCreation1HourTokens: Set<String> = [
        "ephemeral1hinputtokens"
    ]

    static let cacheReadTokens: Set<String> = [
        "cachereadinputtokens",
        "cachereadtokens",
        "cachedinputtokens"
    ]

    static let cachedTokens: Set<String> = [
        "cachedtokens",
        "cachedinputtokens"
    ]

    static let allTokenKeys = inputTokens
        .union(outputTokens)
        .union(cacheCreationTokens)
        .union(cacheCreation5MinuteTokens)
        .union(cacheCreation1HourTokens)
        .union(cacheReadTokens)
        .union(cachedTokens)
}
