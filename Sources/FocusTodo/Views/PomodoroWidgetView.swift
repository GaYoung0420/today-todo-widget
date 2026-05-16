import SwiftUI

struct PomodoroWidgetView: View {
    let session: PomodoroSession
    let store: TodoStore
    let close: () -> Void

    private var activeTodo: TodoItem? {
        session.activeTodo
    }

    private var modeColor: Color {
        session.mode == .focus ? NotionDesign.Colors.primary : NotionDesign.Colors.success
    }

    private var modeBackground: Color {
        session.mode == .focus ? Color(hex: 0xEDE9FC) : NotionDesign.Colors.mint
    }

    private var progress: Double {
        guard let activeTodo else { return 0 }
        let totalSeconds = session.mode == .focus ? activeTodo.pomodoroMinutes * 60 : activeTodo.breakMinutes * 60
        guard totalSeconds > 0 else { return 0 }
        return 1 - (Double(session.remainingSeconds) / Double(totalSeconds))
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            VStack(spacing: 0) {
                taskTitle
                timerControlsRow
            }
        }
        .frame(width: PomodoroWidgetLayout.contentWidth, height: PomodoroWidgetLayout.contentHeight)
        .floatingWidgetSurface(PomodoroWidgetLayout.shape)
        .padding(PomodoroWidgetLayout.shadowPadding)
        .frame(width: PomodoroWidgetLayout.windowWidth, height: PomodoroWidgetLayout.windowHeight)
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Button {
                let nextMode: PomodoroMode = session.mode == .focus ? .rest : .focus
                session.selectMode(nextMode, blockedSites: store.blockedSites)
            } label: {
                Text(session.mode.rawValue)
                    .font(NotionDesign.Fonts.microBold)
                    .foregroundStyle(modeColor)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(modeBackground, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("집중/휴식 전환")

            Text("\(activeTodo?.completedPomodoros ?? 0)/\(activeTodo?.targetPomodoros ?? 4)")
                .font(NotionDesign.Fonts.microBold)
                .foregroundStyle(NotionDesign.Colors.muted)
                .monospacedDigit()

            Spacer(minLength: 8)

            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(NotionDesign.Colors.muted)
            .help("일시정지하고 숨기기")
        }
        .padding(.horizontal, NotionDesign.Panel.headerHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: PomodoroWidgetLayout.headerHeight)
        .background(NotionDesign.Colors.canvas.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairline)
                .frame(height: 1)
        }
    }

    private var taskTitle: some View {
        Text(activeTodo?.title ?? "할 일을 선택하세요")
            .font(NotionDesign.Fonts.caption)
            .foregroundStyle(NotionDesign.Colors.charcoal)
            .fontWeight(.medium)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 10)
    }

    private var timerControlsRow: some View {
        HStack(spacing: 8) {
            timerRing

            Spacer(minLength: 0)

            controls
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(NotionDesign.Colors.hairline, lineWidth: 5)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(modeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: progress)

            VStack(spacing: 3) {
                Text(Formatters.timeRemaining(session.remainingSeconds))
                    .font(NotionDesign.Fonts.pretendard(size: 18, weight: .bold))
                    .foregroundStyle(NotionDesign.Colors.charcoal)
                    .monospacedDigit()

                Text(session.mode == .focus ? "남은 시간" : "잠깐 쉬세요")
                    .font(NotionDesign.Fonts.pretendard(size: 9, weight: .medium))
                    .foregroundStyle(NotionDesign.Colors.muted)
            }
        }
        .frame(width: 76, height: 76)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                session.selectMode(session.mode, blockedSites: store.blockedSites)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(RoundWidgetButtonStyle())
            .help("현재 타이머 초기화")

            Button {
                if session.isRunning {
                    session.pause()
                } else {
                    session.resume(blockedSites: store.blockedSites)
                }
            } label: {
                Image(systemName: session.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(RoundWidgetButtonStyle(isPrimary: true))
            .help(session.isRunning ? "일시정지" : "재개")

            Button {
                session.skip(blockedSites: store.blockedSites)
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(RoundWidgetButtonStyle())
            .help("다음 단계")
        }
    }
}

enum PomodoroWidgetLayout {
    static let contentWidth: CGFloat = 220
    static let contentHeight: CGFloat = 170
    static let headerHeight: CGFloat = 36
    static let shadowPadding = NotionDesign.Panel.shadowPadding
    static let windowWidth = contentWidth + shadowPadding * 2
    static let windowHeight = contentHeight + shadowPadding * 2
    static let shape = RoundedRectangle(cornerRadius: NotionDesign.Radius.widget, style: .continuous)
}

private struct RoundWidgetButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.microBold)
            .foregroundStyle(isPrimary ? NotionDesign.Colors.canvas : NotionDesign.Colors.steel)
            .frame(width: isPrimary ? 32 : 26, height: isPrimary ? 32 : 26)
            .background(
                isPrimary ? NotionDesign.Colors.charcoal : NotionDesign.Colors.surface,
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(isPrimary ? Color.clear : NotionDesign.Colors.hairline, lineWidth: 1)
            }
            .shadow(color: isPrimary ? .black.opacity(0.10) : .clear, radius: 8, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
