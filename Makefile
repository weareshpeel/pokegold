roms := pokegold.gbc pokesilver.gbc

rom_obj := \
audio.o \
home.o \
main.o \
wram.o \
data/text/common.o \
data/pokemon/dex_entries.o \


gold_obj := $(rom_obj:.o=_gold.o)
silver_obj := $(rom_obj:.o=_silver.o)


### Build tools

ifeq (,$(shell which sha1sum))
SHA1 := shasum
else
SHA1 := sha1sum
endif

RGBDS ?=
RGBASM  ?= $(RGBDS)rgbasm
RGBFIX  ?= $(RGBDS)rgbfix
RGBGFX  ?= $(RGBDS)rgbgfx
RGBLINK ?= $(RGBDS)rgblink

PYTHON := python
gfx := $(PYTHON) tools/gfx.py


### Build targets

.SUFFIXES:
.PHONY: all gold silver clean pngs compare tools
.SECONDEXPANSION:
.PRECIOUS:
.SECONDARY:

all: $(roms)
gold: pokegold.gbc
silver: pokesilver.gbc

clean:
	rm -f $(roms) $(gold_obj) $(silver_obj) $(roms:.gbc=.map) $(roms:.gbc=.sym)
	find gfx/pics gfx/trainers \( -name "*.png" -o -name "*.2bpp" \) -delete
	$(MAKE) clean -C tools/

compare: $(roms)
	@$(SHA1) -c roms.sha1

tools:
	$(MAKE) -C tools/


$(gold_obj): RGBASMFLAGS = -D _GOLD
$(silver_obj): RGBASMFLAGS = -D _SILVER

# The dep rules have to be explicit or else missing files won't be reported.
# As a side effect, they're evaluated immediately instead of when the rule is invoked.
# It doesn't look like $(shell) can be deferred so there might not be a better way.
define DEP
$1: $2 $$(shell tools/scan_includes $2)
	$$(RGBASM) $$(RGBASMFLAGS) -L -o $$@ $$<
endef

# Build tools when building the rom.
# This has to happen before the rules are processed, since that's when scan_includes is run.
ifeq (,$(filter clean tools,$(MAKECMDGOALS)))

$(info $(shell $(MAKE) -C tools))

$(foreach obj, $(gold_obj), $(eval $(call DEP,$(obj),$(obj:_gold.o=.asm))))
$(foreach obj, $(silver_obj), $(eval $(call DEP,$(obj),$(obj:_silver.o=.asm))))

endif


pokegold.gbc: $(gold_obj) pokegold.link
	$(RGBLINK) -n pokegold.sym -m pokegold.map -l pokegold.link -o $@ $(gold_obj)
	$(RGBFIX) -cjsv -i AAUE -k 01 -l 0x33 -m 0x10 -p 0 -r 3 -t "POKEMON_GLD" $@
	tools/sort_symfile.sh pokegold.sym

pokesilver.gbc: $(silver_obj) pokesilver.link
	$(RGBLINK) -n pokesilver.sym -m pokesilver.map -l pokesilver.link -o $@ $(silver_obj)
	$(RGBFIX) -cjsv -i AAXE -k 01 -l 0x33 -m 0x10 -p 0 -r 3 -t "POKEMON_SLV" $@
	tools/sort_symfile.sh pokesilver.sym

pngs:
	find . -iname "*.lz"      -exec $(gfx) unlz {} +
	find . -iname "*.[12]bpp" -exec $(gfx) png  {} +
	find . -iname "*.[12]bpp" -exec touch {} +
	find . -iname "*.lz"      -exec touch {} +

%.png: ;
%.2bpp: %.png ; $(gfx) 2bpp $<
%.1bpp: %.png ; $(gfx) 1bpp $<
%.lz: % ; $(gfx) lz $<

%.pal: %.2bpp ;
gfx/pics/%/normal.pal gfx/pics/%/bitmask.asm gfx/pics/%/frames.asm: gfx/pics/%/front.2bpp ;
%.bin: ;
%.blk: ;
%.tilemap: ;
