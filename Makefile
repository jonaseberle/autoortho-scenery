# Requires:
# * Github CLI (gh) command to facilitate authenticated requests to the API
# * pipenv (for otv)
#
# Quick start:
#   Generate tile set:
#     export TILESET=eur ZL=16 VARIANT=o4xp1.40beta1-fallback1.3 VERSION=1.0 && nice make -j $(nproc --ignore=6) --keep-going z_ao_${TILESET}_zl${ZL}_${VARIANT}_v${VERSION}
#
#   Generate single tile:
#     export TILE=+78+015 ZL=16 VARIANT=o4xp1.40beta1-fallback1.3 VERSION=1.0 && nice make -j $(nproc --ignore=6) z_ao__single_${TILE}_zl${ZL}_${VARIANT}_v${VERSION}
#
#   Make all:
#     export ZL=16 VARIANT=o4xp1.40beta1-fallback1.3 VERSION=1.0 && nice make -j $(nproc --ignore=6)
#
#   Stats:
#     make stats

# remove make builtin rules for more useful make -d 
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
SHELL=/bin/bash

# @see ./bin/prepareAssetsElevationData
ELEV_RELEASE_JSON_ENDPOINT?=repos/jonaseberle/autoortho-scenery/releases/tags/elevation-v0.0.1

ZL?=16
VARIANT?=o4xp1.40beta1-fallback1.3
VERSION?=1.0

# paranthesis to use in shell commands
# make chokes on () in shell commands
OP:=(
CP:=)

#
# Work on tile lists
#
.DEFAULT_GOAL := all
var/run/Makefile.tilelistRules_zl$(ZL)_$(VARIANT)_v$(VERSION): bin/genMakefileTilelistRules *_tile_list
	@mkdir -p var/run/
	@echo "[$@]"
	@bin/genMakefileTilelistRules $(ZL) $(VARIANT) $(VERSION) > $@
include var/run/Makefile.tilelistRules_zl$(ZL)_$(VARIANT)_v$(VERSION)

stats:
	@printf "                 validated  (done) /total\n"
	@allDsf="$$(find build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/*/_docs -name 'generated_by_*' -printf "%f\n" 2> /dev/null | sed -E -e 's/generated_by_//' -e 's/\.txt/.dsf/' | sort)" \
	&& validatedDsf="$$(find build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/*/_docs -name 'checked_by_*' -printf "%f\n" 2> /dev/null | sed -E -e 's/checked_by_//' -e 's/\.txt/.dsf/' | sort)" \
		&& for tiles in *_tile_list; do \
			dsfTile="$$(sort $$tiles | uniq)" \
			&& printf "%-20s %5d (%5d) /%5d\n" \
				"$$tiles" \
				$$(comm --total -123 \
						<(echo "$$dsfTile") \
						<(echo "$$validatedDsf") \
					| cut -f3) \
				$$(comm --total -123 <(echo "$$dsfTile") <(echo "$$allDsf") | cut -f3) \
				$$(cat $$tiles | wc -l); \
		done \
		&& printf "——————————————————————————————————————————\n" \
		&& printf "%20s %5d (%5d) /%5d\n" \
			"=" \
			$$(comm --total -123 \
					<(sort *_tile_list | uniq) \
					<(echo "$$validatedDsf") \
				| cut -f3) \
			$$(comm --total -123 <(sort *_tile_list | uniq) <(echo "$$allDsf") | cut -f3) \
			$$(cat *_tile_list | wc -l);
	@printf "\ngenerated_by:\n"
	@sort build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_*/_docs/generated_by* 2> /dev/null | uniq -c

# shows stats with changes from last call
statsdiff:
	@mkdir -p var/run/
	@[ -e var/run/prevStats ] || touch var/run/prevStats
	@new="$$($(MAKE) --silent stats)" \
	&& diff --new-line-format='+%L' --old-line-format='-%L' --unchanged-line-format=' %L' var/run/prevStats <(echo "$$new"); \
	echo "$$new" > var/run/prevStats

# creates directories
%/:
	@echo "[$@]"
	@mkdir -p $@

#
# tilesets and tiles
#

z_ao__single_%_zl$(ZL)_$(VARIANT)_v$(VERSION): build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_%/_docs/checked_by_*.txt
	@echo "[$@]"
	@rm -rf $@/
	@cp --force --link --recursive build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/ $@/

