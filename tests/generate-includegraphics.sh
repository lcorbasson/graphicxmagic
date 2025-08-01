#!/bin/bash
TESTSDIR="$(dirname "$0")"
pushd "$TESTSDIR" > /dev/null

readarray -t converters < <(
	sed -n \
		-e 's:\\GPT@space *: :g' \
		-e 's:.*\\gdef\\@gfxwand@converter{\([^}]*\)}.*:\1:p' \
		graphicxwand.sty \
		| sort -u
)
readarray -t reference_images < <(
	find inputs/ -maxdepth 1 -type l \
		| sed -e 's:.*/\([^/]*\)\..*$:\1:' \
		| sort
)
readarray -t exts < <(
	for reference_image in "${reference_images[@]}"; do
		find inputs/ -maxdepth 1 \( -type f -o -type l \) -name "$reference_image.*"
	done \
		| sed -e 's:^.*\.::' \
		| sort
)

globaltexfile="tests.tex"
tests=(includegraphics)

echo "Tests:            ${tests[@]}"
echo "Converters:       ${converters[@]}"
echo "Reference images: ${reference_images[@]}"
echo "Extensions:       ${exts[@]}"


echo -n > "$globaltexfile"
echo -n > "$globaltexfile.in"

(
	echo '\documentclass[landscape]{article}'
	echo '\usepackage{calc}'
	echo '\usepackage{graphicx}'
	echo '\usepackage{longtable}'
	echo '\newlength{\imgsize}'
	echo '\setlength{\imgsize}{\textwidth/'"${#converters[@]}"'/'"${#reference_images[@]}"'/10*8}'
	echo '\setkeys{Gin}{keepaspectratio,height=\imgsize,width=\imgsize}'
	echo '\newcommand{\includegraphicsifexists}[1]{\IfFileExists{#1}{\includegraphics{#1}}{N/A}}'
	echo '\renewcommand{\familydefault}{\sfdefault}'
	echo '\begin{document}'
	echo '\input{'"$globaltexfile.in"'}'
) | tee -a "$globaltexfile"

for test_name in "${tests[@]}"; do
	echo '\subsection{\texttt{'"$test_name"'}}'
	echo -n '\begin{longtable}{||l||' \
		&& printf "$(printf "c|%.0s" $(seq 1 "${#reference_images[@]}"))|%.0s" $(seq 1 "${#converters[@]}") \
		&& echo '}'
	echo '\hline'
	echo -n ' & '
	for converter_idx in "${!converters[@]}"; do
		echo -n '\multicolumn{'"${#reference_images[@]}"'}{'
		echo -n '|c||}{\texttt{'"${converters[$converter_idx]}"'}}'
		if [ "$converter_idx" -lt "$((${#converters[@]} - 1))" ]; then
			echo -n ' & '
		else
			echo ' \\'
			echo '\hline'
		fi
	done
	echo -n 'Format & '
	for converter_idx in "${!converters[@]}"; do
		for reference_image_idx in "${!reference_images[@]}"; do
			echo -n '\texttt{'"${reference_images[$reference_image_idx]}"'}'
			if [ "$converter_idx" -lt "$((${#converters[@]} - 1))" ] || [ "$reference_image_idx" -lt "$((${#reference_images[@]} - 1))" ]; then
				echo -n ' & '
			else
				echo ' \\'
				echo '\hline'
			fi
		done
	done
	echo '\endhead'

	for ext in "${exts[@]}"; do
		echo -n '\texttt{'"$ext"'} & '
		for converter_idx in "${!converters[@]}"; do
			converter="${converters[$converter_idx]}"
			for reference_image_idx in "${!reference_images[@]}"; do
				reference_image="${reference_images[$reference_image_idx]}"
				texfile="test_$test_name-$reference_image-$ext-${converter// /}.tex"
				ln -sf "test_$test_name.tex" "$texfile"
				texfile_tex="${texfile//_/\\_}"
				echo -n '\includegraphicsifexists{'"${texfile_tex%.tex}.pdf"'}'
				if [ "$converter_idx" -lt "$((${#converters[@]} - 1))" ] || [ "$reference_image_idx" -lt "$((${#reference_images[@]} - 1))" ]; then
					echo -n ' & '
				else
					echo ' \\'
					echo '\hline'
				fi
			done
		done
	done
	echo '\end{longtable}'
	echo
done | tee -a "$globaltexfile.in"

(
	echo '\end{document}'
) | tee -a "$globaltexfile"


for test_name in "${tests[@]}"; do
	for texfile in "test_$test_name-"*".tex"; do
		lualatex -halt-on-error -shell-escape "$texfile"
	done
done

lualatex -halt-on-error "$globaltexfile"

popd > /dev/null

