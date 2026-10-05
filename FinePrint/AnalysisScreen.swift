// Runs the pipeline with live stage progress, then shows findings grouped by tier.

import FinePrintAI
import FinePrintCore
import SwiftUI

@MainActor
@Observable
final class AnalysisRun {
    var stage: AnalysisStage?
    var report: AnalysisReport?
    var engineName: String?
    var error: String?

    func start(_ request: AnalysisRequest, model: AppModel) async {
        guard report == nil, error == nil else { return }
        guard let selection = await model.engineForRequest(request) else {
            error = "No analysis engine is available."
            return
        }
        engineName = selection.kind.displayName
        let analyzer = Analyzer(extractor: selection.extractor, engine: model.ruleEngine)
        do {
            report = try await analyzer.analyze(request.document.text, source: request.document.source) { stage in
                Task { @MainActor in self.stage = stage }
            }
        } catch is CancellationError {
            // left the screen
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AnalysisScreen: View {
    let request: AnalysisRequest
    @Environment(AppModel.self) private var model
    @State private var run = AnalysisRun()

    var body: some View {
        Group {
            if let report = run.report {
                ResultsList(report: report, document: request.document)
            } else if let error = run.error {
                ContentUnavailableView("Analysis failed", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressStages(stage: run.stage, engineName: run.engineName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(request.document.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await run.start(request, model: model) }
    }
}

// MARK: - Progress

struct ProgressStages: View {
    let stage: AnalysisStage?
    let engineName: String?

    private var steps: [(String, Bool, Bool)] {
        // (label, done, active)
        let order: Int = switch stage {
        case nil, .classifying: 0
        case .reading: 1
        case .checkingQuotes: 2
        case .applyingRules: 3
        }
        var reading = "Reading the clauses"
        if case let .reading(section, total) = stage, total > 1 { reading += " (section \(section) of \(total))" }
        return [("Identifying the document type", order > 0, order == 0),
                (reading, order > 1, order == 1),
                ("Checking every quote against your document", order > 2, order == 2),
                ("Applying the rules", false, order == 3)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let engineName {
                Label("Reading with \(engineName)", systemImage: "sparkle.magnifyingglass")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            ForEach(steps, id: \.0) { label, done, active in
                HStack(spacing: 12) {
                    Group {
                        if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.compliant) }
                        else if active { ProgressView() }
                        else { Image(systemName: "circle").foregroundStyle(Theme.inkSecondary.opacity(0.6)) }
                    }
                    .frame(width: 24)
                    Text(label)
                        .foregroundStyle(done || active ? Theme.ink : Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(24)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Results

struct ResultsList: View {
    let report: AnalysisReport
    let document: LoadedDocument

    var body: some View {
        List {
            Group {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ReportFormatter.label(report.documentType))
                            .font(.title3.weight(.semibold)).fontDesign(.serif).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text("\(Int((report.typeConfidence * 100).rounded()))% sure")
                            .font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    HStack(alignment: .top) {
                        ForEach(Tier.displayOrder, id: \.self) { TierCount(tier: $0, count: report.count($0)) }
                    }
                    Label("Read by \(report.engineName) in \(String(format: "%.1f", report.elapsedSeconds))s",
                          systemImage: "cpu").font(.caption).foregroundStyle(Theme.inkSecondary)
                }
                .padding(.vertical, 4)
            }

            if report.documentType == .unknown {
                Section {
                    Label("This document type has no rule pack, so the app only points out common patterns. "
                          + "It makes no legal judgments here.", systemImage: "info.circle")
                        .font(.footnote)
                }
            }
            if !report.failedChunks.isEmpty {
                Section {
                    Label("\(report.failedChunks.count) section(s) couldn't be analyzed. Read them yourself; "
                          + "nothing in them is reflected below.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(Theme.violation)
                }
            }
            if !report.dropped.isEmpty {
                Section {
                    ForEach(ReportFormatter.discardSummary(report), id: \.self) { line in
                        Label("Discarded: " + line, systemImage: "shield.lefthalf.filled")
                            .font(.footnote).foregroundStyle(Theme.inkSecondary)
                    }
                } footer: {
                    Text("These checks run in code after the AI answers, so a mistaken AI suggestion never reaches you as a verdict.")
                        .foregroundStyle(Theme.inkSecondary)
                }
            }

            ForEach(Tier.displayOrder, id: \.self) { tier in
                let items = report.findings.filter { $0.tier == tier }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { finding in
                            NavigationLink {
                                ClauseDetailView(finding: finding, document: document)
                            } label: {
                                FindingRow(finding: finding, document: document)
                            }
                        }
                    } header: {
                        Label(tier.label, systemImage: tier.symbol)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(tier.color).textCase(nil)
                    } footer: {
                        Text(tier.meaning).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }

            if report.findings.isEmpty {
                ContentUnavailableView("Nothing flagged", systemImage: "checkmark.circle",
                                       description: Text("No clauses matched the patterns or rules this app checks."))
            }

            Section {
                Text(ReportFormatter.disclaimer).font(.caption2).foregroundStyle(Theme.inkSecondary)
            }
            }
            .listRowBackground(Theme.card)
            .foregroundStyle(Theme.ink)
        }
        .warmList()
        .toolbar {
            ShareLink(item: ReportFormatter.text(report, documentTitle: document.title, source: document.text)) {
                Label("Share report", systemImage: "square.and.arrow.up")
            }
        }
    }
}

struct FindingRow: View {
    let finding: Finding
    let document: LoadedDocument

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.tier.symbol).foregroundStyle(finding.tier.color).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("\u{201C}\(document.text.slice(finding.clause.range))\u{201D}")
                    .font(.caption).foregroundStyle(Theme.inkSecondary).lineLimit(2)
                if let citation = finding.citation {
                    Text(citation).font(.caption2).foregroundStyle(.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(finding.tier.label)
    }
}
