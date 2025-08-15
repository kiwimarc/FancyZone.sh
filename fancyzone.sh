#!/bin/bash

# Requirements: xdotool, wmctrl, xinput, jq, xwininfo

CONFIG_FILE="$HOME/.config/window-snap-config.json"
DEBUG=0
TEST_MODE=0
WIDTH_OFFSET=0
HEIGHT_OFFSET=0
SAVE_CONFIG=0
WIDTH_OFFSET_ARG=""
HEIGHT_OFFSET_ARG=""

# --- Parse command-line arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            DEBUG=1
            shift
            ;;
        --test)
            TEST_MODE=1
            shift
            ;;
        --width-offset)
            WIDTH_OFFSET_ARG="$2"
            shift 2
            ;;
        --height-offset)
            HEIGHT_OFFSET_ARG="$2"
            shift 2
            ;;
        --save-config)
           SAVE_CONFIG=1
           shift
           ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Ensure config directory exists
mkdir -p "$HOME/.config"

# --- Load or create config ---
if [ -f "$CONFIG_FILE" ]; then
    KEYBOARD_ID=$(jq -r '.keyboard_id' "$CONFIG_FILE")
    KEYCODE=$(jq -r '.keycode' "$CONFIG_FILE")
    KEY_NAME=$(jq -r '.key_name' "$CONFIG_FILE")
    MOUSE_ID=$(jq -r '.mouse_id' "$CONFIG_FILE")
    WIDTH_OFFSET=$(jq -r '.width_offset // 0' "$CONFIG_FILE")
    HEIGHT_OFFSET=$(jq -r '.height_offset // 0' "$CONFIG_FILE")
    [[ $DEBUG -eq 1 ]] && echo "Loaded config:"
    [[ $DEBUG -eq 1 ]] && echo "  Keyboard ID   = $KEYBOARD_ID"
    [[ $DEBUG -eq 1 ]] && echo "  Key Name      = $KEY_NAME"
    [[ $DEBUG -eq 1 ]] && echo "  Keycode       = $KEYCODE"
    [[ $DEBUG -eq 1 ]] && echo "  Mouse ID      = $MOUSE_ID"
    [[ $DEBUG -eq 1 ]] && echo "  Width Offset  = $WIDTH_OFFSET"
    [[ $DEBUG -eq 1 ]] && echo "  Height Offset = $HEIGHT_OFFSET"
else
    # Select keyboard device
    echo "Select a keyboard device:"
    xinput list | grep -i 'keyboard' | grep -v 'XTEST' | nl

    read -p "Enter the number of the keyboard to use: " keyboard_index
    DEVICE_LINE=$(xinput list | grep -i 'keyboard' | grep -v 'XTEST' | sed -n "${keyboard_index}p")

    if [[ -z "$DEVICE_LINE" ]]; then
        echo "Invalid selection."
        exit 1
    fi

    KEYBOARD_ID=$(echo "$DEVICE_LINE" | grep -Po 'id=\K\d+')
    echo "Selected keyboard ID: $KEYBOARD_ID"
    echo "Now press the key you want to use as the modifier..."

    # Use xinput test to capture key press
    KEY_DATA=$(xinput test "$KEYBOARD_ID" | grep --line-buffered "key press" | head -n 1)
    KEYCODE=$(echo "$KEY_DATA" | awk '{print $3}')

    if [[ -z "$KEYCODE" ]]; then
        echo "Failed to detect key press. Make sure you're pressing a real key on the selected device."
        exit 1
    fi

    # Get key name
    KEY_NAME=$(xmodmap -pke | grep "keycode $KEYCODE" | head -n 1 | awk '{print $4}')
    echo "Detected key: $KEY_NAME (keycode $KEYCODE)"
    
    # Select mouse device
    echo -e "\nSelect a mouse device:"
    xinput list | grep -i 'pointer' | grep -v 'XTEST' | nl

    read -p "Enter the number of the mouse to use: " mouse_index
    MOUSE_LINE=$(xinput list | grep -i 'pointer' | grep -v 'XTEST' | sed -n "${mouse_index}p")

    if [[ -z "$MOUSE_LINE" ]]; then
        echo "Invalid selection."
        exit 1
    fi

    MOUSE_ID=$(echo "$MOUSE_LINE" | grep -Po 'id=\K\d+')
    echo "Selected mouse ID: $MOUSE_ID"
    echo "Press the left mouse button..."
    
    # Test that the mouse is working
    MOUSE_BUTTON=$(xinput test "$MOUSE_ID" | grep --line-buffered "button press" | head -n 1)
    BUTTON_CODE=$(echo "$MOUSE_BUTTON" | awk '{print $3}')
    
    if [[ -z "$BUTTON_CODE" || "$BUTTON_CODE" != "1" ]]; then
        echo "Failed to detect left mouse button press or incorrect button. Expected button 1, got $BUTTON_CODE."
        echo "Continuing anyway, but mouse detection might not work correctly."
    else
        echo "Detected left mouse button press correctly."
    fi

    # Save config
    echo "{\"keyboard_id\": $KEYBOARD_ID, \"keycode\": $KEYCODE, \"key_name\": \"$KEY_NAME\", \"mouse_id\": $MOUSE_ID}" > "$CONFIG_FILE"
