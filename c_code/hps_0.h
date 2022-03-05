#ifndef _ALTERA_HPS_0_H_
#define _ALTERA_HPS_0_H_

/*
 * This file was automatically generated by the swinfo2header utility.
 * 
 * Created from SOPC Builder system 'soc_system' in
 * file '/cygdrive/c/Users/villa/Documenti/Sorgenti/DE0/DE0DAQ/c_code/../soc_system.sopcinfo'.
 */

/*
 * This file contains macros for module 'hps_0' and devices
 * connected to the following masters:
 *   h2f_axi_master
 *   h2f_lw_axi_master
 * 
 * Do not include this header file and another header file created for a
 * different module or master group at the same time.
 * Doing so may result in duplicate macro names.
 * Instead, use the system header file which has macros with unique names.
 */

/*
 * Macros for device 'onchip_memory2_0', class 'altera_avalon_onchip_memory2'
 * The macros are prefixed with 'ONCHIP_MEMORY2_0_'.
 * The prefix is the slave descriptor.
 */
#define ONCHIP_MEMORY2_0_COMPONENT_TYPE altera_avalon_onchip_memory2
#define ONCHIP_MEMORY2_0_COMPONENT_NAME onchip_memory2_0
#define ONCHIP_MEMORY2_0_BASE 0x0
#define ONCHIP_MEMORY2_0_SPAN 65536
#define ONCHIP_MEMORY2_0_END 0xffff
#define ONCHIP_MEMORY2_0_ALLOW_IN_SYSTEM_MEMORY_CONTENT_EDITOR 0
#define ONCHIP_MEMORY2_0_ALLOW_MRAM_SIM_CONTENTS_ONLY_FILE 0
#define ONCHIP_MEMORY2_0_CONTENTS_INFO ""
#define ONCHIP_MEMORY2_0_DUAL_PORT 0
#define ONCHIP_MEMORY2_0_GUI_RAM_BLOCK_TYPE AUTO
#define ONCHIP_MEMORY2_0_INIT_CONTENTS_FILE soc_system_onchip_memory2_0
#define ONCHIP_MEMORY2_0_INIT_MEM_CONTENT 1
#define ONCHIP_MEMORY2_0_INSTANCE_ID NONE
#define ONCHIP_MEMORY2_0_NON_DEFAULT_INIT_FILE_ENABLED 0
#define ONCHIP_MEMORY2_0_RAM_BLOCK_TYPE AUTO
#define ONCHIP_MEMORY2_0_READ_DURING_WRITE_MODE DONT_CARE
#define ONCHIP_MEMORY2_0_SINGLE_CLOCK_OP 0
#define ONCHIP_MEMORY2_0_SIZE_MULTIPLE 1
#define ONCHIP_MEMORY2_0_SIZE_VALUE 65536
#define ONCHIP_MEMORY2_0_WRITABLE 1
#define ONCHIP_MEMORY2_0_MEMORY_INFO_DAT_SYM_INSTALL_DIR SIM_DIR
#define ONCHIP_MEMORY2_0_MEMORY_INFO_GENERATE_DAT_SYM 1
#define ONCHIP_MEMORY2_0_MEMORY_INFO_GENERATE_HEX 1
#define ONCHIP_MEMORY2_0_MEMORY_INFO_HAS_BYTE_LANE 0
#define ONCHIP_MEMORY2_0_MEMORY_INFO_HEX_INSTALL_DIR QPF_DIR
#define ONCHIP_MEMORY2_0_MEMORY_INFO_MEM_INIT_DATA_WIDTH 64
#define ONCHIP_MEMORY2_0_MEMORY_INFO_MEM_INIT_FILENAME soc_system_onchip_memory2_0

/*
 * Macros for device 'sysid_qsys', class 'altera_avalon_sysid_qsys'
 * The macros are prefixed with 'SYSID_QSYS_'.
 * The prefix is the slave descriptor.
 */
#define SYSID_QSYS_COMPONENT_TYPE altera_avalon_sysid_qsys
#define SYSID_QSYS_COMPONENT_NAME sysid_qsys
#define SYSID_QSYS_BASE 0x10000
#define SYSID_QSYS_SPAN 8
#define SYSID_QSYS_END 0x10007
#define SYSID_QSYS_ID 2899645186
#define SYSID_QSYS_TIMESTAMP 1496680748

/*
 * Macros for device 'led_pio', class 'altera_avalon_pio'
 * The macros are prefixed with 'LED_PIO_'.
 * The prefix is the slave descriptor.
 */
