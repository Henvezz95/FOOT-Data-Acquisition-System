#
TARGET = DAQMain

#
CROSS_COMPILE = arm-linux-gnueabihf-
CFLAGS = -static -g -Wall  -I${SOCEDS_DEST_ROOT}/ip/altera/hps/altera_hps/hwlib/include
CXXFLAGS = -static -std=c++11 -g -Wall  -I${SOCEDS_DEST_ROOT}/ip/altera/hps/altera_hps/hwlib/include
LDFLAGS =  -g -Wall  
CC = $(CROSS_COMPILE)gcc
CXX = $(CROSS_COMPILE)g++
ARCH= arm


build: $(TARGET)
$(TARGET): daqMain.o FPGASoc.o
	$(CXX) $(LDFLAGS)   $^ -o $@  
build: DAQMain2
DAQMain2: daqMain2.o FPGASoc.o
	$(CXX) $(LDFLAGS)   $^ -o $@  
Dumper: Dumper.o FPGASoc.o
	$(CXX) $(LDFLAGS)   $^ -o $@  
daqMain.o : daqMain.cpp FPGASoc.h hps_0.h
	$(CXX) $(CXXFLAGS) -c $< -o $@
daqMain2.o : daqMain2.cpp FPGASoc.h hps_0.h
	$(CXX) $(CXXFLAGS) -c $< -o $@
Dumper.o : Dumper.cpp FPGASoc.h hps_0.h
	$(CXX) $(CXXFLAGS) -c $< -o $@
FPGASoc.o : FPGASoc.cpp FPGASoc.h hps_0.h
	$(CXX) $(CXXFLAGS) -c $< -o $@
%.o : %.c hps_0.h
	$(CC) $(CFLAGS) -c $< -o $@
hps_0.h:
	./generate_hps_qsys_header.sh

.PHONY: clean
clean:
	rm -f $(TARGET) *.a *.o *~ 
