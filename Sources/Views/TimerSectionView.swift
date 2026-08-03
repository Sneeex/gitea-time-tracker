import SwiftUI

public struct TimerSectionView: View {
    @ObservedObject var timerService = TimerService.shared
    @ObservedObject var idleDetector = IdleDetector.shared
    @ObservedObject var syncManager = OfflineSyncManager.shared

    @State private var isTimeAdjustPopoverPresented: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // MARK: - Active Issue Banner / Empty State Banner
            if let issue = timerService.activeIssue {
                HStack(spacing: 10) {
                    Image(systemName: "circle.circle.fill")
                        .foregroundColor(timerService.state == .running ? .green : (timerService.state == .paused ? .orange : .blue))
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(issue.formattedKey)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)

                            if let repo = issue.repository {
                                Text(repo.name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(issue.title)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    Spacer()

                    Button {
                        timerService.toggleFavorite(issue)
                    } label: {
                        Image(systemName: timerService.isFavorite(issue) ? "star.fill" : "star")
                            .foregroundColor(timerService.isFavorite(issue) ? .yellow : .gray)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Favorit umschalten")

                    Button {
                        timerService.dismissActiveIssue()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Issue/PR abwählen")
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundColor(.blue.opacity(0.8))

                    Text("Kein Issue ausgewählt")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Wähle ein Issue aus dem Reiter 'Issues', um Zeit zu erfassen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
            }

            // MARK: - Big Monospace Timer Display
            VStack(spacing: 8) {
                Button {
                    isTimeAdjustPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text(SmartTimeParser.formatTimerString(timerService.elapsedSeconds))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(timerService.state == .running ? .green : (timerService.state == .paused ? .orange : .primary))

                        Image(systemName: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Circle().fill(Color.blue.opacity(0.12)))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.primary.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isTimeAdjustPopoverPresented ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isTimeAdjustPopoverPresented, arrowEdge: .bottom) {
                    TimeAdjusterPopoverView(
                        elapsedSeconds: Binding(
                            get: { timerService.elapsedSeconds },
                            set: { timerService.setElapsedSeconds($0) }
                        )
                    )
                }
                .help("Klicken, um die Zeit anzupassen")

                Text(timerService.state == .running ? "LÄUFT" : (timerService.state == .paused ? "PAUSIERT" : "BEREIT"))
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(timerService.state == .running ? Color.green.opacity(0.2) : (timerService.state == .paused ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2)))
                    )
                    .foregroundColor(timerService.state == .running ? .green : (timerService.state == .paused ? .orange : .gray))
            }

            // MARK: - Quick Adjust Buttons (+15m, +30m, +1h, +2h)
            HStack(spacing: 6) {
                Text("Schnellwahl:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button("+15m") { timerService.addSeconds(15 * 60) }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                Button("+30m") { timerService.addSeconds(30 * 60) }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                Button("+1h") { timerService.addSeconds(60 * 60) }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                Button("+2h") { timerService.addSeconds(120 * 60) }
                    .buttonStyle(.bordered)
                    .font(.caption2)
            }

            // MARK: - Action Buttons (Only when active issue selected)
            if let issue = timerService.activeIssue {
                HStack(spacing: 12) {
                    if timerService.state == .running {
                        Button {
                            timerService.pause()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if timerService.state == .paused {
                                timerService.resume()
                            } else {
                                timerService.start(issue: issue)
                            }
                        } label: {
                            Label(timerService.state == .paused ? "Weiter" : "Start", systemImage: "play.fill")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        Task {
                            await timerService.stopAndLogTime()
                        }
                    } label: {
                        if timerService.isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Buchen", systemImage: "arrow.up.circle.fill")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill((timerService.elapsedSeconds == 0 || timerService.isSubmitting) ? Color.gray.opacity(0.4) : Color.blue)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(timerService.elapsedSeconds == 0 || timerService.isSubmitting)

                    Button {
                        timerService.stop()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Timer verwerfen")
                }
            }

            // MARK: - Status Message
            if let msg = timerService.statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .overlay {
            if idleDetector.isIdleDialogPresented {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()

                    IdleConfirmationView(idleSeconds: idleDetector.detectedIdleSeconds)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(NSColor.windowBackgroundColor))
                                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
                        )
                        .padding(16)
                }
            }
        }
    }
}

// MARK: - Modern Polished Time Adjuster Popover
struct TimeAdjusterPopoverView: View {
    @Binding var elapsedSeconds: Int
    @Environment(\.dismiss) private var dismiss

    private var hours: Int {
        elapsedSeconds / 3600
    }
    private var minutes: Int {
        (elapsedSeconds % 3600) / 60
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Zeitanpassung")
                .font(.headline)

            // MARK: - Stepper Controls for Hours & Minutes
            HStack(spacing: 20) {
                // Hours Stepper
                VStack(spacing: 4) {
                    Text("Stunden")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            if hours > 0 {
                                elapsedSeconds = max(0, elapsedSeconds - 3600)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Text("\(hours)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(width: 32)

                        Button {
                            elapsedSeconds += 3600
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .frame(height: 36)

                // Minutes Stepper
                VStack(spacing: 4) {
                    Text("Minuten")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            if minutes > 0 {
                                elapsedSeconds = max(0, elapsedSeconds - 60)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Text("\(minutes)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(width: 32)

                        Button {
                            elapsedSeconds += 60
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))

            // MARK: - Quick Presets Chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Dauer setzen:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    Button("15 Min") { elapsedSeconds = 15 * 60 }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button("30 Min") { elapsedSeconds = 30 * 60 }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button("45 Min") { elapsedSeconds = 45 * 60 }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button("1 Std") { elapsedSeconds = 60 * 60 }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button("1.5 Std") { elapsedSeconds = 90 * 60 }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    Button("2 Std") { elapsedSeconds = 120 * 60 }
                        .buttonStyle(.bordered)
                        .font(.caption)
                }
            }

            Button("Fertig") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 280)
    }
}

// MARK: - AFK / Idle Dialog View
struct IdleConfirmationView: View {
    let idleSeconds: Int
    @ObservedObject var timerService = TimerService.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .foregroundColor(.indigo)

            Text("Inaktivität erkannt")
                .font(.headline)

            Text("Du warst ca. **\(SmartTimeParser.formatHumanReadable(idleSeconds))** inaktiv oder der Mac hat geschlafen.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                Button {
                    IdleDetector.shared.isIdleDialogPresented = false
                } label: {
                    Text("Inaktive Zeit behalten (\(SmartTimeParser.formatHumanReadable(idleSeconds)))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    timerService.deductIdleSeconds(idleSeconds)
                    IdleDetector.shared.isIdleDialogPresented = false
                } label: {
                    Text("Inaktive Zeit abziehen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    timerService.stop()
                    IdleDetector.shared.isIdleDialogPresented = false
                } label: {
                    Text("Timer verwerfen")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
