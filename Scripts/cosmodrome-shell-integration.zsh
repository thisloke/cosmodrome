#!/usr/bin/env zsh
# Cosmodrome Shell Integration for Ghostty
#
# Add to ~/.zshrc:
#   source /path/to/cosmodrome-shell-integration.zsh
#
# This script registers the current Ghostty session with Cosmodrome's
# dashboard, enabling project grouping and window focus switching.

# Socket path — set by Cosmodrome dashboard on launch (printed to stdout).
# Export COSMODROME_DASHBOARD_SOCKET in your shell for explicit path, or
# let auto-discovery find it in $TMPDIR.
: "${COSMODROME_DASHBOARD_SOCKET:=}"

_cosmodrome_find_socket() {
    # If explicit path is set and exists, use it
    if [[ -n "$COSMODROME_DASHBOARD_SOCKET" ]] && [[ -S "$COSMODROME_DASHBOARD_SOCKET" ]]; then
        echo "$COSMODROME_DASHBOARD_SOCKET"
        return
    fi
    # Auto-discover: search $TMPDIR (macOS uses /var/folders/...), then /tmp
    local sock
    for dir in "${TMPDIR:-/tmp}" /tmp; do
        sock=$(ls -t "$dir"/cosmodrome-dashboard-*.sock 2>/dev/null | head -1)
        if [[ -S "$sock" ]]; then
            echo "$sock"
            return
        fi
    done
}

_cosmodrome_send() {
    local socket
    socket=$(_cosmodrome_find_socket)
    [[ -z "$socket" ]] && return

    # Send JSON payload to the Unix socket
    echo "$1" | nc -U -w1 "$socket" 2>/dev/null &!
}

# Detect Ghostty window ID
_cosmodrome_window_id() {
    # Ghostty sets GHOSTTY_RESOURCES_DIR but not a window ID directly.
    # Use the TTY device as a stable identifier.
    echo "${TTY:-$(tty)}"
}

# Generate a stable session UUID from PID
_cosmodrome_session_id() {
    if [[ -n "$COSMODROME_SESSION_ID" ]]; then
        echo "$COSMODROME_SESSION_ID"
    else
        # Generate a deterministic UUID-like string from PID + TTY
        local hash
        hash=$(echo "$$-$(tty)" | shasum -a 256 | head -c 32)
        echo "${hash:0:8}-${hash:8:4}-4${hash:13:3}-8${hash:16:3}-${hash:19:12}"
    fi
}

# Register this session with Cosmodrome
_cosmodrome_register() {
    local cwd="$PWD"
    local label="${PWD##*/}"
    local window_id=$(_cosmodrome_window_id)
    local session_id=$(_cosmodrome_session_id)

    _cosmodrome_send "{
        \"type\": \"register\",
        \"session_id\": \"$session_id\",
        \"pid\": $$,
        \"window_id\": \"$window_id\",
        \"cwd\": \"$cwd\",
        \"label\": \"$label\"
    }"
}

# Unregister on shell exit
_cosmodrome_unregister() {
    _cosmodrome_send "{
        \"type\": \"unregister\",
        \"pid\": $$
    }"
}

# Re-register on directory change (updates project grouping)
_cosmodrome_chpwd() {
    _cosmodrome_register
}

# Heartbeat on each prompt (keeps session alive in dashboard)
_cosmodrome_precmd() {
    _cosmodrome_send "{
        \"type\": \"heartbeat\",
        \"pid\": $$,
        \"cwd\": \"$PWD\"
    }"
}

# Detect when Claude Code (or other agents) start
_cosmodrome_preexec() {
    local cmd="$1"
    case "$cmd" in
        claude*|aider*|codex*|gemini*)
            local agent_type
            agent_type="${cmd%% *}"
            _cosmodrome_send "{
                \"type\": \"agent_started\",
                \"pid\": $$,
                \"agent_type\": \"$agent_type\"
            }"
            ;;
    esac
}

# Only activate if running inside Ghostty (or if forced)
if [[ -n "$GHOSTTY_RESOURCES_DIR" ]] || [[ "$COSMODROME_FORCE_INTEGRATION" == "1" ]]; then
    # Register immediately
    _cosmodrome_register

    # Hook into zsh lifecycle
    chpwd_functions+=(_cosmodrome_chpwd)
    precmd_functions+=(_cosmodrome_precmd)
    preexec_functions+=(_cosmodrome_preexec)

    # Unregister on exit
    trap '_cosmodrome_unregister' EXIT
fi
