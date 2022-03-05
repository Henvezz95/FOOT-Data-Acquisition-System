//
//
#ifndef FPGASOC
#define FPGASOC


#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "socal/alt_gpio.h"
#include "hps_0.h"
#include <vector>

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )
#define IOFIFOSCONTROL_BASE ( IOFIFOSCONTROL_0_BASE )

const int IdleToConfig=0;
const int ConfigToRun=1;
const int RunToConfig=2;
const int ConfigToIdle=3;

const int Header_ChangeState = 0xEADE0080;
const int Header_ReadRegs = 0xEADE0081;	//-- Read registers from register file --
const int Header_WriteRegs = 0xEADE0082;//-- Write registers from register file --
const int Header_ResetRegs = 0xEADE0083;//-- Reset Registers of the register file --
const int Instructon_Footer = 0xF00E0099; //-- Footer for the Ethernet instructons --

class FPGAio {
  public:
	FPGAio();
	~FPGAio();
  
	int openMem(); // open memory device
	int closeMem();	// clean up our memory mapping
  
	// getters
	uint32_t getSwitches() {return *sw_p;};
	uint32_t getKeys() {return *key_p;};
	uint32_t getLEDs() {return *led_p;};
	// getters fifo
	uint32_t getIFifoStatus() {return *(iofifo_p+1);};
	uint32_t getOFifoData() {return *(iofifo_p+2);};
	uint32_t getOFifoStatus() {return *(iofifo_p+3);};
	uint32_t getOFifoRegData() {return *(iofifo_p+4);};
	uint32_t getOFifoRegStatus() {return *(iofifo_p+5);};
	// get file descriptor (-1 = error)
	uint32_t getFileDesc() const {return fd;};
	int getVerbosity() const { return verbosity;};

	// setters 
	void setLEDs(uint32_t value) { *led_p = value;};
	void setIFifoData(uint32_t value) { *iofifo_p = value;}
	void setVerbosity(int verb) { verbosity=verb;};
	
	// other
	void printStatus();
	void printFifoStatus();

    // elaboration
	bool OFifoEmpty(){ return (getOFifoStatus()>>16)&1;};
	bool OFifoRegEmpty(){ return (getOFifoRegStatus()>>16)&1;};
	bool FifoEmpty(uint32_t fifostatus){ return (fifostatus>>16)&1;};
	unsigned int OFifoWords(){ return (getOFifoStatus()&0xffff);};
	unsigned int OFifoRegWords(){ return (getOFifoRegStatus()&0xffff);};
	unsigned int IFifoWords(){ return (getIFifoStatus()&0xffff);};
	unsigned int FifoWords(uint32_t fifostatus){ return (fifostatus&0xffff);};
	// commands
	void sendReadAllRegs();
	void sendReadReg(int reg);
	void sendWriteReg(int reg, int value);
	void sendGoTo(int stat);
	void cleanUpOFifo();
	void cleanUpORegFifo();
	void readOfifo(std::vector<uint32_t> & data);
	void readORegfifo(std::vector<uint32_t> & data);
	void PrintAllRegs();
	void ReadAllRegs();
	uint32_t ReadReg(int reg);

  
  private:
  
	void *virtual_base;
	volatile uint32_t * led_p;
	volatile uint32_t * key_p;
	volatile uint32_t * sw_p;
	volatile uint32_t * fifodata_p;
	volatile uint32_t * fifostatus_p;
	volatile uint32_t * fiforeadack_p;
	volatile uint32_t * iofifo_p;
	int fd;
	int verbosity;
    uint32_t regs[32]; // a local copy of the FPGA registers
};

#endif
