//
//  FrameRateTestTabBarController.swift
//  pip_swift
//

import UIKit
import SwiftUI

enum FrameRatePreference {
    static let force120HzKey = "frameRateDemo.force120Hz"
    static let experimentProfileKey = "frameRateDemo.experimentProfile"
    private static let customMinimumKey = "frameRateDemo.customMinimum"
    private static let customMaximumKey = "frameRateDemo.customMaximum"
    private static let customPreferredKey = "frameRateDemo.customPreferred"
    static let didChangeNotification = Notification.Name("FrameRatePreferenceDidChange")

    static var isHighRefreshEnabled: Bool {
        if UserDefaults.standard.object(forKey: force120HzKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: force120HzKey)
    }

    static var targetFrameRate: Int {
        isHighRefreshEnabled ? 120 : 80
    }

    // 帧率检测完美方案：关闭强制120时 preferred 必须回到 0，让系统自适应，避免误判和干涉其它 App。
    static func preferredFrameRateValue(target: Float) -> Float {
        isHighRefreshEnabled ? target : 0
    }

    static var experimentProfile: FrameRateExperimentProfile {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: experimentProfileKey),
                let profile = FrameRateExperimentProfile(rawValue: rawValue)
            else {
                return .followSwitch
            }
            return profile
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: experimentProfileKey)
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    @available(iOS 15.0, *)
    static func frameRateRange(target: Float) -> CAFrameRateRange {
        // 帧率字段实验已暂停：固定回跟随强制120开关，避免历史实验档位继续影响测试。
        FrameRateExperimentProfile.followSwitch.frameRateRange(
            target: target,
            isHighRefreshEnabled: isHighRefreshEnabled,
            customValues: customValues
        )
    }

    static var previewTarget: Float {
        let maximumFramesPerSecond = Float(UIScreen.main.maximumFramesPerSecond)
        return isHighRefreshEnabled
            ? max(60, maximumFramesPerSecond)
            : min(Float(targetFrameRate), maximumFramesPerSecond)
    }

    static var customValues: FrameRateExperimentCustomValues {
        let defaults = UserDefaults.standard
        let minimum = defaults.object(forKey: customMinimumKey) as? Float ?? 30
        let maximum = defaults.object(forKey: customMaximumKey) as? Float ?? 120
        let preferred = defaults.object(forKey: customPreferredKey) as? Float ?? 0
        return FrameRateExperimentCustomValues(
            minimum: minimum,
            maximum: maximum,
            preferred: preferred
        )
    }

    static func cycleCustomValue(_ field: FrameRateExperimentCustomField) {
        let values = customValues
        switch field {
        case .minimum:
            let next = field.nextValue(after: values.minimum)
            saveCustomValues(FrameRateExperimentCustomValues(
                minimum: next,
                maximum: values.maximum,
                preferred: values.preferred
            ))
        case .maximum:
            let next = field.nextValue(after: values.maximum)
            saveCustomValues(FrameRateExperimentCustomValues(
                minimum: values.minimum,
                maximum: next,
                preferred: values.preferred
            ))
        case .preferred:
            let next = field.nextValue(after: values.preferred)
            saveCustomValues(FrameRateExperimentCustomValues(
                minimum: values.minimum,
                maximum: values.maximum,
                preferred: next
            ))
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func saveCustomValues(_ values: FrameRateExperimentCustomValues) {
        UserDefaults.standard.set(values.minimum, forKey: customMinimumKey)
        UserDefaults.standard.set(values.maximum, forKey: customMaximumKey)
        UserDefaults.standard.set(values.preferred, forKey: customPreferredKey)
    }
}

enum FrameRateExperimentProfile: String, CaseIterable {
    case followSwitch
    case min0Max120Preferred0
    case min30Max120Preferred0
    case min0Max120Preferred120
    case min30Max120Preferred120
    case min0Max80Preferred0
    case min30Max80Preferred0
    case custom

    var title: String {
        switch self {
        case .followSwitch:
            return L10n.text("跟随强制120开关", "Follow Force-120 Switch")
        case .min0Max120Preferred0:
            return "minimum 0 / maximum 120 / preferred 0"
        case .min30Max120Preferred0:
            return "minimum 30 / maximum 120 / preferred 0"
        case .min0Max120Preferred120:
            return "minimum 0 / maximum 120 / preferred 120"
        case .min30Max120Preferred120:
            return "minimum 30 / maximum 120 / preferred 120"
        case .min0Max80Preferred0:
            return "minimum 0 / maximum 80 / preferred 0"
        case .min30Max80Preferred0:
            return "minimum 30 / maximum 80 / preferred 0"
        case .custom:
            return L10n.text("自定义字段", "Custom Fields")
        }
    }

    var shortTitle: String {
        switch self {
        case .followSwitch:
            return L10n.text("默认", "Default")
        case .min0Max120Preferred0:
            return "0/120/0"
        case .min30Max120Preferred0:
            return "30/120/0"
        case .min0Max120Preferred120:
            return "0/120/120"
        case .min30Max120Preferred120:
            return "30/120/120"
        case .min0Max80Preferred0:
            return "0/80/0"
        case .min30Max80Preferred0:
            return "30/80/0"
        case .custom:
            let values = FrameRatePreference.customValues
            return "\(values.display(values.minimum))/\(values.display(values.maximum))/\(values.display(values.preferred))"
        }
    }

    var next: FrameRateExperimentProfile {
        let profiles = Self.allCases
        guard let index = profiles.firstIndex(of: self) else { return .followSwitch }
        return profiles[profiles.index(after: index) == profiles.endIndex ? profiles.startIndex : profiles.index(after: index)]
    }

    @available(iOS 15.0, *)
    func frameRateRange(
        target: Float,
        isHighRefreshEnabled: Bool,
        customValues: FrameRateExperimentCustomValues
    ) -> CAFrameRateRange {
        switch self {
        case .followSwitch:
            return CAFrameRateRange(
                minimum: 30,
                maximum: target,
                preferred: isHighRefreshEnabled ? target : 0
            )
        case .min0Max120Preferred0:
            return CAFrameRateRange(minimum: 1, maximum: 120, preferred: 0)
        case .min30Max120Preferred0:
            return CAFrameRateRange(minimum: 30, maximum: 120, preferred: 0)
        case .min0Max120Preferred120:
            return CAFrameRateRange(minimum: 1, maximum: 120, preferred: 120)
        case .min30Max120Preferred120:
            return CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        case .min0Max80Preferred0:
            return CAFrameRateRange(minimum: 1, maximum: 80, preferred: 0)
        case .min30Max80Preferred0:
            return CAFrameRateRange(minimum: 30, maximum: 80, preferred: 0)
        case .custom:
            let values = customValues.effective(defaultTarget: target)
            return CAFrameRateRange(
                minimum: values.minimum,
                maximum: values.maximum,
                preferred: values.preferred
            )
        }
    }
}

struct FrameRateExperimentCustomValues: Equatable {
    static let targetSentinel: Float = -1

    var minimum: Float
    var maximum: Float
    var preferred: Float

    func effective(defaultTarget: Float) -> FrameRateExperimentCustomValues {
        var values = self
        values.minimum = resolved(values.minimum, target: defaultTarget)
        values.maximum = resolved(values.maximum, target: defaultTarget)
        values.preferred = values.preferred == 0 ? 0 : resolved(values.preferred, target: defaultTarget)
        // CAFrameRateRange(minimum: 0, ...) can crash on device. Use 1 fps as
        // the lowest safe approximation of "system decides as low as possible".
        values.minimum = max(1, values.minimum)
        values.maximum = max(1, values.maximum)
        if values.minimum > values.maximum {
            values.minimum = values.maximum
        }
        if values.preferred != 0 {
            values.preferred = min(max(values.preferred, values.minimum), values.maximum)
        }
        return values
    }

    var detailText: String {
        let requested = "请求 \(display(minimum))/\(display(maximum))/\(display(preferred))"
        let effectiveTarget = FrameRatePreference.previewTarget
        let effectiveValues = effective(defaultTarget: effectiveTarget)
        let applied = "实际 T\(display(effectiveTarget))/\(display(effectiveValues.minimum))/\(display(effectiveValues.maximum))/\(display(effectiveValues.preferred))"
        return "\(requested)，\(applied)"
    }

    func display(_ value: Float) -> String {
        if value == Self.targetSentinel {
            return "target"
        }
        if value == 0 {
            return L10n.text("自适应", "Auto")
        }
        return value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func resolved(_ value: Float, target: Float) -> Float {
        value == Self.targetSentinel ? target : value
    }
}

enum FrameRateExperimentCustomField: CaseIterable {
    case minimum
    case maximum
    case preferred

    var title: String {
        switch self {
        case .minimum:
            return "MIN"
        case .maximum:
            return "MAX"
        case .preferred:
            return "PREF"
        }
    }

    private var candidates: [Float] {
        switch self {
        case .minimum:
            return [FrameRateExperimentCustomValues.targetSentinel, 1, 30, 60, 80, 90, 120]
        case .maximum:
            return [FrameRateExperimentCustomValues.targetSentinel, 1, 60, 80, 90, 120]
        case .preferred:
            return [FrameRateExperimentCustomValues.targetSentinel, 0, 1, 60, 80, 90, 120]
        }
    }

    func nextValue(after currentValue: Float) -> Float {
        guard let index = candidates.firstIndex(of: currentValue) else {
            return candidates.first ?? currentValue
        }
        let nextIndex = candidates.index(after: index)
        return candidates[nextIndex == candidates.endIndex ? candidates.startIndex : nextIndex]
    }
}

final class FrameRateTestTabBarController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        DiagnosticsRuntimeState.updateCurrentPage("帧率演示")

        viewControllers = [
            makePage(title: L10n.text("测试页面1-120", "Test 1-120"), contentPrefix: L10n.text("测试页面一", "Test Page 1"), targetFrameRate: 120, symbol: "1.circle", selectedSymbol: "1.circle.fill"),
            makePage(title: L10n.text("测试页面2-80", "Test 2-80"), contentPrefix: L10n.text("测试页面二", "Test Page 2"), targetFrameRate: 90, symbol: "2.circle", selectedSymbol: "2.circle.fill"),
            makePage(title: L10n.text("测试页面3-60", "Test 3-60"), contentPrefix: L10n.text("测试页面三", "Test Page 3"), targetFrameRate: 60, symbol: "3.circle", selectedSymbol: "3.circle.fill")
        ]
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard selectedViewController !== viewController else {
            return true
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DiagnosticsRuntimeState.recordUserAction("帧率演示内切换页面")
        return true
    }

    private func makePage(
        title: String,
        contentPrefix: String,
        targetFrameRate: Int,
        symbol: String,
        selectedSymbol: String
    ) -> UIViewController {
        let controller = UIHostingController(
            rootView: FrameRateTestPageView(title: title, contentPrefix: contentPrefix, targetFrameRate: targetFrameRate) { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        controller.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: symbol),
            selectedImage: UIImage(systemName: selectedSymbol)
        )
        return controller
    }
}

private struct FrameRateTestPageView: View {
    let title: String
    let contentPrefix: String
    let targetFrameRate: Int
    let onBack: () -> Void

    @State private var isCollapsed = false
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @State private var frameTick = 0
    @State private var isScrollActive = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                topBar

                FrameRateScrollableListView(
                    contentPrefix: contentPrefix,
                    isCollapsed: isCollapsed,
                    onScrollActivityChange: { isScrollActive = $0 }
                )
            }
        }
        .background(FrameRateDriverView(frameTick: $frameTick, targetFrameRate: isScrollActive ? targetFrameRate : 60))
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                glassIconButton(systemName: "chevron.left", action: onBack)

                Spacer()

                glassIconButton(systemName: isCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical") {
                    isCollapsed.toggle()
                }

                glassIconButton(systemName: "magnifyingglass") {
                    isSearchVisible.toggle()
                }
            }

            if isSearchVisible {
                TextField(L10n.text("搜索", "Search"), text: $searchText)
                    .font(.system(size: 16, weight: .semibold))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground).opacity(0.78))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color(UIColor.systemGroupedBackground).opacity(0.92))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSearchVisible)
    }

    private func glassIconButton(
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DiagnosticsRuntimeState.recordUserAction("帧率演示按钮：\(systemName)")
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .frame(width: 46, height: 46)
        }
        .buttonStyle(FrameRateGlassIconButtonStyle())
        .accessibilityLabel(Text(systemName))
    }
}