fi

# Override if specified in args
if [[ -n "$WIDTH_OFFSET_ARG" ]]; then
    WIDTH_OFFSET="$WIDTH_OFFSET_ARG"
fi
if [[ -n "$HEIGHT_OFFSET_ARG" ]]; then
    HEIGHT_OFFSET="$HEIGHT_OFFSET_ARG"
fi

if [[ $SAVE_CONFIG -eq 1 ]]; then
    jq \
      --argjson width_offset "$WIDTH_OFFSET" \
      --argjson height_offset "$HEIGHT_OFFSET" \
      '.width_offset = $width_offset | .height_offset = $height_offset' \
      "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

    echo "Offsets saved to config: width_offset = $WIDTH_OFFSET, height_offset = $HEIGHT_OFFSET"
    exit 0
fi

# --- Get primary monitor geometry ---
PRIMARY=$(xrandr | grep ' connected primary' | awk '{print $4}')
if [ -z "$PRIMARY" ]; then
    echo "Error: Could not detect primary monitor."
    exit 1
fi

GEOM=$(echo "$PRIMARY" | grep -oP '\d+x\d+\+\d+\+\d+')
WIDTH=$(echo $GEOM | cut -d'x' -f1)
HEIGHT_PLUS=$(echo $GEOM | cut -d'x' -f2)
HEIGHT=$(echo $HEIGHT_PLUS | cut -d'+' -f1)
XPOS=$(echo $HEIGHT_PLUS | cut -d'+' -f2)
YPOS=$(echo $HEIGHT_PLUS | cut -d'+' -f3)

WIDTH=$((WIDTH - WIDTH_OFFSET))
HEIGHT=$((HEIGHT - HEIGHT_OFFSET))

LEFT_W=$((WIDTH * 25 / 100))
MIDDLE_W=$((WIDTH * 50 / 100))
RIGHT_W=$((WIDTH * 25 / 100))
HALF_H=$((HEIGHT / 2))

if [[ $DEBUG -eq 1 ]]; then
    echo "Screen layout:"
    echo "Monitor: $WIDTH x $HEIGHT at position $XPOS,$YPOS"
    echo "Left zone: ${LEFT_W}x${HEIGHT} at ${XPOS},${YPOS}"
    echo "Middle zone: ${MIDDLE_W}x${HEIGHT} at $((XPOS + LEFT_W)),${YPOS}"
    echo "Top-right zone: ${RIGHT_W}x${HALF_H} at $((XPOS + LEFT_W + MIDDLE_W)),${YPOS}"
    echo "Bottom-right zone: ${RIGHT_W}x${HALF_H} at $((XPOS + LEFT_W + MIDDLE_W)),$((YPOS + HALF_H))"
fi

if [[ $TEST_MODE -eq 1 ]]; then
    echo "Running in test mode: launching windows in each zone"

    # Function to launch a window and move it
    launch_window() {
        local NAME=$1
        local X=$2
        local Y=$3
        local W=$4
        local H=$5

        xterm -title "$NAME" -geometry 10x5 -e sleep 10 &
        WIN_PID=$!
        sleep 0.5  # Give xterm time to start

        WIN_ID=$(xdotool search --sync --pid $WIN_PID | head -n1)
        xdotool windowactivate --sync "$WIN_ID"
        xdotool windowmove "$WIN_ID" $X $Y
        xdotool windowsize "$WIN_ID" $W $H
    }

    launch_window "Left"   "$XPOS" "$YPOS" "$LEFT_W" "$HEIGHT"
    launch_window "Middle" "$((XPOS + LEFT_W))" "$YPOS" "$MIDDLE_W" "$HEIGHT"
    launch_window "TopRight" "$((XPOS + LEFT_W + MIDDLE_W))" "$YPOS" "$RIGHT_W" "$HALF_H"
    launch_window "BotRight" "$((XPOS + LEFT_W + MIDDLE_W))" "$((YPOS + HALF_H))" "$RIGHT_W" "$HALF_H"

    echo "Windows launched in all zones. Exiting test mode."
    exit 0
