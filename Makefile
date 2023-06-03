objects = uart.o xmodem.o kernel.o

kernel : $(objects)
	ld65 -C liveoak.cfg -o kernel -m kernel.map -vm $(objects)

wozmon : uart.o wozmon.o
	ld65 -C liveoak.cfg -o wozmon -m wozmon.map -vm uart.o wozmon.o

%.o : %.s
	ca65 --cpu 65c02 $<

.PHONY : clean
clean :
	rm kernel wozmon $(objects)
