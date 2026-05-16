import AppKit

@MainActor
final class FocusMusicPlayer {
    private var sound: NSSound?
    private var currentTrack: FocusMusicTrack?

    func play(track: FocusMusicTrack?) {
        guard let track else {
            stop()
            return
        }

        if currentTrack == track, let sound {
            if !sound.isPlaying {
                sound.resume()
                if !sound.isPlaying {
                    sound.play()
                }
            }
            return
        }

        stop()

        guard let url = Bundle.module.url(
            forResource: track.resourceName,
            withExtension: track.resourceExtension
        ), let nextSound = NSSound(contentsOf: url, byReference: false) else {
            return
        }

        nextSound.loops = true
        nextSound.volume = 0.45
        nextSound.play()
        sound = nextSound
        currentTrack = track
    }

    func pause() {
        sound?.pause()
    }

    func stop() {
        sound?.stop()
        sound = nil
        currentTrack = nil
    }
}
