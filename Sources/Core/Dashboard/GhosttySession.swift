import Foundation
import Observation

/// Represents a Ghostty terminal session discovered via shell integration.
/// Each session corresponds to one Ghostty tab/window running a shell.
@Observable
public final class GhosttySession: Identifiable {
    public let id: UUID
    /// PID of the shell process inside the Ghostty tab
    public var pid: pid_t
    /// Ghostty window ID (from GHOSTTY_WINDOW_ID or AppleScript index)
    public var windowId: String
    /// Current working directory reported by the shell
    public var cwd: String
    /// Custom label set by user or auto-detected from cwd
    public var label: String
    /// Whether an AI agent (Claude Code, etc.) is running in this session
    public var isAgent: Bool = false
    /// Agent type if detected
    public var agentType: String?
    /// Agent state
    public var agentState: AgentState = .inactive
    /// Agent model
    public var agentModel: String?
    /// Last heartbeat from the shell integration
    public var lastSeen: Date
    /// Whether this session appears to be alive
    public var isAlive: Bool { Date().timeIntervalSince(lastSeen) < 30 }

    public init(
        id: UUID = UUID(),
        pid: pid_t,
        windowId: String,
        cwd: String,
        label: String? = nil
    ) {
        self.id = id
        self.pid = pid
        self.windowId = windowId
        self.cwd = cwd
        self.label = label ?? (cwd as NSString).lastPathComponent
        self.lastSeen = Date()
    }
}
