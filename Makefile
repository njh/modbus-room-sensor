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

.PHONY: all check schematics clean

all: check schematics

check: | $(REPORTS_DIR)
	"$(KICAD_CLI)" sch erc --exit-code-violations --output $(REPORTS_DIR)/modbus-room-sensor-erc.txt modbus-room-sensor.kicad_sch
	"$(KICAD_CLI)" pcb drc --exit-code-violations --output $(REPORTS_DIR)/modbus-room-sensor-drc.txt modbus-room-sensor.kicad_pcb
	"$(KICAD_CLI)" sch erc --exit-code-violations --output $(REPORTS_DIR)/sht4x-breakout-erc.txt sht4x-breakout/sht4x-breakout.kicad_sch
	"$(KICAD_CLI)" pcb drc --exit-code-violations --output $(REPORTS_DIR)/sht4x-breakout-drc.txt sht4x-breakout/sht4x-breakout.kicad_pcb

schematics: $(SCHEMATIC_PDFS)

$(RELEASE_DIR) $(REPORTS_DIR):
	@mkdir -p "$@"

$(RELEASE_DIR)/modbus-room-sensor-schematic.pdf: modbus-room-sensor.kicad_sch
$(RELEASE_DIR)/sht4x-breakout-schematic.pdf: sht4x-breakout/sht4x-breakout.kicad_sch

$(SCHEMATIC_PDFS): | $(RELEASE_DIR)
	"$(KICAD_CLI)" sch export pdf --output "$@" "$<"

clean:
	rm -Rf $(RELEASE_DIR) $(REPORTS_DIR)
