.PHONY: convert README.html

open:
	@xdg-open README.html

watch:
	@ls README.md Makefile | entr make convert

convert: README.html

README.html: README.md
# https://pandoc.org/MANUAL.html#extensions
# https://github.com/edwardtufte/tufte-css
	@pandoc --from=gfm+smart --to=html5 --standalone --css='https://rawcdn.githack.com/edwardtufte/tufte-css/e225f3a0e5f8f42a1d28416c1c85962411711907/tufte.min.css' $< -o $@
