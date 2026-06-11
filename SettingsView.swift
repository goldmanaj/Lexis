import SwiftUI

struct SettingsView: View {
    @AppStorage("lexis.wordNotifEnabled") private var wordNotifEnabled = true
    @AppStorage("lexis.quizNotifEnabled") private var quizNotifEnabled = true

    // Dates stored as TimeInterval (Double) in UserDefaults
    @State private var wordTime: Date = defaultWordTime()
    @State private var quizTime: Date = defaultQuizTime()

    var body: some View {
        ZStack {
            Color.lexisBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AppTitle()
                        .padding(.bottom, 28)

                    // Word notification
                    settingsSectionLabel("notifications")

                    NotifRow(
                        title: "Daily word",
                        subtitle: "Notify me when a new word arrives",
                        enabled: $wordNotifEnabled
                    )
                    .onChange(of: wordNotifEnabled) { _ in
                        Analytics.shared.logEvent("WordNotifToggled")
                        scheduleWordNotif()
                    }

                    if wordNotifEnabled {
                        timeRow(label: "Deliver at", time: $wordTime)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .onChange(of: wordTime) { _ in
                                saveWordTime()
                                scheduleWordNotif()
                            }
                    }

                    Divider().background(Color.lexisDimmed).padding(.vertical, 4)

                    NotifRow(
                        title: "Daily quiz",
                        subtitle: "Remind me to test myself",
                        enabled: $quizNotifEnabled
                    )
                    .onChange(of: quizNotifEnabled) { _ in
                        Analytics.shared.logEvent("QuizNotifToggled")
                        scheduleQuizNotif()
                    }

                    if quizNotifEnabled {
                        timeRow(label: "Remind at", time: $quizTime)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .onChange(of: quizTime) { _ in
                                saveQuizTime()
                                scheduleQuizNotif()
                            }
                    }

                    // Preview
                    Divider().background(Color.lexisDimmed).padding(.vertical, 16)
                    settingsSectionLabel("lock screen preview")
                        .padding(.bottom, 12)
                    VStack(spacing: 12) {
                        if wordNotifEnabled {
                            NotifPreview(
                                title: "Today's word: Vellichor",
                                bodyText: "Tap to see the definition",
                                time: wordTime
                            )
                        }
                        if quizNotifEnabled {
                            NotifPreview(
                                title: "Quiz time",
                                bodyText: "Test yourself on today's word",
                                time: quizTime
                            )
                        }
                        if !wordNotifEnabled && !quizNotifEnabled {
                            Text("Notifications disabled")
                                .font(.system(size: 13))
                                .foregroundColor(.lexisMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .animation(.easeInOut(duration: 0.2), value: wordNotifEnabled)
                .animation(.easeInOut(duration: 0.2), value: quizNotifEnabled)
            }
        }
        .onAppear {
            Analytics.shared.logEvent("SettingsViewed")
            loadSavedTimes()
        }
    }

    // MARK: - Sub-views

    func settingsSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .kerning(1.6)
            .foregroundColor(.lexisSubtle)
            .padding(.bottom, 10)
    }

    func timeRow(label: String, time: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "9a9088"))
            Spacer()
            DatePicker(
                "",
                selection: time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .colorScheme(.dark)
            .tint(.lexisGold)
            .scaleEffect(0.9, anchor: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.leading, 14)
    }

    // MARK: - Persistence

    func loadSavedTimes() {
        let wordInterval = UserDefaults.standard.double(forKey: "lexis.wordTime")
        if wordInterval > 0 { wordTime = Date(timeIntervalSince1970: wordInterval) }

        let quizInterval = UserDefaults.standard.double(forKey: "lexis.quizTime")
        if quizInterval > 0 { quizTime = Date(timeIntervalSince1970: quizInterval) }
    }

    func saveWordTime() {
        UserDefaults.standard.set(wordTime.timeIntervalSince1970, forKey: "lexis.wordTime")
    }

    func saveQuizTime() {
        UserDefaults.standard.set(quizTime.timeIntervalSince1970, forKey: "lexis.quizTime")
    }

    func scheduleWordNotif() {
        NotificationManager.shared.scheduleWordNotification(enabled: wordNotifEnabled, time: wordTime)
    }

    func scheduleQuizNotif() {
        NotificationManager.shared.scheduleQuizNotification(enabled: quizNotifEnabled, time: quizTime)
    }
}

// MARK: - Default times

func defaultWordTime() -> Date {
    Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
}

func defaultQuizTime() -> Date {
    Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
}

// MARK: - Notification row

struct NotifRow: View {
    let title: String
    let subtitle: String
    @Binding var enabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.lexisCream)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.lexisSubtle)
            }
            Spacer()
            Toggle("", isOn: $enabled)
                .tint(.lexisGold)
                .labelsHidden()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Notification preview card

struct NotifPreview: View {
    let title: String
    let bodyText: String
    let time: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LEXIS")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.lexisSubtle)
                Spacer()
                Text(time.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 10))
                    .foregroundColor(.lexisSubtle)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.lexisCream)
            Text(bodyText)
                .font(.system(size: 12))
                .foregroundColor(.lexisMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.lexisSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lexisBorder, lineWidth: 0.5))
    }
}
