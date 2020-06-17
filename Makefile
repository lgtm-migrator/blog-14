.PHONY: all
all:
	@node_modules/hexo/bin/hexo generate

build:
	@sh build.sh

clean:
	@node_modules/hexo/bin/hexo clean

serve:
	@python3 -m http.server --directory public/