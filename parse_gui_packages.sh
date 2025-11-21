#!/bin/bash

# parse_packages <option> <file>
# - case-insensitive option matching
# - global packages returned only when the option exists in the file
# - supports full-line and inline '#' comments
parse_packages() {
    local option="$1"
    local file="$2"

    if [[ -z "$option" || -z "$file" ]]; then
        return 0
    fi
    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # lowercase requested option for case-insensitive comparison
    local opt_lc
    opt_lc="$(printf '%s' "$option" | tr '[:upper:]' '[:lower:]')"

    # ---------- First pass: detect whether the option exists (case-insensitive) ----------
    local found=false
    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        # trim
        line="${raw_line#"${raw_line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue

        # skip full-line comments
        [[ "$line" =~ ^# ]] && continue

        # strip inline comments for header detection
        header="${line%%#*}"
        header="${header%"${header##*[![:space:]]}"}"

        if [[ "$header" =~ ^\[option:([[:alnum:]_-]+)\]$ ]]; then
            local hdr="${BASH_REMATCH[1]}"
            local hdr_lc
            hdr_lc="$(printf '%s' "$hdr" | tr '[:upper:]' '[:lower:]')"
            if [[ "$hdr_lc" == "$opt_lc" ]]; then
                found=true
                break
            fi
        fi
    done < "$file"

    # If the option wasn't found anywhere
    if ! $found; then
        return 0
    fi

    # ---------- Second pass: collect global packages (before first option block)
    # and collect packages for the matching option only ----------
    local global_packages=""
    local option_packages=""
    local current_option=""
    local seen_first_option=false
    local in_matching_section=false

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        # trim
        line="${raw_line#"${raw_line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue

        # skip full-line comments
        [[ "$line" =~ ^# ]] && continue

        # remove inline comment for actual package parsing
        content="${line%%#*}"
        content="${content%"${content##*[![:space:]]}"}"
        [[ -z "$content" ]] && continue

        # option header?
        if [[ "$content" =~ ^\[option:([[:alnum:]_-]+)\]$ ]]; then
            current_option="${BASH_REMATCH[1]}"
            seen_first_option=true

            # set in_matching_section true only if this header matches requested option
            local cur_lc
            cur_lc="$(printf '%s' "$current_option" | tr '[:upper:]' '[:lower:]')"
            if [[ "$cur_lc" == "$opt_lc" ]]; then
                in_matching_section=true
            else
                in_matching_section=false
            fi
            continue
        fi

        # collect
        if ! $seen_first_option; then
            # still in global zone
            global_packages+="$content "
        else
            # inside option blocks; collect only if currently in matching section
            if $in_matching_section; then
                option_packages+="$content "
            fi
        fi
    done < "$file"

    # option FOUND output combined packages, return 1
    printf '%s %s\n' "$global_packages" "$option_packages"
    return 1
}

test_parse_packages() {
    # tests
    echo Testing...
    echo

    echo none
    echo ------------------
    parse_packages none packages_gui.txt
    echo ------------------
    echo

    echo non-existing
    echo ------------------
    parse_packages non-existing packages_gui.txt
    echo ------------------
    echo

    echo i3
    echo ------------------
    parse_packages i3 packages_gui.txt
    echo ------------------
    echo

    echo "SWay - wrong case (should still work)"
    echo ------------------
    parse_packages SWay packages_gui.txt
    echo ------------------
    echo

    echo "kdE - wrong case (should still work)"
    echo ------------------
    parse_packages kdE packages_gui.txt
    echo ------------------
    echo

    echo "openBox - wrong case (should still work)"
    echo ------------------
    parse_packages openBox packages_gui.txt
    echo ------------------
}

