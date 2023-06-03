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

format_bib() {
	bibtex-tidy --curly --numeric --months --space=4 --align=24 --sort=type,key --duplicates=key --no-escape --sort-fields=title,shorttitle,author,doi,isbn,year,month,day,journal,abstract,booktitle,location,on,publisher,address,series,volume,number,pages,issn,url,urldate,copyright,category,note,metadata --trailing-commas --encode-urls --remove-empty-fields --no-remove-dupe-fields --generate-keys="[auth:required:lower]_[year:required]_[veryshorttitle:lower][duplicateNumber]" --wrap=80 --quiet "$@"
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
		echo "$bib_title" | sed 's/{//g' | sed 's/}//g'
		;;
	*)
		echo "$bib_id"
		;;
	esac
}

add_to_library() {
    bib_info="$1"
    bib_id="$2"

	if ! grep -q "$bib_id" "$bib_file"; then
		echo "Adding entry to $bib_file"

		if ! printf "%s" "$bib_info" | grep -qP "abstract[ ]+"; then
			url="$(printf "%s" "$bib_info" | grep -Po 'http[a-zA-Z:/.0-9-=?]+')"
			abstract="$(echo "# Copy the abstract from $url below" | vipe | grep -v "^#")"
			[ -n "$abstract" ] && bib_info="$(printf "%s" "$bib_info" | bibtool -- "add.field{abstract='$abstract'}")"
		fi

		echo "$bib_info" >>"$bib_file"

		echo "Formatting $bib_file"
		format_bib -m "$bib_file"
	fi
}

download_from_scihub() {
    bib="$1"
    pdf_path="$2"

	doi="$(python -c "import bibtexparser; entry = bibtexparser.bparser.BibTexParser(common_strings=True, ignore_nonstandard_types=False).parse(\"\"\"$bib\"\"\").entries[0]; print(entry.get('doi', ''))")"
	if [ -n "$doi" ]; then
		pdf_url="https://sci-hub.st$(curl -s "https://sci-hub.st/$doi" | grep "<button onclick" | awk 'BEGIN {FS="\""} {print $2}' | sed "s/location.href='//g;s/'//g;s/?download=true//g")"
	else
		isbn="$(python -c "import bibtexparser; entry = bibtexparser.bparser.BibTexParser(common_strings=True, ignore_nonstandard_types=False).parse(\"\"\"$bib\"\"\").entries[0]; print(entry.get('isbn', ''))")"
		pdf_url="$(curl -Ls "https://sci-hub.st/$isbn" | grep ">GET<" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
	fi

	[ -n "$pdf_url" ] && curl -s "$pdf_url" >"$pdf_path"
}

download_pdf() {
    pdf_url="$1"
    pdf_path="$2"
    bib="$3"

	if [ -n "$pdf_url" ] && [ "$(file -b --mime-type "$pdf_path")" != "application/pdf" ]; then
		echo "Downloading PDF from $pdf_url to $pdf_path"
		download_path="$(filedl "$pdf_url" "$bibliography_dir")"
		[ -n "$download_path" ] && mv "$download_path" "$pdf_path"
	fi

	if [ "$(file -b --mime-type "$pdf_path")" != "application/pdf" ]; then
		echo "Download failed"
		[ -e "$pdf_path" ] && rm "$pdf_path"

		printf "Download from Sci-Hub? [Y/n] " >&2
		read -r ans
		if [ "$ans" = "" ] || [ "$ans" = "Y" ] || [ "$ans" = "y" ]; then
            download_from_scihub "$bib" "$pdf_path"
		fi
	fi
}

add_from_id() {
	id="$1"
	if [ -z "$id" ]; then
		echo "sci add requires an argument" && exit 1
	fi

	echo "Getting BibTeX metadata..."
	info="$(getbib "$id")"
	bib_info="$(printf "%s" "$info" | grep -v '^http' | format_bib -o)"
	pdf_url="$(printf "%s" "$info" | grep '^http')"

	id_pdf_name="$(get_pdf_name "$bib_info")"
	bib_id="$(echo "$id_pdf_name" | head -n 1)"
	pdf_name="$(echo "$id_pdf_name" | tail -n 1)"

    add_to_library "$bib_info" "$bib_id"
    download_pdf "$pdf_url" "$bibliography_dir/$pdf_name.pdf" "$bib_info"
}

bib_file="$(find_bib_file)"
[ -z "$bib_file" ] && echo "" >library.bib && bib_file="library.bib"

bibliography_dir="$(dirname "$bib_file")/bibliography"
mkdir -p "$bibliography_dir"

case "$1" in
init)
	touch library.bib
	mkdir bibliography
	;;
add)
	shift 1

	add_from_id "$1"
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
