// Turns PDFs and images into text the pipeline can read.
// PDFs use their text layer (exact quote matching). Images go through Vision OCR, and are
// marked as .ocr so quote matching tolerates recognition errors.

import FinePrintCore
import Foundation
import PDFKit
import Vision

enum DocumentLoaderError: LocalizedError {
    case unreadablePDF, noTextInPDF, noTextInImage

    var errorDescription: String? {
        switch self {
        case .unreadablePDF: "This PDF couldn't be opened."
        case .noTextInPDF: "This PDF has no text layer (it may be a scan). Try a photo of it instead."
        case .noTextInImage: "No text was found in this image."
        }
    }
}

enum DocumentLoader {
    static func pdf(at url: URL) throws -> LoadedDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let pdf = PDFDocument(url: url) else { throw DocumentLoaderError.unreadablePDF }
        guard let text = pdf.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw DocumentLoaderError.noTextInPDF }
        return LoadedDocument(title: url.deletingPathExtension().lastPathComponent, text: text, source: .text)
    }

    static func plainText(at url: URL) throws -> LoadedDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return LoadedDocument(title: url.deletingPathExtension().lastPathComponent,
                              text: try String(contentsOf: url, encoding: .utf8), source: .text)
    }

    /// On-device OCR. Lines are put back in reading order, with a blank line where the
    /// vertical gap suggests a new paragraph, so the chunker can still see clause breaks.
    static func image(_ data: Data, title: String) async throws -> LoadedDocument {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: data)

        let lines = observations
            .compactMap { obs -> (rect: CGRect, text: String)? in
                guard let text = obs.topCandidates(1).first?.string else { return nil }
                return (obs.boundingBox.cgRect, text)
            }
            .sorted { $0.rect.midY > $1.rect.midY }  // Vision's origin is bottom-left

        guard !lines.isEmpty else { throw DocumentLoaderError.noTextInImage }
        let typicalHeight = lines.map(\.rect.height).sorted()[lines.count / 2]
        var text = ""
        var previous: CGRect?
        for line in lines {
            if let p = previous {
                text += (p.minY - line.rect.maxY) > typicalHeight * 0.9 ? "\n\n" : "\n"
            }
            text += line.text
            previous = line.rect
        }
        return LoadedDocument(title: title, text: text, source: .ocr)
    }
}

/// Documents bundled for the demo (each is also in the evaluation corpus, so its correct
/// answers are known).
struct Sample: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let file: String
    var isImage: Bool { file.hasSuffix(".png") }

    static let all: [Sample] = [
        Sample(id: "problems", title: "Lease with problems", subtitle: "Ontario tenancy agreement", file: "lease-with-problems.txt"),
        Sample(id: "scan", title: "Scanned lease (photo)", subtitle: "Read with on-device OCR", file: "scanned-lease.png"),
        Sample(id: "fair", title: "A fair lease", subtitle: "Should raise no legal issues", file: "fair-lease.txt"),
        Sample(id: "offer", title: "Job offer", subtitle: "Ontario employment offer", file: "job-offer.txt"),
        Sample(id: "terms", title: "Streaming service terms", subtitle: "No rule pack: patterns only", file: "streaming-terms.txt"),
        Sample(id: "contractor", title: "Contractor agreement", subtitle: "Not employment, so no ESA verdicts", file: "contractor-agreement.txt"),
    ]

    func load() async throws -> LoadedDocument {
        guard let url = Bundle.main.url(forResource: "Samples/\(file)", withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        if isImage { return try await DocumentLoader.image(Data(contentsOf: url), title: title) }
        return LoadedDocument(title: title, text: try String(contentsOf: url, encoding: .utf8), source: .text)
    }
}
