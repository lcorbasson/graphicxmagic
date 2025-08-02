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
	echo '\documentclass[landscape]{book}'
	echo '\usepackage{calc}'
	echo '\usepackage[hoffset=-1in,showframe]{geometry}'
	echo '\usepackage{layout}'
	echo '\usepackage{graphicx}'
	echo '\usepackage{tabularray}'
	echo '\UseTblrLibrary{amsmath,booktabs,counter,diagbox,nameref,siunitx,varwidth,zref}'
	echo '\newlength{\imgsize}'
	echo '\setlength{\imgsize}{\textwidth/'"${#converters[@]}"'/'"${#reference_images[@]}"'/10*8}'
	echo '\newlength{\firstcolumnwd}'
	echo '\setlength{\firstcolumnwd}{\textwidth-'"${#converters[@]}"'*'"${#reference_images[@]}"'*\imgsize}'
	echo '\setkeys{Gin}{keepaspectratio,height=\imgsize,width=\imgsize}'
	echo '\newcommand{\includegraphicsifexists}[1]{\IfFileExists{#1}{\includegraphics{#1}}{N/A}}'
	echo '\renewcommand{\familydefault}{\sfdefault}'
	echo '\begin{document}'
	echo '\section{Tests}'
	echo '\input{'"$globaltexfile.in"'}'
) | tee -a "$globaltexfile"

for test_name in "${tests[@]}"; do
	echo '\subsection{\texttt{'"$test_name"'}}'
	echo '\begin{center}'
	echo '\begin{longtblr}['
	echo '  caption=Results of the \texttt{includegraphics} tests'
	echo ']{'
	echo '  vspan=even, hspan=minimal,'
	echo '  columns={wd=\imgsize, c},'
	echo '  column{1}={wd=\firstcolumnwd, l},'
#	echo '  colspec={Q[l]' \
#		&& echo -n '    ' \
#		&& printf "$(printf "Q[c] %.0s" $(seq 1 "${#reference_images[@]}"))%.0s" $(seq 1 "${#converters[@]}") \
#		&& echo \
#		&& echo '  },'
#	echo '  hlines={1,3,Z}{solid},'
#	echo '  vlines={1,every['"${#reference_images[@]}"']{2}{-1}}{solid},'
#	echo '  vlines={1' \
#		&& echo -n '    ' \
#		&& for c in $(seq 0 "$((${#converters[@]}-1))"); do
#			echo -n ",$((2+c*${#reference_images[@]}))"
#		done \
#		&& echo \
#		&& echo '  }{solid},'
	echo '  rowhead=2,'
	echo '  cell{1}{every['"${#reference_images[@]}"']{2}{-1}}={c='"${#reference_images[@]}"'}{c},'
#	for c in $(seq 1 "${#converters[@]}"); do
#		echo '  cell{1}{'"$((1+c*${#reference_images[@]}))"'}={c='"${#reference_images[@]}"'}{c},'
#	done
	echo '  cell{1}{2-Z}={font=\ttfamily\bfseries},'
	echo '  row{2}={font=\scriptsize\ttfamily},'
	echo '  cell{2-Z}{1}={font=\ttfamily},'
	echo '}'
	echo -n 'Format & '
	for converter_idx in "${!converters[@]}"; do
		echo -n ''"${converters[$converter_idx]}"' & '
		if [ "$converter_idx" -lt "$((${#converters[@]} - 1))" ]; then
			echo -n ' & '
		else
			echo ' \\'
		fi
	done
	echo -n ' & '
	for converter_idx in "${!converters[@]}"; do
		for reference_image_idx in "${!reference_images[@]}"; do
			echo -n ''"${reference_images[$reference_image_idx]}"''
			if [ "$converter_idx" -lt "$((${#converters[@]} - 1))" ] || [ "$reference_image_idx" -lt "$((${#reference_images[@]} - 1))" ]; then
				echo -n ' & '
			else
				echo ' \\'
			fi
		done
	done

	for ext in "${exts[@]}"; do
		echo -n ''"$ext"' & '
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
				fi
			done
		done
	done
	echo '\end{longtblr}'
	echo '\end{center}'
	echo
done | tee -a "$globaltexfile.in"

(
	echo '\layout'
	echo '\end{document}'
) | tee -a "$globaltexfile"

for test_name in "${tests[@]}"; do
	for texfile in "test_$test_name-"*".tex"; do
		lualatex -halt-on-error -shell-escape "$texfile"
	done
done

lualatex -halt-on-error "$globaltexfile"

popd > /dev/null

