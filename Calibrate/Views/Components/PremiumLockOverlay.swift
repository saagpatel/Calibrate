import SwiftUI

struct PremiumLockOverlay<Content: View>: View {
    let isLocked: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .blur(radius: isLocked ? 6 : 0)
            .disabled(isLocked)
            .overlay {
                if isLocked {
                    lockedOverlay
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLocked)
    }

    private var lockedOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.primary)

                VStack(spacing: 6) {
                    Text("Premium Feature")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("Unlock with Calibrate Premium")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Learn More") {
                    // StoreKit paywall integration is handled in Phase 3
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(32)
        }
    }
}

#Preview("Locked") {
    PremiumLockOverlay(isLocked: true) {
        VStack(spacing: 12) {
            Text("Advanced Calibration Curve")
                .font(.headline)
            Text("This content is behind a premium paywall.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

#Preview("Unlocked") {
    PremiumLockOverlay(isLocked: false) {
        VStack(spacing: 12) {
            Text("Advanced Calibration Curve")
                .font(.headline)
            Text("Premium content visible.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}
