# Builds the blog with pandoc (and LaTeX for the PDFs).
#
#   make         build the site into public/
#   make html    the same without the PDFs (no LaTeX needed)
#   make serve   build, serve on http://localhost:8080 and rebuild when a file changes
#   make clean   delete public/
#
# Foo.md becomes Foo.html and Foo.pdf, README.md is the home page,
# and files starting with "_" are not published.

OUT = public

articles := $(filter-out articles/_%,$(wildcard articles/*.md))
sessions := $(filter-out sessions/_%,$(wildcard sessions/*.md))
html := $(OUT)/index.html $(patsubst %.md,$(OUT)/%.html,$(articles) $(sessions))
pdf := $(patsubst %.md,$(OUT)/%.pdf,$(articles))
static := $(addprefix $(OUT)/,style.css $(wildcard fonts/*))

all: html $(pdf)
html: $(html) $(static)

# pandoc/page.html lays out every web page; pandoc/site.lua writes its lists of sessions and articles.
PAGE = @mkdir -p $(@D); pandoc $< --output=$@ --from=markdown-implicit_figures-smart --template=pandoc/page.html --lua-filter=pandoc/site.lua
$(OUT)/index.html: README.md
	$(PAGE)
$(OUT)/%.html: %.md
	$(PAGE)
# Pages list each other, so a change to any of them rebuilds them all.
$(html): $(articles) $(sessions) pandoc/page.html pandoc/site.lua

# Every article page links to a PDF of itself, written next to it (Foo.html, Foo.pdf).
# pandoc/lettrine.lua decorates the initial of the first paragraph;
# the title is the only level 1 heading, as on the web page.
$(OUT)/%.pdf: %.md pandoc/article.tex pandoc/lettrine.lua
	@mkdir -p $(@D); pandoc $< --output=$@ --pdf-engine=xelatex --template=pandoc/article.tex --lua-filter=pandoc/lettrine.lua --shift-heading-level-by=-1

$(OUT)/%: %
	@mkdir -p $(@D); cp $< $@

serve: all
	@python3 -m http.server 8080 --directory $(OUT) & trap "kill $$!" EXIT INT TERM; \
	while sleep 1; do $(MAKE) --silent; done

clean:
	rm -rf $(OUT)

.PHONY: all html serve clean
