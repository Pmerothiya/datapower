#!/bin/bash
# ---------------------------------------------------------------------
# build_destination_general.sh (enhanced + fixed top-level tag filter)
# ---------------------------------------------------------------------
# Purpose:
#   - Parse export XML (data.xml)
#   - Iterate DIRECT children of <configuration domain="default">
#   - Ignore <DomainSettings>
#   - Find matching sections in source.cfg based on tag + name
#   - If not found:
#       → check dictionary mapping for alternate tag name
#       → if still not found, ask user to enter alternate manually
#   - Append matching blocks into destination.cfg (no cleaning)
#   - Preserve XML order
#   - FIXED: Copy only TOP-LEVEL tags (ignore nested blocks)
# ---------------------------------------------------------------------

# --- Step 1: Take input from user ---
read -p "Enter XML file path: " xml_file
read -p "Enter Source CFG file path: " src_cfg
read -p "Enter Destination CFG file path: " dest_cfg

# --- Step 2: Validate files exist ---
for file in "$xml_file" "$src_cfg"; do
    if [[ ! -f "$file" ]]; then
        echo " File '$file' not found!"
        exit 1
    fi
done

echo " Using files:"
echo "   XML: $xml_file"
echo "   Source CFG: $src_cfg"
echo "   Destination CFG: $dest_cfg"
echo

# --- Step 3: Extract ONLY main parent tags from configuration section ---
echo " Extracting main configuration tags from XML..."

config_section=$(sed -n '/<configuration domain="default">/,/<\/configuration>/p' "$xml_file")

tags_with_names=$(echo "$config_section" | grep -E '<[A-Za-z]+ name="[^"]*"' | grep -v 'DomainSettings' | while read -r line; do
    tag=$(echo "$line" | sed 's/^<\([A-Za-z]*\).*/\1/')
    name=$(echo "$line" | sed 's/.*name="\([^"]*\)".*/\1/')
    echo "$tag|$name"
done | sort -u)

if [[ -z "$tags_with_names" ]]; then
    echo "No main configuration tags found in XML."
    exit 0
fi

echo " Found main configuration tags:"
echo "$tags_with_names"
echo
echo " Processing tags in XML order..."
echo

# --- Step 4: Tag Mapping Dictionary (Bash 3.x compatible) ---
tag_map() {
    local xml_tag="$1"
    case "$xml_tag" in
        "MultiProtocolGateway") echo "mpgw" ;;
        "HTTPUserAgent") echo "user-agent" ;;
        "SFTPFilePollerSourceProtocolHandler") echo "source-sftp-poller" ;;
        *) echo "" ;;
    esac
}

# --- Step 5: Function to find and copy matching blocks ---
copy_block() {
    local xml_tag="$1"
    local name="$2"

    echo " Processing: Tag='$xml_tag', Name='$name'"

    xml_tag_lower=$(echo "$xml_tag" | tr '[:upper:]' '[:lower:]')

    # Extract all possible block starters from source.cfg
    block_starters=$(grep -E '^[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]+"[^"]*"' "$src_cfg" | sed 's/^[[:space:]]*//' | cut -d' ' -f1)

    best_match=""
    for starter in $block_starters; do
        starter_lower=$(echo "$starter" | tr '[:upper:]' '[:lower:]')

        xml_tag_no_hyphen=$(echo "$xml_tag_lower" | tr -d '-')
        starter_no_hyphen=$(echo "$starter_lower" | tr -d '-')

        if [[ "$xml_tag_no_hyphen" == "$starter_no_hyphen" ]]; then
            best_match="$starter"
            break
        fi
    done

    # --- Step 1: Normal matching (TOP-LEVEL ONLY) ---
    if [[ -n "$best_match" ]]; then
        echo "   Match found: '$best_match' for tag '$xml_tag'"
        local start_pattern="^${best_match}[[:space:]]*\"${name}\""   
        if grep -qE "$start_pattern" "$src_cfg"; then
            echo "    → Copying block for name '$name'..."
            awk "/$start_pattern/,/^[[:space:]]*exit[[:space:]]*$/" "$src_cfg" >> "$dest_cfg"
            echo "" >> "$dest_cfg"
            return
        fi
    fi

    # --- Step 2: Dictionary Fallback (TOP-LEVEL ONLY) ---
    mapped_tag=$(tag_map "$xml_tag")
    if [[ -n "$mapped_tag" ]]; then
        echo "   Trying dictionary mapping: '$xml_tag' → '$mapped_tag'"
        local start_pattern="^${mapped_tag}[[:space:]]*\"${name}\""   
        if grep -qE "$start_pattern" "$src_cfg"; then
            echo "     Match found via dictionary for '$mapped_tag'"
            awk "/$start_pattern/,/^[[:space:]]*exit[[:space:]]*$/" "$src_cfg" >> "$dest_cfg"
            echo "" >> "$dest_cfg"
            return
        else
            echo "    No block found for mapped tag '$mapped_tag'"
        fi
    fi

    # --- Step 3: Ask user for manual tag input (TOP-LEVEL ONLY) ---
    read -p " No match found for XML tag '$xml_tag'. Enter alternate tag (or press Enter to skip): " user_tag </dev/tty

    if [[ -n "$user_tag" ]]; then
        local start_pattern="^${user_tag}[[:space:]]*\"${name}\""     
        if grep -qE "$start_pattern" "$src_cfg"; then
            echo "     Match found via user input '$user_tag'"
            awk "/$start_pattern/,/^[[:space:]]*exit[[:space:]]*$/" "$src_cfg" >> "$dest_cfg"
            echo "" >> "$dest_cfg"
            return
        else
            echo "    No block found for user-provided tag '$user_tag'"
        fi
    fi

    echo "     No match found for XML tag '$xml_tag'"
}

# --- Step 6: Prepare destination file ---
if [[ ! -f "$dest_cfg" ]]; then
    echo " Creating new destination file at: $dest_cfg"
    touch "$dest_cfg"
else
    echo " Appending to existing destination file: $dest_cfg"
fi

# --- Step 7: Process each main parent tag ---
while IFS='|' read -r tag name; do
    copy_block "$tag" "$name"
    echo
done < <(echo "$tags_with_names")

