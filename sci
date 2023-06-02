#!/bin/sh

help() {
	echo "help"
}

find_bib_file() {
	path="."

	while [ "$path" != / ] && [ -z "$bib_file" ]; do
		bib_file="$(find "$path" -maxdepth 1 -mindepth 1 -name "*.bib" -print -quit)"
		path="$(readlink -f "$path"/..)"
	done

	echo "$bib_file"

}

get_pdf_name() {
	bib="$1"

	bib_id_type="$(python -c "import bibtexparser; entry = bibtexparser.bparser.BibTexParser(common_strings=True, ignore_nonstandard_types=False).parse(\"\"\"$bib\"\"\").entries[-1]; print(entry['ID']); print(entry['ENTRYTYPE']); print(entry['title'])")"
	bib_id="$(echo "$bib_id_type" | sed '1q;d')"
	bib_type="$(echo "$bib_id_type" | sed '2q;d')"
	bib_title="$(echo "$bib_id_type" | sed '3q;d' | sed -e "s/\\\\//g" | sed -e "s/://g")"

	echo "$bib_id"

	case "$bib_type" in
	book)
		echo "$bib_title"
		;;
	*)
		echo "$bib_id"
		;;
	esac
}

extract_identifier() {
	ID="$(echo "$@" | grep -Po "(10\.[0-9a-zA-Z]+\/(?:(?![\"&\'])\S)+)\b")"
	[ -n "$ID" ] && echo "doi $ID" && return 0

	ID="$(echo "$@" | grep -Po "^(?=(?:\D*\d){10}(?:(?:\D*\d){3})?$)[\d-]+\$")"
	[ -n "$ID" ] && echo "isbn $(echo "$ID" | sed -e "s/-//g")" && return 0

	echo "N $*"
}

bib_file="$(find_bib_file)"
[ -z "$bib_file" ] && touch library.bib && bib_file="library.bib"

bibliography_dir="$(dirname "$bib_file")/bibliography"
mkdir -p "$bibliography_dir"

case "$1" in
init)
	touch library.bib
	mkdir bibliography
	;;
add)
	shift 1

	id="$1"
	if [ -z "$id" ]; then
		echo "sci add requires an argument" && exit 1
	fi

	grep -iqF "$id" "$bib_file" && echo "Entry already exists" && exit 0

	info="$(getbib "$id")"
	bib_info="$(echo "$info" | head -n -1)"
	pdf_url="$(echo "$info" | tail -n 1)"

	id_pdf_name="$(get_pdf_name "$bib_info")"
	bib_id="$(echo "$id_pdf_name" | head -n 1)"
	pdf_name="$(echo "$id_pdf_name" | tail -n 1)"

	if grep -qviF "$bib_id" "$bib_file"; then
		echo "$bib_info" >>"$bib_file"
		bibtool -i "$bib_file" -s -o "$bib_file"
		sed -i 's/@\([A-Z]\)/@\L\1/g' "$bib_file"
	fi

	pdf_path="$bibliography_dir/$pdf_name.pdf"

	if [ "$(file -b --mime-type "$pdf_path")" != "application/pdf" ]; then
		curl -Ls "$pdf_url" >"$bibliography_dir/$pdf_name.pdf"
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
	[ -d "$SCI_DIRECTORY" ] && sudo rm -rf "$SCI_DIRECTORY"
	[ -f "/usr/local/bin/sci" ] && sudo rm /usr/local/bin/sci
	printf "Remove %s [y/N]?" "$ACADEMIC_DIRECTORY"
	read -r rm_academic_directory
	if [ "$rm_academic_directory" = "y" ] || [ "$rm_academic_directory" = "Y" ]; then
		sudo rm -rf "$ACADEMIC_DIRECTORY"
	fi
	;;

update-git)
	[ -d "$SCI_DIRECTORY" ] && cd "$SCI_DIRECTORY" && sudo git pull
	;;
esac