#define LED_PIO_COMPONENT_TYPE altera_avalon_pio
#define LED_PIO_COMPONENT_NAME led_pio
#define LED_PIO_BASE 0x10040
#define LED_PIO_SPAN 16
#define LED_PIO_END 0x1004f
#define LED_PIO_BIT_CLEARING_EDGE_REGISTER 0
#define LED_PIO_BIT_MODIFYING_OUTPUT_REGISTER 0
#define LED_PIO_CAPTURE 0
#define LED_PIO_DATA_WIDTH 8
#define LED_PIO_DO_TEST_BENCH_WIRING 0
#define LED_PIO_DRIVEN_SIM_VALUE 0
#define LED_PIO_EDGE_TYPE NONE
#define LED_PIO_FREQ 50000000
#define LED_PIO_HAS_IN 0
#define LED_PIO_HAS_OUT 1
#define LED_PIO_HAS_TRI 0
#define LED_PIO_IRQ_TYPE NONE
#define LED_PIO_RESET_VALUE 0

/*
 * Macros for device 'dipsw_pio', class 'altera_avalon_pio'
 * The macros are prefixed with 'DIPSW_PIO_'.
 * The prefix is the slave descriptor.
 */
#define DIPSW_PIO_COMPONENT_TYPE altera_avalon_pio
#define DIPSW_PIO_COMPONENT_NAME dipsw_pio
#define DIPSW_PIO_BASE 0x10080
#define DIPSW_PIO_SPAN 16
#define DIPSW_PIO_END 0x1008f
#define DIPSW_PIO_IRQ 0
#define DIPSW_PIO_BIT_CLEARING_EDGE_REGISTER 1
#define DIPSW_PIO_BIT_MODIFYING_OUTPUT_REGISTER 0
#define DIPSW_PIO_CAPTURE 1
#define DIPSW_PIO_DATA_WIDTH 4
#define DIPSW_PIO_DO_TEST_BENCH_WIRING 0
#define DIPSW_PIO_DRIVEN_SIM_VALUE 0
#define DIPSW_PIO_EDGE_TYPE ANY
#define DIPSW_PIO_FREQ 50000000
#define DIPSW_PIO_HAS_IN 1
#define DIPSW_PIO_HAS_OUT 0
#define DIPSW_PIO_HAS_TRI 0
#define DIPSW_PIO_IRQ_TYPE EDGE
#define DIPSW_PIO_RESET_VALUE 0

/*
 * Macros for device 'button_pio', class 'altera_avalon_pio'
 * The macros are prefixed with 'BUTTON_PIO_'.
 * The prefix is the slave descriptor.
 */
#define BUTTON_PIO_COMPONENT_TYPE altera_avalon_pio
#define BUTTON_PIO_COMPONENT_NAME button_pio
#define BUTTON_PIO_BASE 0x100c0
#define BUTTON_PIO_SPAN 16
#define BUTTON_PIO_END 0x100cf
#define BUTTON_PIO_IRQ 1
#define BUTTON_PIO_BIT_CLEARING_EDGE_REGISTER 1
#define BUTTON_PIO_BIT_MODIFYING_OUTPUT_REGISTER 0
#define BUTTON_PIO_CAPTURE 1
#define BUTTON_PIO_DATA_WIDTH 4
#define BUTTON_PIO_DO_TEST_BENCH_WIRING 0
#define BUTTON_PIO_DRIVEN_SIM_VALUE 0
#define BUTTON_PIO_EDGE_TYPE FALLING
#define BUTTON_PIO_FREQ 50000000
#define BUTTON_PIO_HAS_IN 1
#define BUTTON_PIO_HAS_OUT 0
#define BUTTON_PIO_HAS_TRI 0
#define BUTTON_PIO_IRQ_TYPE EDGE
#define BUTTON_PIO_RESET_VALUE 0

/*
 * Macros for device 'fifodata', class 'altera_avalon_pio'
 * The macros are prefixed with 'FIFODATA_'.
 * The prefix is the slave descriptor.
 */
