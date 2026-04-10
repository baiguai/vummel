#!/bin/bash

# Check for the correct number of arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <full_path_to_html_file>"
    exit 1
fi

FULL_PATH=$1
TARGET_DIR=$(dirname "$FULL_PATH")
FILENAME=$(basename "$FULL_PATH")
if [[ $FILENAME == *.html ]]; then
    FILENAME=${FILENAME%.html}
fi
SCRNODES_SH="$HOME/scrnodes.sh"
HTML_FILE="$TARGET_DIR/$FILENAME.html"
SAVER_JS_FILE="$TARGET_DIR/svr_$FILENAME.js"

# Check if the files already exist
if [ -f "$HTML_FILE" ] && [ -f "$SAVER_JS_FILE" ]; then
    echo "Installation for $FILENAME in $TARGET_DIR already exists. Aborting."
    exit 0
fi

# Determine the next available port
PORT=3000
if [ -f "$SCRNODES_SH" ]; then
    # Find the last port number from the comments at the top of the script
    LAST_PORT=$(grep -E '^# [0-9]+$' "$SCRNODES_SH" | tail -n 1 | sed 's/# //')
    if [ -n "$LAST_PORT" ]; then
        PORT=$((LAST_PORT + 1))
    else
        # If no port comments are found, check for the old format
        LAST_PORT=$(grep -o 'echo.*: [0-9]*' "$SCRNODES_SH" | tail -n 1 | grep -o '[0-9]*$')
        if [ -n "$LAST_PORT" ]; then
            PORT=$((LAST_PORT + 1))
        fi
    fi
fi

# Create or update the scrnodes.sh script
if [ ! -f "$SCRNODES_SH" ]; then
    echo "#! /bin/bash" > "$SCRNODES_SH"
    echo "" >> "$SCRNODES_SH"
    echo "# $PORT" >> "$SCRNODES_SH"
    echo "" >> "$SCRNODES_SH"
    echo "cd '$TARGET_DIR' && node '$SAVER_JS_FILE' &" >> "$SCRNODES_SH"
    echo "" >> "$SCRNODES_SH"
    echo "sleep 3" >> "$SCRNODES_SH"
    echo "" >> "$SCRNODES_SH"
    echo "echo \"\"" >> "$SCRNODES_SH"
    echo "echo \"\"" >> "$SCRNODES_SH"
    echo "echo \"\"" >> "$SCRNODES_SH"
    echo "echo \"$FILENAME: $PORT\"" >> "$SCRNODES_SH"
    echo "echo \"\"" >> "$SCRNODES_SH"
    echo "echo \"\"" >> "$SCRNODES_SH"
    echo "echo \"\"" >> "$SCRNODES_SH"
    echo "" >> "$SCRNODES_SH"
    echo "wait" >> "$SCRNODES_SH"
    chmod +x "$SCRNODES_SH"
else
	if ! grep -q "cd '$TARGET_DIR' && node '$SAVER_JS_FILE' &" "$SCRNODES_SH"; then
		# Add the new port comment
		LAST_PORT_LINE=$(grep -nE '^# [0-9]+$' "$SCRNODES_SH" | tail -n 1 | cut -d: -f1)
		if [ -n "$LAST_PORT_LINE" ]; then
			sed -i "${LAST_PORT_LINE}a# $PORT" "$SCRNODES_SH"
		else
			sed -i '/^#! \/bin\/bash/a # '$PORT'' "$SCRNODES_SH"
		fi

		# Add the new node service command before sleep 3
		sed -i "/^sleep 3/i cd '$TARGET_DIR' && node '$SAVER_JS_FILE' &" "$SCRNODES_SH"

		# Add the new echo statement
		LAST_ECHO_LINE=$(grep -nE 'echo ".*: [0-9]+"' "$SCRNODES_SH" | tail -n 1 | cut -d: -f1)
		if [ -n "$LAST_ECHO_LINE" ]; then
			sed -i "${LAST_ECHO_LINE}a echo \"$FILENAME: $PORT\"" "$SCRNODES_SH"
		else
			sed -i "/^wait/i echo \"$FILENAME: $PORT\"" "$SCRNODES_SH"
		fi
	fi
fi

if [ ! -f "$HTML_FILE" ]; then
    # Copy scribboleth.html to the target directory
    cp scribboleth.html "$HTML_FILE"

    # Update the node port and file name in the new html file
    sed -i "s/let nodePort = 0;/let nodePort = $PORT;/" "$HTML_FILE"
    sed -i "s/let fileName = \"help\";/let fileName = \"$FILENAME\";/" "$HTML_FILE"
else
    # Update the node port and file name in the existing html file
    sed -i "s/let nodePort = [0-9]*;/let nodePort = $PORT;/" "$HTML_FILE"
    sed -i "s/let fileName = \".*\";/let fileName = \"$FILENAME\";/" "$HTML_FILE"
fi

if [ ! -f "$SAVER_JS_FILE" ]; then
    # Copy saver.js to the target directory
    cp saver.js "$SAVER_JS_FILE"

    # Update the file name and port in the new saver.js file
    sed -i "s|const FILE_PATH = \"./scribboleth.html\";|const FILE_PATH = \"./$FILENAME.html\";|" "$SAVER_JS_FILE"
    sed -i "s/const PORT = 3000;/const PORT = $PORT;/" "$SAVER_JS_FILE"
else
    # Update the file name and port in the existing saver.js file
    sed -i "s|const FILE_PATH = \".*\";|const FILE_PATH = \"./$FILENAME.html\";|" "$SAVER_JS_FILE"
    sed -i "s/const PORT = [0-9]*;/const PORT = $PORT;/" "$SAVER_JS_FILE"
fi


echo "New scribboleth instance '$FILENAME' created in '$TARGET_DIR' on port $PORT."
echo "To start the node service, run: $SCRNODES_SH"

cp ./package.json "$TARGET_DIR"
cd "$TARGET_DIR"
npm install