fi

# --- Main loop ---
[[ $DEBUG -eq 1 ]] && echo "Starting window snapper. Hold key '$KEY_NAME' (keycode $KEYCODE) and left mouse button to select a zone. Release either to snap."

# Function to check if key is pressed
check_key_pressed() {
    xinput query-state "$KEYBOARD_ID" | grep -q "key\\[$KEYCODE\\]=down"
}

# Function to check if left mouse button is pressed
check_mouse_pressed() {
    xinput query-state "$MOUSE_ID" | grep -q "button\[1\]=down"
}

# Function to get window decorations using xwininfo
get_window_decorations() {
    local WIN_ID=$1
    local WIN_INFO=$(xwininfo -id "$WIN_ID")
    
    # Extract border and title bar measurements
    local BORDER_W=$(echo "$WIN_INFO" | grep "Border width:" | awk '{print $3}')
    local TITLE_H=$(echo "$WIN_INFO" | grep "Title height:" | awk '{print $3}')
    
    # If we couldn't get valid measurements, use sensible defaults
    if [[ -z "$BORDER_W" || "$BORDER_W" -eq 0 ]]; then
        BORDER_W=2
    fi
    
    if [[ -z "$TITLE_H" || "$TITLE_H" -eq 0 ]]; then
        TITLE_H=20
    fi
    
    echo "$BORDER_W $TITLE_H"
}

# Function to try multiple methods to unmaximize a window
unmaximize_window() {
    local WIN_ID=$1
    
    # Method 1: Try wmctrl
    if wmctrl -l | grep -q "$WIN_ID"; then
        [[ $DEBUG -eq 1 ]] && echo "Trying to unmaximize with wmctrl..."
        wmctrl -ir "$WIN_ID" -b remove,maximized_vert,maximized_horz,fullscreen
    fi
    
    # Method 2: Try xdotool key commands
    [[ $DEBUG -eq 1 ]] && echo "Trying to unmaximize with keyboard shortcuts..."
    xdotool windowactivate --sync "$WIN_ID"
    xdotool key alt+F5
    sleep 0.1
    
    # Method 3: Try xdotool windowstate
    [[ $DEBUG -eq 1 ]] && echo "Trying to unmaximize with windowstate..."
    xdotool windowactivate --sync "$WIN_ID"
    xdotool windowstate --remove MAXIMIZED_VERT "$WIN_ID"
    xdotool windowstate --remove MAXIMIZED_HORZ "$WIN_ID"
    xdotool windowstate --remove FULLSCREEN "$WIN_ID"
    sleep 0.2
}

# Function to snap window using multiple attempts
snap_window() {
    local WIN_ID=$1
    local X=$2
    local Y=$3
    local W=$4
    local H=$5
    local ZONE_NAME=$6
    
    # Try to unmaximize the window with multiple methods
    unmaximize_window "$WIN_ID"
    
    # Get window decorations
    local DECORATIONS=$(get_window_decorations "$WIN_ID")
    local BORDER_W=$(echo "$DECORATIONS" | awk '{print $1}')
    local TITLE_H=$(echo "$DECORATIONS" | awk '{print $2}')
    
    [[ $DEBUG -eq 1 ]] && echo "Window decorations: Border=$BORDER_W, Title=$TITLE_H"
    
    # Adjust size accounting for window decorations
    local ADJUST_W=$((BORDER_W * 2))
    local ADJUST_H=$((BORDER_W + TITLE_H))
    
    # Final dimensions
    local FINAL_W=$((W - ADJUST_W))
    local FINAL_H=$((H - ADJUST_H))
    
    [[ $DEBUG -eq 1 ]] && echo "Moving window to $X,$Y with size ${FINAL_W}x${FINAL_H}"
    
    # Try multiple approaches
    
    # Approach 1: Use wmctrl if available
    if wmctrl -l | grep -q "$WIN_ID"; then
        [[ $DEBUG -eq 1 ]] && echo "Trying wmctrl approach..."
        if wmctrl -ir "$WIN_ID" -e 0,$X,$Y,$FINAL_W,$FINAL_H; then
            [[ $DEBUG -eq 1 ]] && echo "wmctrl succeeded"
        else
            [[ $DEBUG -eq 1 ]] && echo "wmctrl failed"
        fi
    fi
    
    # Approach 2: Use xdotool with separate move and resize
    [[ $DEBUG -eq 1 ]] && echo "Trying xdotool approach..."
    xdotool windowactivate --sync "$WIN_ID"
    
    # Try multiple times to make it more reliable
    for i in {1..3}; do
        [[ $DEBUG -eq 1 ]] && echo "xdotool attempt $i..."
        
        # First resize
        if ! xdotool windowsize --sync "$WIN_ID" $FINAL_W $FINAL_H 2>/dev/null; then
            [[ $DEBUG -eq 1 ]] && echo "windowsize failed"
        fi
        
        # Then move
        if ! xdotool windowmove --sync "$WIN_ID" $X $Y 2>/dev/null; then
            [[ $DEBUG -eq 1 ]] && echo "windowmove failed"
        fi
        
        sleep 0.1
    done
    
    # Verify results
    local ACTUAL_GEOM=$(xdotool getwindowgeometry "$WIN_ID" 2>/dev/null)
    [[ $DEBUG -eq 1 ]] && echo "Final window geometry: $ACTUAL_GEOM"
    
    echo "Snapped to $ZONE_NAME zone"
}