struct RootFrameRateTestView: View {
    @AppStorage(FrameRatePreference.force120HzKey) private var isHighRefreshEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameTick = 0
    @State private var isVisible = false
    @State private var isAppActive = true
    @State private var isPlaying = false
    @State private var comparisonLowFPS = 60
    @State private var motionEpoch = Date()
    @State private var comparisonSpeed = 1
    @State private var autoScrollEnabled = false
    @State private var frameMetrics = FrameCallbackMetrics()
    @State private var adaptiveSnapshot: FrameCallbackMetrics?
    @State private var highSnapshot: FrameCallbackMetrics?
    @State private var modeSampleStartedAt = Date()

    var body: some View {
        ZStack {
            STRAStyle.canvas
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MOTION LAB").font(.caption.weight(.bold)).tracking(3).foregroundStyle(.secondary)
                            Text(L10n.text("感受每一帧", "Every frame matters"))
                                .font(.largeTitle.weight(.bold))
                        }
                        Spacer()
                        Image(systemName: "waveform.path").font(.title).foregroundStyle(.cyan)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(frameTick > 0 ? "\(frameTick)" : "—")
                                .font(.system(size: 76, weight: .light, design: .rounded)).monospacedDigit()
                                .accessibilityIdentifier("stra.motion.fps")
                            Text("FPS").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                Text(L10n.text("屏幕上限", "Display limit")).font(.caption).foregroundStyle(.secondary)
                                Text("\(UIScreen.main.maximumFramesPerSecond) Hz").font(.headline)
                            }
                        }
                        Text(L10n.text("本页 DisplayLink 回调频率；不是屏幕实测刷新率，也不代表其他 App 帧率", "This page’s DisplayLink callbacks, not a physical display measurement or other apps’ FPS"))
                            .font(.caption).foregroundStyle(.secondary)
                        if frameMetrics.callbackFPS > 0 {
                            Text(String(format: L10n.text("最近 1 秒：平均间隔 %.1f ms · 最大间隔 %.1f ms · 超过 20 ms：%d 次",
                                                           "Last second: avg %.1f ms · longest %.1f ms · gaps over 20 ms: %d"),
                                        frameMetrics.averageIntervalMS, frameMetrics.maximumIntervalMS,
                                        frameMetrics.over20MS))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("stra.motion.frameIntervals")
                        }
                        Picker(L10n.text("刷新模式", "Refresh mode"), selection: forceRefreshBinding) {
                            Text(L10n.text("系统自适应", "Adaptive")).tag(false)
                            Text(L10n.text("请求高刷", "High refresh")).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("stra.motion.mode")
                        Text(isHighRefreshEnabled
                             ? L10n.text("当前请求更高刷新率 · 是否生效以系统与真机体验为准", "Higher refresh requested · actual effect depends on iOS and device")
                             : L10n.text("已释放高刷请求 · 系统自动调节，不保证固定 80Hz", "High-refresh request released · adaptive, not a fixed 80 Hz"))
                            .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                    .background(STRAStyle.glassSurface(cornerRadius: 28))

                    motionDemoSection

                    scrollDemoSection
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 32)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }
        .background {
            if isVisible {
                FrameRateDriverView(frameTick: $frameTick,
                                    targetFrameRate: isHighRefreshEnabled ? UIScreen.main.maximumFramesPerSecond : 80,
                                    onMetrics: { frameMetrics = $0 })
            }
        }
        .onAppear {
            isVisible = true
            isAppActive = UIApplication.shared.applicationState == .active
            isPlaying = !reduceMotion
            motionEpoch = Date()
            modeSampleStartedAt = Date()
        }
        .onDisappear {
            isVisible = false
            isPlaying = false
            autoScrollEnabled = false
            frameTick = 0
            frameMetrics = FrameCallbackMetrics()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isAppActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isAppActive = false
            frameTick = 0
            autoScrollEnabled = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            isAppActive = false
            frameTick = 0
            autoScrollEnabled = false
        }
        .onChange(of: reduceMotion) { reduced in
            if reduced { isPlaying = false }
        }
    }

    private var motionDemoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.text("动态体验 · 同屏对照", "Motion · Side-by-Side Comparison"))
                                    .font(.title3.weight(.bold))
                                Text(L10n.text("两条轨道同速度，只有更新频率不同", "Same speed and distance; only update cadence differs"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Button {
                                if !isPlaying { motionEpoch = Date() }
                                isPlaying.toggle()
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Label(isPlaying ? L10n.text("暂停", "Pause") : L10n.text("播放", "Play"),
                                      systemImage: isPlaying ? "pause.fill" : "play.fill")
                                    .frame(minWidth: 67, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .disabled(reduceMotion)
                            .accessibilityLabel(isPlaying ? L10n.text("暂停演示", "Pause preview") : L10n.text("播放演示", "Play preview"))
                            .accessibilityIdentifier("stra.motion.play")
                        }

                        Picker(L10n.text("对照档位", "Comparison cadence"), selection: $comparisonLowFPS) {
                            Text("30 / 120").tag(30)
                            Text("60 / 120").tag(60)
                            Text("80 / 120").tag(80)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("stra.motion.compareMode")
                        .onChange(of: comparisonLowFPS) { _ in motionEpoch = Date() }
                        Picker(L10n.text("运动速度", "Motion speed"), selection: $comparisonSpeed) {
                            Text("1×").tag(1)
                            Text("2×").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("stra.motion.speed")
                        .onChange(of: comparisonSpeed) { _ in motionEpoch = Date() }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(isPlaying && isAppActive && !reduceMotion ? Color.green : Color.secondary)
                                .frame(width: 7, height: 7)
                            Text(isPlaying && isAppActive && !reduceMotion
                                 ? L10n.text("同速对照播放中", "Matched-speed comparison running")
                                 : L10n.text("已暂停 · 点击播放重新开始", "Paused · tap Play to restart"))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .accessibilityIdentifier("stra.motion.playState")

                        TimelineView(.animation(
                            minimumInterval: 1.0 / 120.0,
                            paused: !isPlaying || !isVisible || !isAppActive || reduceMotion
                        )) { context in
                            let elapsed = max(0, context.date.timeIntervalSince(motionEpoch))
                            VStack(spacing: 17) {
                                motionComparisonLane(
                                    label: L10n.text("模拟低频", "Simulated low"),
                                    sampleRate: comparisonLowFPS, elapsed: elapsed,
                                    speed: comparisonSpeed, accent: Color(UIColor.systemOrange)
                                )
                                motionComparisonLane(
                                    label: L10n.text("模拟高频", "Simulated high"),
                                    sampleRate: 120, elapsed: elapsed,
                                    speed: comparisonSpeed, accent: STRAStyle.accent
                                )
                            }
                        }
                        .frame(height: 188)
                        .accessibilityIdentifier("stra.motion.compareLanes")

                        Text(comparisonLowFPS == 80
                            ? L10n.text("注意：80 不能均匀分配到 120Hz 的刷新周期中，可能产生额外节奏不均；不要将这种抖动理解成真实 80Hz 屏幕表现。", "At 120Hz, 80 samples cannot be evenly spaced across refresh cycles. Uneven cadence here does not prove actual 80Hz appearance.")
                            : L10n.text("盯住移动的文字和边缘；两轨都以相同距离、速度运动，只有目标位置采样频率不同。", "Watch moving text and edges: same speed and distance, different target sampling cadence."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !isHighRefreshEnabled || frameTick == 0 || frameTick < 110 {
                            Label(
                                L10n.text("当前本页回调不足以完整展示 120 帧；点上方“请求高刷”后重试。",
                                          "This page is not receiving enough callbacks to fully show 120. Select High refresh above."),
                                systemImage: "info.circle"
                            )
                            .font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(L10n.text(
                            "上方 30/60/80/120 均为目标采样档位，不是实测 FPS；同一屏幕展示会受到本页实际回调、系统合成与 80/120 抽帧节奏影响。",
                            "30/60/80/120 are sampling targets, not measured FPS. Both lanes share one screen; page callbacks, composition and 80/120 cadence aliasing affect the result."
                        ))
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        if reduceMotion {
                            Text(L10n.text("已开启系统“减弱动态效果”，本页自动暂停。", "Reduce Motion is enabled; this preview is paused."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                    .background(Color.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 28))
    }

    @ViewBuilder
    private var scrollDemoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.text("真实滑动 A / B", "Real Scroll A / B"))
                            .font(.title3.weight(.bold))
                        Text(L10n.text(
                            "先点 A，向下滑一遍；回到这里点 B，以相同手势再滑一遍。对照的是本页请求方式，不是把左右半屏锁成两个物理刷新率。",
                            "Run A and scroll, then return and run B with the same gesture. This changes this page’s refresh request; it is not two physical screen refresh rates."
                        ))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            scrollModeButton(
                                label: L10n.text("A · 系统自适应", "A · Adaptive"),
                                selected: !isHighRefreshEnabled,
                                action: { forceRefreshBinding.wrappedValue = false }
                            )
                            scrollModeButton(
                                label: L10n.text("B · 请求高刷", "B · High Refresh"),
                                selected: isHighRefreshEnabled,
                                action: { forceRefreshBinding.wrappedValue = true }
                            )
                        }
                        Text(L10n.text("本页实际回调：", "Page callbacks: ") + (frameTick > 0 ? "\(frameTick) FPS" : "—"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(STRAStyle.accent)
                            .monospacedDigit()
                            .accessibilityIdentifier("stra.motion.scrollFPS")
                        Text(L10n.text(
                            "A 不是固定 80Hz，B 也不是锁定物理 120Hz。切换时会记录上一模式的稳定回调样本；数值接近则此轮无有效差异。",
                            "A is not fixed 80Hz and B is not a physical 120Hz lock. Switching records the last stable page callback sample; similar readings are inconclusive."
                        ))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.text("A：", "A: ") + metricDescription(for: isHighRefreshEnabled ? adaptiveSnapshot : liveMetrics))
                            .font(.caption.monospacedDigit())
                            .accessibilityIdentifier("stra.motion.modeAResult")
                        Text(L10n.text("B：", "B: ") + metricDescription(for: isHighRefreshEnabled ? liveMetrics : highSnapshot))
                            .font(.caption.monospacedDigit())
                            .accessibilityIdentifier("stra.motion.modeBResult")
                        if let a = isHighRefreshEnabled ? adaptiveSnapshot : liveMetrics,
                           let b = isHighRefreshEnabled ? liveMetrics : highSnapshot {
                            Text(abs(a.callbackFPS - b.callbackFPS) < 12
                                 ? L10n.text("本页 A/B 回调频率接近，不能据此证明高刷带来差异。", "A/B page callbacks are similar; this run does not demonstrate a high-refresh improvement.")
                                 : L10n.text("本页回调频率有差异，但这不是原生滚动内容或其他 App 的实测 FPS。", "Page callback rates differ, but these are not measured native-scroll or other-app FPS."))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(18)
                    .background(STRAStyle.glassSurface(cornerRadius: 23))
                    .id("stra.motion.scrollStart")

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(L10n.text("自动文字滚动 · 同轨迹", "Auto text scroll · same path"))
                                .font(.headline)
                            Spacer(minLength: 6)
                            Button(autoScrollEnabled ? L10n.text("停止", "Stop") : L10n.text("开始", "Start")) {
                                autoScrollEnabled.toggle()
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(reduceMotion || !isHighRefreshEnabled)
                            .accessibilityIdentifier("stra.motion.autoScroll")
                        }
                        Text(L10n.text("左侧模拟每秒 60 次位置更新，右侧模拟每秒 120 次；相同文字、距离和速度。建议先请求高刷。这里是自动移动的 UIKit 文字，不是原生手指滑动帧率测试。",
                                       "Left simulates 60 position updates/s, right 120, with identical text, distance and speed. Request high refresh first. This is scripted UIKit text motion, not native finger-scroll FPS."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(L10n.text("60 目标", "60 target"))
                            Spacer()
                            Text(L10n.text("120 目标", "120 target"))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        ControlledTextScrollComparisonView(isPlaying: autoScrollEnabled && isVisible && isAppActive && !reduceMotion && isHighRefreshEnabled)
                            .frame(height: 170)
                            .accessibilityIdentifier("stra.motion.autoScrollLanes")
                        if frameTick < 110 {
                            Text(L10n.text("本页回调未稳定达到 110 次/秒，右侧可能无法展示完整的 120 目标效果。", "Page callbacks are below 110/s; the 120-target lane may not be fully displayed."))
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    .padding(18)
                    .background(STRAStyle.glassSurface(cornerRadius: 23))

                    LazyVStack(spacing: 0) {
                        ForEach(0..<28, id: \.self) { index in
                            HStack(spacing: 14) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(size: 27, weight: .light, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 46, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(L10n.text("流畅度对照", "Motion clarity") + "  \(index + 1)")
                                        .font(.system(size: 17, weight: .semibold))
                                    Text("STRA / 0123456789  —  \(String(format: "%02d", index + 1))")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Capsule()
                                        .fill(index.isMultiple(of: 2) ? STRAStyle.accent : Color(UIColor.systemOrange))
                                        .frame(width: CGFloat(52 + (index % 4) * 18), height: 3)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: index.isMultiple(of: 2) ? "circle.hexagongrid.fill" : "circle.grid.3x3.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(index.isMultiple(of: 2) ? STRAStyle.accent : Color(UIColor.systemOrange))
                            }
                            .padding(.vertical, 18)
                            Divider()
                        }
                    }
                    .accessibilityLabel(L10n.text("A B 滑动对照列表", "A B scroll comparison list"))
    }

    private func scrollModeButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 45)
                .foregroundStyle(selected ? Color.white : STRAStyle.accent)
                .background(selected ? STRAStyle.accent : STRAStyle.accent.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func motionComparisonLane(label: String, sampleRate: Int, elapsed: TimeInterval,
                                      speed: Int, accent: Color) -> some View {
        let sampled = floor(elapsed * Double(sampleRate)) / Double(sampleRate)
        let cycle = (sampled * Double(speed)).truncatingRemainder(dividingBy: 2.4)
        let progress = cycle <= 1.2 ? cycle / 1.2 : (2.4 - cycle) / 1.2
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(sampleRate) FPS")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            GeometryReader { geometry in
                let travel = max(0, geometry.size.width - 42)
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<15, id: \.self) { _ in
                            Rectangle().fill(Color.primary.opacity(0.12))
                                .frame(width: 1.5, height: 38)
                            Spacer(minLength: 0)
                        }
                    }
                    RoundedRectangle(cornerRadius: 11)
                        .fill(accent)
                        .frame(width: 42, height: 42)
                        .overlay {
                            Text("STRA")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color.white)
                        }
                        .offset(x: travel * CGFloat(progress))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 43)
        }
        .accessibilityElement(children: .combine)
    }

    private var liveMetrics: FrameCallbackMetrics? {
        frameMetrics.callbackFPS > 0 && Date().timeIntervalSince(modeSampleStartedAt) >= 1.5
            ? frameMetrics : nil
    }

    private func metricDescription(for metric: FrameCallbackMetrics?) -> String {
        guard let metric = metric else { return L10n.text("等待至少 1.5 秒样本", "Wait for a sample of at least 1.5 s") }
        return String(format: L10n.text("%d 回调/秒 · 最大间隔 %.1f ms", "%d callbacks/s · longest %.1f ms"),
                      metric.callbackFPS, metric.maximumIntervalMS)
    }

    private var forceRefreshBinding: Binding<Bool> {
        Binding(get: { isHighRefreshEnabled }, set: { value in
            guard value != isHighRefreshEnabled else { return }
            if let valid = liveMetrics {
                if isHighRefreshEnabled { highSnapshot = valid }
                else { adaptiveSnapshot = valid }
            }
            isHighRefreshEnabled = value
            frameTick = 0
            frameMetrics = FrameCallbackMetrics()
            modeSampleStartedAt = Date()
            autoScrollEnabled = false
            UISelectionFeedbackGenerator().selectionChanged()
            NotificationCenter.default.post(name: FrameRatePreference.didChangeNotification, object: nil)
        })
    }
}

private struct RootFrameRateListView: View {
    let contentPrefix: String
    let targetFrameRate: Int
    let onScrollActivityChange: (Bool) -> Void
    @State private var lastScrollOffset: CGFloat?
    @State private var scrollIdleWorkItem: DispatchWorkItem?
    private let scrollCoordinateSpace = "RootFrameRateScroll"

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                FrameCadenceComparisonCard()

                ForEach(0..<36, id: \.self) { index in
                    twoLineItem(index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(scrollOffsetReader)
        }
        .coordinateSpace(name: scrollCoordinateSpace)
        .onPreferenceChange(FrameRateScrollOffsetPreferenceKey.self, perform: handleScrollOffsetChange)
        .onDisappear {
            scrollIdleWorkItem?.cancel()
            onScrollActivityChange(false)
        }
    }

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: FrameRateScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named(scrollCoordinateSpace)).minY
            )
        }
    }

    private func handleScrollOffsetChange(_ offset: CGFloat) {
        defer { lastScrollOffset = offset }
        guard let lastScrollOffset, abs(offset - lastScrollOffset) > 0.5 else { return }
        onScrollActivityChange(true)
        scrollIdleWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            onScrollActivityChange(false)
        }
        scrollIdleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func twoLineItem(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(contentPrefix)-\(index + 1)")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(Color(UIColor.label))

                Spacer()

                Text("\(targetFrameRate)Hz")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color(UIColor.systemBlue))
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.systemBlue).opacity(0.12))
                    )
            }

            Text(L10n.text("测试测试测试测试测试", "Refresh rate test sample text"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 74)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct FrameCadenceComparisonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("80Hz / 120Hz 同速动画对比", "80 Hz / 120 Hz Same-Speed Comparison"))
                .font(.system(size: 16, weight: .black))
                .foregroundColor(Color(UIColor.label))

            Text(L10n.text(
                "两个蓝色球速度一致；80Hz按较低频率更新位置，120Hz移动更连续。",
                "The two blue balls move at the same speed; 80 Hz updates position less often, while 120 Hz appears more continuous."
            ))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(UIColor.secondaryLabel))
            .fixedSize(horizontal: false, vertical: true)

            TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: false)) { context in
                VStack(spacing: 12) {
                    cadenceLane(label: "80Hz", sampleRate: 80, date: context.date)
                    cadenceLane(label: "120Hz", sampleRate: 120, date: context.date)
                }
            }
            .frame(height: 76)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(UIColor.separator).opacity(0.35), lineWidth: 1)
        )
    }

    private func cadenceLane(label: String, sampleRate: Double, date: Date) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Color(UIColor.systemBlue))
                .frame(width: 44, alignment: .trailing)

            GeometryReader { proxy in
                let sampledTime = floor(date.timeIntervalSinceReferenceDate * sampleRate) / sampleRate
                let cycle = sampledTime.truncatingRemainder(dividingBy: 4.0)
                let progress = cycle <= 2.0 ? cycle / 2.0 : (4.0 - cycle) / 2.0
                let travel = max(proxy.size.width - 22, 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.systemBlue).opacity(0.12))
                        .frame(height: 7)

                    Circle()
                        .fill(Color(UIColor.systemBlue))
                        .frame(width: 22, height: 22)
                        .shadow(color: Color(UIColor.systemBlue).opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(x: travel * CGFloat(progress))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 28)
        }
    }
}

