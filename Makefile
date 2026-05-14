GAME      = space-invaders-part-ii
LOVE_FILE = $(GAME).love
WEB_DIR   = web

.PHONY: all love web server clean

all: love

love:
	python3 -c "import zipfile, os, sys; \
	    z = zipfile.ZipFile('$(LOVE_FILE)', 'w', zipfile.ZIP_DEFLATED, compresslevel=9); \
	    [z.write(os.path.join(r,f), os.path.relpath(os.path.join(r,f), 'src')) \
	     for r,_,fs in os.walk('src') for f in fs if not f.endswith('.DS_Store')]; \
	    z.close()"

web: love
	npx love.js -t "Space Invaders Part II" $(LOVE_FILE) $(WEB_DIR)

server:
	python3 server.py

clean:
	rm -rf $(LOVE_FILE) $(WEB_DIR)
