# Build the ngspades-client checklist from the Typst sources in src/.
#
#   make site     the website into site/ (index.html, style.css, 404.html, pdf/)
#   make check    site, then the requirement check and the link check
#                 (`make check OFFLINE=1` skips fetching the protocol pages)
#   make clean    remove site/
#   make publish  force-push site/ to the gh-pages branch of origin
#
# Needs Typst 0.15 or later (HTML export is experimental there) and Python 3.

TYPST   := tools/typst.sh
SITE    := site
HTMLOPT := --features html --format html --input target=html
SRC     := $(wildcard src/*.typ src/parts/*.typ)

.PHONY: all site check clean publish
all: site

site: $(SITE)/index.html $(SITE)/404.html $(SITE)/style.css $(SITE)/.nojekyll $(SITE)/pdf/client-checklist.pdf

$(SITE)/index.html: src/index.typ $(SRC)
	@mkdir -p $(SITE)
	$(TYPST) $(HTMLOPT) $< $@

# Served from any path on a missing page, so its links are absolute.
$(SITE)/404.html: src/404.typ $(SRC)
	@mkdir -p $(SITE)
	$(TYPST) $(HTMLOPT) --input base=/shoot-and-destroy/ $< $@

$(SITE)/style.css: src/style.css
	@mkdir -p $(SITE)
	cp $< $@

# Without it GitHub Pages would run Jekyll over the pushed branch.
$(SITE)/.nojekyll:
	@mkdir -p $(SITE)
	touch $@

$(SITE)/pdf/client-checklist.pdf: src/index.typ $(SRC)
	@mkdir -p $(SITE)/pdf
	$(TYPST) $< $@

check: site
	python3 tools/check_reqs.py --site $(SITE)
	python3 tools/linkcheck.py $(SITE) $(if $(OFFLINE),--offline)

clean:
	rm -rf $(SITE)

publish: check
	@printf 'Force-push %s/ to the gh-pages branch of origin? [y/N] ' $(SITE); read a; [ "$$a" = y ]
	tools/publish.sh $(SITE) gh-pages
