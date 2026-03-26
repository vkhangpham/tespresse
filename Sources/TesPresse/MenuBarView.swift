import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var alarmManager: AlarmManager
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("T'es pressé ?")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text(alarmManager.statusSummary(now: now))
                .foregroundStyle(.secondary)

            HStack {
                Label("Countdown", systemImage: "timer")
                Spacer()
                Text(alarmManager.countdownSummary(now: now))
                    .monospacedDigit()
            }

            HStack {
                Label("Prompt pool", systemImage: "books.vertical")
                Spacer()
                Text("\(alarmManager.activeSentencePool.count)")
                    .monospacedDigit()
            }

            HStack {
                Label("Voice backend", systemImage: "waveform")
                Spacer()
                Text(alarmManager.loadedVoiceModels.isEmpty ? "Waiting" : "MLX-Audio")
                    .foregroundStyle(alarmManager.loadedVoiceModels.isEmpty ? .secondary : .primary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Random interval")
                    .font(.headline)
                HStack {
                    Stepper("Min \(Int(alarmManager.minimumIntervalMinutes))m", value: $alarmManager.minimumIntervalMinutes, in: 1...120)
                    Stepper("Max \(Int(alarmManager.maximumIntervalMinutes))m", value: $alarmManager.maximumIntervalMinutes, in: alarmManager.minimumIntervalMinutes...240)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Actions")
                    .font(.headline)

                HStack {
                    Button("Trigger Now") {
                        alarmManager.triggerAlarm()
                    }
                    Button("Control Center") {
                        alarmManager.showControlCenter()
                    }
                    Button("Replay") {
                        alarmManager.replaySentence()
                    }
                    .disabled(!alarmManager.canReplayNow)
                }

                HStack {
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

            Divider()

            HStack {
                Button("Rescan Sources") {
                    alarmManager.refreshSentenceSources()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
        .onReceive(timer) { current in
            now = current
        }
    }
}
