import Foundation
import Observation
import AppKit

enum PomodoroMode: String {
    case focus = "집중"
    case rest = "휴식"
}

@MainActor
@Observable
final class PomodoroSession {
    var activeTodo: TodoItem?
    var remainingSeconds = 0
    var isRunning = false
    var mode: PomodoroMode = .focus

    private var timer: Timer?
    private let musicPlayer = FocusMusicPlayer()
    let blocker: BrowserBlocker
    @ObservationIgnored var onFocusCompleted: ((TodoItem) -> TodoItem)?
    @ObservationIgnored var shouldPlayAlert: () -> Bool = { true }
    @ObservationIgnored var selectedFocusMusic: () -> FocusMusicTrack? = { nil }

    init(blocker: BrowserBlocker) {
        self.blocker = blocker
    }

    func start(todo: TodoItem, blockedSites: [String]) {
        if activeTodo?.id == todo.id, remainingSeconds > 0 {
            activeTodo = todo
            if isRunning {
                if mode == .focus {
                    blocker.start(blockedSites: blockedSites)
                    playFocusMusicIfNeeded()
                } else {
                    blocker.stop()
                    musicPlayer.stop()
                }
                scheduleTimer()
            } else {
                resume(blockedSites: blockedSites)
            }
            return
        }

        activeTodo = todo
        mode = .focus
        remainingSeconds = durationSeconds(for: .focus, todo: todo)
        isRunning = true
        blocker.start(blockedSites: blockedSites)
        playFocusMusicIfNeeded()
        scheduleTimer()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        musicPlayer.pause()
    }

    func resume(blockedSites: [String]) {
        guard activeTodo != nil, remainingSeconds > 0 else { return }
        isRunning = true
        if mode == .focus {
            blocker.start(blockedSites: blockedSites)
            playFocusMusicIfNeeded()
        } else {
            blocker.stop()
        }
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        activeTodo = nil
        remainingSeconds = 0
        mode = .focus
        timer?.invalidate()
        timer = nil
        blocker.stop()
        musicPlayer.stop()
    }

    func selectMode(_ newMode: PomodoroMode, blockedSites: [String]) {
        guard let todo = activeTodo else { return }
        mode = newMode
        remainingSeconds = durationSeconds(for: newMode, todo: todo)

        if newMode == .focus, isRunning {
            blocker.start(blockedSites: blockedSites)
            playFocusMusicIfNeeded()
        } else if newMode == .rest {
            blocker.stop()
            musicPlayer.stop()
        }

        if isRunning {
            scheduleTimer()
        }
    }

    func skip(blockedSites: [String]) {
        completeCurrentInterval(blockedSites: blockedSites, playSound: false)
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isRunning else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            completeCurrentInterval(blockedSites: blocker.currentBlockedSites, playSound: true)
        }
    }

    private func completeCurrentInterval(blockedSites: [String], playSound: Bool) {
        guard let todo = activeTodo else {
            stop()
            return
        }

        if playSound, shouldPlayAlert() {
            NSSound(named: "Glass")?.play()
        }

        switch mode {
        case .focus:
            musicPlayer.stop()
            let updatedTodo = onFocusCompleted?(todo) ?? todo
            activeTodo = updatedTodo
            mode = .rest
            remainingSeconds = durationSeconds(for: .rest, todo: updatedTodo)
            blocker.stop()
        case .rest:
            mode = .focus
            remainingSeconds = durationSeconds(for: .focus, todo: todo)
            blocker.start(blockedSites: blockedSites)
            playFocusMusicIfNeeded()
        }

        scheduleTimer()
    }

    private func durationSeconds(for mode: PomodoroMode, todo: TodoItem) -> Int {
        switch mode {
        case .focus:
            todo.pomodoroMinutes * 60
        case .rest:
            todo.breakMinutes * 60
        }
    }

    private func playFocusMusicIfNeeded() {
        guard mode == .focus, isRunning else { return }
        musicPlayer.play(track: selectedFocusMusic())
    }
}
