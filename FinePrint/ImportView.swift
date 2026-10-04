// Home screen: paste, import a PDF, pick a photo, or try a bundled sample.
// If the current engine would send the document off the device, the user is asked once per
// session, with a way to keep it on the device instead.
//
// Layout: a padded ScrollView of cards (not a List with custom insets, which clipped the
// header text at the screen edge). Everything sits inside one gutter, wraps at any width,
// and grows with Dynamic Type.

import FinePrintAI
import FinePrintCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(AppModel.self) private var model
    @State private var pasted = ""
    @State private var path: [AnalysisRequest] = []
    @State private var showFileImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var loading: String?
    @State private var loadError: String?
    @State private var pendingConsent: LoadedDocument?
    @State private var showSettings = false
    @FocusState private var editorFocused: Bool

    private var canAnalyzePasted: Bool {
        pasted.trimmingCharacters(in: .whitespacesAndNewlines).count >= 40
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    pasteCard
                    importCard
                    samplesCard
                    Text(ReportFormatter.disclaimer)
                        .font(.caption2).foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)              // comfortable line length on wide screens
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { editorFocused = false }
                }
            }
            .navigationDestination(for: AnalysisRequest.self) { AnalysisScreen(request: $0) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .plainText]) { result in
                guard case let .success(url) = result else { return }
                Task {
                    await load("Reading \(url.lastPathComponent)…") {
                        url.pathExtension.lowercased() == "pdf" ? try DocumentLoader.pdf(at: url) : try DocumentLoader.plainText(at: url)
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    await load("Reading text from the photo…") {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw DocumentLoaderError.noTextInImage }
                        return try await DocumentLoader.image(data, title: "Photo of a document")
                    }
                    photoItem = nil
                }
            }
            .overlay {
                if let loading {
                    ProgressView(loading)
                        .padding(24)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
                }
            }
            // Real two-way bindings: SwiftUI must be able to set these back to nil/false when
            // the user dismisses. (.constant bindings here broke the Settings sheet.)
            .alert("Couldn't open that", isPresented: isPresent($loadError), presenting: loadError) { _ in
                Button("OK") { loadError = nil }
            } message: { Text($0) }
            .confirmationDialog("Send this document to Google Gemini?", isPresented: isPresent($pendingConsent),
                                titleVisibility: .visible, presenting: pendingConsent) { doc in
                Button("Send to Gemini") {
                    model.sessionConsent = true
                    pendingConsent = nil
                    path.append(AnalysisRequest(document: doc, offline: false))
                }
                Button("Keep it on this device") {
                    pendingConsent = nil
                    path.append(AnalysisRequest(document: doc, offline: true))
                }
                Button("Cancel", role: .cancel) { pendingConsent = nil }
            } message: { _ in
                Text("Gemini is the most accurate engine, but the text leaves your device and is processed by Google. "
                     + "Keeping it on this device uses on-device AI if available, otherwise the keyword engine.")
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fine Print")
                .font(.largeTitle.weight(.bold)).fontDesign(.serif)
                .foregroundStyle(Theme.ink)
            Text("Find what matters in a contract, and what Ontario law says about it.")
                .font(.callout).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            engineStatus
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var engineStatus: some View {
        Button { showSettings = true } label: {
            HStack(spacing: 6) {
                if model.checkingEngines || model.engine == nil {
                    ProgressView().controlSize(.small)
                    Text("Checking which AI engine works…")
                } else if let engine = model.engine {
                    Image(systemName: engine.kind.symbol)
                    Text("Reading with: \(engine.kind.displayName)")
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Theme.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens engine settings")
    }

    private var pasteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Paste a document")
            Card {
                TextEditor(text: $pasted)
                    .focused($editorFocused)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if pasted.isEmpty {
                            Text("Paste a lease, job offer or terms of service…")
                                .foregroundStyle(Theme.inkSecondary.opacity(0.7))
                                .padding(.top, 16).padding(.leading, 13)
                                .allowsHitTesting(false)
                        }
                    }
                Button {
                    editorFocused = false
                    start(LoadedDocument(title: "Pasted document", text: pasted, source: .text))
                } label: {
                    Label("Analyze pasted text", systemImage: "doc.text.magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        // Disabled state stays readable: warm grey text on the field colour,
                        // not faded white on pale peach.
                        .foregroundStyle(canAnalyzePasted ? Color.white : Theme.inkSecondary)
                        .background(canAnalyzePasted ? Theme.accent : Theme.field,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canAnalyzePasted)
                .padding(.top, 12)
            }
        }
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Import")
            Card(padding: 0) {
                Button { showFileImporter = true } label: {
                    RowLabel(icon: "doc.richtext", title: "PDF or text file", subtitle: "Uses the document's own text")
                }
                .buttonStyle(.plain)
                Divider().overlay(Theme.border).padding(.leading, 56)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    RowLabel(icon: "photo.on.rectangle", title: "Photo of a document", subtitle: "Read on this device with OCR")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var samplesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Try a sample")
            Card(padding: 0) {
                ForEach(Array(Sample.all.enumerated()), id: \.element.id) { index, sample in
                    if index > 0 { Divider().overlay(Theme.border).padding(.leading, 56) }
                    Button {
                        Task { await load("Opening \(sample.title)…") { try await sample.load() } }
                    } label: {
                        RowLabel(icon: sample.isImage ? "doc.viewfinder" : "doc.plaintext",
                                 title: sample.title, subtitle: sample.subtitle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    /// A Bool binding that is true while `value` is non-nil and clears it when set to false.
    private func isPresent<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }

    private func load(_ message: String, _ work: () async throws -> LoadedDocument) async {
        loading = message
        defer { loading = nil }
        do { start(try await work()) } catch { loadError = error.localizedDescription }
    }

    private func start(_ document: LoadedDocument) {
        if model.engine?.kind == .gemini && !model.sessionConsent {
            pendingConsent = document
        } else {
            path.append(AnalysisRequest(document: document, offline: false))
        }
    }
}

/// An icon + two-line row used inside cards. Full-width tap target, wraps at large text sizes.
struct RowLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSecondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
