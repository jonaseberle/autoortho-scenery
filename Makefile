# Requires:
# * Github CLI (gh) command to facilitate authenticated requests to the API
# * pipenv (for otv)
#
# Quick start:
#   Generate tile set:
#     make clean
#     make z_ao_eur
#     make -j $(nproc --ignore=2)
#
#   Generate single tile:
#     make z_ao__single_+78+015
#
#   Test:
#     make test_z_ao__single_+78+015
#     make test_z_eur

# remove make builtin rules for more useful make -d 
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

# @see ./bin/prepareAssetsElevationData
ELEV_RELEASE_JSON_ENDPOINT?=repos/jonaseberle/autoortho-scenery/releases/tags/elevation-v0.0.1
SHELL=/bin/bash

# paranthesis to use in shell commands
# make chokes on () in shell commands
OP:=(
CP:=)

# creates directories
%/:
	@echo "[$@]"
	@mkdir -p $@

#
# tilesets and tiles
#

z_ao__single_%: build/Tiles/zOrtho4XP_%/Earth\ nav\ data/*/*.dsf
	@echo "[$@]"
	@rm -rf $@/
	@cp --force --link --recursive build/Tiles/zOrtho4XP_$*/ z_ao__single_$*/

z_ao__single_%.zip: z_ao__single_%
	@echo "[$@]"
	@cd z_ao__single_$* && zip -r ../../../$@ .