struct FrameRateScrollableListView: View {
    let contentPrefix: String
    let isCollapsed: Bool
    let onScrollActivityChange: (Bool) -> Void
    @State private var lastScrollOffset: CGFloat?
    @State private var scrollIdleWorkItem: DispatchWorkItem?
    private let scrollCoordinateSpace = "FrameRateScrollableList"

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(visibleRows, id: \.self) { index in
                    testTextField(index: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(scrollOffsetReader)
        }
        .coordinateSpace(name: scrollCoordinateSpace)
        .onPreferenceChange(FrameRateScrollOffsetPreferenceKey.self, perform: handleScrollOffsetChange)
        .onDisappear {
            scrollIdleWorkItem?.cancel()
            onScrollActivityChange(false)
        }
    }

    private var visibleRows: Range<Int> {
        isCollapsed ? 0..<1 : 0..<36
    }

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: FrameRateScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named(scrollCoordinateSpace)).minY
            )
        }
    }

    private func handleScrollOffsetChange(_ offset: CGFloat) {
        defer { lastScrollOffset = offset }
        guard let lastScrollOffset, abs(offset - lastScrollOffset) > 0.5 else { return }
        onScrollActivityChange(true)
        scrollIdleWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            onScrollActivityChange(false)
        }
        scrollIdleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func testTextField(index: Int) -> some View {
        TextField("", text: .constant("\(contentPrefix)-\(index + 1) \(L10n.text("测试测试测试测试测试", "Refresh rate test sample text"))"))
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Color(UIColor.label))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(UIColor.separator).opacity(0.35), lineWidth: 1)
            )
            .textFieldStyle(.plain)
    }
}

