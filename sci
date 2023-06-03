#!/bin/sh

help() {
	echo "help"
}

check_dependencies() {
	# test for install dependencies
	test -z "$(
		test "$(which bibtool)" && test "$(which bibtex-tidy)" && test "$(which curl)" && test "$(which vipe)" && echo true
	)" && echo "$(basename "$0") requires curl, bibtool and bibtex-tidy to be installed and in your path." >&2 && return 1

	return 0
}

check() {
	if [ "$2" = "1" ]; then
		printf "%s [Y/n] " "$1" >&2
		read -r ans

		[ "$ans" = "" ] || [ "$ans" = "Y" ] || [ "$ans" = "y" ]
	else
		printf "%s [y/N] " "$1" >&2
		read -r ans

		! [ "$ans" = "" ] || [ "$ans" = "N" ] || [ "$ans" = "n" ]
	fi
}

find_bib_file() {
	path="."

	while [ "$path" != / ] && [ -z "$bib_file" ]; do
		bib_file="$(find "$path" -maxdepth 1 -mindepth 1 -name "*.bib" -print -quit)"
		path="$(readlink -f "$path"/..)"
	done

	echo "$bib_file"

}

pdf_to_doi() {
    pdftotext -q -l 2 "$1" - | sed 's/Digital Object Identifier[:]*/doi:/g' | grep -m1 -A1 'DOI\|doi' | sed 's/[\[\]]/ /g' | sed 's/dx\.doi\.org\// doi:/g' | sed 's/doi>/ doi:/g' | sed 's/</ /g' | sed -n -e 's_.*[Dd][Oo][Ii][:) ] *\([[:digit:]][[:digit:]]*.[[:alnum:])(.-]*/[[:alnum:])(.-][[:alnum:]):(.-]*[[:alnum:]-]\).*_\1_p'
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
    bib_file="$1"
    bib_info="$2"
    bib_id="$3"

	if ! grep -q "$bib_id" "$bib_file"; then
		echo "Adding entry to $bib_file"

		if ! printf "%s" "$bib_info" | grep -qP "abstract[ ]+"; then
			url="$(printf "%s" "$bib_info" | grep -Po 'http[a-zA-Z:/.0-9-=?]+')"
			abstract="$(echo "# Copy the abstract from $url below" | vipe | grep -v "^#")"
			[ -n "$abstract" ] && bib_info="$(printf "%s" "$bib_info" | bibtool -- "add.field{abstract='$abstract'}")"
		fi

		printf '%s' "$bib_info" >>"$bib_file"

		echo "Formatting $bib_file"
		format_bib -m "$bib_file"
	fi
}

download_from_scihub() {
    bib="$1"
    pdf_path="$2"

	doi="$(python -c "import bibtexparser; entry = bibtexparser.bparser.BibTexParser(common_strings=True, ignore_nonstandard_types=False).parse(\"\"\"$bib\"\"\").entries[0]; print(entry.get('doi', ''))")"
	if [ -n "$doi" ]; then
        scihub_link="$(curl -s "https://sci-hub.st/$doi" | grep "<button onclick" | awk 'BEGIN {FS="\""} {print $2}' | sed "s/location.href='//g;s/'//g;s/?download=true//g")"

	    if [ "${scihub_link#*"//"}" != "$scihub_link" ]; then
            pdf_url="https:$scihub_link"
        else
		    pdf_url="https://sci-hub.st$scihub_link"
        fi
	else
		isbn="$(python -c "import bibtexparser; entry = bibtexparser.bparser.BibTexParser(common_strings=True, ignore_nonstandard_types=False).parse(\"\"\"$bib\"\"\").entries[0]; print(entry.get('isbn', ''))")"
		pdf_url="$(curl -Ls "https://sci-hub.st/$isbn" | grep ">GET<" | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")"
	fi

	[ -n "$pdf_url" ] && curl -Ls "$pdf_url" >"$pdf_path"
}

download_pdf() {
    pdf_url="$1"
    pdf_path="$2"
    bib="$3"

	echo "Downloading PDF from $pdf_url to $pdf_path"

	if [ -n "$pdf_url" ] && [ "$(file -b --mime-type "$pdf_path")" != "application/pdf" ]; then
        curl -Ls "$pdf_url" > "$pdf_path"
	fi

	if [ -n "$pdf_url" ] && [ "$(file -b --mime-type "$pdf_path")" != "application/pdf" ]; then
        [ -e "$pdf_path" ] && rm "$pdf_path"
		download_path="$(filedl "$pdf_url" "$bibliography_dir")"
		[ -n "$download_path" ] && mv "$download_path" "$pdf_path"
	fi

	if [ "$(file -b --mime-type "$pdf_path")" != "application/pdf" ]; then
		echo "Download failed"
		[ -e "$pdf_path" ] && rm "$pdf_path"

        check "Download from Sci-Hub?" 1 && download_from_scihub "$bib" "$pdf_path"
	fi
}

add_from_id() {
	id="$1"
    file="$2"

    bib_file="$(find_bib_file)"
    [ -z "$bib_file" ] && echo "" >library.bib && bib_file="library.bib"

    bibliography_dir="$(dirname "$bib_file")/bibliography"
    mkdir -p "$bibliography_dir"

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

    add_to_library "$bib_file" "$bib_info" "$bib_id"

    pdf_path="$bibliography_dir/$pdf_name.pdf"

    if [ -n "$file" ]; then
        mv "$file" "$pdf_path"
    else
        download_pdf "$pdf_url" "$pdf_path" "$bib_info"
    fi
}

check_dependencies || exit 1

case "$1" in
help)
    help
    ;;
init)
	touch library.bib
	mkdir bibliography
	;;
add)
	shift 1

    if [ -f "$1" ]; then
        doi="$(pdf_to_doi "$1")"

        if [ -n "$doi" ]; then
            add_from_id "$doi" "$1"
        else
            echo "Could not find DOI from $1"
        fi
    else
	    add_from_id "$1"
    fi
	;;
search)
    shift 1

    search="$(echo "$@" | sed 's/ /%20/g')"
    doi_results="$(curl -s "https://api.crossref.org/works?query.bibliographic=%22$search%22&rows=4" | jq -r '.message.items[] | "Paper: [\(.author[0].family)] \(.title[0]) (\(."published-print"."date-parts"[0][0])){\(.DOI)}"')"
    isbn_results="$(curl -s "https://www.googleapis.com/books/v1/volumes?q=intitle:$search&maxResults=5" | jq -r '.items[].volumeInfo | "Book: [\(.authors[0])] \(.title) (\(.publishedDate)){\(.industryIdentifiers[0].identifier)}"')"

    all_results="$(echo "$doi_results"; echo "$isbn_results")"

    fzf_result="$(echo "$all_results" | sed -E 's|\{.+\}$||g' | fzf)"
    [ -z "$fzf_result" ] && exit 0
    fzf_result="$(echo "$fzf_result" | sed 's|\[|\\\[|g' | sed 's|\]|\\\]|g')"

    id="$(echo "$all_results" | grep "$fzf_result" | sed "s|$fzf_result||g" | sed -E 's|^\{||g' | sed -E 's|\}$||g')"

    [ -n "$id" ] && getbib "$id"
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
    cd /usr/share/sci && sudo git pull
	;;
esac
