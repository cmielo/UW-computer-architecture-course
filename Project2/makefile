CC       	= gcc
CFLAGS   	= -Wall -Wextra -std=c17 -g -O2

.PHONY: all clean

all: mdiv_example

mdiv_example.o: mdiv_example.c

mdiv.o:
	nasm -f elf64 -w+all -w+error -g -o mdiv.o mdiv.asm

mdiv_example: mdiv_example.o mdiv.o
	gcc -z noexecstack -g -o mdiv_example mdiv_example.o mdiv.o

clean:
	rm -rf mdiv_example *.o
