# Singo Night

A private Apple TV app for family Singo nights. It shuffles an Apple Music
playlist, plays a fixed-length clip of each song on a black screen, fades in
hints on a timer, then reveals the answer and adds it to the called list.

Family only: installed from Xcode, never the App Store or TestFlight.

## First-time setup

1. **Turn on MusicKit for the app ID.** In the Apple Developer portal
   (Certificates, Identifiers & Profiles → Identifiers), register the bundle ID
   `family.singonight.app` (or your own, see step 3) and tick **MusicKit**
   under App Services.
2. **Open `Singo.xcodeproj`** in Xcode 16 or later.
3. **Signing.** Select the Singo target → Signing & Capabilities → pick your
   team. If the bundle ID is taken, change it here and use the same one in
   step 1.
4. **Pair the Apple TV.** On the Apple TV: Settings → Remotes and Devices →
   Remote App and Devices. In Xcode: Window → Devices and Simulators, pick the
   Apple TV and pair. Both need to be on the same Wi-Fi.
5. **Run.** Choose the Apple TV as the run destination and press ⌘R. The first
   launch asks for Apple Music access.

The Apple TV needs to be signed into an Apple Music account with an active
subscription. The tvOS Simulator can't play Apple Music, so test playback on a
real Apple TV.

## Playing a round

1. Pick a playlist. The setup screen shows the playlist on the left with
   **Start Round**, and the settings on the right: click a row to change it.
   **Round:** clip length, where each song starts, the add-time button, and
   whether the next song starts automatically. **Hints:** genre, release
   year, title, album art and artist, each of which can be turned off. A
   timeline under the hints shows when each one appears. Choices are
   remembered.
2. Each song, with a 30-second clip:

   | Time | What happens |
   | ---- | ------------ |
   | 0s   | Black screen, song starts 45s in, countdown ring begins |
   | 10s  | Title hint, if turned on: a blank per letter, like `H _ _   J _ _ _` |
   | 15s  | Genre and release year (each can be turned off) |
   | 20s  | Album art fades in heavily blurred, sharpening until 30s |
   | 25s  | Artist |
   | 30s  | Reveal: title, artist, sharp art; added to the called list |
   | 35s  | Next song (or wait for the host, if auto-advance is off) |

   Hint times scale with the clip length, so a 60-second clip shows hints at
   20, 30, 40 and 50 seconds.

### Remote

| Press | Does |
| ----- | ---- |
| Play/Pause | Pause or resume the song and the clock |
| Replay | Restart the clip from the start offset (hints already shown stay up) |
| +15 sec | Before the reveal: pushes the reveal back. After: keeps the answer up longer |
| Called songs | Pauses and opens a full-screen list of every revealed song, in order or A–Z, to check a Singo |
| Skip / Next | Next song. A song skipped before its reveal isn't added to the called list |
| Menu/Back | Pauses and asks whether to end the round |

The control buttons sit dimmed along the bottom; swipe to move between them and
click to press. They're buttons rather than swipe shortcuts so a stray swipe
can't skip a song.

## Code layout

```
Singo/
  SingoApp.swift          App entry
  Core/                   Game rules, no Apple frameworks (unit tested)
    RoundEngine.swift     Timer state machine: hints, reveal, advance, called list
    RoundSettings.swift   Every timing setting, hint schedule, start offset
    TitleHint.swift       Title as blanks: "H _ _   J _ _ _"
    SongInfo.swift        Song details the game needs
  Music/                  MusicKit and app state
    MusicLibrary.swift    Permission, playlists, playlist songs
    ClipPlayer.swift      ApplicationMusicPlayer: play a song from an offset
    GameController.swift  Runs a round: clock, engine, player, catalog lookups
    SettingsStore.swift   Saves settings between launches
  Views/                  SwiftUI screens
Tests/SingoCoreTests/     Tests for Core
```

The Xcode project uses a synced folder, so new files under `Singo/` show up in
Xcode on their own.

**Suggested split:** one of you takes `Music/` (MusicKit, playlist picker,
playback and timing), the other takes `Views/` (reveal screen, hint
animations, remote controls, called list). `Core/` is shared.

## Tests

The game rules in `Singo/Core` build without MusicKit, so they test on the Mac
directly:

```bash
swift test
```

Or open `Package.swift` in Xcode and press ⌘U.

## Notes

- Music videos in a playlist are skipped so the screen stays dark.
- Duplicate songs in a playlist are played once.
- If a library song is missing its genre, year or artwork, the app looks it up
  in the Apple Music catalog.
- For songs too short for the start offset, the clip starts earlier so it
  still fits.
- If three songs in a row fail to play (no subscription, no network), the round
  pauses with a message instead of running through the playlist.
- The Apple TV won't go to its screensaver during a round.
- Title hint styles (set before the round): off (default), blanks only,
  blanks + first letter, blanks + first letter of each word, or "fills in as
  it plays": starts as blanks and fills in letters (first letters first)
  until about 70% are showing at the end of the clip. "Fills in, no blanks"
  does the same without the lines under each letter.
- Game screen: the album-art disc sits in the middle with the countdown
  inside it; the title hint is above it, genre and year to the left, artist
  to the right.
- **Turn on Do Not Disturb before a round** (hold the TV button on the remote
  to open Control Center). Otherwise tvOS pops up a "Now Playing" card with
  the song title and artist each time a song starts. The setup screen shows
  this reminder too.
- If a song won't play, the reason shows on screen. Playback details also
  print in Xcode's console (filter for "playback") while running from Xcode.
- There's no app icon yet; the Apple TV home screen shows a blank tile.
- Builds signed with a paid developer account last a year; reinstall from Xcode
  after that.

## Not built yet (from the brief's "later" list)

Singo check by game type, printable bingo cards, saving a game if the Apple TV
sleeps, a sound cue at the reveal, and editing individual hint times.
