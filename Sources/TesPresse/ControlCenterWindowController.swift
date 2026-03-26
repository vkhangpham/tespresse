import AppKit
import SwiftUI

@MainActor
final class ControlCenterWindowController: NSWindowController {
    init(manager: AlarmManager) {
        let view = ControlCenterView()
            .environmentObject(manager)

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "T'es pressé ?"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 760, height: 760))
        window.center()
        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

struct ControlCenterView: View {
    @EnvironmentObject private var alarmManager: AlarmManager
    @State private var previewQuery = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                timingCard
                voiceCard
                responseCard
                sourceCard
                previewCard
                quickActionsCard
            }
            .padding(24)
        }
        .frame(width: 760, height: 760)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.orange.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("T'es pressé ?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Random French listening drills from your own books.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("\(alarmManager.activeSentencePool.count) prompts", systemImage: "books.vertical.fill")
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.15), in: Capsule())
        }
    }

    private var timingCard: some View {
        card("Timing", systemImage: "timer") {
            VStack(alignment: .leading, spacing: 10) {
                Stepper(value: $alarmManager.minimumIntervalMinutes, in: 1...180, step: 1) {
                    Text("Minimum gap between alarms: \(Int(alarmManager.minimumIntervalMinutes)) min")
                }

                Stepper(value: $alarmManager.maximumIntervalMinutes, in: alarmManager.minimumIntervalMinutes...240, step: 1) {
                    Text("Maximum random interval: \(Int(alarmManager.maximumIntervalMinutes)) min")
                }

                Stepper(value: $alarmManager.repeatSpeechEverySeconds, in: 5...90, step: 1) {
                    Text("Repeat the sentence every \(Int(alarmManager.repeatSpeechEverySeconds)) sec while active")
                }

                Text("The app will always wait at least the minimum gap before another prompt can fire.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var responseCard: some View {
        card("Turn-Off Method", systemImage: "mic.badge.plus") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Response mode", selection: $alarmManager.responseMode) {
                    ForEach(ResponseMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(alarmManager.responseMode.subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var voiceCard: some View {
        card("Open-Source Voice Models", systemImage: "waveform.badge.mic") {
            VStack(alignment: .leading, spacing: 12) {
                if alarmManager.isRefreshingVoiceServerStatus {
                    ProgressView("Checking MLX-Audio server...")
                } else {
                    Text(alarmManager.voiceServerStatusMessage)
                        .foregroundStyle(.secondary)
                }

                TextField("Voice server URL", text: $alarmManager.voiceServiceBaseURL)
                    .textFieldStyle(.roundedBorder)

                TextField("TTS model", text: $alarmManager.ttsModelName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("TTS voice", text: $alarmManager.ttsVoiceName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Lang", text: $alarmManager.ttsLanguageCode)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                TextField("STT model", text: $alarmManager.sttModelName)
                    .textFieldStyle(.roundedBorder)

                Stepper(value: $alarmManager.ttsSpeed, in: 0.7...1.35, step: 0.05) {
                    Text("TTS speed: \(alarmManager.ttsSpeed.formatted(.number.precision(.fractionLength(2))))")
                }

                if !alarmManager.loadedVoiceModels.isEmpty {
                    Text("Loaded on server")
                        .font(.headline)

                    ForEach(alarmManager.loadedVoiceModels, id: \.self) { model in
                        Text(model)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Text("Start the server in tmux with `\(alarmManager.voiceServerLaunchCommand)`.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("First run is heavier: Kokoro TTS downloads about 361 MB and Whisper STT about 1.6 GB before they feel instant.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Check Voice Server") {
                        alarmManager.refreshVoiceServerStatus()
                    }

                    Button("Restore Voice Defaults") {
                        alarmManager.restoreDefaultVoiceSettings()
                    }
                }
            }
        }
    }

    private var sourceCard: some View {
        card("Sentence Sources", systemImage: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: 12) {
                if alarmManager.isImportingSentenceSources {
                    ProgressView("Scanning French source files...")
                } else {
                    Text(alarmManager.importStatusMessage)
                        .foregroundStyle(.secondary)
                }

                Text("Configured paths")
                    .font(.headline)

                if alarmManager.selectedSourcePaths.isEmpty {
                    Text("No custom paths selected. The app will fall back to its built-in prompt list.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(alarmManager.selectedSourcePaths, id: \.self) { path in
                        Text(path)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    }
                }

                if !alarmManager.sourceSummaries.isEmpty {
                    Divider()
                    Text("Imported sources")
                        .font(.headline)

                    ForEach(alarmManager.sourceSummaries) { summary in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(summary.displayName) • \(summary.importedSentenceCount) prompts")
                            Text(summary.path)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Button("Scan Current Sources") {
                        alarmManager.refreshSentenceSources()
                    }

                    Button("Choose Files or Folder…") {
                        alarmManager.chooseSentenceSources()
                    }

                    Button("Restore Defaults") {
                        alarmManager.restoreDefaultSources()
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        card("Imported Prompt Preview", systemImage: "list.bullet.rectangle.portrait") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Filter by prompt text or source name", text: $previewQuery)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("\(filteredImportedSentences.count) visible")
                    Spacer()
                    Text("\(alarmManager.importedSentences.count) imported total")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)

                if alarmManager.importedSentences.isEmpty {
                    Text("No imported prompts yet. Scan your source files first, or the app will keep using the fallback prompts.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        previewHeader

                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filteredImportedSentences.enumerated()), id: \.element.id) { offset, sentence in
                                    PromptPreviewRow(
                                        index: offset + 1,
                                        sentence: sentence
                                    )

                                    if offset < filteredImportedSentences.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 240, maxHeight: 320)
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var quickActionsCard: some View {
        card("Quick Actions", systemImage: "bolt.fill") {
            HStack {
                Button("Trigger Test Alarm") {
                    alarmManager.triggerAlarm()
                }

                Button("Snooze 5m") {
                    alarmManager.snooze(minutes: 5)
                }
                .disabled(alarmManager.currentChallenge == nil)

                Button("Pause 30m") {
                    alarmManager.pause(minutes: 30)
                }

                Button("Mute 15m") {
                    alarmManager.mute(minutes: 15)
                }
            }
        }
    }

    private func card<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var previewHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("#")
                .font(.caption.weight(.semibold))
                .frame(width: 36, alignment: .trailing)

            Text("Source")
                .font(.caption.weight(.semibold))
                .frame(width: 220, alignment: .leading)

            Text("French Prompt")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.04))
    }

    private var filteredImportedSentences: [FrenchSentence] {
        let query = previewQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return alarmManager.importedSentences
        }

        return alarmManager.importedSentences.filter { sentence in
            sentence.text.localizedCaseInsensitiveContains(query) ||
            sentence.sourceTitle.localizedCaseInsensitiveContains(query) ||
            sentence.sourcePath.localizedCaseInsensitiveContains(query)
        }
    }
}

private struct PromptPreviewRow: View {
    let index: Int
    let sentence: FrenchSentence

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Text(sentence.sourceTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)

            Text(sentence.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
