MACOS_KICAD_CLI := /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
ifneq ($(wildcard $(MACOS_KICAD_CLI)),)
  KICAD_CLI ?= $(MACOS_KICAD_CLI)
else
  KICAD_CLI ?= kicad-cli
endif

RELEASE_DIR := release

SCHEMATIC_PDFS := \
	$(RELEASE_DIR)/modbus-room-sensor-schematic.pdf \
	$(RELEASE_DIR)/sht4x-breakout-schematic.pdf

.PHONY: all schematics clean

all: schematics

schematics: $(SCHEMATIC_PDFS)

$(RELEASE_DIR):
	@mkdir -p "$@"

$(RELEASE_DIR)/modbus-room-sensor-schematic.pdf: modbus-room-sensor.kicad_sch
$(RELEASE_DIR)/sht4x-breakout-schematic.pdf: sht4x-breakout/sht4x-breakout.kicad_sch

$(SCHEMATIC_PDFS): | $(RELEASE_DIR)
	"$(KICAD_CLI)" sch export pdf --output "$@" "$<"

clean:
	rm -Rf $(RELEASE_DIR)
