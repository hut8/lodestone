lodestone: lodestone.o condition.o
	gcc -m32 condition.o lodestone.o -o lodestone

condition.o: condition.c
	gcc -g -Wall -m32 -c condition.c

lodestone.o: lodestone.s
	nasm -f elf -g -Wall lodestone.s

clean:
	rm -vf lodestone.o lodestone condition.o
