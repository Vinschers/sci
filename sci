#!/bin/sh

extract_identifier() {
	ID="$(echo "$@" | grep -Po "(10\.[0-9a-zA-Z]+\/(?:(?![\"&\'])\S)+)\b")"
	[ -n "$ID" ] && echo "doi $ID" && return 0

	ID="$(echo "$@" | grep -Po "^(?=(?:\D*\d){10}(?:(?:\D*\d){3})?$)[\d-]+\$")"
	[ -n "$ID" ] && echo "isbn $(echo "$ID" | sed -e "s/-//g")" && return 0

	echo "N $*"
}

[ -z "$1" ] && sci_open && exit 0

BIB_FILE="$(find . -maxdepth 1 -name "*.bib" -print -quit)"
[ -z "$BIB_FILE" ] && BIB_FILE="$(find_up . -name "*.bib" -print -quit)"

[ -z "$ACADEMIC_DIRECTORY" ] && export ACADEMIC_DIRECTORY="$HOME"

[ -n "$BIB_FILE" ] && [ "$(dirname "$(realpath "$BIB_FILE")")" = "$(realpath "$ACADEMIC_DIRECTORY/bibliography")" ] && BIB_FILE=""

case "$1" in
init)
	touch library.bib
	mkdir bibliography
	;;
add)
	shift

	if [ -z "$1" ]; then
		ID="$(dmenu -p "Identifier: " </dev/null)"
	else
		ID="$1"
	fi

	[ -f "$BIB_FILE" ] && BIB_STR="$(cat "$BIB_FILE")"

	TYPE_ID="$(extract_identifier "$ID")"

	if sci_add $TYPE_ID "$BIB_FILE" && [ -f "$BIB_FILE" ]; then
		sci_update "$BIB_FILE"
	fi

	;;

open)
	shift

	ID="$(extract_identifier "$1" | cut -d' ' -f 2-)"
	sci_open "$ID" "$BIB_FILE"
	;;

update)
	[ -f "$BIB_FILE" ] && sci_update "$BIB_FILE"
	;;

uninstall)
    [ -d "/usr/share/sci" ] && sudo rm -rf /usr/share/sci
    [ -f "/usr/local/bin/sci" ] && sudo rm /usr/local/bin/sci
    printf "Remove %s [y/N]?" "$ACADEMIC_DIRECTORY"
    read -r rm_academic_directory
    if [ "$rm_academic_directory" = "y" ] || [ "$rm_academic_directory" = "Y" ]; then
        sudo rm -rf "$ACADEMIC_DIRECTORY"
    fi
    ;;

*)
	TYPE_ID="$(extract_identifier "$1")"

	if sci_add $TYPE_ID "$BIB_FILE" && [ -f "$BIB_FILE" ]; then
		sci_update "$BIB_FILE"
	elif [ -f "$BIB_FILE" ]; then
		sci_open "$(echo "$TYPE_ID" | cut -d' ' -f 2-)" "$BIB_FILE"
	fi
	;;
esac
