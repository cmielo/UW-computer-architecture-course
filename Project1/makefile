CC       	= gcc
CFLAGS   	= -Wall -Wextra -Wno-implicit-fallthrough -std=gnu17 -fPIC -O2
MEMORYFLAGS = -std=gnu17 -fPIC
LDFLAGS  	= -shared -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=reallocarray -Wl,--wrap=free -Wl,--wrap=strdup -Wl,--wrap=strndup

.PHONY: all example clean

all: libnand.so

nand.o: nand.c nand.h linked_list.h

linked_list.o: linked_list.c linked_list.h nand.h

memory_tests.o: memory_tests.c memory_tests.h
	$(CC) $(MEMORYFLAGS) $< -c -o $@

nand_example.o: nand_example.c nand.h memory_tests.h

libnand.so: nand.o linked_list.o memory_tests.o
	$(CC) $(LDFLAGS) $^ -o $@
	rm nand.o linked_list.o memory_tests.o

example: nand_example.o libnand.so
	$(CC) -L. $< -lnand -o $@
	rm nand_example.o

clean:
	rm -rf example libnand.so *.o