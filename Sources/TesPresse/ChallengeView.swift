import SwiftUI

struct ChallengeView: View {
    @EnvironmentObject private var alarmManager: AlarmManager
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("T'es pressé ?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Type it or repeat it to stop the alarm, depending on the mode you chose.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: alarmManager.menuBarSymbolName)
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
            }

            if let challenge = alarmManager.currentChallenge {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Triggered at \(challenge.triggeredAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                        .foregroundStyle(.secondary)
                    Label("Source: \(challenge.sentence.sourceTitle)", systemImage: "book")
                        .foregroundStyle(.secondary)

                    if alarmManager.isAnswerRevealed {
                        Text(challenge.sentence.text)
                            .font(.title3.weight(.semibold))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Text("Listen closely, then answer from memory.")
                            .font(.title3.weight(.semibold))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                if alarmManager.responseMode != .speechOnly {
                    typingSection
                }

                if alarmManager.responseMode != .typingOnly {
                    speechSection
                }

                controlStrip
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No active alarm")
                        .font(.title2.weight(.semibold))
                    Text("The next random prompt will open this window automatically when it's time.")
                        .foregroundStyle(.secondary)
                }
                controlStrip
            }
        }
        .padding(22)
        .frame(width: 520, height: 470, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.orange.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if alarmManager.responseMode != .speechOnly {
                isInputFocused = true
            }
        }
    }

    private var typingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type the sentence")
                .font(.headline)

            TextField("Ex: Je n'ai pas encore fini mon café.", text: $alarmManager.typedResponse)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .onSubmit {
                    alarmManager.submitTypedResponse()
                }

            HStack {
                Button("Submit") {
                    alarmManager.submitTypedResponse()
                }
                .keyboardShortcut(.return, modifiers: [])

                Button("Replay") {
                    alarmManager.replaySentence()
                }
                .disabled(!alarmManager.canReplayNow)

                Button("Reveal Answer") {
                    alarmManager.revealAnswer()
                }
            }
        }
    }

    private var speechSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repeat the sentence")
                .font(.headline)

            HStack {
                Button(alarmManager.isListening ? "Stop & Transcribe" : "Start Recording") {
                    if alarmManager.isListening {
                        alarmManager.stopListening()
                    } else {
                        alarmManager.startListening()
                    }
                }
                .disabled(alarmManager.isTranscribingSpeech)

                Button("Replay") {
                    alarmManager.replaySentence()
                }
                .disabled(!alarmManager.canReplayNow)

                Button("Reveal Answer") {
                    alarmManager.revealAnswer()
                }
            }

            if alarmManager.isTranscribingSpeech {
                ProgressView("Transcribing with \(alarmManager.sttModelName)...")
            }

            if !alarmManager.speechTranscript.isEmpty {
                Text(alarmManager.speechTranscript)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text("Open-source speech stack: Kokoro TTS + Whisper STT via MLX-Audio.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var controlStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("Quick controls")
                .font(.headline)

            HStack {
                Button("Snooze 5m") {
                    alarmManager.snooze(minutes: 5)
                }
                Button("Snooze 10m") {
                    alarmManager.snooze(minutes: 10)
                }
                Button("Mute 15m") {
                    alarmManager.mute(minutes: 15)
                }
                Button("Pause 30m") {
                    alarmManager.pause(minutes: 30)
                }
            }
        }
    }
}
