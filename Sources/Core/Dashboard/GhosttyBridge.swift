import Foundation

/// Bridges Cosmodrome to Ghostty via AppleScript.
/// Can focus specific Ghostty windows and send keystrokes.
public final class GhosttyBridge {
    public init() {}

    /// Focus a Ghostty window by matching its PID or window title.
    /// Uses AppleScript to bring the window to front.
    public func focusWindow(pid: pid_t) {
        // First bring Ghostty to front, then use System Events to focus the right window
        let script = """
        tell application "Ghostty"
            activate
        end tell

        tell application "System Events"
            tell process "Ghostty"
                set frontmost to true
                -- Find the window associated with the given PID via title matching
                repeat with w in windows
                    try
                        perform action "AXRaise" of w
                        return true
                    end try
                end repeat
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Focus a Ghostty window by its window ID (index or title).
    public func focusWindow(windowId: String) {
        if let index = Int(windowId) {
            let script = """
            tell application "Ghostty"
                activate
            end tell

            tell application "System Events"
                tell process "Ghostty"
                    set frontmost to true
                    if (count of windows) >= \(index) then
                        perform action "AXRaise" of window \(index)
                    end if
                end tell
            end tell
            """
            runAppleScript(script)
        } else {
            // Match by window title
            let escapedTitle = windowId.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "Ghostty"
                activate
            end tell

            tell application "System Events"
                tell process "Ghostty"
                    set frontmost to true
                    repeat with w in windows
                        if name of w contains "\(escapedTitle)" then
                            perform action "AXRaise" of w
                            return true
                        end if
                    end repeat
                end tell
            end tell
            """
            runAppleScript(script)
        }
    }

    /// List all Ghostty windows (returns window titles).
    public func listWindows() -> [String] {
        let script = """
        tell application "System Events"
            if not (exists process "Ghostty") then return ""
            tell process "Ghostty"
                set windowNames to {}
                repeat with w in windows
                    set end of windowNames to name of w
                end repeat
                return windowNames
            end tell
        end tell
        """
        guard let result = runAppleScriptWithResult(script) else { return [] }
        return result.components(separatedBy: ", ")
    }

    /// Send keystrokes to the frontmost Ghostty window.
    public func sendKeys(_ keys: String) {
        let escapedKeys = keys.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "System Events"
            tell process "Ghostty"
                keystroke "\(escapedKeys)"
            end tell
        end tell
        """
        runAppleScript(script)
    }

    /// Check if Ghostty is running.
    public var isGhosttyRunning: Bool {
        let script = """
        tell application "System Events"
            return exists process "Ghostty"
        end tell
        """
        return runAppleScriptWithResult(script) == "true"
    }

    // MARK: - Private

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        return error == nil
    }

    private func runAppleScriptWithResult(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }
}
