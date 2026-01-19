#!/bin/bash
# Module: dialog-helpers.sh
# Purpose: Wrapper functions for dialog/whiptail with consistent styling

# Dialog settings
DIALOG_CMD=""
DIALOG_HEIGHT="${DIALOG_HEIGHT:-20}"
DIALOG_WIDTH="${DIALOG_WIDTH:-70}"
DIALOG_TITLE="${DIALOG_TITLE:-HAProxy CLI GUI}"
DIALOG_BACKTITLE="${DIALOG_BACKTITLE:-HAProxy Configuration Manager}"

# Initialize dialog command
init_dialog() {
    DIALOG_CMD=$(get_dialog_command)

    if [[ -z "$DIALOG_CMD" ]]; then
        die "Neither dialog nor whiptail found. Please install one of them."
    fi

    log_debug "Using dialog command: $DIALOG_CMD"
}

# Show menu dialog
# Args: $1 = title
#       $2 = menu text
#       $@ = menu items (tag description pairs)
# Returns: selected tag via stdout
show_menu() {
    local title="$1"
    local text="$2"
    shift 2
    local items=("$@")
    local result

    result=$($DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --menu "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $(( DIALOG_HEIGHT - 8 )) \
        "${items[@]}" \
        2>&1 >/dev/tty)

    echo "$result"
}

# Show yes/no dialog
# Args: $1 = title
#       $2 = text
# Returns: 0 for yes, 1 for no
show_yesno() {
    local title="$1"
    local text="$2"

    $DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --yesno "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH \
        2>&1 >/dev/tty

    return $?
}

# Show message box
# Args: $1 = title
#       $2 = text
show_msgbox() {
    local title="$1"
    local text="$2"

    $DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --msgbox "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH \
        2>&1 >/dev/tty
}

# Show input box
# Args: $1 = title
#       $2 = text
#       $3 = default value (optional)
# Returns: input value via stdout
show_inputbox() {
    local title="$1"
    local text="$2"
    local default="${3:-}"
    local result

    result=$($DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --inputbox "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH \
        "$default" \
        2>&1 >/dev/tty)

    echo "$result"
}

# Show text box (display file content)
# Args: $1 = title
#       $2 = file path
show_textbox() {
    local title="$1"
    local file="$2"

    if [[ ! -f "$file" ]]; then
        show_msgbox "Error" "File not found: $file"
        return 1
    fi

    $DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --textbox "$file" \
        $DIALOG_HEIGHT $DIALOG_WIDTH \
        2>&1 >/dev/tty
}

# Show form dialog
# Args: $1 = title
#       $2 = text
#       $@ = form fields (label y x item y x flen ilen)
# Returns: field values separated by newlines via stdout
show_form() {
    local title="$1"
    local text="$2"
    shift 2
    local fields=("$@")
    local result

    result=$($DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --form "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH 10 \
        "${fields[@]}" \
        2>&1 >/dev/tty)

    echo "$result"
}

# Show checklist dialog
# Args: $1 = title
#       $2 = text
#       $@ = checklist items (tag description status)
# Returns: selected tags via stdout
show_checklist() {
    local title="$1"
    local text="$2"
    shift 2
    local items=("$@")
    local result

    result=$($DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --checklist "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $(( DIALOG_HEIGHT - 8 )) \
        "${items[@]}" \
        2>&1 >/dev/tty)

    echo "$result"
}

# Show radiolist dialog
# Args: $1 = title
#       $2 = text
#       $@ = radiolist items (tag description status)
# Returns: selected tag via stdout
show_radiolist() {
    local title="$1"
    local text="$2"
    shift 2
    local items=("$@")
    local result

    result=$($DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --radiolist "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $(( DIALOG_HEIGHT - 8 )) \
        "${items[@]}" \
        2>&1 >/dev/tty)

    echo "$result"
}

# Show progress gauge
# Args: $1 = title
#       $2 = text
#       $3 = percentage (0-100)
show_gauge() {
    local title="$1"
    local text="$2"
    local percent="$3"

    echo "$percent" | $DIALOG_CMD --clear --backtitle "$DIALOG_BACKTITLE" \
        --title "$title" \
        --gauge "$text" \
        $DIALOG_HEIGHT $DIALOG_WIDTH \
        2>&1 >/dev/tty
}

# Export functions
export -f init_dialog show_menu show_yesno show_msgbox show_inputbox
export -f show_textbox show_form show_checklist show_radiolist show_gauge

log_debug "Dialog helpers module loaded"
