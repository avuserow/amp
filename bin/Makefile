CC = gcc
CCOPTS = -g -Wall `taglib-config --cflags`
LINKOPTS = -ltag

all: tagreader

tagreader:
	$(CC) $(CCOPTS) $(LINKOPTS) -o $@ tagreader.cpp

clean:
	rm -f tagreader
