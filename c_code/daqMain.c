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
#incl

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )


struct Fpga_regs {
  void *virtual_base;
  volatile uint32_t * led_p;
  volatile uint32_t * key_p;
  volatile uint32_t * sw_p;
  volatile uint32_t * fifodata_p;
  volatile uint32_t * fifostatus_p;
  volatile uint32_t * fiforeadack_p;
  int fd;
};

// open memory device and assign register pointers
// return -1 in case of errors
int openMem(struct Fpga_regs *reg){
  // map the address space for the LED registers into user space so we can interact with them.
  // we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span

  printf("open /dev/mem \n");
  if( ( reg->fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
	printf( "ERROR: could not open \"/dev/mem\"...\n" );
	return( -1 );
  }

  printf("mmap  \n");
  reg->virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, reg->fd, HW_REGS_BASE );

  if( reg->virtual_base == MAP_FAILED ) {
	printf( "ERROR: mmap() failed...\n" );
	close( reg->fd );
	return( -1 );
  }

  printf("define pointers  \n");
  //  HERE ALL THE DEFINITION OF POINTERS. To be checked!!
  reg->led_p = (uint32_t *) (reg->virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + LED_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  reg->key_p = (uint32_t *) (reg->virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + BUTTON_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  reg->sw_p  = (uint32_t *) (reg->virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + DIPSW_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  reg->fifodata_p = (uint32_t *) (reg->virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFODATA_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  reg->fifostatus_p = (uint32_t *) (reg->virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFOREG_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  reg->fiforeadack_p = (uint32_t *) (reg->virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFOREADACK_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  
  printf("end openMem  \n");

  return reg->fd;
}

int closeMem(struct Fpga_regs *reg){
  // clean up our memory mapping
	
  if( munmap( reg->virtual_base, HW_REGS_SPAN ) != 0 ) {
	printf( "ERROR: munmap() failed...\n" );
	close( reg->fd );
	return 1 ;
  }

  close( reg->fd );
  return 0 ;
}

void printStatus(struct Fpga_regs *reg){
  static int oldsw=-1, oldkey=-1;
  char p[11];
  int sw, key;
  printf("printStatus  \n");
  sw=*reg->sw_p;
  key=*reg->key_p;
  if( sw!=oldsw || key!=oldkey){
    strncpy(p," ******* ",10); 
  } else {
	strncpy(p, "\0",10);
  }
  oldsw = sw;
  oldkey = key;
  printf("Switches: S0=%d, S1=%d, S2=%d, S3=%d -- Keys= K0=%d, K1=%d   - %s \n", sw&1, (sw>>1)&1, (sw>>2)&1, (sw>>3)&1, key&1, (key>>1)&1, p);
}


uint32_t fifoData(struct Fpga_regs *reg){
  return *(reg->fifodata_p);
}

uint32_t fifoReg(struct Fpga_regs *reg){
  return *(reg->fifostatus_p);
}

bool fifoEmpty(struct Fpga_regs *reg){
  int fifostatus;
  fifostatus=fifoReg(reg);
  return (fifostatus>>16)&1;
}

uint32_t fifoReadAck(struct Fpga_regs *reg){
  static uint32_t val =1;
  val++;
  *(reg->fiforeadack_p) = val;
  return val;
}

void printFifoStatus(struct Fpga_regs *reg){
  int fifreg;
  fifreg=fifoReg(reg);
  printf("Fifo reg: %08x,  %d stored words,  empty=%d, almost full=%d, full=%d \n", fifreg, (fifreg&0xfff), (fifreg>>16)&1, (fifreg>>17)&1, (fifreg>>18)&1);
}

void testFifoRegs(struct Fpga_regs *reg){
  int ix;

  printf("Testing Fifo Regs\n");
  sleep(1);
  for(ix=0; ix<4; ix++){
    printf("Cycle: %d\n", ix);
    printf("Reading data     %08x\n", fifoData(reg));
	printf("Reading status   %08x\n", fifoReg(reg));
	printf("Writing read ack %08x\n", fifoReadAck(reg));
    sleep(1);
  }
}



void measurePerf(struct Fpga_regs *reg){
  int ntot=0;
  int reads=0;
  time_t start;
  time_t stop;
  int sw= *(reg->sw_p);
  start = time(NULL);
  while((sw&3)==3){
	reads =0;
	ntot = 0;
    start = time(NULL);
	while( !fifoEmpty(reg) && reads<20000){
  	  int n=fifoReg(reg)&0xfff;
	  int idx;
	  for(idx=0; idx<n; idx++){
		fifoData(reg);
        fifoReadAck(reg);			  
 	  }
      reads++;
	  ntot += n;
	}
	stop = time(NULL);
	double diff = difftime(stop, start);
	double rate=ntot*4.0/diff/1000000.0; // Units are MB/s
	printf(" Reads: %d, words read: %d,  time= %f, transfer rate: %f MB/s \n",reads, ntot,diff, rate);
    printFifoStatus(reg);		
    //usleep(1000*1000);  // 1.0 s sleep	  
	sw= *(reg->sw_p); 
  }
}


int main() {

  struct Fpga_regs regs;
  int rc, idx,nmax;
  nmax=20000000;
  
  printf("Fifo Reading SOC!\n");
  
  rc = openMem(&regs);
  if( rc<0 ){
    printf("Closing prog\n");
	return 1;
  }

  // toggle the LEDs a bit
  for(idx=0; idx<8; idx++){
	  *regs.led_p = (1<<idx);
	usleep(500*1000);
  }
  *regs.led_p = 0;

  printf("Print status\n");
  printStatus(&regs);
  
  // test fifo resg registers
  testFifoRegs(&regs);
  
  
  printf("Start with SW0=0 and SW3=0\n");

  //wait for the right combination of switches
  int sw= *(regs.sw_p);
  while( (sw&9)!=0 ){
	if( (sw&8)==8 ){
      printf("Got reset; closing \n");
  	  rc = closeMem(&regs);	
  	  return( rc );
	}
	// wait 2.0 s
	usleep( 2000*1000 );
	// read switch
	sw= *regs.sw_p;
    printStatus(&regs);
  }
  
  while(nmax>0){
    sw= *regs.sw_p;
    printStatus(&regs);
	if( (sw&8)==8 ) break;
	if( (sw&2)==2 )
	  measurePerf(&regs);
	if( (sw&1)==1 ){  //here there is a running condition
	  if( fifoEmpty(&regs) || (fifoReg(&regs)&0xfff)==0 ){
		// no action... or just print FIFO status??
        usleep(2000*1000);  // 2.0 s sleep
  	    printFifoStatus(&regs);			
	  } else  {
		// here an event is waiting for us!!
        printFifoStatus(&regs);		
		while( !fifoEmpty(&regs) ){
  		  int n=fifoReg(&regs)&0xfff;
          if( n==0 || nmax <0 ) break;
		  if( n>10 ) n=10;
		  for(idx=0; idx<n; idx++){
			  uint32_t dat= fifoData(&regs);
			  printf("%08x ", dat);			
              fifoReadAck(&regs);			  
              nmax--;
		  }
		  printFifoStatus(&regs);					
 	      if( (sw&8)==8 ) break;
		}
	  }
	} else {
	  printf("Turn on SW0 if you want to trigger \n");	
		// no action... or just print FIFO status??
      usleep(2500*1000);  // 2.5 s sleep
  	  printFifoStatus(&regs);
	}
	
  }
  

  // clean up our memory mapping and exit
	
  printf("Got reset; closing \n");
  rc = closeMem(&regs);	

  return( rc );
}
