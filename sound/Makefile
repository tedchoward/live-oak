objects = sound.o

sound : $(objects)
	ld65 -C liveoak-ram.cfg -o sound -m sound.map $(objects)

%.o : %.s
	ca65 --cpu 65c02 $<

.PHONY : clean
clean :
	rm sound $(objects)
