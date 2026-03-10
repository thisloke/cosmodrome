import Foundation
import Observation

/// Tracks Ghostty sessions registered via shell integration.
/// Groups them into projects based on working directory.
@Observable
public final class DashboardRegistry {
    public var projects: [DashboardProject] = []
    public var activeProjectId: UUID?

    public init() {}

    public var activeProject: DashboardProject? {
        guard let id = activeProjectId else { return projects.first }
        return projects.first { $0.id == id }
    }

    /// Register or update a session from shell integration data.
    public func registerSession(
        sessionId: UUID,
        pid: pid_t,
        windowId: String,
        cwd: String,
        label: String?
    ) {
        // Find existing session by pid (re-registration on cd)
        for project in projects {
            if let existing = project.sessions.first(where: { $0.pid == pid }) {
                existing.cwd = cwd
                existing.label = label ?? (cwd as NSString).lastPathComponent
                existing.lastSeen = Date()

                // If cwd changed to a different project root, move the session
                let newProjectRoot = detectProjectRoot(cwd)
                if newProjectRoot != project.rootPath {
                    project.sessions.removeAll { $0.pid == pid }
                    if project.sessions.isEmpty {
                        projects.removeAll { $0.id == project.id }
                    }
                    let target = findOrCreateProject(rootPath: newProjectRoot, name: label)
                    target.sessions.append(existing)
                }
                return
            }
        }

        // New session
        let session = GhosttySession(
            id: sessionId,
            pid: pid,
            windowId: windowId,
            cwd: cwd,
            label: label
        )

        let projectRoot = detectProjectRoot(cwd)
        let project = findOrCreateProject(rootPath: projectRoot, name: nil)
        project.sessions.append(session)

        if activeProjectId == nil {
            activeProjectId = project.id
        }
    }

    /// Update agent state for a session (from Claude Code hooks).
    public func updateAgentState(sessionId: UUID, state: AgentState, agentType: String?, model: String?) {
        for project in projects {
            if let session = project.sessions.first(where: { $0.id == sessionId }) {
                session.isAgent = true
                session.agentState = state
                session.agentType = agentType
                session.agentModel = model
                return
            }
        }
    }

    /// Heartbeat — mark session as alive.
    public func heartbeat(pid: pid_t) {
        for project in projects {
            if let session = project.sessions.first(where: { $0.pid == pid }) {
                session.lastSeen = Date()
                return
            }
        }
    }

    /// Remove dead sessions (no heartbeat for 30s+).
    public func pruneDeadSessions() {
        for project in projects {
            project.sessions.removeAll { !$0.isAlive }
        }
        projects.removeAll { $0.sessions.isEmpty }
    }

    /// Unregister a session explicitly (shell exited).
    public func unregisterSession(pid: pid_t) {
        for project in projects {
            project.sessions.removeAll { $0.pid == pid }
        }
        projects.removeAll { $0.sessions.isEmpty }
    }

    // MARK: - Private

    private func findOrCreateProject(rootPath: String, name: String?) -> DashboardProject {
        if let existing = projects.first(where: { $0.rootPath == rootPath }) {
            return existing
        }
        let projectName = name ?? (rootPath as NSString).lastPathComponent
        let project = DashboardProject(name: projectName, rootPath: rootPath)
        projects.append(project)
        return project
    }

    /// Walk up from cwd looking for project markers (.git, Package.swift, package.json, etc.)
    private func detectProjectRoot(_ cwd: String) -> String {
        let markers = [".git", "Package.swift", "package.json", "Cargo.toml", "go.mod",
                       "pyproject.toml", "Gemfile", "pom.xml", "build.gradle", ".project",
                       "cosmodrome.yml"]
        var dir = cwd
        let fm = FileManager.default

        while dir != "/" && dir != "" {
            for marker in markers {
                let path = (dir as NSString).appendingPathComponent(marker)
                if fm.fileExists(atPath: path) {
                    return dir
                }
            }
            dir = (dir as NSString).deletingLastPathComponent
        }

        // No project marker found — use cwd itself
        return cwd
    }
}

/// A project in dashboard mode — groups Ghostty sessions by detected project root.
@Observable
public final class DashboardProject: Identifiable {
    public let id: UUID
    public var name: String
    public let rootPath: String
    public var sessions: [GhosttySession] = []
    @ObservationIgnored public let activityLog = ActivityLog()

    /// Random but stable color for the project dot
    public let color: String

    public var aggregateState: AgentState {
        let agents = sessions.filter { $0.isAgent }
        if agents.contains(where: { $0.agentState == .error }) { return .error }
        if agents.contains(where: { $0.agentState == .needsInput }) { return .needsInput }
        if agents.contains(where: { $0.agentState == .working }) { return .working }
        return .inactive
    }

    public var attentionCount: Int {
        sessions.count(where: { $0.agentState == .needsInput || $0.agentState == .error })
    }

    public init(id: UUID = UUID(), name: String, rootPath: String) {
        self.id = id
        self.name = name
        self.rootPath = rootPath

        // Deterministic color from name hash
        let hash = abs(name.hashValue)
        let colors = ["#4A90D9", "#D94A4A", "#4AD97B", "#D9A64A", "#9B4AD9",
                       "#4AD9D9", "#D94A90", "#7BD94A", "#D9D94A", "#4A4AD9"]
        self.color = colors[hash % colors.count]
    }
}
