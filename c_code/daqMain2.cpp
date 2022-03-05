#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "socal/alt_gpio.h"
#include "hps_0.h"
#include "FPGASoc.h"

const int IdleToConfig=0;
const int ConfigToRun=1;
const int RunToConfig=2;
const int ConfigToIdle=3;

const int Header_ChangeState = 0xEADE0080;
//-- Read registers from register file --
const int Header_ReadRegs = 0xEADE0081;
//-- Write registers from register file --
const int Header_WriteRegs = 0xEADE0082;
//-- Reset Registers of the register file --
const int Header_ResetRegs = 0xEADE0083;
//-- Footer for the Ethernet instructons --
const int Instructon_Footer = 0xF00E0099; 

// uint32_t fifoData(struct Fpga_regs *reg){
  // return *(reg->fifodata_p);
// }

// uint32_t fifoReg(struct Fpga_regs *reg){
  // return *(reg->fifostatus_p);
// }

bool OFifoEmpty(FPGAio & fpga){
  int fifostatus;
  fifostatus=fpga.getOFifoStatus();
  return (fifostatus>>16)&1;
}

// uint32_t fifoReadAck(struct Fpga_regs *reg){
  // static uint32_t val =1;
  // val++;
  // *(reg->fiforeadack_p) = val;
  // return val;
// }

// void printFifoStatus(struct Fpga_regs *reg){
  // int fifreg;
  // fifreg=fifoReg(reg);
  // printf("Fifo reg: %08x,  %d stored words,  empty=%d, almost full=%d, full=%d \n", fifreg, (fifreg&0xfff), (fifreg>>16)&1, (fifreg>>17)&1, (fifreg>>18)&1);
// }

// void testFifoRegs(struct Fpga_regs *reg){
  // int ix;

  // printf("Testing Fifo Regs\n");
  // sleep(1);
  // for(ix=0; ix<4; ix++){
    // printf("Cycle: %d\n", ix);
    // printf("Reading data     %08x\n", fifoData(reg));
	// printf("Reading status   %08x\n", fifoReg(reg));
	// printf("Writing read ack %08x\n", fifoReadAck(reg));
    // sleep(1);
  // }
// }



// void measurePerf(struct Fpga_regs *reg){
  // int ntot=0;
  // int reads=0;
  // time_t start;
  // time_t stop;
  // int sw= *(reg->sw_p);
  // start = time(NULL);
  // while((sw&3)==3){
	// reads =0;
	// ntot = 0;
    // start = time(NULL);
	// while( !fifoEmpty(reg) && reads<20000){
  	  // int n=fifoReg(reg)&0xfff;
	  // int idx;
	  // for(idx=0; idx<n; idx++){
		// fifoData(reg);
        // fifoReadAck(reg);			  
 	  // }
      // reads++;
	  // ntot += n;
	// }
	// stop = time(NULL);
	// double diff = difftime(stop, start);
	// double rate=ntot*4.0/diff/1000000.0; // Units are MB/s
	// printf(" Reads: %d, words read: %d,  time= %f, transfer rate: %f MB/s \n",reads, ntot,diff, rate);
    // printFifoStatus(reg);		
//    usleep(1000*1000);  // 1.0 s sleep	  
	// sw= *(reg->sw_p); 
  // }
// }


// set read all registers
void sendReadAll(FPGAio & fpga){
  unsigned int nreg = 27;
  printf("Reading all regs\n");
  fpga.printFifoStatus();					
  fpga.setIFifoData(nreg+3);
  fpga.setIFifoData(Header_ReadRegs);
  for(unsigned int i=0; i<nreg; i++){
    fpga.setIFifoData(i);
  }	
  fpga.setIFifoData(Instructon_Footer);  
  fpga.printFifoStatus();					
}

void sendGoTo(int stat, FPGAio &fpga){
  printf("Go to state %d\n",stat);
  fpga.printFifoStatus();					
  fpga.setIFifoData(4);
  fpga.setIFifoData(Header_ChangeState);
  fpga.setIFifoData(stat&3);  
  fpga.setIFifoData(Instructon_Footer);  
  fpga.printFifoStatus();					
}

void sendWriteReg(int reg, int value, FPGAio &fpga){
  printf("Write reg %d with %08x\n",reg, value);
  fpga.printFifoStatus();					
  fpga.setIFifoData(5);
  fpga.setIFifoData(Header_WriteRegs);
  fpga.setIFifoData(reg);  
  fpga.setIFifoData(value);  
  fpga.setIFifoData(Instructon_Footer);  
  fpga.printFifoStatus();					
}

void sendReadReg(int reg, FPGAio &fpga){
  printf("Read reg %d \n",reg);
  fpga.printFifoStatus();					
  fpga.setIFifoData(4);
  fpga.setIFifoData(Header_ReadRegs);
  fpga.setIFifoData(reg);  
  fpga.setIFifoData(Instructon_Footer);  
  fpga.printFifoStatus();					
}

void readOfifo(FPGAio & fpga){
  int nmax = 2000;
  fpga.printFifoStatus();		
  usleep(1000); // just for this moment 1ms delay!
  while( !OFifoEmpty(fpga) ){
    int n=fpga.getOFifoStatus()&0xfff;
    if( n==0 || nmax <0 ) break;
	if( n>10 ) n=10;
	for(int idx=0; idx<n; idx++){
	  uint32_t dat= fpga.getOFifoData();
	  printf("%08x ", dat);			
      nmax--;
	}
    printf("\n");			
  }
  fpga.printFifoStatus();					
}


int main() {

  FPGAio fpga;
  int rc;
  
  
  printf("Fifo Reading SOC!\n");
  
  rc = fpga.openMem();
  if( rc<0 ){
    printf("Closing prog\n");
	return 1;
  }


  printf("Print status\n");
  fpga.printStatus();
  
  // test fifo regs registers
  fpga.printFifoStatus();
  
  
  printf("\n\nReading all regs\n\n");
  sendReadAll(fpga);
  readOfifo(fpga);

  //

  printf("\n\nGo to config mode\n\n");
  sendGoTo(IdleToConfig, fpga);
  sleep(1);
  sendReadAll(fpga);
  sleep(1);
  readOfifo(fpga);
  
  printf("Sleeping\n");  
  sleep(2);
  printf("\n\nAccessing reg 2\n\n");  
  printf("*********** Reading\n");  
  sendReadReg(2,fpga);
  readOfifo(fpga);
  sleep(2);
  printf("************* Writing AA551122\n");  
  sendWriteReg(2,0xaa551122,fpga);
  printf("************ Reading back\n");  
  sendReadReg(2,fpga);
  readOfifo(fpga);
  fpga.printFifoStatus();
  sleep(2);

  printf("************ Read firmware version\n");  
  sendReadReg(26,fpga);
  readOfifo(fpga);
  fpga.printFifoStatus();
  sleep(2);
  readOfifo(fpga);


  
  printf("Go to run mode\n");
  sendGoTo(ConfigToRun, fpga);
  sleep(1);
  fpga.printFifoStatus();
  sendReadAll(fpga);
  fpga.printFifoStatus();
  readOfifo(fpga);
  fpga.printFifoStatus();
  
  
  // clean up our memory mapping and exit
	
  printf("Got reset; closing \n");
  fpga.closeMem();	

  return( rc );
}
