AS := ca65
LD := ld65

ASFLAGS = --cpu 65c02
LDFLAGS = -C liveoak.cfg -m $@.map -Ln $@.lbl -vm

SRC = $(wildcard *.s)
OBJ = $(SRC:.s=.o)
BIN = wozmon
ROM_DEVICE ?= at28c256

all: $(BIN)

flash: $(BIN)
	minipro -p $(ROM_DEVICE) -uP -w $(BIN)

$(BIN): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

clean:
	rm -f $(BIN) $(OBJ) *.map *.lbl

.PHONY:
	all flash clean

