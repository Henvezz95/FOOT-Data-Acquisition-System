//
//
//
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include "FPGASoc.h"


FPGAio::FPGAio(){
	fd = -1;
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
  led_p = (uint32_t *) (virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + LED_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  key_p = (uint32_t *) (virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + BUTTON_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  sw_p  = (uint32_t *) (virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + DIPSW_PIO_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  fifodata_p = (uint32_t *) (virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFODATA_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  fifostatus_p = (uint32_t *) (virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFOREG_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  fiforeadack_p = (uint32_t *) (virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + FIFOREADACK_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  iofifo_p = (((uint32_t *)virtual_base) + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST + IOFIFOCONTROL_BASE ) & ( unsigned long)( HW_REGS_MASK ) ));
  
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

