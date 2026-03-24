import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var premiumStore: PremiumStore
    @State private var entries: [LeaderboardEntry] = []
    @State private var userEntry: LeaderboardEntry? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showFriendGroups = false
    @State private var showUpgrade = false

    private let displayCount = 20

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else if entries.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if premiumStore.isPremium {
                        showFriendGroups = true
                    } else {
                        showUpgrade = true
                    }
                } label: {
                    Image(systemName: "person.2")
                }
            }
        }
        .navigationDestination(isPresented: $showFriendGroups) {
            FriendGroupView()
        }
        .sheet(isPresented: $showUpgrade) {
            PremiumUpgradeView()
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<10, id: \.self) { _ in
                    skeletonRow
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemFill))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemFill))
                    .frame(width: 80, height: 12)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemFill))
                .frame(width: 48, height: 28)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .redacted(reason: .placeholder)
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Rankings Yet", systemImage: "trophy")
        } description: {
            Text("Complete today's set to appear on the leaderboard.")
        }
    }

    // MARK: - List State

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let topEntries = Array(entries.prefix(displayCount))
                ForEach(Array(topEntries.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRowView(
                        rank: index + 1,
                        entry: entry,
                        isCurrentUser: entry.id == userEntry?.id
                    )
                }

                if let user = userEntry, !topEntries.contains(where: { $0.id == user.id }) {
                    pinnedUserSection(user: user)
                }

                if let user = userEntry {
                    let rank = entries.firstIndex(where: { $0.id == user.id }).map { $0 + 1 }
                    if let rank {
                        Text("Rank \(rank) of \(entries.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private func pinnedUserSection(user: LeaderboardEntry) -> some View {
        VStack(spacing: 8) {
            HStack {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }

            let rank = entries.firstIndex(where: { $0.id == user.id }).map { $0 + 1 } ?? 0
            LeaderboardRowView(
                rank: rank,
                entry: user,
                isCurrentUser: true
            )
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedEntries = LeaderboardService.fetchLeaderboard()
            async let fetchedUser = LeaderboardService.fetchUserEntry()

            let (leaderboard, user) = try await (fetchedEntries, fetchedUser)
            entries = leaderboard
            userEntry = user
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - LeaderboardRowView

private struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isCurrentUser: Bool

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .secondary
        }
    }

    private var calibrationColor: Color {
        if entry.calibrationScore >= 75 { return .green }
        if entry.calibrationScore >= 50 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            Text("\(rank)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(rank <= 3 ? rankColor : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((rank <= 3 ? rankColor : Color(.systemFill)).opacity(rank <= 3 ? 0.15 : 1.0))
                )

            // Name + meta
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if entry.isPremium {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text("\(entry.totalAnswered) answered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score
            Text(String(format: "%.0f", entry.calibrationScore))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(calibrationColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
                .overlay(
                    Group {
                        if isCurrentUser {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                        }
                    }
                )
        )
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
    .environmentObject(PremiumStore())
}
