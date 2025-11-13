import SwiftUI

struct OnboardingPage: View {
    let title: String
    let text: String
    let image: String

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: image)
                .font(.system(size: 80))
                .foregroundColor(Theme.accentYellow)
            Text(title)
                .font(Theme.nunito(32))
            Text(text)
                .font(Theme.inter(18))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    
    var body: some View {
        TabView(selection: $page) {
            OnboardingPage(title: "Add a Batch",
                           text: "Start incubation with preset or custom profile",
                           image: "EggChicken").tag(0)
            OnboardingPage(title: "Monitor T° & RH",
                           text: "Track temperature and humidity in real time",
                           image: "Thermometer").tag(1)
            OnboardingPage(title: "Get Reminders",
                           text: "Never miss a turn, candling or hatch",
                           image: "Bell").tag(2)
            OnboardingPage(title: "Reports & Forecast",
                           text: "Success rate, deviations, PDF export",
                           image: "Chart").tag(3)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .overlay(alignment: .bottom) {
            Button(page == 3 ? "Finish" : "Next") {
                if page == 3 {
                    onFinish()
                } else {
                    withAnimation {
                        page += 1
                    }
                }
                // scheduleInitialNotifications()
            }
            .buttonStyle(BigYellowButton())
            .padding()
        }
    }
}

struct BigYellowButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.nunito(20))
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accentYellow)
            .foregroundColor(.black)
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

func scheduleTurnNotification(for batch: Batch, day: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Time to turn eggs"
    content.body = "\(batch.name) – Day \(day)"
    content.sound = .default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false) // demo
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}

#Preview {
    OnboardingView {
        
    }
}
