objects = basic.o

basic : $(objects)
	ld65 -C liveoak-ram.cfg -o basic -m basic.map $(objects)

%.o : %.s
	ca65 --cpu 65c02 $<

.PHONY : clean
clean :
	rm basic $(objects)
