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

    func chat(system: String, user: String, maxTokens: Int = 400) async throws -> String {
        guard !apiKey.isEmpty, !model.isEmpty else { throw LLMError.notConfigured }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model, "max_tokens": maxTokens, "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = ((json?["error"] as? [String: Any])?["message"] as? String) ?? "HTTP error"
            throw LLMError.api(msg)
        }
        let blocks = json?["content"] as? [[String: Any]] ?? []
        return blocks.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
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

    func translate(_ text: String, lang: String, context: [String]) async throws -> String? {
        let system = """
        You translate live speech into \(native) for subtitles in smart glasses. Return ONLY the \
        \(native) translation – natural, concise, no quotes, no comments. If the transcript is \
        garbled, translate the most likely meaning. If it is clearly not \(lang) speech or is \
        meaningless noise, return exactly: -
        """
        var user = ""
        if !context.isEmpty {
            user += "Earlier sentences (context only, do not translate):\n" + context.suffix(4).joined(separator: "\n") + "\n\n"
        }
        user += "Language: \(lang)\nTranslate into \(native):\n\(text)"
        let out = try await llm.chat(system: system, user: user, maxTokens: 300)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"„“ \n"))
        return out == "-" || out.isEmpty ? nil : out
    }

    func replies(turn: String, lang: String, context: [String]) async throws -> [Reply] {
        let system = """
        The user is a native \(native) speaker who does not speak \(lang). Someone has just spoken \
        to them in \(lang). Suggest 3 very short replies IN \(lang) that the user can read out loud:
        1. "yes" – positive / agreement / thanks (whatever fits),
        2. "no" – negative / polite refusal,
        3. "question" – a follow-up question on the topic, OR a request to repeat more slowly if \
        the speech made no sense.
        Each reply max 5 words, simple vocabulary. For each add a pronunciation guide written with \
        \(native) spelling conventions, so a \(native) speaker reading it naturally sounds right, \
        and its meaning in \(native) (max 4 words – all three must fit on a tiny display).
        Return ONLY JSON: {"replies": [{"kind": "yes", "text": "...", "pron": "...", "meaning": "..."}, ...]}
        """
        var user = ""
        if !context.isEmpty { user += "Conversation so far:\n" + context.suffix(8).joined(separator: "\n") + "\n\n" }
        user += "They just said:\n\(turn)"
        let raw = try await llm.chat(system: system, user: user, maxTokens: 500)
        let items = (Self.json(raw)?["replies"] as? [[String: Any]]) ?? []
        return items.prefix(3).compactMap { Self.reply($0, kind: nil) }
    }

    func followups(turn: String, lang: String, context: [String], replies: [Reply]) async throws -> [[Reply]] {
        let system = """
        The user is a native \(native) speaker talking with someone in \(lang), which the user does \
        not speak. The other person just said something and the user will answer with ONE of the \
        replies listed below. For EACH reply, suggest 3 short follow-up questions IN \(lang) the \
        user can ask right after answering, to keep the conversation going:
        1. if the other person asked the user a question, ask the same question back (e.g. 'And \
        you?'); otherwise a natural reaction question,
        2.–3. other sensible, friendly questions on the topic.
        Each max 5 words, simple vocabulary, with a pronunciation guide in \(native) spelling \
        conventions and the meaning in \(native) (max 4 words – they must fit on a tiny display).
        Return ONLY JSON: {"followups": [[{"text": "...", "pron": "...", "meaning": "..."}, ...3 items], ...one list per reply, in the same order]}
        """
        var user = ""
        if !context.isEmpty { user += "Conversation so far:\n" + context.suffix(8).joined(separator: "\n") + "\n\n" }
        user += "They just said:\n\(turn)\n\nThe user's possible replies:\n"
        user += replies.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
        let raw = try await llm.chat(system: system, user: user, maxTokens: 900)
        let groups = (Self.json(raw)?["followups"] as? [[[String: Any]]]) ?? []
        var out = groups.prefix(replies.count).map { $0.prefix(3).compactMap { Self.reply($0, kind: "ask") } }
        while out.count < replies.count { out.append([]) }
        return out
    }

    private static func json(_ raw: String) -> [String: Any]? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end,
              let data = String(raw[start...end]).data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func reply(_ d: [String: Any], kind: String?) -> Reply? {
        guard let text = d["text"] as? String, !text.isEmpty else { return nil }
        let k = kind ?? ((d["kind"] as? String)?.lowercased() ?? "")
        return Reply(kind: k, text: text.trimmingCharacters(in: .whitespaces),
                     pron: (d["pron"] as? String ?? "").trimmingCharacters(in: .whitespaces),
                     meaning: (d["meaning"] as? String ?? "").trimmingCharacters(in: .whitespaces))
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
