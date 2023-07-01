objects = uart.o xmodem.o kernel.o pinky.o

kernel : $(objects)
	ld65 -C liveoak.cfg -o kernel -m kernel.map -vm $(objects)

wozmon : uart.o wozmon.o pinky.o
	ld65 -C liveoak.cfg -o wozmon -m wozmon.map -vm uart.o wozmon.o pinky.o

%.o : %.s
	ca65 --cpu 65c02 $<

.PHONY : flash
flash:
	minipro -p at28c256 -w wozmon

.PHONY : clean
clean :
	rm kernel wozmon $(objects)
