import Core
import SwiftUI

/// Main dashboard view — shows all Ghostty sessions grouped by project.
/// No terminal rendering, just project/session management and agent status.
struct DashboardView: View {
    @Bindable var registry: DashboardRegistry
    var onFocusSession: (GhosttySession) -> Void
    var onRenameProject: (DashboardProject, String) -> Void

    @State private var selectedProjectId: UUID?
    @State private var hoveredSessionId: UUID?

    var body: some View {
        HSplitView {
            // Left: Project list
            projectList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            // Right: Session grid for selected project
            sessionGrid
                .frame(minWidth: 400)
        }
        .frame(minWidth: 700, minHeight: 400)
    }

    // MARK: - Project List

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "rocket.fill")
                    .foregroundColor(.orange)
                Text("Cosmodrome")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let count = ghosttyStatus {
                    Text(count)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if registry.projects.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No sessions detected")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text("Open Ghostty and source the\nshell integration script")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(registry.projects, id: \.id) { project in
                            DashboardProjectRow(
                                project: project,
                                isSelected: project.id == effectiveProjectId,
                                onSelect: { selectedProjectId = project.id },
                                onRename: { newName in onRenameProject(project, newName) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
            }
        }
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)))
    }

    // MARK: - Session Grid

    private var sessionGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let project = selectedProject {
                // Header
                HStack {
                    Circle()
                        .fill(Color(hex: project.color) ?? .blue)
                        .frame(width: 10, height: 10)
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text(project.rootPath)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("\(project.sessions.count) session\(project.sessions.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // Sessions
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(project.sessions, id: \.id) { session in
                            DashboardSessionCard(
                                session: session,
                                isHovered: hoveredSessionId == session.id,
                                onFocus: { onFocusSession(session) }
                            )
                            .onHover { isHovered in
                                hoveredSessionId = isHovered ? session.id : nil
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a project")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)))
    }

    // MARK: - Helpers

    private var effectiveProjectId: UUID? {
        selectedProjectId ?? registry.projects.first?.id
    }

    private var selectedProject: DashboardProject? {
        guard let id = effectiveProjectId else { return nil }
        return registry.projects.first { $0.id == id }
    }

    private var ghosttyStatus: String? {
        let total = registry.projects.flatMap(\.sessions).count
        guard total > 0 else { return nil }
        let agents = registry.projects.flatMap(\.sessions).filter(\.isAgent).count
        if agents > 0 {
            return "\(total) sessions, \(agents) agents"
        }
        return "\(total) sessions"
    }
}

// MARK: - Project Row

private struct DashboardProjectRow: View {
    let project: DashboardProject
    let isSelected: Bool
    var onSelect: () -> Void
    var onRename: (String) -> Void

    @State private var isEditing = false
    @State private var editName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: project.color) ?? .blue)
                .frame(width: 8, height: 8)

            if isEditing {
                TextField("Name", text: $editName, onCommit: {
                    if !editName.trimmingCharacters(in: .whitespaces).isEmpty {
                        onRename(editName.trimmingCharacters(in: .whitespaces))
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .focused($isNameFocused)
                .onAppear { isNameFocused = true }
                .onExitCommand { isEditing = false }
            } else {
                Text(project.name)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .gray)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(project.sessions.count)")
                .font(.system(size: 11))
                .foregroundColor(.gray)

            if project.aggregateState != .inactive {
                Circle()
                    .fill(stateColor(project.aggregateState))
                    .frame(width: 6, height: 6)
            }

            if project.attentionCount > 0 {
                Text("\(project.attentionCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.red))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editName = project.name
            isEditing = true
        }
        .onTapGesture(count: 1) {
            if !isEditing { onSelect() }
        }
    }

    private func stateColor(_ state: AgentState) -> Color {
        switch state {
        case .working: return .green
        case .needsInput: return .yellow
        case .error: return .red
        case .inactive: return .gray
        }
    }
}

// MARK: - Session Card

private struct DashboardSessionCard: View {
    let session: GhosttySession
    let isHovered: Bool
    var onFocus: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Agent state indicator
            VStack {
                if session.isAgent {
                    Image(systemName: "cpu")
                        .font(.system(size: 16))
                        .foregroundColor(stateColor(session.agentState))
                } else {
                    Image(systemName: "terminal")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 32)

            // Session info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    if session.isAgent, let type = session.agentType {
                        Text(type)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(stateColor(session.agentState).opacity(0.3))
                            )
                    }

                    if session.isAgent, let model = session.agentModel {
                        Text(model)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }

                Text(session.cwd)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text("PID \(session.pid)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.6))

                    if session.isAgent {
                        Text(stateLabel(session.agentState))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(stateColor(session.agentState))
                    }

                    if !session.isAlive {
                        Text("disconnected")
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Focus button
            Button(action: onFocus) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Focus")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(isHovered ? 0.8 : 0.5))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            session.agentState == .needsInput ? Color.yellow.opacity(0.4) :
                            session.agentState == .error ? Color.red.opacity(0.4) :
                            Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }

    private func stateColor(_ state: AgentState) -> Color {
        switch state {
        case .working: return .green
        case .needsInput: return .yellow
        case .error: return .red
        case .inactive: return .gray
        }
    }

    private func stateLabel(_ state: AgentState) -> String {
        switch state {
        case .working: return "working"
        case .needsInput: return "needs input"
        case .error: return "error"
        case .inactive: return "idle"
        }
    }
}
