//
//
//
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include "FPGASoc.h"


FPGAio::FPGAio(){
  fd = -1;
  for(int i=0; i<32; i++) regs[i]= 0xffffffff;
}

FPGAio::~FPGAio(){
  if( fd>-1 ) 
	closeMem();
  fd = -1;
}

// open memory device and assign register pointers
// return -1 in case of errors
int FPGAio::openMem(){
  // map the address space for the LED registers into user space so we can interact with them.
  // we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span

  printf("open /dev/mem \n");
  if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
	printf( "ERROR: could not open \"/dev/mem\"...\n" );
	fd = -1;
	return( -1 );
  }

  printf("mmap  \n");
  virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );

  if( virtual_base == MAP_FAILED ) {
	printf( "ERROR: mmap() failed...\n" );
	close( fd );
	fd = -1;
	return( -1 );
  }

  printf("define pointers  \n");
  //  HERE ALL THE DEFINITION OF POINTERS. To be checked!!
  led_p = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + LED_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  key_p = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + BUTTON_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  sw_p  = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + DIPSW_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  fifodata_p = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFODATA_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  fifostatus_p = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFOREG_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  fiforeadack_p = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFOREADACK_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  iofifo_p = (uint32_t *)(((char *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + IOFIFOSCONTROL_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  
  printf("end openMem  \n");

  return fd;
}

int FPGAio::closeMem(){
  // clean up our memory mapping
	
  if( munmap( virtual_base, HW_REGS_SPAN ) != 0 ) {
	printf( "ERROR: munmap() failed...\n" );
	close( fd );
	return 1 ;
  }

  close( fd );
  fd = -1;
  return 0 ;
}

void FPGAio::printStatus(){
  static uint32_t oldsw=-1, oldkey=-1;
  char p[11];
  uint32_t sw, key;
  printf("printStatus  \n");
  sw =getSwitches();
  key = getKeys();
  if( sw!=oldsw || key!=oldkey){
    strncpy(p," ******* ",10); 
  } else {
	strncpy(p, "\0",10);
  }
  oldsw = sw;
  oldkey = key;
  printf("Switches: S0=%d, S1=%d, S2=%d, S3=%d -- Keys= K0=%d, K1=%d   - %s \n", sw&1, (sw>>1)&1, (sw>>2)&1, (sw>>3)&1, key&1, (key>>1)&1, p);
}


void FPGAio::printFifoStatus(){
  int fifreg;
  fifreg=getIFifoStatus();
  printf("Input    Fifo reg: %08x,  %d stored words,  empty=%d, almost full=%d, full=%d \n", fifreg, (fifreg&0xfff), (fifreg>>16)&1, (fifreg>>17)&1, (fifreg>>18)&1);
  fifreg=getOFifoStatus();
  printf("Output   Fifo reg: %08x,  %d stored words,  empty=%d, almost full=%d, full=%d \n", fifreg, (fifreg&0xfff), (fifreg>>16)&1, (fifreg>>17)&1, (fifreg>>18)&1);
  fifreg=getOFifoRegStatus();
  printf("Register Fifo reg: %08x,  %d stored words,  empty=%d, almost full=%d, full=%d \n", fifreg, (fifreg&0xfff), (fifreg>>16)&1, (fifreg>>17)&1, (fifreg>>18)&1);
}


//          COMMANDS

	// commands
void FPGAio::sendReadAllRegs(){
  unsigned int nreg = 27;
  setIFifoData(nreg+3);
  setIFifoData(Header_ReadRegs);
  for(unsigned int i=0; i<nreg; i++)
    setIFifoData(i);
  setIFifoData(Instructon_Footer);  
}

void FPGAio::sendReadReg(int reg){
  setIFifoData(4);
  setIFifoData(Header_ReadRegs);
  setIFifoData(reg);  
  setIFifoData(Instructon_Footer); 
}

void FPGAio::sendWriteReg(int reg, int value){
  setIFifoData(5);
  setIFifoData(Header_WriteRegs);
  setIFifoData(reg);  
  setIFifoData(value);  
  setIFifoData(Instructon_Footer);    
}

void FPGAio::sendGoTo(int stat){
  setIFifoData(4);
  setIFifoData(Header_ChangeState);
  setIFifoData(stat&3);  
  setIFifoData(Instructon_Footer);  
}

void FPGAio::cleanUpOFifo(){
  while( !OFifoEmpty() ){
    int n=OFifoWords();
	for(int idx=0; idx<n; idx++){
	  getOFifoData();
	}
	usleep(20);
  }
}

void FPGAio::cleanUpORegFifo(){
  while( !OFifoRegEmpty() ){
    int n=OFifoRegWords();
	for(int idx=0; idx<n; idx++){
	  getOFifoRegData();
	}
	usleep(20);
  }
}

void FPGAio::readOfifo(std::vector<uint32_t> & data){
  int nmax = 2000;
  if( verbosity>1 ) printFifoStatus();		
  //usleep(1000); // just for this moment 1ms delay!
  while( !OFifoEmpty() ){
    int n=getOFifoStatus()&0xfff;
    if( n==0 || nmax <0 ) break;
	if( n>10 ) n=10;
	for(int idx=0; idx<n; idx++){
	  uint32_t dat= getOFifoData();
	  if( verbosity>0 ) printf("%08x ", dat);			
      nmax--;
	  data.push_back(dat);
	}
    if( verbosity>0 ) printf("\n");			
  }
  if( verbosity>0 ) printFifoStatus();					
}

void FPGAio::readORegfifo(std::vector<uint32_t> & data){
  int nmax = 2000;
  if( verbosity>1 ) printFifoStatus();		
  usleep(1000); // just for this moment 1ms delay!
  while( !OFifoRegEmpty() ){
    int n=getOFifoRegStatus()&0xfff;
    if( n==0 || nmax <0 ) break;
	if( n>10 ) n=10;
	for(int idx=0; idx<n; idx++){
	  uint32_t dat= getOFifoRegData();
	  if( verbosity>0 ) printf("%08x ", dat);			
      nmax--;
	  data.push_back(dat);
	}
    if( verbosity>0 ) printf("\n");			
  }
  if( verbosity>0 ) printFifoStatus();					
}

void FPGAio::PrintAllRegs(){
	
  std::vector<uint32_t> data;

  printf("\n\nReading all regs\n\n");
  sendReadAllRegs();
  readORegfifo(data);

  
  if( verbosity>0 ){
    printf("Message: \n");			
    for( unsigned int i=0;i<data.size(); i++){
      printf("%08x ", data[i]);
    }
    printf("\n");			
  }
  
  if(data.size()>20 && data[2]==0xEADE2020 && data[3]==0xEADE2121){
    printf("Size and headers ok\n");			  
  }
//  int regs= (data.size()-6)/2;
  for( unsigned int i=4;i<data.size()-4; i+=2){
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
	case 10:
	case 11:
	case 12:
	case 13:
	case 14:
	case 15:
	  printf("%2d - Control reg not used : %08x\n",rg,val);
	  break;
	case 16:
	  printf("%2d - Monitor reg FIRMWARE VERSION : %08x\n",rg,val);
	  break;
	case 17:
	  printf("%2d - Monitor reg FSM : %08x  ",rg,val);
	  switch (val&0x7){
	  case 0: printf(" IDLE"); break;
	  case 1: printf(" CONFIG"); break;
	  case 2: printf(" PREPAREFORRUN"); break;
	  case 3: printf(" RUN"); break;
	  case 4: printf(" ENDOFRUN"); break;
	  case 5: printf(" WAITINGEMPTYFIFO"); break;
	  default: printf(" UNKNOWN STATE"); break;
	  };
	  if(val&0x10000000) printf(" DAQIsRunning ");
	  if(val&0x8000000) printf(" DAQReset ");
	  if(val&0x4000000) printf(" DAQConfig ");
	  if(val&0x2000000) printf(" DAQReading ");
	  printf("\n");
	  break;
	case 18:
	  printf("%2d - Monitor reg DAQ errors : %08x\n",rg,val);
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
	case 26:
	  printf("%2d - Monitor reg TX Reg FIFO status %08x\n",rg,val);
	  break;
	default:
	  printf("%2d - UNKNOWN : %08x\n",rg,val);
	  break;
	}
  }
}

void FPGAio::ReadAllRegs(){
  std::vector<uint32_t> data;
  cleanUpOFifo();
  sendReadAllRegs();
  usleep(20);
  readORegfifo(data);

  if(data.size()>20 && data[2]==0xEADE2020 && data[3]==0xEADE2121){
    for( unsigned int i=4;i<data.size()-4; i+=2){
	  int rg = data[i];
	  int val = data[i+1];
	  regs[rg]=val;
	}
  } else {
	printf("Error reading all registers \n");
  }
}

uint32_t FPGAio::ReadReg(int reg){
  std::vector<uint32_t> data;
  cleanUpORegFifo();
  sendReadReg(reg);
  usleep(20);
  readORegfifo(data);
  if(data.size()>4 && data[2]==0xEADE2020 && data[3]==0xEADE2121 && data[4]==(uint32_t)reg){
    int val = data[5];
	regs[reg]=val;
  } else {
	printf("Error reading reg %d\n",reg);
	regs[reg]=0xffffffff;
  }
  return regs[reg];
}
