// Engine-independent prompt text, shared by the on-device and Gemini extractors so the
// two engines are compared on equal terms. Iterations are logged in docs/prompt_engineering.md.

public enum Prompts {
    public static let version = "v2.1"

    /// v1: all 26 clause types for every document. v2: only the types relevant to the
    /// detected document type (see ClauseCatalog.types(for:) and docs/phase5_evaluation.md).
    /// The unscoped form (all types) is still used to size the on-device token budget.
    public static var extractionInstructions: String { extractionInstructions(for: nil) }

    public static func extractionInstructions(for documentType: DocumentType?) -> String {
        let types = documentType.map(ClauseCatalog.types(for:)) ?? ClauseCatalog.extractableTypes
        return """
        You read contracts and legal documents and extract clauses for a review app.

        RULES
        1. Only extract clauses whose type is in the list below. Skip everything else.
        2. "quote" must be copied EXACTLY from the document, character for character, \
        including its punctuation. Do not paraphrase, summarize, shorten mid-sentence, fix \
        typos, or join separate sentences. Code checks every quote against the document and \
        throws away any quote that doesn't match.
        3. Quote at least one full sentence.
        4. "parameters": include only numbers the document actually states. Never estimate or \
        assume a number. Leave parameters out when the document doesn't state them.
        5. You do not decide whether anything is legal or fair. Only tag and quote.
        6. If the same clause fits two types, list it once for each type.

        CLAUSE TYPES
        \(ClauseCatalog.promptList(for: types))
        """
    }

    public static let documentTypeInstructions = """
        Classify the document. Types:
        - residential_lease: a lease or tenancy agreement for a home or apartment
        - employment: an employment contract or job offer for an employee
        - subscription_terms: terms of service, terms of use, or a subscription or membership agreement
        - unknown: anything else (for example a contractor agreement, a loan, or a purchase agreement), \
        or when you can't tell
        Report your genuine confidence from 0 to 1. Use a low value if the document is short, \
        mixed, or unclear.
        """

    public static func extractionPrompt(chunk: String, documentType: DocumentType) -> String {
        "Document type: \(documentType.rawValue)\n\nDocument text:\n\(chunk)"
    }

    public static func documentTypePrompt(sample: String) -> String {
        "Document (beginning):\n\(sample)"
    }

    /// Enough of the document to classify it without spending the context window.
    public static func sample(_ text: String, maxCharacters: Int = 3000) -> String {
        String(text.prefix(maxCharacters))
    }
}