#define FIFODATA_COMPONENT_TYPE altera_avalon_pio
#define FIFODATA_COMPONENT_NAME fifodata
#define FIFODATA_BASE 0x10200
#define FIFODATA_SPAN 16
#define FIFODATA_END 0x1020f
#define FIFODATA_BIT_CLEARING_EDGE_REGISTER 0
#define FIFODATA_BIT_MODIFYING_OUTPUT_REGISTER 0
#define FIFODATA_CAPTURE 0
#define FIFODATA_DATA_WIDTH 32
#define FIFODATA_DO_TEST_BENCH_WIRING 0
#define FIFODATA_DRIVEN_SIM_VALUE 0
#define FIFODATA_EDGE_TYPE NONE
#define FIFODATA_FREQ 50000000
#define FIFODATA_HAS_IN 1
#define FIFODATA_HAS_OUT 0
#define FIFODATA_HAS_TRI 0
#define FIFODATA_IRQ_TYPE NONE
#define FIFODATA_RESET_VALUE 0

/*
 * Macros for device 'fiforeg', class 'altera_avalon_pio'
 * The macros are prefixed with 'FIFOREG_'.
 * The prefix is the slave descriptor.
 */
#define FIFOREG_COMPONENT_TYPE altera_avalon_pio
#define FIFOREG_COMPONENT_NAME fiforeg
#define FIFOREG_BASE 0x10220
#define FIFOREG_SPAN 16
#define FIFOREG_END 0x1022f
#define FIFOREG_BIT_CLEARING_EDGE_REGISTER 0
#define FIFOREG_BIT_MODIFYING_OUTPUT_REGISTER 0
#define FIFOREG_CAPTURE 0
#define FIFOREG_DATA_WIDTH 32
#define FIFOREG_DO_TEST_BENCH_WIRING 0
#define FIFOREG_DRIVEN_SIM_VALUE 0
#define FIFOREG_EDGE_TYPE NONE
#define FIFOREG_FREQ 50000000
#define FIFOREG_HAS_IN 1
#define FIFOREG_HAS_OUT 0
#define FIFOREG_HAS_TRI 0
#define FIFOREG_IRQ_TYPE NONE
#define FIFOREG_RESET_VALUE 0

/*
 * Macros for device 'fiforeadack', class 'altera_avalon_pio'
 * The macros are prefixed with 'FIFOREADACK_'.
 * The prefix is the slave descriptor.
 */
#define FIFOREADACK_COMPONENT_TYPE altera_avalon_pio
#define FIFOREADACK_COMPONENT_NAME fiforeadack
#define FIFOREADACK_BASE 0x10240
#define FIFOREADACK_SPAN 16
#define FIFOREADACK_END 0x1024f
#define FIFOREADACK_BIT_CLEARING_EDGE_REGISTER 0
#define FIFOREADACK_BIT_MODIFYING_OUTPUT_REGISTER 0
#define FIFOREADACK_CAPTURE 0
#define FIFOREADACK_DATA_WIDTH 32
#define FIFOREADACK_DO_TEST_BENCH_WIRING 0
#define FIFOREADACK_DRIVEN_SIM_VALUE 0
#define FIFOREADACK_EDGE_TYPE NONE
#define FIFOREADACK_FREQ 50000000
#define FIFOREADACK_HAS_IN 0
#define FIFOREADACK_HAS_OUT 1
#define FIFOREADACK_HAS_TRI 0
#define FIFOREADACK_IRQ_TYPE NONE
#define FIFOREADACK_RESET_VALUE 0

/*
 * Macros for device 'iofifoscontrol_0', class 'iofifoscontrol'
 * The macros are prefixed with 'IOFIFOSCONTROL_0_'.
 * The prefix is the slave descriptor.
 */
#define IOFIFOSCONTROL_0_COMPONENT_TYPE iofifoscontrol
#define IOFIFOSCONTROL_0_COMPONENT_NAME iofifoscontrol_0
#define IOFIFOSCONTROL_0_BASE 0x10300
#define IOFIFOSCONTROL_0_SPAN 16
#define IOFIFOSCONTROL_0_END 0x1030f

/*
 * Macros for device 'jtag_uart', class 'altera_avalon_jtag_uart'
 * The macros are prefixed with 'JTAG_UART_'.
 * The prefix is the slave descriptor.
 */
#define JTAG_UART_COMPONENT_TYPE altera_avalon_jtag_uart
#define JTAG_UART_COMPONENT_NAME jtag_uart
#define JTAG_UART_BASE 0x20000
#define JTAG_UART_SPAN 8
#define JTAG_UART_END 0x20007
#define JTAG_UART_IRQ 2
#define JTAG_UART_READ_DEPTH 64
#define JTAG_UART_READ_THRESHOLD 8
#define JTAG_UART_WRITE_DEPTH 64
#define JTAG_UART_WRITE_THRESHOLD 8


#endif /* _ALTERA_HPS_0_H_ */
