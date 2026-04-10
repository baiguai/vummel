#!/bin/bash
set -e

# Function to display usage
usage() {
    echo "Usage: $0 <full_path_to_html_file>"
    echo "Example: $0 /home/user/notes/mynotes.html"
    exit 1
}

# Check for the correct number of arguments
if [ -z "$1" ]; then
    usage
fi

FULL_PATH_HTML="$1"
FILENAME=$(basename "$FULL_PATH_HTML" .html)
TARGET_DIR=$(dirname "$FULL_PATH_HTML")
HTML_FILE="${TARGET_DIR}/${FILENAME}.html"
SAVER_JS_FILE="${TARGET_DIR}/svr_${FILENAME}.js"
SCRNODES_SH="$HOME/scrnodes.sh"
PACKAGE_JSON="${TARGET_DIR}/package.json"
NODE_MODULES_DIR="${TARGET_DIR}/node_modules"

echo "Attempting to uninstall Scribboleth instance for: ${HTML_FILE}"
echo "Associated saver script: ${SAVER_JS_FILE}"
echo "This will also remove entries from: ${SCRNODES_SH}"
read -r -p "Are you sure you want to proceed? (y/N) " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# --- Find the port from HTML file ---
PORT=""
if [ -f "$HTML_FILE" ]; then
    NODE_PORT_LINE=$(grep "let nodePort = [0-9]\+;" "$HTML_FILE")
    if [[ "$NODE_PORT_LINE" =~ [0-9]+ ]]; then
        PORT=$(echo "$NODE_PORT_LINE" | grep -oE '[0-9]+')
    fi
fi

if [ -z "$PORT" ]; then
    echo "Error: Could not find nodePort in ${HTML_FILE}. Cannot proceed with scrnodes.sh cleanup."
    exit 1
else
    echo "Identified port from HTML file: ${PORT}"
fi

# --- Remove files ---
echo "Removing ${HTML_FILE}..."
rm -f "${HTML_FILE}"
echo "Removing ${SAVER_JS_FILE}..."
rm -f "${SAVER_JS_FILE}"
echo "Removing ${PACKAGE_JSON}..."
rm -f "${PACKAGE_JSON}"

# --- Clean scrnodes.sh ---
if [ -f "$SCRNODES_SH" ]; then
    echo "Cleaning up ${SCRNODES_SH}..."
    TEMP_SCRNODES=$(mktemp)

    # Define the exact lines to match, escaping potential regex characters in paths
    # Note: Bash variables are expanded before being passed to sed.
    # We must escape characters that have special meaning in regex such as '/', '.', '*', '[', ']', '$', '^'.
    # The main concern is '/' in paths.
    
    # Escape '/' in TARGET_DIR and SAVER_JS_FILE for sed regex
    ESCAPED_TARGET_DIR=$(echo "${TARGET_DIR}" | sed 's/\//\\\//g')
    ESCAPED_SAVER_JS_FILE=$(echo "${SAVER_JS_FILE}" | sed 's/\//\\\//g')

    PORT_COMMENT_PATTERN="^# ${PORT}$"
    CD_NODE_PATTERN="^cd '${ESCAPED_TARGET_DIR}' && node '${ESCAPED_SAVER_JS_FILE}' &$"
    ECHO_PATTERN="^echo \"?${FILENAME}: ${PORT}\"?$"
    

    # Read scrnodes.sh into an array, filter out matching lines, and write back.
    # This approach is more robust and less prone to sed portability issues.
    mapfile -t SCRNODES_LINES < "$SCRNODES_SH"
    
    NEW_SCRNODES_CONTENT=()
    for LINE in "${SCRNODES_LINES[@]}"; do
        REMOVE_LINE=0
        # Check if line matches port comment pattern
        if [ -n "$PORT" ] && [[ "$LINE" =~ $PORT_COMMENT_PATTERN ]]; then
            REMOVE_LINE=1
        fi
        # Check if line matches cd/node service pattern
        if [[ "$LINE" =~ $CD_NODE_PATTERN ]]; then
            REMOVE_LINE=1
        fi
        # Check if line matches echo pattern
        if [ -n "$PORT" ] && [[ "$LINE" =~ $ECHO_PATTERN ]]; then
            REMOVE_LINE=1
        fi
        
        if [ "$REMOVE_LINE" -eq 0 ]; then
            NEW_SCRNODES_CONTENT+=("$LINE")
        fi
    done
    
    # Write the filtered content back to scrnodes.sh, ensuring empty lines are also handled.
    printf "%s\n" "${NEW_SCRNODES_CONTENT[@]}" | grep -vE '^\s*$' > "$SCRNODES_SH"

    echo "scrnodes.sh cleaned up. You may need to run 'chmod +x ${SCRNODES_SH}' if permissions were lost."
else
    echo "Warning: ${SCRNODES_SH} not found. Skipping scrnodes.sh cleanup."
fi

echo ""
echo "--------------------------------------------------------"
echo "Uninstallation complete for ${FILENAME}."
echo "You may need to remove the Node.js modules folder if it's no longer needed: ${NODE_MODULES_DIR}"
echo "--------------------------------------------------------"

exit 0
