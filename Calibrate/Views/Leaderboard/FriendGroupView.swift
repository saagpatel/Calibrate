import SwiftUI
import CloudKit

// MARK: - FriendGroup model

private struct FriendGroup {
    let groupID: String
    let groupName: String
    let memberRecordNames: [String]
    let createdBy: String
    let createdAt: Date

    static func from(record: CKRecord) -> FriendGroup? {
        guard
            let groupID = record["groupID"] as? String,
            let memberRecordNames = record["memberRecordNames"] as? [String],
            let createdBy = record["createdBy"] as? String,
            let createdAt = record["createdAt"] as? Date
        else {
            return nil
        }
        let groupName = record["groupName"] as? String ?? "Group \(groupID)"
        return FriendGroup(
            groupID: groupID,
            groupName: groupName,
            memberRecordNames: memberRecordNames,
            createdBy: createdBy,
            createdAt: createdAt
        )
    }
}

// MARK: - View error types

private enum FriendGroupError: LocalizedError {
    case notAuthenticated
    case groupNotFound
    case network(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to iCloud in Settings to use Friend Groups."
        case .groupNotFound:
            return "Group code not found. Check the code and try again."
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .unknown(let underlying):
            return underlying.localizedDescription
        }
    }

    static func from(_ error: Error) -> FriendGroupError {
        guard let ckError = error as? CKError else {
            return .unknown(error)
        }
        switch ckError.code {
        case .notAuthenticated, .permissionFailure:
            return .notAuthenticated
        case .unknownItem:
            return .groupNotFound
        case .networkUnavailable, .networkFailure:
            return .network(ckError)
        default:
            return .unknown(ckError)
        }
    }
}

// MARK: - FriendGroupView

struct FriendGroupView: View {
    @AppStorage("currentGroupID") private var currentGroupID: String = ""

    @State private var group: FriendGroup? = nil
    @State private var groupEntries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var pageError: FriendGroupError? = nil

    // Create group
    @State private var isCreating = false

    // Join group
    @State private var joinCode: String = ""
    @State private var isJoining = false
    @State private var joinError: String? = nil

    // Leave group
    @State private var isLeaving = false
    @State private var showLeaveConfirmation = false

