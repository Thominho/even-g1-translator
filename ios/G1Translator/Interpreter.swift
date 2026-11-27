import Foundation

struct Reply: Equatable {
    var kind: String      // "yes" | "no" | "question" | "ask"
    var text: String      // in the speaker's language
    var pron: String      // pronunciation spelled for the native language
    var meaning: String   // meaning in the native language
}

/// Calls the Anthropic Messages API.
struct LLMClient {
    var apiKey: String
    var model: String

    /// Models that refuse `thinking: disabled` (they always think) – learnt at runtime.
    nonisolated(unsafe) private static var alwaysThinks: Set<String> = []

    func chat(system: String, user: String, maxTokens: Int = 400) async throws -> String {
        guard !apiKey.isEmpty, !model.isEmpty else { throw LLMError.notConfigured }
        // Newer models think by default; thinking tokens count against max_tokens and add seconds.
        // Short live replies don't need it → switch it off where the model allows that.
        let thinkingOff = !Self.alwaysThinks.contains(model)
        var body: [String: Any] = [
            "model": model, "system": system,
            "max_tokens": thinkingOff ? maxTokens : max(maxTokens * 4, 4000),
            "messages": [["role": "user", "content": user]],
        ]
        if thinkingOff { body["thinking"] = ["type": "disabled"] }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP error"
            if thinkingOff, (resp as? HTTPURLResponse)?.statusCode == 400, msg.lowercased().contains("thinking") {
                Self.alwaysThinks.insert(model)             // this model can't switch thinking off
                return try await chat(system: system, user: user, maxTokens: maxTokens)
            }
            throw LLMError.api(msg)
        }
        // read text blocks by type (thinking blocks may come first)
        let blocks = json?["content"] as? [[String: Any]] ?? []
        let text = blocks.filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            await dlog("API: no text, stop_reason \(json?["stop_reason"] as? String ?? "?")")
        }
        return text
    }

    struct Model: Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// Models available for this API key, newest first (GET /v1/models).
    static func listModels(apiKey: String) async throws -> [Model] {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=100")!)
        req.timeoutInterval = 20
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "Could not load models"
            throw LLMError.api(msg)
        }
        let items = json?["data"] as? [[String: Any]] ?? []
        return items.compactMap { d in
            guard let id = d["id"] as? String else { return nil }
            return Model(id: id, name: (d["display_name"] as? String) ?? id)
        }
    }

    /// Default: the newest fast, low-cost model (Haiku family), otherwise the newest model.
    static func defaultModel(in models: [Model]) -> Model? {
        models.first { $0.id.lowercased().contains("haiku") } ?? models.first
    }

    enum LLMError: LocalizedError {
        case notConfigured, api(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Add your API key and model in Settings."
            case .api(let m): return m
            }
        }
    }
}

/// Prompts for translation, reply suggestions and follow-up questions.
struct Interpreter {
    var llm: LLMClient
    var native: String          // English name, e.g. "Czech"

