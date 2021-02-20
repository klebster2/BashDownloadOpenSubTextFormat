#!/bin/bash

# $1 xargs processes to use
cpu_processes=$1
lang=$2

set -e pipefail

echo "$cpu_processes" | grep -qE '^[0-9]+$' || ( echo "Bad CPU proc int supplied for \$1" && exit 1 )
[ ! -z "$lang" ] || ( echo "Bad path supplied for \$2" && exit 1 )

if [ ! -d "OpenSubtitles/xml/$lang" ]; then
    curl -SLo "$lang.zip" "https://opus.nlpl.eu/download.php?f=OpenSubtitles/v2018/xml/$lang.zip"
    unzip "$lang.zip"
    rm "$lang.zip"
else
    echo "OpenSubtitles/xml/$lang found... Skipping download"
fi

echo "**** Counting xml files..."

opensub_files=()
spinner=( "-" "\\" "|" "/" )
dots=( ".  " ".. " "..." )

while IFS=  read -r -d $'\0'; do
    opensub_files+=("$REPLY:$((count % cpu_processes))")
    ((count+=1))
    newsec=$(printf %.0f "$(( `date +%1N` * 5 ))")
    if ! [[ "$newsec" -eq "$prevsec" ]];
        then
        icon_count=$(( $newsec % 4 ));
        printf "\rCounting xml files${dots[$(( $icon_count % 4 ))]} ${spinner[$(( $icon_count % 4 ))]} found $count"
    fi
    prevsec=$(printf %.0f "$(( `date +%1N` * 5 ))")

done < <(find "OpenSubtitles/xml/$lang" -iname "*.xml" -print0)
printf "\rCounting xml files... found $count.  \n"

group_size=$(( $count / $cpu_processes ))

echo "**** Now splitting into $cpu_processes groups of <= $(( $count / $cpu_processes ))"

[ -d "tmp" ] && rm -r "tmp"
mkdir "tmp"

subtitle_extractor() {
    # append file to process file
    [ ! -d "tmp" ] && mkdir "tmp"
    for file_proc; do
        file=${file_proc/:*/}
        proc=${file_proc/*:/}
        echo "put $file in ./tmp/$proc"
        xpath -q -e "//s//w[not(@alternative)]/text()" "$file" >> "./tmp/$proc"
    done
}

printf "%s\n" "${opensub_files[@]}" | \
    xargs -P "$cpu_processes" -I{} \
    bash -c "$( declare -f subtitle_extractor); subtitle_extractor {}"

