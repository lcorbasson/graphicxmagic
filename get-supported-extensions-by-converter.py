#!/usr/bin/env python3

import csv
from io import StringIO
from PIL import Image
import pyvips
import subprocess


supported_extensions = dict()

supported_extensions['PIL'] = {file_ext.lstrip('.') for file_ext, file_format in Image.registered_extensions().items() if file_format in Image.OPEN}
supported_extensions['img2pdf'] = supported_extensions['PIL']

supported_extensions['vips'] = set(pyvips.base.get_suffixes())

def get_magick_supported_extensions(variant=None):
	magick_formats_list_command = ['convert', '-list', 'format']
	if variant is not None:
		magick_formats_list_command = [variant] + magick_formats_list_command

	magick_formats_list_to_tsv_command = [
		'sed', '-n', # Don't print non-matching lines
		# List header
		"-e", r'1s:^ *::', # Remove leading spaces
		"-e", r'1s:   *:\t:g', # Convert column separators to tabs
		"-e", r'1s:\t:\tNative blob support\t:', # Add the 'Native blob support' column (extracted from the 'Format' column)
		"-e", r'1p', # Print the TSV header
		# List contents
		"-e", r'2,$s:^ *\([A-Za-z0-9_-][A-Za-z0-9_-]*\)\(\*\|\)  *\([^ ]*\)  *\([r-][w-][-+]\)  *\([^ ][^ ]*\):\1\t\2\t\3\t\4\t\5:p', # Remove leading spaces and convert column separators to tabs
	]
	gm_formats_list_to_tsv_command = [
		'sed', '-n', # Don't print non-matching lines
		# List header
		"-e", r'1s:^ *::', # Remove leading spaces
		"-e", r'1s:  *:\t:g', # Convert column separators to tabs
		"-e", r'1p', # Print the TSV header
		# List contents
		"-e", r'2,$s:^ *\([A-Za-z0-9_-][A-Za-z0-9_-]*\)  *\([^ ]*\)  *\([r-][w-][-+]\)  *\([^ ][^ ]*\):\1\t\2\t\3\t\4:p', # Remove leading spaces and convert column separators to tabs
	]
	if variant == 'gm':
		magick_formats_list_to_tsv_command = gm_formats_list_to_tsv_command

	magick_formats_list_subprocess = subprocess.Popen(magick_formats_list_command, stdout=subprocess.PIPE)
	magick_formats_list_tsv = subprocess.check_output(magick_formats_list_to_tsv_command, stdin=magick_formats_list_subprocess.stdout)
	magick_formats_list_subprocess.wait()

	magick_supported_extensions = {row['Format'].lower() for row in csv.DictReader(StringIO(magick_formats_list_tsv.decode("utf-8"), newline=''), delimiter='\t')}
	return magick_supported_extensions

supported_extensions['convert'] = get_magick_supported_extensions()

magick_variants = [
	'magick',	# ImageMagick
	'gm',		# GraphicsMagick
]

for magick_variant in magick_variants:
	supported_extensions[magick_variant] = get_magick_supported_extensions(variant=magick_variant)

for converter in sorted(supported_extensions.keys()):
	print(converter)
#%% FIXME: remove extensions natively supported by graphicx
	sorted_exts = sorted(set(
		[ext for ext in sorted(supported_extensions[converter])]
		+ [ext.upper() for ext in sorted(supported_extensions[converter])]
		+ [ext.lower() for ext in sorted(supported_extensions[converter])]
		+ ['*']
	), key=str.casefold)
	namedefs = {
		output_format: [
			r'  \@namedef{Gin@rule@.' + ext + '}#1{{imagetopdf}{.' + output_format + '}{#1}}'
			for ext in sorted_exts
		]
		for output_format in ('xbb', 'pdf')
	}
	print(r'\if@gfxmagic@dvipdfmx')
	print('\n'.join(namedefs['xbb']))
	print(r'\else\if@gfxmagic@pdftex')
	print('\n'.join(namedefs['pdf']))
	print()

print()
print()
print("{")
for converter in sorted(supported_extensions.keys()):
	print(f"\t'{converter}':")
	print("\t\t{" + str(sorted(supported_extensions[converter])).strip('[]') + '},')
print("}")

