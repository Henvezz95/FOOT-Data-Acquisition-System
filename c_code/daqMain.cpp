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


int main(int argc, char* argv[]) {

  FPGAio fpga;
  int rc, idx,nmax;
  nmax=20000000;
  std::vector<uint32_t> evt;
  
  if( argc>1 ) fpga.setVerbosity(argc-1);
  
  printf("Fifo Reading SOC!\n");
  
  rc = fpga.openMem();
  if( rc<0 ){
    printf("Closing prog\n");
	return 1;
  }

  printf("Set LEDs\n");
  // toggle the LEDs a bit
  for(idx=0; idx<8; idx++){
	fpga.setLEDs(1<<idx);
	usleep(500*1000);
  }
  fpga.setLEDs(0);

  printf("Print status\n");
  fpga.printStatus();
  
  printf(" test fifo regs registers\n");
  fpga.printFifoStatus();
  
  printf(" Cleaning output fifo\n");
  fpga.cleanUpOFifo();
  fpga.cleanUpORegFifo();
  fpga.cleanUpOFifo();
  fpga.cleanUpORegFifo();
  fpga.printFifoStatus();

  printf("\n\n Check firmware \n");
  uint32_t fwver = fpga.ReadReg(16);
  printf("Firmware version: %x\n", fwver);
  fpga.printFifoStatus();
  
  printf("\n\n Dumping current registers\n");
  fpga.PrintAllRegs();
  

  printf("\n\n Check current status\n");
  uint32_t status = fpga.ReadReg(17) & 7;
  if( status>7 ){
	printf("Error reading register 16!!\n");
    fpga.PrintAllRegs();
	fpga.closeMem();	
	return 1;
  }
    
  while( status!=1){
	if( status==0){
	  fpga.sendGoTo(IdleToConfig);
    } else if( status==3){
	  fpga.sendGoTo(RunToConfig);
    } else  if( status==5){
      fpga.cleanUpOFifo();
	} else {
	  printf("waiting for a status change \n");
      sleep(1);
	}
	usleep(100);
	status = fpga.ReadReg(17) & 0x7;	
  }

  fpga.sendWriteReg(2,0x00eade00);
  fpga.sendWriteReg(4,0x44);

  printf("Start with SW0=0 and SW3=0\n");
  
  //wait for the right combination of switches
  int sw= fpga.getSwitches();
  while( (sw&9)!=0 ){
	if( (sw&8)==8 ){
      printf("Got reset; closing \n");
  	  rc = fpga.closeMem();	
  	  return( rc );
	}
	// wait 2.0 s
	usleep( 2000*1000 );
	// read switch
    sw= fpga.getSwitches();
    fpga.printStatus();
    fpga.printFifoStatus();
  }

  
  printf("\n\nReading all regs\n\n");
  fpga.PrintAllRegs();
  fpga.printFifoStatus();

  //
  printf("\n\nGo to run mode\n\n");
  fpga.sendGoTo(ConfigToRun);
  sleep(1);
  fpga.printFifoStatus();
  int events = 0,counts=0;  
  int wordsread = 0;
  time_t start,stop;
  time(&start);
  bool printdone=false;
  while(nmax>0){
    sw= fpga.getSwitches();
	if( (counts%1000)==1 ) fpga.printStatus();
	if( (sw&8)==8 ) break;
//	if( (sw&1)==1 ){  //here there is a running condition
	  if( fpga.OFifoEmpty() || (fpga.getOFifoStatus()&0xffff)==0 ){
		// no action... or just print FIFO status??
		counts++;
        usleep(20*1000);  // 0.02 s sleep
		if( (counts%1000)==0 ) fpga.printFifoStatus();			
  	    if( (events%10)==0 && fpga.OFifoRegEmpty() && !printdone){
          fpga.PrintAllRegs();	
		  printdone=true;
		}
	  } else  {
  	    printdone=false;
		counts = 0;
		// here an event is waiting for us!!
        fpga.readOfifo(evt);
		events++;
		if(evt.size()>0 && evt.size()==evt[0] && evt[1]==0xEADEBABA ){
  		  printf("Correct reading of event %d \n",events);	
		}
		wordsread += evt.size();
		evt.erase(evt.begin(),evt.end());
	  }
	/* } else {
	  printf("Turn on SW0 if you want to READ DATA \n");	
		// no action... or just print FIFO status??
      usleep(2500*1000);  // 2.5 s sleep
  	  fpga.printFifoStatus();
	} */
	
  }
  time(&stop);
  double diff = difftime(stop,start);
  if( diff<1) diff=1.;
  double rate=wordsread*4/diff;
  printf("Read %d events, %d words in %f seconds for a rate of %f\n", events, wordsread, diff, rate);

  printf("\n\nGo to config mode\n\n");
  fpga.sendGoTo(RunToConfig);
  printf("\n\nGo to Idle mode\n\n");
  fpga.sendGoTo(ConfigToIdle);

  // clean up our memory mapping and exit
	
  printf("Got reset; closing \n");
  fpga.closeMem();	

  return( rc );
}



/************* OLD CODE *************/

// uint32_t fifoData(struct Fpga_regs *reg){
  // return *(reg->fifodata_p);
// }

// uint32_t fifoReg(struct Fpga_regs *reg){
  // return *(reg->fifostatus_p);
// }

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
/*
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

*/