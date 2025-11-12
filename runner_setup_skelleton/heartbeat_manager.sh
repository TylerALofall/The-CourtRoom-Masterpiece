#!/bin/bash

# Heartbeat Manager - Pulse Width Modulator for Model Pacing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${SCRIPT_DIR}/data/state"
HEARTBEAT_FILE="${STATE_DIR}/heartbeat_state.json"

mkdir -p "$STATE_DIR"

# Initialize if not exists
if [ ! -f "$HEARTBEAT_FILE" ]; then
    echo '{"enabled":false,"interval":60,"last_pulse":0,"color":"clear"}' > "$HEARTBEAT_FILE"
fi

# Get current epoch
get_epoch() {
    date +%s
}

# Enable heartbeat
enable_heartbeat() {
    local interval="${1:-60}"
    local current_epoch=$(get_epoch)

    jq --arg interval "$interval" --arg epoch "$current_epoch" \
        '.enabled = true | .interval = ($interval | tonumber) | .last_pulse = ($epoch | tonumber) | .color = "green"' \
        "$HEARTBEAT_FILE" > "${HEARTBEAT_FILE}.tmp" && mv "${HEARTBEAT_FILE}.tmp" "$HEARTBEAT_FILE"

    echo "✓ Heartbeat enabled: ${interval}s interval"
}

# Disable heartbeat
disable_heartbeat() {
    jq '.enabled = false | .color = "clear"' \
        "$HEARTBEAT_FILE" > "${HEARTBEAT_FILE}.tmp" && mv "${HEARTBEAT_FILE}.tmp" "$HEARTBEAT_FILE"

    echo "✓ Heartbeat disabled"
}

# Set interval (0-3600 seconds)
set_interval() {
    local interval="$1"

    if [ "$interval" -lt 0 ] || [ "$interval" -gt 3600 ]; then
        echo "✗ Error: Interval must be 0-3600 seconds"
        return 1
    fi

    if [ "$interval" -eq 0 ]; then
        disable_heartbeat
        return 0
    fi

    jq --arg interval "$interval" \
        '.interval = ($interval | tonumber)' \
        "$HEARTBEAT_FILE" > "${HEARTBEAT_FILE}.tmp" && mv "${HEARTBEAT_FILE}.tmp" "$HEARTBEAT_FILE"

    echo "✓ Heartbeat interval set to: ${interval}s"
}

# Pulse (update last pulse time)
pulse() {
    local current_epoch=$(get_epoch)

    jq --arg epoch "$current_epoch" \
        '.last_pulse = ($epoch | tonumber)' \
        "$HEARTBEAT_FILE" > "${HEARTBEAT_FILE}.tmp" && mv "${HEARTBEAT_FILE}.tmp" "$HEARTBEAT_FILE"

    echo "✓ Pulse recorded at epoch: $current_epoch"
}

# Check if ready for next pulse
check_ready() {
    local current_epoch=$(get_epoch)
    local enabled=$(jq -r '.enabled' "$HEARTBEAT_FILE")
    local interval=$(jq -r '.interval' "$HEARTBEAT_FILE")
    local last_pulse=$(jq -r '.last_pulse' "$HEARTBEAT_FILE")

    if [ "$enabled" != "true" ]; then
        echo "ready|no_heartbeat"
        return 0
    fi

    local elapsed=$((current_epoch - last_pulse))

    if [ $elapsed -ge $interval ]; then
        echo "ready|$elapsed"
        return 0
    else
        local remaining=$((interval - elapsed))
        echo "waiting|$remaining"
        return 1
    fi
}

# Set heartbeat color (red if blocking, clear if ready)
set_color() {
    local color="$1"  # "red" or "clear"

    jq --arg color "$color" \
        '.color = $color' \
        "$HEARTBEAT_FILE" > "${HEARTBEAT_FILE}.tmp" && mv "${HEARTBEAT_FILE}.tmp" "$HEARTBEAT_FILE"
}

# Get status
get_status() {
    if [ ! -f "$HEARTBEAT_FILE" ]; then
        echo "Error: Heartbeat state file not found"
        return 1
    fi

    jq . "$HEARTBEAT_FILE"
}

# Show visual status
show_visual() {
    local enabled=$(jq -r '.enabled' "$HEARTBEAT_FILE")
    local interval=$(jq -r '.interval' "$HEARTBEAT_FILE")
    local last_pulse=$(jq -r '.last_pulse' "$HEARTBEAT_FILE")
    local color=$(jq -r '.color' "$HEARTBEAT_FILE")
    local current_epoch=$(get_epoch)
    local elapsed=$((current_epoch - last_pulse))

    if [ "$color" == "red" ]; then
        local color_code='\033[0;31m'
    elif [ "$color" == "green" ]; then
        local color_code='\033[0;32m'
    else
        local color_code='\033[0m'
    fi

    echo -e "${color_code}♥${NC} Heartbeat: $([ "$enabled" == "true" ] && echo "Enabled" || echo "Disabled")"
    echo "  Interval: ${interval}s"
    echo "  Last Pulse: $elapsed seconds ago"
    echo "  Status: $(check_ready | cut -d'|' -f1)"
}

# Main command handler
case "${1:-status}" in
    enable)
        enable_heartbeat "${2:-60}"
        ;;
    disable)
        disable_heartbeat
        ;;
    interval)
        set_interval "${2:-60}"
        ;;
    pulse)
        pulse
        ;;
    ready)
        check_ready
        ;;
    color)
        set_color "${2:-clear}"
        ;;
    status)
        get_status
        ;;
    visual)
        show_visual
        ;;
    *)
        echo "Usage: $0 {enable|disable|interval|pulse|ready|color|status|visual} [args]"
        echo ""
        echo "Commands:"
        echo "  enable [interval]   - Enable heartbeat (default: 60s)"
        echo "  disable             - Disable heartbeat"
        echo "  interval <seconds>  - Set interval (0-3600)"
        echo "  pulse               - Record pulse"
        echo "  ready               - Check if ready for next pulse"
        echo "  color <red|clear>   - Set heartbeat color"
        echo "  status              - Show JSON status"
        echo "  visual              - Show visual status"
        exit 1
        ;;
esac
