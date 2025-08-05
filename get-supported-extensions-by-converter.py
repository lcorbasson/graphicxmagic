#!/usr/bin/env python3

import csv
from io import StringIO
import os
from PIL import Image
try:
	import pyvips
except ModuleNotFoundError as e:
	pyvips = None
	print(e)
import subprocess
try:
	from unoserver import converter as unoconverter
	from unoserver.converter import prop2dict as unoprop2dict
except ModuleNotFoundError as e:
	unoconverter = None
	print(e)

os.chdir(os.path.dirname(os.path.abspath(__file__)))


supported_extensions = dict()

supported_extensions['PIL'] = {file_ext.lstrip('.') for file_ext, file_format in Image.registered_extensions().items() if file_format in Image.OPEN}
supported_extensions['img2pdf'] = supported_extensions['PIL']

if pyvips is not None:
	supported_extensions['vips'] = {ext.lstrip('.') for ext in pyvips.base.get_suffixes()}

def get_inkscape_supported_extensions():
# inkscape --export-type=unknown --export-filename=tiger.unknown tiger.svg 2>&1 > /dev/null | sed -n -e 's|.*Allowed values: \[\([^]]*\),*\].*|\1|p' | tr -d ' .' | tr ',' '\n'
	inkscape_formats_list_command = ['inkscape', '--export-type=unknown', '--export-filename=tiger.unknown', 'tests/inputs/tiger.svg'] # Generated an error message, listing available formats
	inkscape_formats_list_to_str_command = [
		'sed', '-n', # Don't print non-matching lines
		'-e', r's|.*Allowed values: \[\([^]]*\),*\].*|\1|p', # Get the list of available formats
	]
	inkscape_formats_list_subprocess = subprocess.Popen(inkscape_formats_list_command, stderr=subprocess.PIPE)
	inkscape_formats_list_str = subprocess.check_output(inkscape_formats_list_to_str_command, stdin=inkscape_formats_list_subprocess.stderr)
	inkscape_formats_list_subprocess.wait()

	inkscape_supported_extensions = {ext.lstrip('.') for ext in inkscape_formats_list_str.decode("utf-8").split(', ') if '\n' not in ext}
	return inkscape_supported_extensions

supported_extensions['inkscape'] = get_inkscape_supported_extensions()

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

def get_soffice_draw_supported_extensions():
# soffice --export-type=unknown --export-filename=tiger.unknown tiger.svg 2>&1 > /dev/null | sed -n -e 's|.*Allowed values: \[\([^]]*\),*\].*|\1|p' | tr -d ' .' | tr ',' '\n'
	server_command = ['unoserver']
	server_subprocess = subprocess.Popen(server_command)

	try:
		outs, errs = server_subprocess.communicate(timeout=30)
		# TODO: find a line with:
		# INFO:unoserver:Starting UnoConverter.
	except subprocess.TimeoutExpired as e:
		print(e)

	converter = unoconverter.UnoConverter()
	soffice_import_filters_list = converter.get_available_import_filters()
	soffice_types = converter.type_service.createSubSetEnumerationByProperties(tuple())
	soffice_types_list = []
	while soffice_types.hasMoreElements():
		soffice_types_list.append(unoprop2dict(soffice_types.nextElement()))

	soffice_import_filters_list = [{k: v for k, v in soffice_import_filter.items() if k != 'UINames'} for soffice_import_filter in soffice_import_filters_list]
	soffice_types_list = [{k: v for k, v in soffice_type.items() if k != 'UINames'} for soffice_type in soffice_types_list]

	soffice_types_and_filters_list = [
		{**soffice_import_filter, **soffice_type}
			for soffice_import_filter in soffice_import_filters_list
				for soffice_type in soffice_types_list
					if soffice_import_filter['Name'] == soffice_type['PreferredFilter']
	]
	soffice_draw_types_and_filters_list = [
		t for t in soffice_types_and_filters_list
			if t['DocumentService'] == 'com.sun.star.drawing.DrawingDocument'
	]

	soffice_draw_supported_extensions = set()
	for soffice_type in soffice_draw_types_and_filters_list:
		soffice_draw_supported_extensions.update(ext.lower() for ext in soffice_type['Extensions'] if ext != '*')

	server_subprocess.terminate()

	return soffice_draw_supported_extensions

supported_extensions['soffice_draw'] = get_soffice_draw_supported_extensions()

for converter in sorted(supported_extensions.keys()):
	print(converter)
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
	print(r'\if@gfxwand@dvipdfmx')
	print('\n'.join(namedefs['xbb']))
	print(r'\else\if@gfxwand@pdftex')
	print('\n'.join(namedefs['pdf']))
	print()

print()
print()
print("{")
for converter in sorted(supported_extensions.keys()):
	with open(f'tests/inputs/formats-{converter}.csv', 'w', newline='') as csvfile:
		csvwriter = csv.writer(csvfile, dialect=csv.unix_dialect, quoting=csv.QUOTE_MINIMAL)
		csvwriter.writerows([[ext] for ext in sorted(supported_extensions[converter])])
	print(f"\t'{converter}':")
	print("\t\t{" + str(sorted(supported_extensions[converter])).strip('[]') + '},')
print("}")

