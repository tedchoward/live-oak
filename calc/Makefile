all: calc

calc:  calc.o
	ld65 -C liveoak-ram.cfg -o $@ -m calc.map calc.o

%.o : %.s
	ca65 --cpu 65c02 $<

.PHONY : all clean
clean :
	-rm calc calc.o calc.map
