#!/bin/bash
INPUTSDIR="$(dirname "$0")"
pushd "$INPUTSDIR" > /dev/null

find . -maxdepth 1 -type l | while read reference_image; do
	ext="${reference_image##*.}"
	case "$ext" in
		"eps" | "pdf" | "ps")
		"svg" | "svgz")
			# Vector images
			echo "$reference_image --(soffice --draw)--> ..."
			while IFS=',' read format; do
				if [ "$format" != "$ext" ]; then
					converted_image="${reference_image%.*}.$format"
					soffice --headless --convert-to "$format" "$reference_image" \
						|| soffice --headless --convert-to "$format:draw_${format}_Export" "$reference_image"
					mv "$reference_image.$format" "$converted_image"
					if [ -f "$converted_image" ] && [ ! -s "$converted_image" ]; then
						rm "$converted_image"
					fi
				fi
			done < "formats-soffice_draw.csv"
			echo "$reference_image --(inkscape)--> ..."
			while IFS=',' read format; do
				if [ "$format" != "$ext" ]; then
					converted_image="${reference_image%.*}.$format"
					inkscape --export-type="$format" --export-filename="$converted_image" "$reference_image"
					if [ -f "$converted_image" ] && [ ! -s "$converted_image" ]; then
						rm "$converted_image"
					fi
				fi
			done < "formats-inkscape.csv"
			# TODO: use gs/ps2pdf/... for eps/pdf/ps?
			;;
		"png")
			# Raster images
			echo "$reference_image --(vips)--> ..."
			while IFS=',' read format; do
				if [ "$format" != "$ext" ]; then
					converted_image="${reference_image%.*}.$format"
					vips copy "$reference_image" "$converted_image"
					if [ -f "$converted_image" ] && [ ! -s "$converted_image" ]; then
						rm "$converted_image"
					fi
				fi
			done < "formats-vips.csv"
			for magick_converter in 'gm' 'magick'; do
				echo "$reference_image --($magick_converter)--> ..."
				while IFS=',' read format; do
					if [ "$format" != "$ext" ]; then
						converted_image="${reference_image%.*}.$format"
						"$magick_converter" convert "$reference_image" "$converted_image"
						if [ -f "$converted_image" ] && [ ! -s "$converted_image" ]; then
							rm "$converted_image"
						fi
					fi
				done < "formats-$magick_converter.csv"
				echo
			done
			;;
		*)
			echo "$reference_image: '$ext' format unknown, skipping" >&2
			;;
	esac
done

popd > /dev/null