z_ao_%: %_tile_list var/run/%_tiles
	@echo "[$@]"
	@rm -rf $@/
	@mkdir -p $@
	@cd build/Tiles \
		&& set -x \
		&& for dsf in $$(cat ../../$*_tile_list); do \
			echo $$dsf \
				&& dir=zOrtho4XP_$$(basename $$dsf .dsf) \
				&& [ -e $$dir/"Earth nav data"/*/$$dsf ] \
				&& cp --force --recursive --link $$dir/* $(CURDIR)/$@/. ; \
		done

test_%: otv
	@echo "[$@]"
	@PIPENV_PIPFILE=./otv/Pipfile PIPENV_IGNORE_VIRTUALENVS=1 pipenv run ./otv/bin/otv --all --ignore-textures --no-progress build/Tiles/$* \

#
# Ortho4XP setup
#

Ortho4XP:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/oscarpilote/Ortho4XP.git $@
	@mkdir -p build/Elevation_data/ build/Geotiffs/ build/Masks/ build/OSM_data/ build/Orthophotos build/Tiles/
	@cd $@/ \
		&& git checkout c5e0d4b50774de1850246fac56b9d461ae026a72 \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > generated_by.template \
		&& cp ../requirements.txt . \
		&& cp ../Ortho4XP.cfg . \
		&& ln -snfr ../build/Elevation_data ../build/Geotiffs ../build/Masks ../build/OSM_data ../build/Orthophotos ../build/Tiles . \
		&& python3 -m venv .venv \
		&& . .venv/bin/activate \
		&& pip install -r requirements.txt

Ortho4XP-v1.3:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/w8sl/Ortho4XP.git $@
	@mkdir -p build/Elevation_data/ build/Geotiffs/ build/Masks/ build/OSM_data/ build/Orthophotos build/Tiles/
	@cd $@/ \
		&& git switch Progressive_130 \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > generated_by.template \
		&& cp ../Ortho4XP-v1.3.cfg Ortho4XP.cfg \
		&& mkdir -p build/ \
		&& ln -snfr ../build/Elevation_data ../build/Geotiffs ../build/Masks ../build/OSM_data ../build/Orthophotos ../build/Tiles build/ \
		&& python3 -m venv .venv \
		&& . .venv/bin/activate \
		&& pip install -r requirements.txt

Ortho4XP-shred86:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/shred86/Ortho4XP.git $@
	@mkdir -p build/Elevation_data/ build/Geotiffs/ build/Masks/ build/OSM_data/ build/Orthophotos build/Tiles/
	@cd $@/ \
		&& git checkout 1f88dadca0d3b718b5d18b5cd66be6d701d31c81 \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > generated_by.template \
		&& cp ../Ortho4XP.cfg . \
		&& ln -snfr ../build/Elevation_data ../build/Geotiffs ../build/Masks ../build/OSM_data ../build/Orthophotos ../build/Tiles . \
		&& python3 -m venv .venv \
		&& . .venv/bin/activate \
		&& pip install -r requirements.txt

build/Elevation_data/:
	@echo "Setting up symlinks in order to not care about Ortho4XP's expected directory structure in ./Elevation_data..."
	@mkdir -p $@ && cd $@ \
		&& bash -c 'for lat in {-9..9}; do for lon in {-18..18}; do ln -snfr ./ "./$$(printf "%+d0%+03d0" "$$lat" "$$lon")"; done; done'
	mkdir -p var/cache/ferranti_nonStandardNames/ \
		&& cd var/cache/ferranti_nonStandardNames/ \
		&& wget --continue --no-verbose \
			http://viewfinderpanoramas.org/dem1/U19.zip \
			http://viewfinderpanoramas.org/dem1/U20.zip \
			http://viewfinderpanoramas.org/dem1/U21.zip \
			http://viewfinderpanoramas.org/dem1/U22.zip \
			http://viewfinderpanoramas.org/dem1/U23.zip \
			http://viewfinderpanoramas.org/dem1/U24.zip \
			http://viewfinderpanoramas.org/dem1/U25.zip \
			http://viewfinderpanoramas.org/dem1/U26.zip \
			http://viewfinderpanoramas.org/dem1/U27.zip \
			http://viewfinderpanoramas.org/dem1/U28.zip \
			http://viewfinderpanoramas.org/dem1/U29.zip \
			http://viewfinderpanoramas.org/dem1/T18.zip \
			http://viewfinderpanoramas.org/dem1/T19.zip \
			http://viewfinderpanoramas.org/dem1/T20.zip \
			http://viewfinderpanoramas.org/dem1/T21.zip \
			http://viewfinderpanoramas.org/dem1/T22.zip \
			http://viewfinderpanoramas.org/dem1/T23.zip \
			http://viewfinderpanoramas.org/dem1/T24.zip \
			http://viewfinderpanoramas.org/dem1/T25.zip \
			http://viewfinderpanoramas.org/dem1/T26.zip \
			http://viewfinderpanoramas.org/dem1/T27.zip \
			http://viewfinderpanoramas.org/dem1/T28.zip \
			http://viewfinderpanoramas.org/dem1/S19.zip \
			http://viewfinderpanoramas.org/dem1/S20.zip \
			http://viewfinderpanoramas.org/dem1/S21.zip \
			http://viewfinderpanoramas.org/dem1/S22.zip \
			http://viewfinderpanoramas.org/dem1/S23.zip \
			http://viewfinderpanoramas.org/dem1/S24.zip \
			http://viewfinderpanoramas.org/dem1/S25.zip \
			http://viewfinderpanoramas.org/dem1/S26.zip \
			http://viewfinderpanoramas.org/dem1/S27.zip \
			http://viewfinderpanoramas.org/dem1/S28.zip \
			http://viewfinderpanoramas.org/dem1/R21.zip \
			http://viewfinderpanoramas.org/dem1/R22.zip \
			http://viewfinderpanoramas.org/dem1/R23.zip \
			http://viewfinderpanoramas.org/dem1/R24.zip \
			http://viewfinderpanoramas.org/dem1/R25.zip \
			http://viewfinderpanoramas.org/dem1/R26.zip \
			http://viewfinderpanoramas.org/dem1/R27.zip \
			http://viewfinderpanoramas.org/dem1/Q22.zip \
			http://viewfinderpanoramas.org/dem1/R23.zip \
			http://viewfinderpanoramas.org/dem1/R24.zip \
			http://viewfinderpanoramas.org/dem1/R25.zip \
			http://viewfinderpanoramas.org/dem1/P22.zip \
			http://viewfinderpanoramas.org/dem1/P23.zip \
			http://viewfinderpanoramas.org/dem1/R24.zip \
			http://viewfinderpanoramas.org/dem1/O23.zip \
		&& unzip -j -d ../../../build/Elevation_data -o '*.zip' \
		&& cd ../../../build/Elevation_data \
		&& find -type f -exec sh -c 'mv {} "$$(tr [:lower:] [:upper:] <<< $$(basename {} .hgt)).hgt"' \;

#
# dsftool
#

xptools:
	@echo "[$@]"
	@mkdir $@ && cd $@ \
	&& wget -4qO- https://files.x-plane.com/public/xptools/xptools_lin_24-5.zip | bsdtar -xvf- \
	&& chmod +x tools/* \

#
# hotbso/o4xp_2_xp12 fork
#

o4xp_2_xp12: xptools
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/jonaseberle/o4xp_2_xp12.git
	@cd $@/ \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > adjusted_by.template \
		&& cp o4xp_2_xp12.ini-sample o4xp_2_xp12.ini \
		&& sed -i "/^xp12_root =/s/=.*/=\\/home\\/jonas\\/Storage\\/X-Plane 12/" o4xp_2_xp12.ini \
		&& sed -i "/^dsf_tool =/s/=.*/=..\\/xptools\\/tools\\/DSFTool/" o4xp_2_xp12.ini \
		&& sed -i "/^ortho_dir =/s/=.*/=..\\/build\\/Tiles/" o4xp_2_xp12.ini \
		&& sed -i "/^work_dir =/s/=.*/=.\\/tmp/" o4xp_2_xp12.ini \
		&& sed -i "/^7zip =/s/=.*/=7z/" o4xp_2_xp12.ini \
        && python3 -m venv .venv \
        && . .venv/bin/activate

#
# dyoung522/otv (Tile Checker) fork
#

otv:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone --single-branch --branch develop --depth=1 https://github.com/jonaseberle/otv.git
	PIPENV_PIPFILE=./otv/Pipfile PIPENV_IGNORE_VIRTUALENVS=1 pipenv install

#
# Custom tile elevation
#

# generates the targets var/run/neighboursOfTile_%.elevation with surrounding tiles' elevations 
# as prerequisites (takes a little while, 360*180 rules):
var/run/Makefile.elevationRules:
	@mkdir -p var/run/
	@echo "[$@]"
	@bin/genMakefileElevationRules > $@
include var/run/Makefile.elevationRules

var/run/tile_%.elevation: var/cache/elevation/elevation_%.zip Ortho4XP
	@mkdir -p build/Elevation_data/
	@# Unzips if file not empty, but fails on unzip error.
	@# Ignores the .zip if empty
	@if [ -s "var/cache/elevation/elevation_$*.zip" ]; then \
		printf "[$@] unzipping custom elevation: %s\n" \
			"$$(unzip -o -d build/Elevation_data/ var/cache/elevation/elevation_$*.zip | tr "\n" " | ")"; \
	else \
		echo "[$@] no custom elevation for this tile"; \
	fi
	@touch $@

var/run/elevationRelease.json:
	@mkdir -p var/run/
	@echo "[$@]"
	@json="$$(gh api $(ELEV_RELEASE_JSON_ENDPOINT) --paginate)" \
		&& echo "$$json" > $@ \
		&& printf "[$@] got %s\n" "$$(jq -r '.assets[].name' $@ | tr --delete "elevation_" | tr --delete ".zip" | tr "\n" ",")"

var/cache/elevation/elevation_%.zip: var/run/elevationRelease.json
	@mkdir -p var/cache/elevation/
	@# Fails if we expect a file but download failed. 
	@# Creates an empty .zip file if there is no custom elevation.
	@url=$$(jq -r '.assets[] | select$(OP).name == "elevation_$*.zip"$(CP) .browser_download_url' \
			var/run/elevationRelease.json); \
		if [ -n "$$url" ]; then \
			echo "[$@] downloading custom elevation"; \
			wget --continue --quiet -O $@ "$$url" && touch $@; \
		else \
			echo "[$@] no custom elevation for this tile"; \
			touch $@; \
		fi

#
# Build and test tile
#

build/Tiles/zOrtho4XP_%/Earth\ nav\ data/*/*.dsf: Ortho4XP Ortho4XP-shred86 Ortho4XP-v1.3 build/Elevation_data/ var/run/neighboursOfTile_%.elevation otv o4xp_2_xp12
	@echo [$@]
	@mkdir -p build/Tiles/zOrtho4XP_$*
	@# this silences deprecation warnings in Ortho4XP for more concise output
	@set -e; \
	export COORDS=$$(echo $(@) | sed -e 's/.*\/\([-+][0-9]\+\)\([-+][0-9]\+\).dsf/\1 \2/g'); \
	cd $(CURDIR)/Ortho4XP \
		&& cp Ortho4XP.cfg $(CURDIR)/build/Tiles/zOrtho4XP_$*/Ortho4XP_$*.cfg \
		&& . .venv/bin/activate \
		&& python3 Ortho4XP.py $$COORDS 2>&1 \
		&& cp generated_by.template $(CURDIR)/build/Tiles/zOrtho4XP_$*/generated_by_$*.txt ;\
	[ -e Tiles/*/*/*/$*.dsf ] || ( \
		echo "ERROR DETECTED! Retry tile $@ with noroads config."; \
		cd $(CURDIR)/Ortho4XP \
			&& cp Ortho4XP.cfg $(CURDIR)/build/Tiles/zOrtho4XP_$*/Ortho4XP_$*.cfg \
			&& . .venv/bin/activate \
			&& python3 Ortho4XP.py $$COORDS 2>&1 \
			&& cp generated_by.template $(CURDIR)/build/Tiles/zOrtho4XP_$*/generated_by_$*.txt ;\
	); \
	[ -e Tiles/*/*/*/$*.dsf ] || ( \
		echo "ERROR DETECTED! Retry tile $@ with Ortho4XP 1.3"; \
		cd $(CURDIR)/Ortho4XP-v1.3 \
			&& cp Ortho4XP.cfg $(CURDIR)/build/Tiles/zOrtho4XP_$*/Ortho4XP_$*.cfg \
			&& . .venv/bin/activate \
			&& python3 Ortho4XP.py $$COORDS 2>&1 \
			&& cp generated_by.template $(CURDIR)/build/Tiles/zOrtho4XP_$*/generated_by_$*.txt \
			&& cd $(CURDIR)/o4xp_2_xp12 \
			&& . .venv/bin/activate \
			&& python o4xp_2_xp12.py -subset $* -limit 1 -root ./ convert \
			&& cp adjusted_by.template $(CURDIR)/build/Tiles/zOrtho4XP_$*/adjusted_by_$*.txt ;\
	);
	@[ -e build/Tiles/*/*/*/$*.dsf ] \
		&& cd "$(CURDIR)/build/Tiles/zOrtho4XP_$*/" \
		&& PIPENV_PIPFILE=$(CURDIR)/otv/Pipfile PIPENV_IGNORE_VIRTUALENVS=1 pipenv run \
			$(CURDIR)/otv/bin/otv --all --ignore-textures --no-progress ./ \
		&& rm -f Data* *.bak

#
# Work on tile lists
#

var/run/Makefile.tilelistRules:
	@mkdir -p var/run/
	@echo "[$@]"
	@bin/genMakefileTilelistRules > $@
include var/run/Makefile.tilelistRules


clean:
	@echo "[$@]"
	-rm -rf build/Tiles/*
	-rm -rf var/run
	-rm -rf z_*

distclean: clean
	@echo "[$@]"
	-rm -rf Ortho4XP
	-rm -rf build
	-rm -rf var
	-rm -rf z_*
	-rm -f *_tile_list.*
