// Engine status (with the probe log), Gemini key and permission, and rule-pack provenance.

import FinePrintAI
import FinePrintCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keyField = ""

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Group {
                Section {
                    if let engine = model.engine {
                        Label(engine.kind.displayName, systemImage: engine.kind.symbol).font(.headline)
                        ForEach(engine.log, id: \.self) { Text($0).font(.caption).foregroundStyle(Theme.inkSecondary) }
                    }
                    Button {
                        Task { await model.checkEngines() }
                    } label: {
                        HStack {
                            Text("Check engines again")
                            if model.checkingEngines { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(model.checkingEngines)
                } header: {
                    Text("Analysis engine")
                } footer: {
                    Text("Engines are chosen by running a real test request, not by trusting what the system reports. "
                         + "Order: Gemini (if allowed), then on-device AI, then the keyword engine.")
                }

                Section {
                    Toggle("Allow sending documents to Gemini", isOn: $model.geminiAllowed)
                        .onChange(of: model.geminiAllowed) { Task { await model.checkEngines() } }
                    switch model.keySource {
                    case .keychain:
                        Label("API key saved in the Keychain", systemImage: "key.fill").foregroundStyle(Theme.compliant)
                        Button("Remove key", role: .destructive) { Task { await model.removeGeminiKey() } }
                    case .developmentEnvironment:
                        Label("Using a development key from the launch environment (debug builds only)",
                              systemImage: "hammer.fill").foregroundStyle(Theme.inkSecondary)
                    case .none:
                        SecureField("Gemini API key", text: $keyField)
                            .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                        Button("Save key") {
                            Task { await model.saveGeminiKey(keyField); keyField = "" }
                        }
                        .disabled(keyField.trimmingCharacters(in: .whitespaces).isEmpty)
                        if let error = model.keySaveError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(Theme.violation)
                        }
                    }
                } header: {
                    Text("Google Gemini")
                } footer: {
                    Text("The most accurate engine in testing. Document text is sent to Google for processing, and "
                         + "you'll be asked to confirm once per session. Your key is stored only in this device's Keychain.")
                }

                Section {
                    Toggle("Use on-device AI when available", isOn: $model.allowOnDevice)
                        .onChange(of: model.allowOnDevice) { Task { await model.checkEngines() } }
                } footer: {
                    Text("Private and offline, but it found fewer clauses than Gemini in testing.")
                }

                Section("Rule packs") {
                    ForEach(model.packs, id: \.id) { pack in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pack.name).font(.subheadline.weight(.semibold))
                            Text("\(pack.rules.count) rules · \(pack.jurisdiction) · checked \(pack.lastVerified)")
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                            if let url = URL(string: pack.sourceUrl) {
                                Link("Official source", destination: url).font(.caption)
                            }
                        }
                    }
                    ForEach(model.packProblems, id: \.self) {
                        Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.violation).font(.caption)
                    }
                }

                Section("About") {
                    Text(ReportFormatter.disclaimer).font(.footnote)
                }
                }
                .listRowBackground(Theme.card)
            }
            .warmList()
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