# Function to determine which zone the mouse is in
get_current_zone() {
    local REL_X=$1
    local REL_Y=$2
    
    if [ "$REL_X" -lt "$LEFT_W" ]; then
        echo "Left"
    elif [ "$REL_X" -lt "$((LEFT_W + MIDDLE_W))" ]; then
        echo "Middle"
    elif [ "$REL_Y" -lt "$HALF_H" ]; then
        echo "Top-right"
    else
        echo "Bottom-right"
    fi
}

# State variables
BOTH_PRESSED=0
CURRENT_ZONE=""
WIN_ID=""

while true; do
    KEY_PRESSED=$(check_key_pressed && echo 1 || echo 0)
    MOUSE_PRESSED=$(check_mouse_pressed && echo 1 || echo 0)
    
    # When both key and mouse are pressed
    if [[ $KEY_PRESSED -eq 1 && $MOUSE_PRESSED -eq 1 ]]; then
        # If we're just starting the combo, get the window ID
        if [[ $BOTH_PRESSED -eq 0 ]]; then
            BOTH_PRESSED=1
            WIN_ID=$(xdotool getactivewindow)
            [[ $DEBUG -eq 1 ]] && echo "Both keys pressed. Window ID: $WIN_ID"
        fi
        
        # Get mouse position
        MOUSE_POS=$(xdotool getmouselocation --shell)
        eval "$MOUSE_POS"
        
        # Check if mouse is on primary monitor
        if (( X >= XPOS && X < XPOS + WIDTH && Y >= YPOS && Y < YPOS + HEIGHT )); then
            # Calculate relative position on screen
            REL_X=$((X - XPOS))
            REL_Y=$((Y - YPOS))
            
            # Determine current zone
            NEW_ZONE=$(get_current_zone $REL_X $REL_Y)
            
            # Only print if zone has changed
            if [[ "$NEW_ZONE" != "$CURRENT_ZONE" ]]; then
                CURRENT_ZONE="$NEW_ZONE"
                [[ $DEBUG -eq 1 ]] && echo "Mouse in $CURRENT_ZONE zone"
            fi
        else
            # Mouse not on primary monitor
            if [[ -n "$CURRENT_ZONE" ]]; then
                CURRENT_ZONE=""
                [[ $DEBUG -eq 1 ]] && echo "Mouse not on primary monitor"
            fi
        fi
    # When the combo is released (either key released while both were pressed)
    elif [[ $BOTH_PRESSED -eq 1 ]]; then
        BOTH_PRESSED=0
        
        # Snap the window if we have a valid zone
        if [[ -n "$CURRENT_ZONE" && -n "$WIN_ID" ]]; then
            [[ $DEBUG -eq 1 ]] && echo "Keys released - snapping to $CURRENT_ZONE zone"
            
            # Determine the correct position and size based on the zone
            case "$CURRENT_ZONE" in
                "Left")
                    snap_window "$WIN_ID" "$XPOS" "$YPOS" "$LEFT_W" "$HEIGHT" "Left"
                    ;;
                "Middle")
                    snap_window "$WIN_ID" "$((XPOS + LEFT_W))" "$YPOS" "$MIDDLE_W" "$HEIGHT" "Middle"
                    ;;
                "Top-right")
                    snap_window "$WIN_ID" "$((XPOS + LEFT_W + MIDDLE_W))" "$YPOS" "$RIGHT_W" "$HALF_H" "Top-right"
                    ;;
                "Bottom-right")
                    snap_window "$WIN_ID" "$((XPOS + LEFT_W + MIDDLE_W))" "$((YPOS + HALF_H))" "$RIGHT_W" "$HALF_H" "Bottom-right"
                    ;;
            esac
            
            # Reset state
            CURRENT_ZONE=""
            WIN_ID=""
        fi
    fi
    
    sleep 0.1
done