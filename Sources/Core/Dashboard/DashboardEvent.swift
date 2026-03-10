import Foundation

/// Events received from shell integration scripts running in Ghostty.
/// Sent as JSON to the Cosmodrome dashboard socket.
public enum DashboardEvent {
    case registerSession(sessionId: UUID, pid: pid_t, windowId: String, cwd: String, label: String?)
    case unregisterSession(pid: pid_t)
    case heartbeat(pid: pid_t, cwd: String?)
    case agentStarted(pid: pid_t, agentType: String)
    case agentStateChanged(pid: pid_t, state: String, model: String?)
    case agentStopped(pid: pid_t)

    /// Parse from JSON data received on the dashboard socket.
    public static func parse(from data: Data) -> DashboardEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        switch type {
        case "register":
            guard let pidVal = json["pid"] as? Int else { return nil }
            let windowId = json["window_id"] as? String ?? "1"
            let cwd = json["cwd"] as? String ?? ""
            let label = json["label"] as? String
            let sessionId: UUID
            if let idStr = json["session_id"] as? String, let id = UUID(uuidString: idStr) {
                sessionId = id
            } else {
                sessionId = UUID()
            }
            return .registerSession(
                sessionId: sessionId,
                pid: pid_t(pidVal),
                windowId: windowId,
                cwd: cwd,
                label: label
            )

        case "unregister":
            guard let pidVal = json["pid"] as? Int else { return nil }
            return .unregisterSession(pid: pid_t(pidVal))

        case "heartbeat":
            guard let pidVal = json["pid"] as? Int else { return nil }
            let cwd = json["cwd"] as? String
            return .heartbeat(pid: pid_t(pidVal), cwd: cwd)

        case "agent_started":
            guard let pidVal = json["pid"] as? Int,
                  let agentType = json["agent_type"] as? String else { return nil }
            return .agentStarted(pid: pid_t(pidVal), agentType: agentType)

        case "agent_state":
            guard let pidVal = json["pid"] as? Int,
                  let state = json["state"] as? String else { return nil }
            let model = json["model"] as? String
            return .agentStateChanged(pid: pid_t(pidVal), state: state, model: model)

        case "agent_stopped":
            guard let pidVal = json["pid"] as? Int else { return nil }
            return .agentStopped(pid: pid_t(pidVal))

        default:
            return nil
        }
    }
}
