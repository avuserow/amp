CC = g++
CCOPTS = -g -Wall `taglib-config --cflags`
LINKOPTS = -ltag

all: tagreader

tagreader: tagreader.cpp
	$(CC) $(CCOPTS) $(LINKOPTS) -o $@ $<

clean:
	rm -f tagreader
