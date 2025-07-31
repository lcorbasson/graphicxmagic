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

globaltexfile="tests.tex.in"
tests=(includegraphics)

for test_name in "${tests[@]}"; do
	echo '\subsection{\texttt{'"$test_name"'}}'
	find inputs/ -maxdepth 1 -type l | sort | while read reference_image; do
		reference_image_name="$(basename "${reference_image%.*}")"
		echo '\subsubsection{\texttt{'"$reference_image_name"'}}'
		find inputs/ -maxdepth 1 -type f -name "$reference_image_name.*" | sort | while read image; do
			ext="${image##*.}"
			for converter in "${converters[@]}"; do
				texfile="test_$test_name-$reference_image_name-$ext-${converter// /}.tex"
				ln -sf "test_$test_name.tex" "$texfile"
				echo '\IfFileExists{'"${texfile%.tex}.pdf"'}{\includegraphics{'"${texfile%.tex}.pdf"'}}{'"${texfile%.tex}.pdf"' not found}'
			done
		done
	done
done | tee "$globaltexfile"

for test_name in "${tests[@]}"; do
	for texfile in "test_$test_name-"*".tex"; do
		lualatex -halt-on-error -shell-escape "$texfile"
	done
done

popd > /dev/null

