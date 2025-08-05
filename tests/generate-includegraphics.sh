#!/bin/bash
set -Ee -o pipefail

TESTSDIR="$(dirname "$0")"
pushd "$TESTSDIR" > /dev/null

readarray -t rasterconverters < <(
	sed -n \
		-e 's:\\GPT@space *: :g' \
		-e 's:.*\\gdef\\@gfxwand@rasterconverter{\([^}]*\)}.*:\1:p' \
		graphicxwand.sty \
		| sort -u
)
readarray -t vectorconverters < <(
	sed -n \
		-e 's:\\GPT@space *: :g' \
		-e 's:.*\\gdef\\@gfxwand@vectorconverter{\([^}]*\)}.*:\1:p' \
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
convertersmax="$(for converter in "${rasterconverters[@]}" "${vectorconverters[@]}"; do echo "$converter"; done | sort -u | wc -l)"

globaltexfile="tests.tex"
tests=(includegraphics)

echo "Tests:            ${tests[@]}"
echo "Raster converters:       ${rasterconverters[@]}"
echo "Vector converters:       ${vectorconverters[@]}"
echo "Reference images: ${reference_images[@]}"
echo "Extensions:       ${exts[@]}"


find . -maxdepth 1 -type l -name "test_*.tex" -exec rm {} \;

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
	echo '\setlength{\imgsize}{\textwidth/'"$convertersmax"'/'"${#reference_images[@]}"'/10*9}'
	echo '\newlength{\firstcolumnwd}'
	echo '\setlength{\firstcolumnwd}{\textwidth/10*1}'
	echo '\setkeys{Gin}{keepaspectratio,height=\imgsize,width=\imgsize}'
	echo '\newcommand{\includegraphicsifexists}[1]{\IfFileExists{#1}{\parbox{\imgsize}{\includegraphics{#1}}}{N/A}}'
	echo '\usepackage[sfdefault]{atkinson}'
	echo '\begin{document}'
	echo '\chapter{Tests}'
	echo '\input{'"$globaltexfile.in"'}'
) | tee -a "$globaltexfile"

insert_test_results() {
	local test_name="$1"
	shift
	local image_type="$1"
	shift
	local converters=("$@")

	echo '\section{\texttt{'"$test_name"'} for \emph{'"$image_type"'} images}'
	echo '\begin{center}'
	echo '\begin{longtblr}['
	echo '  caption=Results of the \texttt{includegraphics} tests'
	echo ']{'
	echo '  vspan=even, hspan=minimal,'
	echo '  colsep=0pt, rowsep=0pt,',
	echo '  columns={wd=\imgsize, c},'
	echo '  column{1}={wd=\firstcolumnwd, l},'
	echo '  rows={ht=\imgsize, m},'
	echo '  rowhead=2,'
	echo '  cell{1}{every['"${#reference_images[@]}"']{2}{-1}}={c='"${#reference_images[@]}"'}{c},'
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
				if [ "$image_type" == "raster-lossless" ]; then
					texfile="test_$test_name-$reference_image-$ext-${converter// /}--true.tex"
				elif [ "$image_type" == "raster-lossy" ]; then
					texfile="test_$test_name-$reference_image-$ext-${converter// /}--false.tex"
				elif [ "$image_type" == "vector" ]; then
					texfile="test_$test_name-$reference_image-$ext--${converter// /}.tex"
				else
					echo "Image type '$image_type' unknown" >&2
					exit 1
				fi
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
}

for test_name in "${tests[@]}"; do
	insert_test_results "$test_name" "raster-lossless" "${rasterconverters[@]}"
	insert_test_results "$test_name" "raster-lossy" "${rasterconverters[@]}"
	insert_test_results "$test_name" "vector" "${vectorconverters[@]}"
done | tee -a "$globaltexfile.in"

(
	echo '\layout'
	echo '\end{document}'
) | tee -a "$globaltexfile"

set +e
for test_name in "${tests[@]}"; do
	for texfile in "test_$test_name-"*".tex"; do
		lualatex -halt-on-error -shell-escape "$texfile"
	done
done

lualatex -halt-on-error "$globaltexfile"
set -e

popd > /dev/null

