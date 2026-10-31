import Charts
import SwiftUI

struct JoinBlock: View {
    let code: String?
    let joined: Int
    let families: [LobbyFamily]

    var body: some View {
        HStack(alignment: .center, spacing: 72) {
            joinColumn
            roster
        }
    }

    private var joinColumn: some View {
        VStack(spacing: 28) {
            Eyebrow("Scan to join", systemImage: "qrcode.viewfinder")
            if let code {
                QRCodeView(text: code)
                    .frame(width: 400, height: 400)
                    .padding(24)
                    .background(.white, in: .rect(cornerRadius: 36))
                Text("Open Moonfall on your phone and scan, or type the code")
                    .font(.stageRounded(30, weight: .medium))
                    .foregroundStyle(DisplayPalette.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                HStack(spacing: 20) {
                    ForEach(Array(groups(of: code).enumerated()), id: \.offset) { _, group in
                        Text(group)
                            .font(.system(size: 76, weight: .bold, design: .default).monospacedDigit())
                            .foregroundStyle(DisplayPalette.primary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Join code \(code.map(String.init).joined(separator: " "))")
            }
        }
        .frame(width: 560)
    }

    private func groups(of code: String) -> [String] {
        stride(from: 0, to: code.count, by: 3).map { start in
            let from = code.index(code.startIndex, offsetBy: start)
            let to = code.index(from, offsetBy: min(3, code.count - start))
            return String(code[from ..< to])
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("\(joined) \(joined == 1 ? "player" : "players") joined", systemImage: "person.3.fill")
                .font(.stage(64))
                .foregroundStyle(DisplayPalette.primary)
            if families.isEmpty {
                Text("Waiting for the first family…")
                    .font(.stageRounded(40, weight: .medium))
                    .foregroundStyle(DisplayPalette.secondary)
            } else {
                let shown = Array(families.prefix(PublicDisplayLayout.maxRosterTiles))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), spacing: 20)], alignment: .leading, spacing: 20) {
                    ForEach(shown) { family in
                        tile(family)
                    }
                }
                if families.count > shown.count {
                    Text("+\(families.count - shown.count) more")
                        .font(.stageRounded(34, weight: .semibold))
                        .foregroundStyle(DisplayPalette.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tile(_ family: LobbyFamily) -> some View {
        DisplayCard {
            HStack(spacing: 18) {
                FaceView(selfie: family.selfie, initial: String(family.player?.first ?? family.name.first ?? "?"), size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(family.name)
                        .font(.stage(40))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(family.player ?? "Waiting…")
                        .font(.stageRounded(28, weight: .medium))
                        .foregroundStyle(DisplayPalette.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(-12)
        }
        .foregroundStyle(DisplayPalette.primary)
        .accessibilityElement(children: .combine)
    }
}

struct ResultBlock: View {
    let result: VoteResultView

    var body: some View {
        VStack(spacing: 28) {
            Eyebrow(result.isFinal ? "Final vote result" : "Vote result", systemImage: "hand.raised.fill")
            DisplayCard(tint: result.expelled.isEmpty ? nil : DisplayPalette.redFill) {
                VStack(spacing: 8) {
                    if let expelled = result.expelled.first {
                        Text(expelled.name)
                            .font(.stage(150))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Text("was voted out")
                            .font(.stageRounded(52, weight: .semibold))
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 72))
                        Text("Nobody was voted out")
                            .font(.stage(110))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    }
                }
                .foregroundStyle(DisplayPalette.primary)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 1300)
            if !result.rows.isEmpty {
                chart
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart(result.rows) { row in
            BarMark(x: .value("Votes", row.count), y: .value("Candidate", row.name))
                .foregroundStyle(row.isSkip ? DisplayPalette.grey : DisplayPalette.redBright)
                .cornerRadius(8)
                .annotation(position: .trailing) {
                    Text("\(row.count)")
                        .font(.stageDigits(36))
                        .foregroundStyle(DisplayPalette.primary)
                }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.stageRounded(32, weight: .medium))
                    .foregroundStyle(DisplayPalette.primary)
            }
        }
        .frame(maxWidth: 1100)
        .frame(height: min(CGFloat(result.rows.count) * 64 + 16, 400))
    }
}

struct RevealBlock: View {
    let outcome: Outcome
    let families: [RevealedFamily]

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Werewolves win!")
                    .font(.stage(180))
                    .foregroundStyle(DisplayPalette.redText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(outcome.reason.explanation)
                    .font(.stageRounded(44, weight: .medium))
                    .foregroundStyle(DisplayPalette.secondary)
                    .multilineTextAlignment(.center)
            }
            CenteredFlowLayout(spacing: 20) {
                ForEach(families) { family in
                    card(family).frame(width: 340)
                }
            }
        }
    }

    private func card(_ family: RevealedFamily) -> some View {
        HStack(spacing: 16) {
            FaceView(selfie: family.selfie, initial: String(family.player?.first ?? family.name.first ?? "?"), size: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(family.name)
                    .font(.stage(38))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let player = family.player {
                    Text(player)
                        .font(.stageRounded(26, weight: .medium))
                        .foregroundStyle(DisplayPalette.secondary)
                        .lineLimit(1)
                }
                if family.isWerewolf {
                    Label("Werewolf", systemImage: Role.werewolf.symbol)
                        .font(.stageRounded(28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(DisplayPalette.primary)
        .padding(14)
        .background(family.isWerewolf ? DisplayPalette.redFill : DisplayPalette.card, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
