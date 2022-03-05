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
#include <vector>

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

void readOfifo(FPGAio & fpga, std::vector<uint32_t> & data){
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
	  data.push_back(dat);
	}
    printf("\n");			
  }
  fpga.printFifoStatus();					
}


int main() {

  FPGAio fpga;
  int rc;
  std::vector<uint32_t> data;
  
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

  // delete any data in fifo  
  printf("Cleaning Output fifo");
  while( !OFifoEmpty(fpga) ){
    int n=fpga.getOFifoStatus()&0xfff;
	for(int idx=0; idx<n; idx++){
	  fpga.getOFifoData();
	}
    printf(".");			
  }
  printf("\n");			
  
  printf("\n\nReading all regs\n\n");
  sendReadAll(fpga);
  readOfifo(fpga, data);

  
  printf("Message: \n");			
  for( unsigned int i=0;i<data.size(); i++){
    printf("%08x ", data[i]);
  }
  printf("\n");			
  if(data.size()>20 && data[1]==0xEADE2020 && data[2]==0xEADE2121){
    printf("Size and headers ok\n");			  
  }
//  int regs= (data.size()-6)/2;
  for( unsigned int i=3;i<data.size()-4; i+=2){
	int rg = data[i];
	int val = data[i+1];
	switch (rg){
	case 0:
	  printf(" 0 - Control reg empty: %08x\n",val);
	  break;
	case 1:
	  printf(" 1 - Control reg last FSM command: %d",val);
	  switch (val&3){
	  case 0: printf(" IdleToConfig\n"); break;
	  case 1: printf(" ConfigToRun\n"); break;
	  case 2: printf(" RunToConfig\n"); break;
	  case 3: printf(" ConfigToIdle\n"); break;
	  default: printf(" UNKNOWN STATE\n"); break;
	  };
	  break;
	case 2:
	  printf(" 2 - Control reg Event Builder Header: %08x\n",val);
	  break;
	case 3:
	  printf(" 3 - Control reg Busy Model: %d, %s\n",val,(val? "Busy on 1 event": "Busy on fifo almost full"));
	  break;
	case 4:
	  printf(" 4 - Control reg Duration of ENDOFRUN status: %08x\n",val);
	  break;
	case 5:
	case 6:
	case 7:
	case 8:
	case 9:
	case 11:
	case 12:
	case 13:
	case 14:
	case 15:
	  printf("%2d - Control reg not used : %08x\n",rg,val);
	  break;
	case 10:
	  printf("%2d - Control reg FIRMWARE VERSION : %08x\n",rg,val);
	  break;
	case 16:
	  printf("%2d - Monitor reg FSM : %d ",rg,val);
	  switch (val){
	  case 0: printf(" IDLE\n"); break;
	  case 1: printf(" CONFIG\n"); break;
	  case 2: printf(" PREPAREFORRUN\n"); break;
	  case 3: printf(" RUN\n"); break;
	  case 4: printf(" ENDOFRUN\n"); break;
	  case 5: printf(" WAITINGEMPTYFIFO\n"); break;
	  default: printf(" UNKNOWN STATE\n"); break;
	  };
	  break;
	case 17:
	  printf("%2d - Monitor reg DAQ errors : %08x\n",rg,val);
	  break;
	case 18:
	  printf("%2d - Monitor reg DAQ errors II??: %08x\n",rg,val);
	  break;
	case 19:
	  printf("%2d - Monitor reg Trigger Counter : %8d\n",rg,val);
	  break;
	case 20:
	  printf("%2d - Monitor reg BCOCounter : %08x\n",rg,val);
	  break;
	case 21:
	  printf("%2d - Monitor reg Clock counter MSB: %08x\n",rg,val);
	  break;
	case 22:
	  printf("%2d - Monitor reg Clock counter LSB : %08x\n",rg,val);
	  break;
	case 23:
	  printf("%2d - Monitor reg Event builder FIFO status %08x\n",rg,val);
	  break;
	case 24:
	  printf("%2d - Monitor reg TX FIFO status %08x\n",rg,val);
	  break;
	case 25:
	  printf("%2d - Monitor reg RX FIFO status %08x\n",rg,val);
	  break;
	default:
	  printf("%2d - UNKNOWN : %08x\n",rg,val);
	  break;
	}
  }
  
  
  // clean up our memory mapping and exit
	
  printf("Got reset; closing \n");
  fpga.closeMem();	

  return( rc );
}
