import SwiftUI

struct ChillAudioDiagnosticsView: View {
    @StateObject private var probe = ChillPlayerProbe()

    var body: some View {
        NavigationStack {
            Form {
                Section("État") {
                    LabeledContent("Moteur", value: probe.state.rawValue)
                    Text(probe.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Generation associée à chaque opération; aucun cue ne démarre avec le moteur.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Cue et scheduling") {
                    Picker("Cue WAV", selection: $probe.selectedCue) {
                        ForEach(ChillPlayerProbe.Cue.allCases) { cue in
                            Text(cue.title).tag(cue)
                        }
                    }
                    Picker("Lead frames", selection: $probe.selectedLeadFrames) {
                        ForEach(probe.leadFrameChoices, id: \.self) { frames in
                            Text(String(format: "%d frames · %.2f ms @ %.0f Hz", CInt(frames),
                                        Double(frames) / max(probe.playerRate, 1) * 1_000,
                                        probe.playerRate))
                                .tag(frames)
                        }
                    }
                    Button("Démarrer le moteur (sans lire)") { probe.startEngine() }
                    Button("Planifier et lire le cue", action: probe.scheduleSelectedCue)
                        .disabled(probe.state != .ready && probe.state != .completed)
                    LabeledContent("Lead retenu", value: probe.scheduledLeadFrames.map { "\($0) frames · \(String(format: "%.2f", probe.scheduledLeadDurationMilliseconds ?? 0)) ms" } ?? "—")
                    LabeledContent("Sample time planifié", value: probe.scheduledNodeSampleTime.map { String($0) } ?? "—")
                    LabeledContent("Délai lastRenderTime", value: probe.startRenderDelayMilliseconds.map { String(format: "%.3f ms", $0) } ?? "—")
                }

                Section("Pause / reprise A-B") {
                    Button("Pause avec fondu technique 20 ms", action: probe.pauseWithTechnicalFade)
                        .disabled(probe.state != .playing && probe.state != .scheduled)
                    Picker("Offset de reprise", selection: $probe.resumePolicy) {
                        ForEach(ChillPlayerProbe.ResumePolicy.allCases) { policy in
                            Text(policy.title).tag(policy)
                        }
                    }
                    Button("Reprendre / reconstruire à l'offset choisi", action: probe.resumeUsingSelectedOffset)
                        .disabled(probe.state != .paused && probe.state != .interrupted && probe.state != .needsRebuild)
                    Button("Arrêter avec fondu (ou arrêt immédiat documenté)", action: probe.stopWithTechnicalFade)
                    LabeledContent("Position de reprise", value: probe.currentPositionText)
                    Text(probe.resumeOffsetText)
                        .font(.caption.monospacedDigit())
                        .textSelection(.enabled)
                    Text("A fige l'offset à la demande. B reprend à l'offset observé en fin de rampe. Le temps logique reste figé pendant le fondu; le signal peut avancer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Avant N0, stop() annule les événements du player; l'acceptation intervient après son retour. Un rendu concurrent avant ce retour reste possible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Gain") {
                    Picker("Nœud à tester", selection: $probe.selectedGainUnit) {
                        ForEach(ChillPlayerProbe.GainUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    Button("Inspecter les parameterTree", action: probe.inspectGainParameters)
                    Text(probe.gainParameterReport)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Text("Une rampe n'est programmée que si le paramètre identifié expose flag_CanRamp. −96 dB n'est pas un zéro numérique.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("La correspondance outputVolume / paramètre Audio Unit du mixer reste un candidat heuristique tant qu'elle n'est pas confirmée par le signal sur appareil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Formats et route") {
                    LabeledContent("WAV", value: String(format: "%.0f Hz", probe.wavRate))
                    LabeledContent("Player", value: String(format: "%.0f Hz", probe.playerRate))
                    LabeledContent("Nœud gain", value: String(format: "%.0f Hz", probe.gainRate))
                    LabeledContent("Sortie graphe", value: String(format: "%.0f Hz", probe.outputRate))
                    LabeledContent("Préparation → moteur", value: probe.engineSetupMilliseconds.map { String(format: "%.3f ms", $0) } ?? "—")
                    LabeledContent("Moteur → lastRenderTime", value: probe.startRenderDelayMilliseconds.map { String(format: "%.3f ms", $0) } ?? "—")
                    Text(probe.routeReport)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                Section("Signal rendu") {
                    Text(probe.captureReport)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Text(probe.attackReport)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Text(probe.rampSignalReport)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    LabeledContent("Vidange théorique outputLatency + ioBuffer",
                                   value: probe.theoreticalOutputDrainMilliseconds.map { String(format: "%.3f ms", $0) } ?? "non disponible")
                    LabeledContent("Temporisation appliquée",
                                   value: probe.estimatedOutputDrainMilliseconds.map { String(format: "%.3f ms", $0) } ?? "—")
                    Text(probe.outputDrainCeilingApplied
                         ? "Plafond de 1 s appliqué : temporisation saturée, silence acoustique non garanti."
                         : "La temporisation calculée ne garantit pas la fin du son physique; mesure externe requise selon la route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Les taps mesurent le graphe AVAudioEngine, pas le haut-parleur. outputLatency et la sortie acoustique doivent être mesurés séparément sur iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Journal horodaté") {
                    Button("Préparer le CSV et les samples") { probe.prepareExport() }
                    ShareLink(item: probe.exportReport, subject: Text("Rapport Chill Audio Diagnostics")) {
                        Label("Partager le rapport", systemImage: "square.and.arrow.up")
                    }
                    .disabled(probe.exportReport.isEmpty)
                    Text(probe.journalText.isEmpty ? "Aucun événement." : probe.journalText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Chill Audio Diagnostics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Arrêt") { probe.shutdown() }
                }
            }
            .onDisappear { probe.shutdown() }
        }
    }
}