z_ao__single_%_zl$(ZL)_$(VARIANT)_v$(VERSION).zip: z_ao__single_%_zl$(ZL)_$(VARIANT)_v$(VERSION)
	@echo "[$@]"
	@cd z_ao__single_$*_zl$(ZL)_$(VARIANT)_v$(VERSION) \
		&& zip -r ../$@ .

z_ao_%_zl$(ZL)_$(VARIANT)_v$(VERSION): %_tile_list var/run/%_zl$(ZL)_$(VARIANT)_v$(VERSION)_tiles var/run/Makefile.tilelistRules_zl$(ZL)_$(VARIANT)_v$(VERSION)
	@echo "[$@]"
	@rm -rf $@/
	@mkdir -p $@
	@cd build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/ \
		&& for dsf in $$(cat $(CURDIR)/$*_tile_list); do \
			echo $$dsf \
				&& dir=zOrtho4XP_$$(basename -- $$dsf .dsf) \
				&& [ -e $$dir/"Earth nav data"/*/$$dsf ] \
				&& cp --force --recursive --link $$dir/* $(CURDIR)/$@/. \
				|| exit 1; \
		done

#
# Ortho4XP setup
#

Ortho4XP:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/jonaseberle/Ortho4XP.git $@
	@mkdir -p build/Elevation_data/ build/Geotiffs/ build/Masks/ build/OSM_data/ build/Orthophotos build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)
	@cd $@/ \
		&& git switch release/for-autoortho-scenery \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > generated_by.template \
		&& cp ../requirements.txt . \
		&& ln -snfr ../Ortho4XP.cfg Ortho4XP.cfg \
		&& ln -snfr ../build/Elevation_data ../build/Geotiffs ../build/Masks ../build/OSM_data ../build/Orthophotos . \
		&& python3 -m venv .venv \
		&& . .venv/bin/activate \
		&& pip install -r requirements.txt \
		&& pip install gdal==$$(gdalinfo --version | cut -f 2 -d' ' | cut -f1 -d ',')

Ortho4XP-v1.3:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/w8sl/Ortho4XP.git $@
	@mkdir -p build/Elevation_data/ build/Geotiffs/ build/Masks/ build/OSM_data/ build/Orthophotos build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)
	@cd $@/ \
		&& git switch Progressive_130 \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > generated_by.template \
		&& ln -snfr ../Ortho4XP-v1.3.cfg Ortho4XP.cfg \
		&& mkdir -p build/ \
		&& ln -snfr ../build/Elevation_data ../build/Geotiffs ../build/Masks ../build/OSM_data ../build/Orthophotos build/ \
		&& python3 -m venv .venv \
		&& . .venv/bin/activate \
		&& pip install -r requirements.txt \
		&& pip install gdal==$$(gdalinfo --version | cut -f 2 -d' ' | cut -f1 -d ',')

Ortho4XP-shred86:
	@echo "[$@]"
	[ ! -e $@ ] || rm -rf $@
	git clone https://github.com/shred86/Ortho4XP.git $@
	@mkdir -p build/Elevation_data/ build/Geotiffs/ build/Masks/ build/OSM_data/ build/Orthophotos build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)
	@cd $@/ \
		&& git checkout 1f88dadca0d3b718b5d18b5cd66be6d701d31c81 \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > generated_by.template \
		&& ln -snfr ../Ortho4XP.cfg Ortho4XP.cfg \
		&& ln -snfr ../build/Elevation_data ../build/Geotiffs ../build/Masks ../build/OSM_data ../build/Orthophotos . \
		&& python3 -m venv .venv \
		&& . .venv/bin/activate \
		&& pip install -r requirements.txt \
		&& pip install gdal==$$(gdalinfo --version | cut -f 2 -d' ' | cut -f1 -d ',')

build/Elevation_data/:
	@echo "Setting up symlinks in order to not care about Ortho4XP's expected directory structure in ./Elevation_data..."
	@mkdir -p $@ && cd $@ \
		&& bash -c 'for lat in {-9..9}; do for lon in {-18..18}; do ln -snfr ./ "./$$(printf "%+d0%+03d0" "$$lat" "$$lon")"; done; done'

	# not avail:
	# 			https://viewfinderpanoramas.org/dem1/N01.zip \
	# 			https://viewfinderpanoramas.org/dem1/N02.zip \
	# 			https://viewfinderpanoramas.org/dem1/N03.zip \
	# 			https://viewfinderpanoramas.org/dem1/N04.zip \
	# 			https://viewfinderpanoramas.org/dem1/N05.zip \
	# 			https://viewfinderpanoramas.org/dem1/M01.zip \
	# 			https://viewfinderpanoramas.org/dem1/H11.zip \
	# removed from list: Europe

	@mkdir -p var/cache/ferranti_nonStandardNames/ \
		&& cd var/cache/ferranti_nonStandardNames/ \
		&& wget --continue --no-verbose \
			https://viewfinderpanoramas.org/dem1/O23.zip \
			https://viewfinderpanoramas.org/dem1/P22.zip \
			https://viewfinderpanoramas.org/dem1/P23.zip \
			https://viewfinderpanoramas.org/dem1/P24.zip \
			https://viewfinderpanoramas.org/dem1/Q22.zip \
			https://viewfinderpanoramas.org/dem1/Q23.zip \
			https://viewfinderpanoramas.org/dem1/Q24.zip \
			https://viewfinderpanoramas.org/dem1/Q25.zip \
			https://viewfinderpanoramas.org/dem1/R21.zip \
			https://viewfinderpanoramas.org/dem1/R22.zip \
			https://viewfinderpanoramas.org/dem1/R23.zip \
			https://viewfinderpanoramas.org/dem1/R24.zip \
			https://viewfinderpanoramas.org/dem1/R25.zip \
			https://viewfinderpanoramas.org/dem1/R26.zip \
			https://viewfinderpanoramas.org/dem1/R27.zip \
			https://viewfinderpanoramas.org/dem1/S19.zip \
			https://viewfinderpanoramas.org/dem1/S20.zip \
			https://viewfinderpanoramas.org/dem1/S21.zip \
			https://viewfinderpanoramas.org/dem1/S22.zip \
			https://viewfinderpanoramas.org/dem1/S23.zip \
			https://viewfinderpanoramas.org/dem1/S24.zip \
			https://viewfinderpanoramas.org/dem1/S25.zip \
			https://viewfinderpanoramas.org/dem1/S26.zip \
			https://viewfinderpanoramas.org/dem1/S27.zip \
			https://viewfinderpanoramas.org/dem1/S28.zip \
			https://viewfinderpanoramas.org/dem1/T18.zip \
			https://viewfinderpanoramas.org/dem1/T19.zip \
			https://viewfinderpanoramas.org/dem1/T20.zip \
			https://viewfinderpanoramas.org/dem1/T21.zip \
			https://viewfinderpanoramas.org/dem1/T22.zip \
			https://viewfinderpanoramas.org/dem1/T23.zip \
			https://viewfinderpanoramas.org/dem1/T24.zip \
			https://viewfinderpanoramas.org/dem1/T25.zip \
			https://viewfinderpanoramas.org/dem1/T26.zip \
			https://viewfinderpanoramas.org/dem1/T27.zip \
			https://viewfinderpanoramas.org/dem1/T28.zip \
			https://viewfinderpanoramas.org/dem1/U19.zip \
			https://viewfinderpanoramas.org/dem1/U20.zip \
			https://viewfinderpanoramas.org/dem1/U21.zip \
			https://viewfinderpanoramas.org/dem1/U22.zip \
			https://viewfinderpanoramas.org/dem1/U23.zip \
			https://viewfinderpanoramas.org/dem1/U24.zip \
			https://viewfinderpanoramas.org/dem1/U25.zip \
			https://viewfinderpanoramas.org/dem1/U26.zip \
			https://viewfinderpanoramas.org/dem1/U27.zip \
			https://viewfinderpanoramas.org/dem1/U28.zip \
			https://viewfinderpanoramas.org/dem1/U29.zip \
			https://viewfinderpanoramas.org/dem1/U14.zip \
			https://viewfinderpanoramas.org/dem1/U15.zip \
			https://viewfinderpanoramas.org/dem1/U16.zip \
			https://viewfinderpanoramas.org/dem1/U17.zip \
			https://viewfinderpanoramas.org/dem1/U18.zip \
			https://viewfinderpanoramas.org/dem1/T10.zip \
			https://viewfinderpanoramas.org/dem1/T11.zip \
			https://viewfinderpanoramas.org/dem1/T12.zip \
			https://viewfinderpanoramas.org/dem1/T13.zip \
			https://viewfinderpanoramas.org/dem1/T14.zip \
			https://viewfinderpanoramas.org/dem1/T15.zip \
			https://viewfinderpanoramas.org/dem1/T16.zip \
			https://viewfinderpanoramas.org/dem1/T17.zip \
			https://viewfinderpanoramas.org/dem1/S10.zip \
			https://viewfinderpanoramas.org/dem1/S11.zip \
			https://viewfinderpanoramas.org/dem1/S12.zip \
			https://viewfinderpanoramas.org/dem1/S13.zip \
			https://viewfinderpanoramas.org/dem1/S14.zip \
			https://viewfinderpanoramas.org/dem1/S15.zip \
			https://viewfinderpanoramas.org/dem1/S16.zip \
			https://viewfinderpanoramas.org/dem1/S17.zip \
			https://viewfinderpanoramas.org/dem1/S18.zip \
			https://viewfinderpanoramas.org/dem1/R03.zip \
			https://viewfinderpanoramas.org/dem1/R04.zip \
			https://viewfinderpanoramas.org/dem1/R05.zip \
			https://viewfinderpanoramas.org/dem1/R06.zip \
			https://viewfinderpanoramas.org/dem1/R07.zip \
			https://viewfinderpanoramas.org/dem1/R08.zip \
			https://viewfinderpanoramas.org/dem1/R09.zip \
			https://viewfinderpanoramas.org/dem1/R10.zip \
			https://viewfinderpanoramas.org/dem1/R11.zip \
			https://viewfinderpanoramas.org/dem1/R12.zip \
			https://viewfinderpanoramas.org/dem1/R13.zip \
			https://viewfinderpanoramas.org/dem1/R14.zip \
			https://viewfinderpanoramas.org/dem1/R15.zip \
			https://viewfinderpanoramas.org/dem1/R16.zip \
			https://viewfinderpanoramas.org/dem1/R17.zip \
			https://viewfinderpanoramas.org/dem1/R18.zip \
			https://viewfinderpanoramas.org/dem1/R19.zip \
			https://viewfinderpanoramas.org/dem1/R20.zip \
			https://viewfinderpanoramas.org/dem1/Q03.zip \
			https://viewfinderpanoramas.org/dem1/Q04.zip \
			https://viewfinderpanoramas.org/dem1/Q05.zip \
			https://viewfinderpanoramas.org/dem1/Q06.zip \
			https://viewfinderpanoramas.org/dem1/Q07.zip \
			https://viewfinderpanoramas.org/dem1/Q08.zip \
			https://viewfinderpanoramas.org/dem1/Q09.zip \
			https://viewfinderpanoramas.org/dem1/Q10.zip \
			https://viewfinderpanoramas.org/dem1/Q11.zip \
			https://viewfinderpanoramas.org/dem1/Q12.zip \
			https://viewfinderpanoramas.org/dem1/Q13.zip \
			https://viewfinderpanoramas.org/dem1/Q14.zip \
			https://viewfinderpanoramas.org/dem1/Q15.zip \
			https://viewfinderpanoramas.org/dem1/Q16.zip \
			https://viewfinderpanoramas.org/dem1/Q17.zip \
			https://viewfinderpanoramas.org/dem1/Q18.zip \
			https://viewfinderpanoramas.org/dem1/Q19.zip \
			https://viewfinderpanoramas.org/dem1/Q20.zip \
			https://viewfinderpanoramas.org/dem1/P03.zip \
			https://viewfinderpanoramas.org/dem1/P04.zip \
			https://viewfinderpanoramas.org/dem1/P05.zip \
			https://viewfinderpanoramas.org/dem1/P06.zip \
			https://viewfinderpanoramas.org/dem1/P07.zip \
			https://viewfinderpanoramas.org/dem1/P08.zip \
			https://viewfinderpanoramas.org/dem1/P09.zip \
			https://viewfinderpanoramas.org/dem1/P10.zip \
			https://viewfinderpanoramas.org/dem1/P11.zip \
			https://viewfinderpanoramas.org/dem1/P12.zip \
			https://viewfinderpanoramas.org/dem1/P13.zip \
			https://viewfinderpanoramas.org/dem1/P14.zip \
			https://viewfinderpanoramas.org/dem1/P15.zip \
			https://viewfinderpanoramas.org/dem1/P16.zip \
			https://viewfinderpanoramas.org/dem1/P17.zip \
			https://viewfinderpanoramas.org/dem1/P18.zip \
			https://viewfinderpanoramas.org/dem1/P19.zip \
			https://viewfinderpanoramas.org/dem1/P20.zip \
			https://viewfinderpanoramas.org/dem1/O02.zip \
			https://viewfinderpanoramas.org/dem1/O03.zip \
			https://viewfinderpanoramas.org/dem1/O04.zip \
			https://viewfinderpanoramas.org/dem1/O05.zip \
			https://viewfinderpanoramas.org/dem1/O06.zip \
			https://viewfinderpanoramas.org/dem1/O07.zip \
			https://viewfinderpanoramas.org/dem1/O08.zip \
			https://viewfinderpanoramas.org/dem1/O09.zip \
			https://viewfinderpanoramas.org/dem1/O10.zip \
			https://viewfinderpanoramas.org/dem1/O11.zip \
			https://viewfinderpanoramas.org/dem1/O12.zip \
			https://viewfinderpanoramas.org/dem1/O13.zip \
			https://viewfinderpanoramas.org/dem1/O14.zip \
			https://viewfinderpanoramas.org/dem1/O15.zip \
			https://viewfinderpanoramas.org/dem1/O16.zip \
			https://viewfinderpanoramas.org/dem1/O17.zip \
			https://viewfinderpanoramas.org/dem1/O18.zip \
			https://viewfinderpanoramas.org/dem1/O19.zip \
			https://viewfinderpanoramas.org/dem1/O20.zip \
			https://viewfinderpanoramas.org/dem1/N08.zip \
			https://viewfinderpanoramas.org/dem1/N09.zip \
			https://viewfinderpanoramas.org/dem1/N10.zip \
			https://viewfinderpanoramas.org/dem1/N11.zip \
			https://viewfinderpanoramas.org/dem1/N12.zip \
			https://viewfinderpanoramas.org/dem1/N13.zip \
			https://viewfinderpanoramas.org/dem1/N14.zip \
			https://viewfinderpanoramas.org/dem1/N15.zip \
			https://viewfinderpanoramas.org/dem1/N16.zip \
			https://viewfinderpanoramas.org/dem1/N17.zip \
			https://viewfinderpanoramas.org/dem1/N18.zip \
			https://viewfinderpanoramas.org/dem1/N19.zip \
			https://viewfinderpanoramas.org/dem1/N20.zip \
			https://viewfinderpanoramas.org/dem1/N21.zip \
			https://viewfinderpanoramas.org/dem1/M09.zip \
			https://viewfinderpanoramas.org/dem1/M10.zip \
			https://viewfinderpanoramas.org/dem1/M11.zip \
			https://viewfinderpanoramas.org/dem1/M12.zip \
			https://viewfinderpanoramas.org/dem1/M13.zip \
			https://viewfinderpanoramas.org/dem1/M14.zip \
			https://viewfinderpanoramas.org/dem1/M15.zip \
			https://viewfinderpanoramas.org/dem1/M16.zip \
			https://viewfinderpanoramas.org/dem1/M17.zip \
			https://viewfinderpanoramas.org/dem1/M18.zip \
			https://viewfinderpanoramas.org/dem1/M19.zip \
			https://viewfinderpanoramas.org/dem1/M20.zip \
			https://viewfinderpanoramas.org/dem1/M21.zip \
			https://viewfinderpanoramas.org/dem1/M22.zip \
			https://viewfinderpanoramas.org/dem1/L10.zip \
			https://viewfinderpanoramas.org/dem1/L11.zip \
			https://viewfinderpanoramas.org/dem1/L12.zip \
			https://viewfinderpanoramas.org/dem1/L13.zip \
			https://viewfinderpanoramas.org/dem1/L14.zip \
			https://viewfinderpanoramas.org/dem1/L15.zip \
			https://viewfinderpanoramas.org/dem1/L16.zip \
			https://viewfinderpanoramas.org/dem1/L17.zip \
			https://viewfinderpanoramas.org/dem1/L18.zip \
			https://viewfinderpanoramas.org/dem1/L19.zip \
			https://viewfinderpanoramas.org/dem1/L20.zip \
			https://viewfinderpanoramas.org/dem1/L21.zip \
			https://viewfinderpanoramas.org/dem1/L22.zip \
			https://viewfinderpanoramas.org/dem1/K10.zip \
			https://viewfinderpanoramas.org/dem1/K11.zip \
			https://viewfinderpanoramas.org/dem1/K12.zip \
			https://viewfinderpanoramas.org/dem1/K13.zip \
			https://viewfinderpanoramas.org/dem1/K14.zip \
			https://viewfinderpanoramas.org/dem1/K15.zip \
			https://viewfinderpanoramas.org/dem1/K16.zip \
			https://viewfinderpanoramas.org/dem1/K17.zip \
			https://viewfinderpanoramas.org/dem1/K18.zip \
			https://viewfinderpanoramas.org/dem1/K19.zip \
			https://viewfinderpanoramas.org/dem1/K20.zip \
			https://viewfinderpanoramas.org/dem1/K21.zip \
			https://viewfinderpanoramas.org/dem1/J10.zip \
			https://viewfinderpanoramas.org/dem1/J11.zip \
			https://viewfinderpanoramas.org/dem1/J12.zip \
			https://viewfinderpanoramas.org/dem1/J13.zip \
			https://viewfinderpanoramas.org/dem1/J14.zip \
			https://viewfinderpanoramas.org/dem1/J15.zip \
			https://viewfinderpanoramas.org/dem1/J16.zip \
			https://viewfinderpanoramas.org/dem1/J17.zip \
			https://viewfinderpanoramas.org/dem1/J18.zip \
			https://viewfinderpanoramas.org/dem1/I10.zip \
			https://viewfinderpanoramas.org/dem1/I11.zip \
			https://viewfinderpanoramas.org/dem1/I12.zip \
			https://viewfinderpanoramas.org/dem1/I13.zip \
			https://viewfinderpanoramas.org/dem1/I14.zip \
			https://viewfinderpanoramas.org/dem1/I15.zip \
			https://viewfinderpanoramas.org/dem1/I16.zip \
			https://viewfinderpanoramas.org/dem1/I17.zip \
			https://viewfinderpanoramas.org/dem1/I18.zip \
			https://viewfinderpanoramas.org/dem1/H12.zip \
			https://viewfinderpanoramas.org/dem1/H13.zip \
			https://viewfinderpanoramas.org/dem1/H14.zip \
			https://viewfinderpanoramas.org/dem1/H15.zip \
			https://viewfinderpanoramas.org/dem1/H16.zip \
			https://viewfinderpanoramas.org/dem1/H17.zip \
			https://viewfinderpanoramas.org/dem1/G14.zip \
			https://viewfinderpanoramas.org/dem1/G17.zip \
			https://viewfinderpanoramas.org/dem1/SI59.zip \
			https://viewfinderpanoramas.org/dem1/SI60.zip \
			https://viewfinderpanoramas.org/dem1/SJ59.zip \
			https://viewfinderpanoramas.org/dem1/SJ60.zip \
			https://viewfinderpanoramas.org/dem1/SK59.zip \
			https://viewfinderpanoramas.org/dem1/SK60.zip \
			https://viewfinderpanoramas.org/dem1/SL58.zip \
			https://viewfinderpanoramas.org/dem1/SL59.zip \
			https://viewfinderpanoramas.org/dem1/SL60.zip \
		&& unzip -j -d ../../../build/Elevation_data -o '*.zip' \
		&& cd ../../../build/Elevation_data \
		&& find -type f -exec sh -c 'mv {} "$$(tr [:lower:] [:upper:] <<< $$(basename -- {} .hgt)).hgt"' \;

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
	git clone --single-branch --branch develop https://github.com/jonaseberle/otv.git
	@cd $@/ \
		&& echo "$$(git remote get-url origin)|$$(git describe --tags)" > checked_by.template \
		&& PIPENV_PIPFILE=./Pipfile PIPENV_IGNORE_VIRTUALENVS=1 pipenv install

#
# Custom tile elevation
#

# generates the targets var/run/neighboursOfTile_%.elevation with surrounding tiles' elevations 
# as prerequisites (takes a little while, 360*180 rules):
var/run/Makefile.elevationRules: bin/genMakefileElevationRules
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

build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_%/_docs/checked_by_*.txt: build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_%/_docs/generated_by_*.txt otv
	@echo [$@]
	@cd $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$* \
		&& PIPENV_PIPFILE=$(CURDIR)/otv/Pipfile PIPENV_IGNORE_VIRTUALENVS=1 pipenv run \
			$(CURDIR)/otv/bin/otv --all --ignore-textures --no-progress . \
		&& mkdir -p _docs/ \
		&& rm -f Data* *.bak "Earth nav data"/*/*.bak \
		&& ( ls Ortho4XP_*.cfg &>/dev/null && mv Ortho4XP_*.cfg _docs/ || true ) \
		&& cp $(CURDIR)/otv/checked_by.template _docs/checked_by_$*.txt \


build/Tiles/zl$(ZL)/o4xp1.40beta1-fallback1.3/v$(VERSION)/zOrtho4XP_%/_docs/generated_by_*.txt: Ortho4XP Ortho4XP-shred86 Ortho4XP-v1.3 build/Elevation_data/ var/run/neighboursOfTile_%.elevation o4xp_2_xp12
	@echo [$@]
	@mkdir -p $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/_docs/
	@# this silences deprecation warnings in Ortho4XP for more concise output
	@set -x; \
	echo $(@); \
	export COORDS=$$(echo $(@) | sed -e 's/.*\([-+][0-9]\+\)\([-+][0-9]\+\).*/\1 \2/g'); \
	cd $(CURDIR)/Ortho4XP \
		&& cp Ortho4XP.cfg $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Ortho4XP_$*.cfg \
		&& sed -i "/^default_zl=/s/=.*/=$(ZL)/" $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Ortho4XP_$*.cfg \
		&& ln -snfr ../build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION) ./Tiles \
		&& . .venv/bin/activate \
		&& python3 Ortho4XP.py $$COORDS 2>&1 \
		&& [ -e "$(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Earth nav data/"*/$*.dsf ] \
		&& cp generated_by.template $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/_docs/generated_by_$*.txt; \
	[ -e "$(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Earth nav data/"*/$*.dsf ] || ( \
		echo "ERROR DETECTED! Retry tile $@ with noroads config."; \
		cd $(CURDIR)/Ortho4XP \
			&& cp Ortho4XP_noroads.cfg $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Ortho4XP_$*.cfg \
			&& sed -i "/^default_zl=/s/=.*/=$(ZL)/" $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Ortho4XP_$*.cfg \
			&& ln -snfr ../build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION) ./Tiles \
			&& . .venv/bin/activate \
			&& python3 Ortho4XP.py $$COORDS 2>&1 \
			&& [ -e "$(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Earth nav data/"*/$*.dsf ] \
			&& cp generated_by.template $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/_docs/generated_by_$*.txt \
	); \
	[ -e "$(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Earth nav data/"*/$*.dsf ] || ( \
		echo "ERROR DETECTED! Retry tile $@ with Ortho4XP 1.3"; \
		cd $(CURDIR)/Ortho4XP-v1.3 \
			&& cp Ortho4XP.cfg $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Ortho4XP_$*.cfg \
			&& sed -i "/^default_zl=/s/=.*/=$(ZL)/" $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Ortho4XP_$*.cfg \
			&& ln -snfr ../build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION) ./build/Tiles \
			&& . .venv/bin/activate \
			&& python3 Ortho4XP.py $$COORDS 2>&1 \
			&& [ -e "$(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/Earth nav data/"*/$*.dsf ] \
			&& cd $(CURDIR)/o4xp_2_xp12 \
			&& . .venv/bin/activate \
			&& python o4xp_2_xp12.py -subset $* -limit 1 convert \
			&& python o4xp_2_xp12.py -subset $* -limit 1 cleanup \
			&& rm -f $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/"Earth nav data"/*/*.dsf-o4xp_2_xp12_done \
			&& cp adjusted_by.template $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/_docs/adjusted_by_$*.txt \
			&& cp $(CURDIR)/Ortho4XP-v1.3/generated_by.template $(CURDIR)/build/Tiles/zl$(ZL)/$(VARIANT)/v$(VERSION)/zOrtho4XP_$*/_docs/generated_by_$*.txt \
	);


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
