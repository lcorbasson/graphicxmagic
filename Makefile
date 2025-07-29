graphicxmagic.pdf: graphicxmagic.tex
	lualatex -shell-escape graphicxmagic

graphicxmagic.zip: clean
	git archive --format=tar --prefix=graphicxmagic/ HEAD | gtar -x

	## remove unpacked files
	rm -f graphicxmagic/.gitignore graphicxmagic/Makefile

	## then, now just make archive
	zip -9 -r graphicxmagic.zip graphicxmagic/*

	rm -rf graphicxmagic
	@echo finished

clean:
	rm -rf graphicxmagic.zip graphicxmagic
	rm -f *.aux *.log *4gfxmagic.*
	find . -type f -name "*~" -delete

.PHONY: graphicxmagic.zip