private struct FrameRateScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FrameCallbackMetrics: Equatable {
    var callbackFPS = 0
    var averageIntervalMS = 0.0
    var maximumIntervalMS = 0.0
    var over20MS = 0
}

private struct FrameRateDriverView: UIViewRepresentable {
    @Binding var frameTick: Int
    let targetFrameRate: Int
    var onMetrics: ((FrameCallbackMetrics) -> Void)? = nil

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let displayLink = CADisplayLink(
            target: context.coordinator,
            selector: #selector(Coordinator.step)
        )
        configure(displayLink)
        displayLink.add(to: .main, forMode: .common)
        context.coordinator.displayLink = displayLink
        context.coordinator.onMetrics = onMetrics
        context.coordinator.installObservers()
        context.coordinator.updatePausedState()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onMetrics = onMetrics
        if let displayLink = context.coordinator.displayLink {
            configure(displayLink)
            context.coordinator.updatePausedState()
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.displayLink?.invalidate()
        coordinator.displayLink = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(frameTick: $frameTick)
    }

    private func configure(_ displayLink: CADisplayLink) {
        let maximumFramesPerSecond = UIScreen.main.maximumFramesPerSecond
        let requestedFrameRate = FrameRatePreference.isHighRefreshEnabled
            ? targetFrameRate
            : min(targetFrameRate, FrameRatePreference.targetFrameRate)
        let targetFramesPerSecond = min(requestedFrameRate, maximumFramesPerSecond)
        if #available(iOS 15.0, *) {
            let target = Float(targetFramesPerSecond)
            // 1.0.8 fix2: 演示页要稳定跑到页面目标帧率；关闭强制120时目标会先被限制到80。
            displayLink.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: target,
                preferred: FrameRatePreference.isHighRefreshEnabled ? target : 0
            )
        } else {
            displayLink.preferredFramesPerSecond = targetFramesPerSecond
        }
    }

    final class Coordinator {
        var displayLink: CADisplayLink?
        private var frameTick: Binding<Int>
        private var didInstallObservers = false
        private var measurementStart: CFTimeInterval = 0
        private var measurementFrames = 0
        private var lastTimestamp: CFTimeInterval = 0
        private var intervalSum: Double = 0
        private var intervalMaximum: Double = 0
        private var intervalCount = 0
        private var gapsOver20MS = 0
        var onMetrics: ((FrameCallbackMetrics) -> Void)?

        init(frameTick: Binding<Int>) {
            self.frameTick = frameTick
        }

        func installObservers() {
            guard !didInstallObservers else { return }
            didInstallObservers = true
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(updatePausedState), name: UIApplication.didBecomeActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(updatePausedState), name: UIApplication.willResignActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(updatePausedState), name: UIApplication.didEnterBackgroundNotification, object: nil)
        }

        @objc func updatePausedState() {
            displayLink?.isPaused = UIApplication.shared.applicationState != .active
            if displayLink?.isPaused == true {
                measurementStart = 0
                measurementFrames = 0
                lastTimestamp = 0
                intervalSum = 0
                intervalMaximum = 0
                intervalCount = 0
                gapsOver20MS = 0
            }
        }

        @objc func step() {
            guard UIApplication.shared.applicationState == .active else {
                displayLink?.isPaused = true
                return
            }
            guard let link = displayLink else { return }
            if measurementStart == 0 {
                measurementStart = link.timestamp
                lastTimestamp = link.timestamp
                return
            }
            let interval = link.timestamp - lastTimestamp
            lastTimestamp = link.timestamp
            if interval > 0 && interval < 1 {
                intervalSum += interval
                intervalMaximum = max(intervalMaximum, interval)
                intervalCount += 1
                if interval > 0.020 { gapsOver20MS += 1 }
            }
            measurementFrames += 1
            let elapsed = link.timestamp - measurementStart
            guard elapsed >= 1.0 else { return }
            let callbacks = Int((Double(measurementFrames) / elapsed).rounded())
            frameTick.wrappedValue = callbacks
            onMetrics?(FrameCallbackMetrics(
                callbackFPS: callbacks,
                averageIntervalMS: intervalCount > 0 ? intervalSum * 1000 / Double(intervalCount) : 0,
                maximumIntervalMS: intervalMaximum * 1000,
                over20MS: gapsOver20MS
            ))
            measurementStart = link.timestamp
            measurementFrames = 0
            intervalSum = 0
            intervalMaximum = 0
            intervalCount = 0
            gapsOver20MS = 0
        }
    }
}

