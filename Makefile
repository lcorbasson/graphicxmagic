graphicxwand.pdf: graphicxwand.tex
	lualatex -shell-escape graphicxwand

graphicxwand.zip: clean
	git archive --format=tar --prefix=graphicxwand/ HEAD | gtar -x

	## remove unpacked files
	rm -f graphicxwand/.gitignore graphicxwand/Makefile

	## then, now just make archive
	zip -9 -r graphicxwand.zip graphicxwand/*

	rm -rf graphicxwand
	@echo finished

clean:
	rm -rf graphicxwand.zip graphicxwand
	rm -f *.aux *.log *4gfxwand.*
	find . -type f -name "*~" -delete

.PHONY: graphicxwand.zip
