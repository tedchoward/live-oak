objects = uart.o xmodem.o kernel.o

kernel : $(objects)
	ld65 -C liveoak.cfg -o kernel $(objects)

%.o : %.s
	ca65 --cpu 65c02 $<

.PHONY : clean
clean :
	rm kernel $(objects)
