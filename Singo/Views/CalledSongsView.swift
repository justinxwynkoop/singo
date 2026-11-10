import MusicKit
import SwiftUI

/// Every song revealed so far, for checking a Singo claim.
/// The round pauses while this is open and picks up again when it closes.
struct CalledSongsView: View {
    let controller: GameController

    enum Order: String, CaseIterable {
        case called = "Order called"
        case alphabetical = "A–Z by title"
    }

    @State private var order: Order = .called

    private var rows: [CalledSong] {
        let called = controller.engine.called
        switch order {
        case .called:
            return called
        case .alphabetical:
            return called.sorted {
                $0.song.title.localizedCaseInsensitiveCompare($1.song.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack {
                Text("Called songs (\(rows.count))")
                    .font(.system(size: 52, weight: .bold))
                Spacer()
                Picker("Sort", selection: $order) {
                    ForEach(Order.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 600)
            }

            if rows.isEmpty {
                Spacer()
                Text("No songs called yet.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(rows) { entry in
                    let song = controller.info(for: entry.song)
                    // A focusable row so the remote can scroll the list.
                    Button {} label: {
                        HStack(spacing: 30) {
                            Text("\(entry.number)")
                                .font(.system(size: 30, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                            if let artwork = controller.artwork(for: song.id) {
                                ArtworkImage(artwork, width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title).font(.system(size: 34, weight: .semibold))
                                Text(song.artistName).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Text("Press Menu to go back to the round.")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
        }
        .padding(60)
    }
}
