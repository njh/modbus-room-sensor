MACOS_KICAD_CLI := /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
ifneq ($(wildcard $(MACOS_KICAD_CLI)),)
  KICAD_CLI ?= $(MACOS_KICAD_CLI)
else
  KICAD_CLI ?= kicad-cli
endif

RELEASE_DIR := release
REPORTS_DIR := reports

SCHEMATIC_PDFS := \
	$(RELEASE_DIR)/modbus-room-sensor-schematic.pdf \
	$(RELEASE_DIR)/sht4x-breakout-schematic.pdf

GERBER_ZIPS := \
	$(RELEASE_DIR)/modbus-room-sensor-gerbers.zip \
	$(RELEASE_DIR)/sht4x-breakout-gerbers.zip

GERBER_LAYERS := F.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts

.PHONY: all
all: check schematics gerbers

.PHONY: check
check: | $(REPORTS_DIR)
	"$(KICAD_CLI)" sch erc --exit-code-violations --output $(REPORTS_DIR)/modbus-room-sensor-erc.txt modbus-room-sensor.kicad_sch
	"$(KICAD_CLI)" pcb drc --exit-code-violations --output $(REPORTS_DIR)/modbus-room-sensor-drc.txt modbus-room-sensor.kicad_pcb
	"$(KICAD_CLI)" sch erc --exit-code-violations --output $(REPORTS_DIR)/sht4x-breakout-erc.txt sht4x-breakout/sht4x-breakout.kicad_sch
	"$(KICAD_CLI)" pcb drc --exit-code-violations --output $(REPORTS_DIR)/sht4x-breakout-drc.txt sht4x-breakout/sht4x-breakout.kicad_pcb


### Schematics ###

.PHONY: schematics
schematics: $(SCHEMATIC_PDFS)

$(RELEASE_DIR) $(REPORTS_DIR):
	@mkdir -p "$@"

$(RELEASE_DIR)/modbus-room-sensor-schematic.pdf: modbus-room-sensor.kicad_sch
$(RELEASE_DIR)/sht4x-breakout-schematic.pdf: sht4x-breakout/sht4x-breakout.kicad_sch

$(SCHEMATIC_PDFS): | $(RELEASE_DIR)
	"$(KICAD_CLI)" sch export pdf --output "$@" "$<"


### Gerbers ###

.PHONY: gerbers
gerbers: $(GERBER_ZIPS)

$(RELEASE_DIR)/modbus-room-sensor-gerbers.zip: modbus-room-sensor.kicad_pcb
$(RELEASE_DIR)/sht4x-breakout-gerbers.zip: sht4x-breakout/sht4x-breakout.kicad_pcb

# Export to a temporary directory named after the zip, then zip it up
$(GERBER_ZIPS): GERBER_DIR = $(@:.zip=)
$(GERBER_ZIPS): | $(RELEASE_DIR)
	rm -Rf "$(GERBER_DIR)" "$@"
	"$(KICAD_CLI)" pcb export gerbers --check-zones --layers $(GERBER_LAYERS) --output "$(GERBER_DIR)" "$<"
	"$(KICAD_CLI)" pcb export drill --output "$(GERBER_DIR)" "$<"
	zip -j "$@" "$(GERBER_DIR)"/*
	rm -Rf "$(GERBER_DIR)"


.PHONY: clean
clean:
	rm -Rf $(RELEASE_DIR) $(REPORTS_DIR)
