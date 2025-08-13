#!/bin/bash

# Universal AI Assistant with DeepSeek and OpenAI support
CONFIG_FILE="$HOME/.bin/ai_config.conf"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    notify-send "❌ AI Assistant" "Configuration file not found: $CONFIG_FILE" --icon="dialog-error"
    exit 1
fi

# Read settings from config
source "$CONFIG_FILE"

# Select API parameters based on configuration
case "$ACTIVE_API" in
    "deepseek")
        API_KEY="$DEEPSEEK_API_KEY"
        API_URL="$DEEPSEEK_API_URL"
        MODEL="$DEEPSEEK_MODEL"
        WINDOW_TITLE="DeepSeek AI"
        ;;
    "openai")
        API_KEY="$OPENAI_API_KEY"
        API_URL="$OPENAI_API_URL"
        MODEL="$OPENAI_MODEL"
        WINDOW_TITLE="OpenAI GPT"
        ;;
    *)
        notify-send "❌ AI Assistant" "Unsupported API: $ACTIVE_API. Supported: deepseek, openai" --icon="dialog-error"
        exit 1
        ;;
esac

# Check for API key
if [ -z "$API_KEY" ]; then
    notify-send "❌ AI Assistant" "API key not specified for $ACTIVE_API in configuration" --icon="dialog-error"
    exit 1
fi

# # Improve Zenity's appearance through system settings
# if command -v gsettings &>/dev/null; then
#       # Use the system GTK theme
#       SYSTEM_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
#       ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
#       if [ -n "$SYSTEM_THEME" ]; then
#           export GTK_THEME="$SYSTEM_THEME"
#       fi
#       if [ -n "$ICON_THEME" ]; then
#           export GTK_ICON_THEME="$ICON_THEME"
#       fi
# fi

# # Function to add visual padding via text formatting
# format_text_with_padding() {
#       local text="$1"
#       local padding="$2"
#       [ -z "$padding" ] && padding="    "
#       echo -e "\n$padding$text\n"
# }

# Get selected text (primary selection)
CONTEXT=$(xclip -o -selection primary 2>/dev/null)
# If empty, take from clipboard
if [ -z "$CONTEXT" ]; then
    CONTEXT=$(xclip -o -selection clipboard 2>/dev/null)
fi

# Format context for insertion into the dialog (remove extra \n)
if [ -n "$CONTEXT" ]; then
    CONTEXT="$CONTEXT"
fi

# Determine available dialog tool (only Zenity)
DIALOG_TOOL=""
if command -v zenity &>/dev/null; then
    DIALOG_TOOL="zenity"
else
    notify-send "❌ AI Assistant" "Zenity is required for the interface. Install with: sudo apt install zenity" --icon="dialog-error"
    exit 1
fi

# Dialog for input (context and prompt in one area)
USER_INPUT=""

# Show input dialog with improved formatting
USER_INPUT=$(zenity --text-info --editable --title="🤖 $WINDOW_TITLE" \
    --width=$WINDOW_WIDTH --height=$WINDOW_HEIGHT \
    --ok-label="📤 Send" --cancel-label="❌ Cancel" \
    --window-icon="applications-development" <<< "$CONTEXT")

# If user cancelled input, exit
if [ -z "$USER_INPUT" ]; then
    notify-send "🤖 $WINDOW_TITLE" "Input cancelled or empty." --icon="dialog-information"
    exit 0
fi

# Show notification about start of processing (with longer duration)
# notify-send -t 10000 "DeepSeek" "Sending request... Please wait."

# Show loading indicator with improved design
show_progress_dialog() {
    # Pulsating progress bar with emoji and better text
    (
        while true; do
            echo "# 🧠 AI is thinking..."
        done
    ) | zenity --progress --title="🤖 $WINDOW_TITLE" --text="Processing request..." \
        --pulsate --no-cancel --window-icon="applications-development" &
    PROGRESS_PID=$!
}

# Start loading indicator
show_progress_dialog

# Universal function to send a request to the API
send_api_request() {
    local user_input="$1"
    
    # Escape special characters in user input
    local user_input_escaped=$(echo "$user_input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    # Create JSON request
    local json_request=$(jq -n \
      --arg model "$MODEL" \
      --arg content "$user_input" \
      '{
        "model": $model,
        "messages": [{"role": "user", "content": $content}]
      }')

    # Send request and save both response and HTTP status
    local temp_response=$(mktemp)
    
    # Execute the request and get the status separately
    local http_status=$(curl -sS -o "$temp_response" -w "%{http_code}" -X POST "$API_URL" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$json_request")

    # Read the response
    local response=$(cat "$temp_response")
    rm -f "$temp_response"
    
    # Return status and response
    echo "$http_status|$response"
}

# Send the request
API_RESULT=$(send_api_request "$USER_INPUT")

# Parse the result more reliably
if [[ "$API_RESULT" == *"|"* ]]; then
    HTTP_STATUS="${API_RESULT%%|*}"  # Everything before the first |
    RESPONSE="${API_RESULT#*|}"      # Everything after the first |
else
    # If no delimiter, assume it's an error
    HTTP_STATUS="000"
    RESPONSE