    func translate(_ text: String, lang: String, context: [String], background: String = "") async throws -> String? {
        let system = """
        You translate live speech into \(native) for subtitles in smart glasses. Return ONLY the \
        \(native) translation – natural, concise, no quotes, no comments.
        The text comes from automatic speech recognition: words can be misheard, split or missing \
        punctuation, and a sentence may continue the previous one. Use the background and the \
        earlier sentences to work out what the person really means (topic, names, places, numbers, \
        regional words and slang) and translate that meaning. If it is clearly not \(lang) speech \
        or is meaningless noise, return exactly: -
        """
        var user = background.isEmpty ? "" : "Background:\n\(background)\n\n"
        if !context.isEmpty {
            user += "Earlier sentences (context only, do not translate):\n" + context.suffix(8).joined(separator: "\n") + "\n\n"
        }
        user += "Language: \(lang)\nTranslate into \(native):\n\(text)"
        let out = try await llm.chat(system: system, user: user, maxTokens: 300)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"„“ \n"))
        return out == "-" || out.isEmpty ? nil : out
    }

    func replies(turn: String, lang: String, context: [String], background: String = "") async throws -> [Reply] {
        let system = """
        The user is a native \(native) speaker who does not speak \(lang). Someone has just spoken \
        to them in \(lang). Suggest 3 very short replies IN \(lang) that the user can read out loud:
        1. "yes" – positive / agreement / thanks (whatever fits),
        2. "no" – negative / polite refusal,
        3. "question" – a follow-up question on the topic, OR a request to repeat more slowly if \
        the speech made no sense.
        Each reply max 5 words, simple vocabulary. For each add a pronunciation guide written with \
        \(native) spelling conventions, so a \(native) speaker reading it naturally sounds right, \
        and its meaning in \(native) (all three must fit on a tiny display).
        Replies must be natural, polite things a real person would say in this situation.
        The "meaning" must sound like a native \(native) speaker would naturally say the same thing in this situation – idiomatic and correct, never a word-for-word calque (e.g. Spanish "¿Qué tal el día?" is "How's your day going?", not "How is the day?"). Short (up to 5 words), no full stop at the end.
        Return ONLY JSON: {"replies": [{"kind": "yes", "text": "...", "pron": "...", "meaning": "..."}, ...]}
        """
        var user = background.isEmpty ? "" : "Background:\n\(background)\n\n"
        if !context.isEmpty { user += "Conversation so far:\n" + context.suffix(8).joined(separator: "\n") + "\n\n" }
        user += "They just said:\n\(turn)"
        let raw = try await llm.chat(system: system, user: user, maxTokens: 800)
        let items = Self.items(Self.parse(raw), key: "replies")
        let kinds = ["yes", "no", "question"]
        let out: [Reply] = items.prefix(3).enumerated().compactMap { i, d in
            guard let r = Self.reply(d, kind: nil) else { return nil }
            return kinds.contains(r.kind) ? r : Reply(kind: kinds[i], text: r.text, pron: r.pron, meaning: r.meaning)
        }
        if out.isEmpty {
            let flat = raw.replacingOccurrences(of: "\n", with: "⏎")
            await dlog("REPLIES RAW len \(raw.count) START: " + String(flat.prefix(160)))
            await dlog("REPLIES RAW END: " + String(flat.suffix(160)))
        }
        return out
    }

    func followups(turn: String, lang: String, context: [String], replies: [Reply], background: String = "") async throws -> [[Reply]] {
        let system = """
        The user is a native \(native) speaker talking with someone in \(lang), which the user does \
        not speak. The other person just said something and the user will answer with ONE of the \
        replies listed below. For EACH reply, suggest 3 short follow-up questions IN \(lang) the \
        user can ask right after answering, to keep the conversation going:
        1. if the other person asked the user a question, ask the same question back (e.g. 'And \
        you?'); otherwise a natural reaction question,
        2.–3. other sensible, friendly questions on the topic.
        Each max 5 words, simple vocabulary, with a pronunciation guide in \(native) spelling \
        conventions and the meaning in \(native) (they must fit on a tiny display).
        Questions must be natural and make sense in this conversation – what a friendly person \
        would really ask next.
        The "meaning" must sound like a native \(native) speaker would naturally say the same thing in this situation – idiomatic and correct, never a word-for-word calque (e.g. Spanish "¿Qué tal el día?" is "How's your day going?", not "How is the day?"). Short (up to 5 words), no full stop at the end.
        Return ONLY JSON: {"followups": [[{"text": "...", "pron": "...", "meaning": "..."}, ...3 items], ...one list per reply, in the same order]}
        """
        var user = background.isEmpty ? "" : "Background:\n\(background)\n\n"
        if !context.isEmpty { user += "Conversation so far:\n" + context.suffix(8).joined(separator: "\n") + "\n\n" }
        user += "They just said:\n\(turn)\n\nThe user's possible replies:\n"
        user += replies.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
        let raw = try await llm.chat(system: system, user: user, maxTokens: 1200)
        let parsed = Self.parse(raw)
        var groups: [[[String: Any]]] = []
        if let d = parsed as? [String: Any], let g = d["followups"] as? [[[String: Any]]] { groups = g }
        else if let g = parsed as? [[[String: Any]]] { groups = g }
        else if let d = parsed as? [String: Any], let g = d["followups"] as? [[String: Any]] {
            groups = g.map { Self.items($0, key: "questions") }       // [{"questions": [...]}, ...]
        }
        if groups.isEmpty { await dlog("FOLLOWUPS RAW: " + String(raw.prefix(200)).replacingOccurrences(of: "\n", with: " ")) }
        var out = groups.prefix(replies.count).map { $0.prefix(3).compactMap { Self.reply($0, kind: "ask") } }
        while out.count < replies.count { out.append([]) }
        return out
    }

    /// A short running summary of the conversation – gives every translation the bigger picture.
    func summarize(previous: String, recent: [String]) async throws -> String {
        let system = """
        You keep a running summary of a live conversation for a translator. In at most 2 short \
        sentences in English, state the setting, who the other person is (role, name if said), the \
        topic and facts that matter later (names, places, numbers, prices, what was agreed). \
        Return ONLY the summary.
        """
        var user = previous.isEmpty ? "" : "Previous summary:\n\(previous)\n\n"
        user += "Latest lines (They = the other person, Me = the user):\n" + recent.joined(separator: "\n")
        return try await llm.chat(system: system, user: user, maxTokens: 160)
    }

    /// The user said something in their own language → how to say it in the conversation language.
    func sayIt(_ text: String, lang: String, context: [String], background: String = "") async throws -> Reply {
        let system = """
        The user is a native \(native) speaker talking with someone in \(lang), which the user does \
        not speak. Translate what the user wants to say into natural, simple, polite spoken \(lang) \
        (short sentences, fitting the conversation). Add a pronunciation guide written with \(native) \
        spelling conventions so a \(native) speaker reading it naturally sounds right, and a very short \
        \(native) summary of the meaning (max 6 words, natural \(native), no full stop).
        Return ONLY JSON: {"text": "...", "pron": "...", "meaning": "..."}
        """
        var user = background.isEmpty ? "" : "Background:\n\(background)\n\n"
        if !context.isEmpty { user += "Conversation so far:\n" + context.suffix(6).joined(separator: "\n") + "\n\n" }
        user += "The user wants to say:\n\(text)"
        let raw = try await llm.chat(system: system, user: user, maxTokens: 600)
        if let d = (Self.parse(raw) as? [String: Any]) ?? Self.items(Self.parse(raw), key: "").first,
           let r = Self.reply(d, kind: "say") { return r }
        await dlog("SAY RAW: " + String(raw.prefix(200)).replacingOccurrences(of: "\n", with: " "))
        throw LLMClient.LLMError.api("Could not translate")
    }

    /// Lenient JSON: code fences, text around the JSON, trailing commas, a top-level array.
    static func parse(_ raw: String) -> Any? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        var candidates = [t]
        candidates += balancedBlocks(t)                     // each complete {...} / [...] on its own
        if let a = t.firstIndex(of: "{"), let b = t.lastIndex(of: "}"), a < b { candidates.append(String(t[a...b])) }
        if let a = t.firstIndex(of: "["), let b = t.lastIndex(of: "]"), a < b { candidates.append(String(t[a...b])) }
        for c in candidates {
            for text in [c, c.replacingOccurrences(of: #",\s*([}\]])"#, with: "$1", options: .regularExpression)] {
                if let data = text.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                   obj is [String: Any] || obj is [Any] {
                    return obj
                }
            }
        }
        return nil
    }

    /// Top-level balanced JSON blocks in the text (strings and escapes respected), largest first.
    static func balancedBlocks(_ t: String) -> [String] {
        var out: [String] = []
        let chars = Array(t)
        var i = 0
        while i < chars.count {
            guard chars[i] == "{" || chars[i] == "[" else { i += 1; continue }
            var depth = 0, inString = false, escaped = false, j = i
            var end: Int?
            while j < chars.count {
                let c = chars[j]
                if inString {
                    if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
                } else if c == "\"" { inString = true }
                else if c == "{" || c == "[" { depth += 1 }
                else if c == "}" || c == "]" { depth -= 1; if depth == 0 { end = j; break } }
                j += 1
            }
            if let end { out.append(String(chars[i...end])); i = end + 1 } else { i += 1 }
        }
        return out.sorted { $0.count > $1.count }
    }

    /// The list of reply objects, whatever shape the model chose.
    static func items(_ any: Any?, key: String) -> [[String: Any]] {
        if let arr = any as? [[String: Any]] { return arr }
        guard let d = any as? [String: Any] else { return [] }
        if let arr = d[key] as? [[String: Any]] { return arr }
        for v in d.values { if let arr = v as? [[String: Any]], !arr.isEmpty { return arr } }
        // {"yes": {...}, "no": {...}, "question": {...}}
        let byKind: [[String: Any]] = ["yes", "no", "question"].compactMap { k in
            guard var x = d[k] as? [String: Any] else { return nil }
            if x["kind"] == nil { x["kind"] = k }
            return x
        }
        if !byKind.isEmpty { return byKind }
        return d["text"] != nil ? [d] : []
    }

    private static func reply(_ d: [String: Any], kind: String?) -> Reply? {
        let keys = ["text", "reply", "phrase", "answer", "question", "target", "translation"]
        guard let text = keys.lazy.compactMap({ d[$0] as? String }).first(where: { !$0.isEmpty }) else { return nil }
        let k = kind ?? ((d["kind"] as? String)?.lowercased() ?? "")
        return Reply(kind: k, text: text.trimmingCharacters(in: .whitespaces),
                     pron: ((d["pron"] ?? d["pronunciation"]) as? String ?? "").trimmingCharacters(in: .whitespaces),
                     meaning: ((d["meaning"] ?? d["translation_native"]) as? String ?? "")
                        .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ".!。"))))
    }
}

/// 0…1 similarity of two sentences (normalized edit distance) – detects a suggestion read aloud.
func similarity(_ a: String, _ b: String) -> Double {
    func norm(_ s: String) -> [Character] {
        Array(s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
            .trimmingCharacters(in: .whitespaces))
    }
    let x = norm(a), y = norm(b)
    if x.isEmpty || y.isEmpty { return 0 }
    var prev = Array(0...y.count)
    for i in 1...x.count {
        var cur = [i] + Array(repeating: 0, count: y.count)
        for j in 1...y.count {
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
        }
        prev = cur
    }
    return 1 - Double(prev[y.count]) / Double(max(x.count, y.count))
}