private struct FrameRateGlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = Circle()

        return configuration.label
            .background(background(isPressed: configuration.isPressed, shape: shape))
            .overlay(
                shape.strokeBorder(
                    Color.white.opacity(configuration.isPressed ? 0.38 : 0.22),
                    lineWidth: 1
                )
            )
            .clipShape(shape)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.12),
                radius: configuration.isPressed ? 6 : 14,
                x: 0,
                y: configuration.isPressed ? 3 : 8
            )
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(
        isPressed: Bool,
        shape: Circle
    ) -> some View {
        if #available(iOS 26.0, *) {
            shape
                .fill(Color(UIColor.secondarySystemBackground).opacity(isPressed ? 0.42 : 0.24))
                .glassEffect(.regular.interactive(), in: shape)
        } else if #available(iOS 15.0, *) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color(UIColor.secondarySystemBackground).opacity(isPressed ? 0.38 : 0.22))
                )
        } else {
            shape
                .fill(Color(UIColor.secondarySystemBackground).opacity(isPressed ? 0.86 : 0.68))
        }
    }
}


// A deliberate, comparable text-motion demonstration. These labels indicate target position
// sampling, not physical display refresh or native UIScrollView finger-scroll FPS.
private struct ControlledTextScrollComparisonView: UIViewRepresentable {
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let left = makeTextScroll()
        let right = makeTextScroll()
        let stack = UIStackView(arrangedSubviews: [left, right])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.attach(low: left, high: right)
        context.coordinator.setPlaying(isPlaying)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setPlaying(isPlaying && UIApplication.shared.applicationState == .active)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    private func makeTextScroll() -> UIScrollView {
        let scroll = UIScrollView()
        scroll.isUserInteractionEnabled = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.55)
        scroll.layer.cornerRadius = 14
        scroll.clipsToBounds = true
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.text = (1...48).map { String(format: "%02d  STRA  0123456789", $0) }.joined(separator: "\n")
        scroll.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            label.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -16)
        ])
        return scroll
    }

    final class Coordinator: NSObject {
        private weak var low: UIScrollView?
        private weak var high: UIScrollView?
        private var displayLink: CADisplayLink?
        private var startTime: CFTimeInterval = 0
        private var playing = false

        func attach(low: UIScrollView, high: UIScrollView) {
            self.low = low
            self.high = high
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            let limit = min(120, UIScreen.main.maximumFramesPerSecond)
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(
                    minimum: 30, maximum: Float(limit), preferred: Float(limit)
                )
            } else {
                link.preferredFramesPerSecond = limit
            }
            link.add(to: .main, forMode: .common)
            link.isPaused = true
            displayLink = link
        }

        func setPlaying(_ active: Bool) {
            guard active != playing else { return }
            playing = active
            startTime = 0
            if !active {
                low?.setContentOffset(.zero, animated: false)
                high?.setContentOffset(.zero, animated: false)
            }
            displayLink?.isPaused = !active
        }

        @objc private func tick(_ link: CADisplayLink) {
            guard playing, let low = low, let high = high else { return }
            if startTime == 0 { startTime = link.timestamp }
            let elapsed = max(0, link.timestamp - startTime)
            move(low, sampledTime: floor(elapsed * 60) / 60)
            move(high, sampledTime: floor(elapsed * 120) / 120)
        }

        private func move(_ scroll: UIScrollView, sampledTime: TimeInterval) {
            let distance = max(0, scroll.contentSize.height - scroll.bounds.height)
            let cycle = sampledTime.truncatingRemainder(dividingBy: 6)
            let progress = cycle <= 3 ? cycle / 3 : (6 - cycle) / 3
            scroll.setContentOffset(CGPoint(x: 0, y: distance * CGFloat(progress)), animated: false)
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            low = nil
            high = nil
        }
    }
}