    private static let db = CKContainer(identifier: Constants.CloudKit.containerID).publicCloudDatabase

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = pageError {
                errorView(error: error)
            } else if group == nil {
                noGroupView
            } else {
                hasGroupView
            }
        }
        .navigationTitle("Friend Group")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadOnAppear() }
        .refreshable { await refresh() }
        .confirmationDialog(
            "Leave Group",
            isPresented: $showLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task { await leaveGroup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be removed from the group. You can rejoin with the code later.")
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                skeletonCard(height: 120)
                skeletonCard(height: 80)
                ForEach(0..<5, id: \.self) { _ in
                    skeletonCard(height: 68)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private func skeletonCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.secondarySystemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .redacted(reason: .placeholder)
            .shimmering()
    }

    // MARK: - Error

    private func errorView(error: FriendGroupError) -> some View {
        ContentUnavailableView {
            Label(
                error == .notAuthenticated ? "iCloud Required" : "Couldn't Load",
                systemImage: error == .notAuthenticated ? "icloud.slash" : "wifi.slash"
            )
        } description: {
            Text(error.errorDescription ?? "An unknown error occurred.")
        } actions: {
            if error != .notAuthenticated {
                Button("Try Again") {
                    Task { await refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - No Group State

    private var noGroupView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header blurb
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Compete with Friends")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Create a group and share the 6-character code with friends. Everyone uses the code to join the same leaderboard.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .padding(.top, 24)

                // Create card
                createGroupCard

                // Join card
                joinGroupCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private var createGroupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Create a Group", systemImage: "plus.circle.fill")
                .font(.headline)

            Text("Generate a unique code and share it with up to 49 friends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await createGroup() }
            } label: {
                Group {
                    if isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Group")
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCreating)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var joinGroupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Join a Group", systemImage: "person.badge.plus")
                .font(.headline)

            Text("Enter the 6-character code from a friend.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField("XXXXXX", text: $joinCode)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .onChange(of: joinCode) { _, newValue in
                        let filtered = newValue
                            .uppercased()
                            .filter { $0.isLetter || $0.isNumber }
                        if filtered.count > 6 {
                            joinCode = String(filtered.prefix(6))
                        } else if filtered != newValue {
                            joinCode = filtered
                        }
                        if joinError != nil { joinError = nil }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemBackground))
                    )
                    .font(.system(.body, design: .monospaced, weight: .semibold))

                Button {
                    Task { await joinGroup() }
                } label: {
                    Group {
                        if isJoining {
                            ProgressView()
                                .frame(width: 52)
                        } else {
                            Text("Join")
                                .frame(width: 52)
                        }
                    }
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isJoining || joinCode.count != 6)
            }

            if let joinError {
                Label(joinError, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .animation(.easeInOut(duration: 0.2), value: joinError)
    }

    // MARK: - Has Group State

    private var hasGroupView: some View {
        HasGroupContentView(
            group: group,
            entries: groupEntries,
            isLeaving: isLeaving,
            onLeave: { showLeaveConfirmation = true }
        )
    }

    // MARK: - Actions

    private func loadOnAppear() async {
        guard !currentGroupID.isEmpty else { return }
        await refresh()
    }

    private func refresh() async {
        isLoading = true
        pageError = nil

        if currentGroupID.isEmpty {
            group = nil
            groupEntries = []
            isLoading = false
            return
        }

        do {
            let fetchedGroup = try await fetchGroup(id: currentGroupID)
            self.group = fetchedGroup
            if let fetchedGroup {
                self.groupEntries = try await fetchGroupLeaderboard(members: fetchedGroup.memberRecordNames)
            } else {
                // Stale groupID in storage — group was deleted
                currentGroupID = ""
                self.group = nil
                self.groupEntries = []
            }
        } catch {
            let friendGroupError = FriendGroupError.from(error)
            if case .groupNotFound = friendGroupError {
                // Group no longer exists
                currentGroupID = ""
                group = nil
                groupEntries = []
            } else {
                pageError = friendGroupError
            }
        }

        isLoading = false
    }

    private func createGroup() async {
        isCreating = true
        defer { isCreating = false }

        do {
            let myRecordName = try await userRecordName()
            let groupID = generateGroupCode()

            let db = Self.db
            let recordID = CKRecord.ID(recordName: groupID)
            let record = CKRecord(recordType: Constants.CloudKit.friendGroupRecordType, recordID: recordID)
            record["groupID"] = groupID
            record["groupName"] = "Group \(groupID)"
            record["memberRecordNames"] = [myRecordName] as [String]
            record["createdBy"] = myRecordName
            record["createdAt"] = Date()
            try await db.save(record)

            currentGroupID = groupID

            // Reload into has-group state
            await refresh()
        } catch {
            let mapped = FriendGroupError.from(error)
            print("[FriendGroupView] createGroup error: \(mapped.errorDescription ?? error.localizedDescription)")
            pageError = mapped
        }
    }

    private func joinGroup() async {
        let code = joinCode.uppercased()
        guard code.count == 6 else { return }

        isJoining = true
        joinError = nil
        defer { isJoining = false }

        do {
            let myRecordName = try await userRecordName()
            let db = Self.db
            let recordID = CKRecord.ID(recordName: code)
            let record = try await db.record(for: recordID)

            var members = record["memberRecordNames"] as? [String] ?? []
            guard !members.contains(myRecordName) else {
                // Already a member — just load the group
                currentGroupID = code
                joinCode = ""
                await refresh()
                return
            }

            members.append(myRecordName)
            record["memberRecordNames"] = members as [String]
            try await db.save(record)

            currentGroupID = code
            joinCode = ""
            await refresh()
        } catch {
            let mapped = FriendGroupError.from(error)
            switch mapped {
            case .groupNotFound:
                joinError = "Group code not found."
            case .notAuthenticated:
                pageError = .notAuthenticated
            default:
                joinError = mapped.errorDescription ?? "Something went wrong."
            }
            print("[FriendGroupView] joinGroup error: \(mapped.errorDescription ?? error.localizedDescription)")
        }
    }

    private func leaveGroup() async {
        guard let group else { return }
        isLeaving = true
        defer { isLeaving = false }

        do {
            let myRecordName = try await userRecordName()
            let db = Self.db
            let recordID = CKRecord.ID(recordName: group.groupID)
            let record = try await db.record(for: recordID)

            var members = record["memberRecordNames"] as? [String] ?? []
            members.removeAll { $0 == myRecordName }
            record["memberRecordNames"] = members as [String]
            try await db.save(record)

            currentGroupID = ""
            self.group = nil
            self.groupEntries = []
        } catch {
            let mapped = FriendGroupError.from(error)
            print("[FriendGroupView] leaveGroup error: \(mapped.errorDescription ?? error.localizedDescription)")
            // Non-fatal — clear local state anyway so user isn't stuck
            if case .groupNotFound = mapped {
                currentGroupID = ""
                self.group = nil
                self.groupEntries = []
            } else {
                pageError = mapped
            }
        }
    }

    // MARK: - CloudKit helpers

    private func userRecordName() async throws -> String {
        let container = CKContainer(identifier: Constants.CloudKit.containerID)
        let id = try await container.userRecordID()
        return id.recordName
    }

    private func fetchGroup(id: String) async throws -> FriendGroup? {
        let db = Self.db
        let recordID = CKRecord.ID(recordName: id)
        do {
            let record = try await db.record(for: recordID)
            return FriendGroup.from(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func fetchGroupLeaderboard(members: [String]) async throws -> [LeaderboardEntry] {
        async let allEntries = LeaderboardService.fetchLeaderboard()
        let entries = try await allEntries
        return entries.filter { members.contains($0.id) }
    }

    // MARK: - Utilities

    private func generateGroupCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no ambiguous O/0/I/1
        return String((0..<6).map { _ in chars.randomElement() ?? "A" })
    }
}

// MARK: - HasGroupContentView

private struct HasGroupContentView: View {
    let group: FriendGroup?
    let entries: [LeaderboardEntry]
    let isLeaving: Bool
    let onLeave: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let group {
                    groupHeaderCard(group: group)
                }

                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Rankings Yet", systemImage: "person.3")
                    } description: {
                        Text("Group members will appear here once they've completed today's set.")
                    }
                    .padding(.top, 16)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRowView(rank: index + 1, entry: entry)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func groupHeaderCard(group: FriendGroup) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.groupName)
                        .font(.headline)
                    Text("\(group.memberRecordNames.count) member\(group.memberRecordNames.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive, action: onLeave) {
                    Group {
                        if isLeaving {
                            ProgressView()
                        } else {
                            Text("Leave")
                        }
                    }
                    .font(.subheadline)
                    .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isLeaving)
            }

            Divider()

            VStack(spacing: 4) {
                Text("Invite Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    UIPasteboard.general.string = group.groupID
                } label: {
                    HStack(spacing: 8) {
                        Text(group.groupID)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                            .tracking(4)
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemBackground))
                    )
                }
                .buttonStyle(.plain)

                Text("Tap to copy — share with friends")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Shimmer effect

private extension View {
    func shimmering() -> some View {
        self.overlay(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipped()
        )
    }
}

// MARK: - LeaderboardRowView (local copy for group context)

private struct LeaderboardRowView: View {
    let rank: Int
    let entry: LeaderboardEntry

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
            Text("\(rank)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(rank <= 3 ? rankColor : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill((rank <= 3 ? rankColor : Color(.systemFill)).opacity(rank <= 3 ? 0.15 : 1.0))
                )

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

            Text(String(format: "%.0f", entry.calibrationScore))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(calibrationColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Equatable conformance for error comparison in views

extension FriendGroupError: Equatable {
    static func == (lhs: FriendGroupError, rhs: FriendGroupError) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated): return true
        case (.groupNotFound, .groupNotFound): return true
        case (.network, .network): return true
        case (.unknown, .unknown): return true
        default: return false
        }
    }
}

// MARK: - Preview

#Preview("No Group") {
    NavigationStack {
        FriendGroupView()
    }
}

#Preview("Has Group — With Members") {
    let group = FriendGroup(
        groupID: "RK7X4M",
        groupName: "Group RK7X4M",
        memberRecordNames: ["_alice", "_bob", "_carol", "_dave"],
        createdBy: "_alice",
        createdAt: Date()
    )
    let entries: [LeaderboardEntry] = [
        LeaderboardEntry(id: "_alice", displayName: "Alice", calibrationScore: 84.0, totalAnswered: 45, lastUpdated: Date(), isPremium: true),
        LeaderboardEntry(id: "_bob", displayName: "Bob", calibrationScore: 71.5, totalAnswered: 38, lastUpdated: Date(), isPremium: false),
        LeaderboardEntry(id: "_carol", displayName: "Carol", calibrationScore: 63.2, totalAnswered: 30, lastUpdated: Date(), isPremium: false),
        LeaderboardEntry(id: "_dave", displayName: "Dave", calibrationScore: 48.9, totalAnswered: 22, lastUpdated: Date(), isPremium: false),
    ]
    NavigationStack {
        HasGroupContentView(group: group, entries: entries, isLeaving: false, onLeave: {})
            .navigationTitle("Friend Group")
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("Has Group — Empty Leaderboard") {
    let group = FriendGroup(
        groupID: "ZT2PNQ",
        groupName: "Group ZT2PNQ",
        memberRecordNames: ["_alice"],
        createdBy: "_alice",
        createdAt: Date()
    )
    NavigationStack {
        HasGroupContentView(group: group, entries: [], isLeaving: false, onLeave: {})
            .navigationTitle("Friend Group")
            .navigationBarTitleDisplayMode(.large)
    }
}
