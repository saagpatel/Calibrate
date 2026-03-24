import SwiftUI

struct OnboardingView: View {
    @AppStorage(Constants.UserDefaultsKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false

    @State private var selectedPage = 0
    @State private var navigateToTutorial = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedPage) {
                WelcomePage()
                    .tag(0)

                HowItWorksPage()
                    .tag(1)

                TryItOutPage(
                    onStartTutorial: { navigateToTutorial = true },
                    onSkip: { hasCompletedOnboarding = true }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationDestination(isPresented: $navigateToTutorial) {
                TutorialQuestionView()
            }
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "target")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)

                VStack(spacing: 12) {
                    Text("Welcome to Calibrate")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("How well do you know\nwhat you don't know?")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 16) {
                featurePill(
                    icon: "calendar",
                    text: "5 estimation questions every day"
                )
                featurePill(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Track your calibration over time"
                )
                featurePill(
                    icon: "person.2",
                    text: "Compare with a global leaderboard"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 80)
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Page 2: How It Works

private struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("How It Works")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 20) {
                stepCard(
                    number: "1",
                    title: "Answer a question",
                    description: "Each day you'll see 5 numeric estimation questions.",
                    accentColor: .blue
                )
                stepCard(
                    number: "2",
                    title: "Set confidence intervals",
                    description: "For each question, set a 50% interval (you're 50% sure the truth falls within) and a 90% interval (you're 90% sure).",
                    accentColor: .orange
                )
                stepCard(
                    number: "3",
                    title: "Track your calibration",
                    description: "Over time, see if your stated confidence matches reality. A 90% interval should contain the answer 9 times out of 10.",
                    accentColor: .green
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.bottom, 80)
    }

    private func stepCard(number: String, title: String, description: String, accentColor: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Page 3: Try It Out

private struct TryItOutPage: View {
    let onStartTutorial: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "hand.point.up.braille")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Try It Out")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Practice with a sample question before your first real set.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                Button(action: onStartTutorial) {
                    HStack {
                        Text("Try a practice question")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }

                Button(action: onSkip) {
                    Text("Skip tutorial")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.bottom, 80)
    }
}

#Preview {
    OnboardingView()
}
