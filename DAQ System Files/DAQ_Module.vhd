library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.DAQ_Package.all;


entity DAQ_Module is
  port(
    -- Inputs --
    Clock: in std_logic;
	 Reset : in std_logic;
	 Reset_Errors : in std_logic;
	 -- Input from Data Generator --
	 Data_Valid : in std_logic;
	 EndOfEvent : in std_logic;
	 In_Data : in unsigned (31 downto 0);
	 -- Input from Ethernet --
	 Ethernet_Rdreq : in std_logic;
	 Ethernet_RegistersRdreq : in std_logic;
	 Ethernet_Wrreq : in std_logic;
	 Ethernet_DataIn : in std_logic_vector(31 downto 0);
	 -- Signals from GPIO --
	 BCOClock : in std_logic;
	 BCOReset : in std_logic;
	 Trigger : in std_logic;
	 
	 -- Outputs --
	 Busy_Out : out std_logic;
	 Status : out std_logic_vector ( 2 downto 0);
	 Trigger_Out : out std_logic;
	 Ethernet_DataOut : out std_logic_vector(31 downto 0);
	 Ethernet_RegistersOut : out std_logic_vector (31 downto 0);
	 regfifostatus : out std_logic_vector (31 downto 0);
	 TX_emptyFlag : out std_logic;
	 RX_almostFullFlag : out std_logic;
	 Errors : out std_logic
  );
end DAQ_Module;



architecture Structural of DAQ_Module is
  
  component Main_FSM 
    port(
      --Inputs
      Clock : in std_logic;
	   Reset : in std_logic;
	   To_State : in std_logic_vector (1 downto 0);
	   Empty_Fifo : in std_logic;
	   ReadingEvent : in std_logic;
		-- Minimum time to wait before checking if it's possible to go to config mode
	   Time_Out : in unsigned (7 downto 0);
	   --State of the machine
	   Status : out MainFSM_state;
	   --Outputs
	   DAQIsRunning : out std_logic;
	   DAQ_Reset : out std_logic;
	   DAQ_Config : out std_logic
    );
  end component;
  
  component Register_File 
    port(
      Clock : in std_logic;
	   Reset : in std_logic;
	   --- Communication with Local Ethernet Interace ---
	   Address : in natural;
	   Rdreq : in std_logic;
	   Wrreq : in std_logic;
	   DataIn : in std_logic_vector (31 downto 0);
	   Data_ValidOut : out std_logic := '0';
	   DataOut: out std_logic_vector (31 downto 0) := (others => '0');
	   --- Selective Reset contains a Reset std_logic line for every Control Register ---
	   Selective_Reset : in std_logic_vector(N_CONTROL_REGS-1 downto 0);
	   --- Communication with Main_FSM ---
	   Monitor_RegistersIn : in MONITOR_REGS_T;
	   Control_RegistersOut : out CONTROL_REGS_T := default_CtrlRegisters;
	   --- Errors ---
	   Reset_Errors : in std_logic;
	   Invalid_Address : out std_logic := '0';
	   INOut_Both_Active : out std_logic := '0'
    );
  end component;
  
  component Trigger_Control 
    port (
      --Inputs 
      Clock : in std_logic;          
      Reset : in std_logic;                
      --The Finite state machine is in Running State
      DAQIsRunning : in std_logic;  
      --Resets Counters preparing for run 
      DAQ_Reset : in std_logic; 
      Reset_Errors : in std_logic;		
      --External clock 
      BCOClock : in std_logic;      
      BCOReset : in std_logic;    
      --Trigger signal from GPIO
      Trigger : in std_logic;       
      --Internl Busy from Event Builder
      Busy : in std_logic;
     
      --Outputs
      --ClkCounter counts the number of clocks since DAQIsRunning passed from 0 to 1. The counter has 38bit
      ClkCounter : out unsigned (31 downto 0);      
      LSB_ClkCounter : out unsigned (5 downto 0); 
      --BCOCounter Counts the number of BCOClocks      
      BCOCounter : out unsigned (31 downto 0);  
      --TriggerCounter Counts the number of Main_Trigger since DAQIsRunning passed from 0 to 1    
      triggerCounter : out unsigned (31 downto 0);  
      --Trigger is sent to the inner part of the machine if DAQ is Running and the event builder is not busy
      Internal_Trigger : out std_logic ;
      --Busy out passes a stretched version of the Event Builder Busy to GPIO 
      Busy_Out : out std_logic; 
      --Errors
      Error_notRunning : out std_logic; 
      Error_busy : out std_logic        
    );
  end component;
  
  component Event_Builder 
    port (
      --Inputs
      Clock : in std_logic;
	   Reset : in std_logic;
      -- Value of the variable header
      Variable_Header : in std_logic_vector(31 downto 0);
      -- From Main_FSM
	   DAQ_Reset : in std_logic;
	   -- From Event_Simulator
	   Data_Valid : in std_logic;
	   endOfEvent : in std_logic;
	   in_Data : in unsigned (31 downto 0);
	   -- From Local eth Interface
	   outRequest : in std_logic;
	   -- Counters
	   inTrigger : in std_logic;
	   inBCOCounter : in unsigned (31 downto 0);
	   inClkCounter : in unsigned (31 downto 0);
	   inLSB_ClkCounter : in unsigned (5 downto 0);
	   inTriggerCounter : in unsigned (31 downto 0);
      --If Busy_Mode = '0' machine is busy when reading in_Data or in case of AlmostFull
      --If Busy_mode = '1' the Event_Buider is busy every time the fifo is not empty
	   Busy_Mode : in std_logic;
      --Outputs
      out_Data : out unsigned (31 downto 0);
	   outData_Valid : out std_logic;
	   out_Ready : out std_logic;
	   Empty_Fifo : out std_logic;
      --AlmostFull = '1' when Fifo_Usage > 1790
	   AlmostFull : out std_logic;
      --When Busy = '1' the machine can't accept a new Read request (trigger)
	   Busy : out std_logic;
	   ReadingEvent : out std_logic;
	   Fifo_Usage : out std_logic_vector (10 downto 0);
	   EventsInTheFifo : out std_logic_vector (7 downto 0);
      outTrigger : out std_logic;
	   outBCOCounter : out unsigned (31 downto 0);
	   outClkCounter : out unsigned (31 downto 0);
	   outLSB_ClkCounter : out unsigned (5 downto 0);
	   outTriggerCounter : out unsigned (31 downto 0);
	   FifoFull : out std_logic;
	   MetadataFifoFull : out std_logic
    );
  end component;
  
  component Local_TX 
    port(
      Clock : in std_logic;
	   Reset : in std_logic;
	   -- Ethernet request of reading stored Data --
	   Ethernet_Rdreq : in std_logic;
	   Ethernet_RegistersRdreq : in std_logic;
	   Ethernet_DataOut : out std_logic_vector (31 downto 0);
	   Ethernet_RegistersOut : out std_logic_vector (31 downto 0);
	   -- Communication with Event_Builder --
	   EventBuilder_Data : in unsigned (31 downto 0);
	   EventBuilder_DataValid : in std_logic;
	   EventBuilder_Ready : in std_logic;
	   EventBuilder_OutRequest : out std_logic;
	   -- Communication With Local Ethernet Interface RX --
	   LocalRX_Data : in std_logic_vector (31 downto 0);
	   LocalRX_Ready: in std_logic;
	   LocalRX_Rdreq : out std_logic;
	   -- Internal data_Fifo stats --
	   Fifo_Usage : out std_logic_vector (10 downto 0);
	   Fifo_Empty : out std_logic;
	   Fifo_AlmostFull : out std_logic;
	   Fifo_Full : out std_logic;
	   -- Fifo_RX stats --
	   RegsFifo_Usage : out std_logic_vector (8 downto 0);
	   RegsFifo_Empty : out std_logic;
	   RegsFifo_AlmostFull : out std_logic;
	   RegsFifo_Full : out std_logic
    );
  end component;
  
  component LocalRX 
    port(
      Clock : in std_logic;
	   Reset : in std_logic;
	   -- Data from outher world --
	   Ethernet_wrreq : in std_logic;
	   Ethernet_Data : in std_logic_vector(31 downto 0); 
	   -- Configuration mode from FSM --
	   DAQ_Config : in std_logic;
	   -- Read Request from Local TX --
	   LocalTX_Rdreq : in std_logic;
	   -- Data From Register File --
	   Register_DataValid : in std_logic;
	   Register_DataRead : in std_logic_vector(31 downto 0);
	   -- Data to Register file --
	   Register_Address : out natural;
	   Register_Wrreq : out std_logic;
	   Register_Rdreq : out std_logic;
	   Register_SelectiveReset : out std_logic_vector(N_CONTROL_REGS-1 downto 0) := (others => '0');
	   Register_DataWrite : out std_logic_vector(31 downto 0);
	   -- Data to LocalTX --
	   DataOut : out std_logic_vector(31 downto 0);
	   Data_Ready : out std_logic := '0';
	   -- FIFORX stats --
	   FifoRX_Usage : out std_logic_vector (8 downto 0);
	   FifoRX_Empty : out std_logic;
	   FifoRX_AlmostFull : out std_logic;
	   FifoRX_Full : out std_logic;
	   -- internal FIFO out stats --
	   FifoOut_Empty : out std_logic;
	   FifoOut_Full : out std_logic
    );
  end component;
  
  ----  FSM Signals  ----
  signal internalDAQIsRunning : std_logic :='0';
  signal internalDAQ_Reset : std_logic:='0';
  signal internalDAQ_Config : std_logic:='0';
  signal Status_Bus : MainFSM_state;
  signal Time_Out : unsigned (7 downto 0) := unsigned(CtrlReg4 ( 7 downto 0));
  -- From Event Builder signals --
  signal EB_Busy : std_logic;
  signal EB_FifoFull : std_logic;
  signal EB_MetadataFull : std_logic;
  signal EB_ReadingEvent : std_logic:='0';
  signal EB_outData_Valid : std_logic:='0';
  signal EB_OutData : unsigned (31 downto 0);
  signal EB_Ready : std_logic;
  -- From LocalEth_TX --
  signal forEB_outRequest : std_logic;
  signal forLocalRX_Rdreq : std_logic;
  signal FifoTX_Full : std_logic;
  signal RegFifoTX_Full : std_logic;
  -- From LocalEth_RX --
  signal LocalRX_Data : std_logic_vector(31 downto 0);
  signal LocalRX_Ready: std_logic;
  signal FifoRX_Full : std_logic;
  signal FifoRX_AlmostFull : std_logic;
  -- Counters --
  signal ToEB_ClkCounter : unsigned (31 downto 0);
  signal FromEB_ClkCounter : unsigned (31 downto 0);
  signal ToEB_LSBClkCounter : unsigned (5 downto 0);
  signal FromEB_LSBClkCounter : unsigned (5 downto 0);
  signal ToEB_BCOCounter : unsigned (31 downto 0);
  signal FromEB_BCOCounter : unsigned (31 downto 0);
  signal ToEB_triggerCounter : unsigned (31 downto 0);
  signal FromEB_triggerCounter : unsigned (31 downto 0);
  -- From Trigger Control --
  signal internalTrigger : std_logic;
  -- Registers signals --
  signal Register_Address : natural;
  signal Register_Wrreq : std_logic:='0';
  signal Register_Rdreq : std_logic:='0';
  signal Register_DataValid : std_logic;
  signal Reset_DAQErrors : std_logic;
  signal Register_SelectiveReset : std_logic_vector(N_CONTROL_REGS-1 downto 0);
  signal Register_DataWrite : std_logic_vector(31 downto 0);
  signal Register_DataRead : std_logic_vector(31 downto 0);
  signal Monitor_Registers_Bus : MONITOR_REGS_T:= default_MonRegisters;
  signal Control_Registers_Bus : CONTROL_REGS_T:= default_CtrlRegisters;
  
begin

  Reset_DAQErrors <= Reset_Errors or internalDAQ_Reset;
  
  Monitor_Registers_Bus(FSM_StatusSignals_Reg)(DAQ_IsRunning_Flag) <= internalDAQIsRunning;
  Monitor_Registers_Bus(FSM_StatusSignals_Reg)(DAQ_Reset_Flag) <= internalDAQ_Reset;
  Monitor_Registers_Bus(FSM_StatusSignals_Reg)(DAQ_Config_Flag) <= internalDAQ_Config;
  Monitor_Registers_Bus(FSM_StatusSignals_Reg)(ReadingEvent_Flag) <= EB_ReadingEvent;
  Time_Out <= unsigned(Control_Registers_Bus(FSMTimeOut_Reg)(7 downto 0));
  
  Monitor_Registers_Bus(FSM_StatusSignals_Reg)(2 downto 0) <= To_stdlogicvector(Status_Bus);
  Status <= Monitor_Registers_Bus(FSM_StatusSignals_Reg)(2 downto 0);
  Monitor_Registers_Bus (ClkCounter_Reg) <= std_logic_vector(FromEB_ClkCounter);  
  Monitor_Registers_Bus (LSB_ClkCounter_Reg) <= conv_std_logic_vector(0,26) & std_logic_vector(FromEB_LSBClkCounter);    
  Monitor_Registers_Bus (BCOCounter_Reg) <= std_logic_vector(FromEB_BCOCounter);    
  Monitor_Registers_Bus (TriggerCounter_Reg) <= std_logic_vector(FromEB_triggerCounter); 
  
  Monitor_Registers_Bus(EB_Fifos_Reg)(EBFull_Flag) <=  EB_FifoFull;
  Monitor_Registers_Bus(EB_Fifos_Reg)(11) <=  EB_FifoFull;
  Monitor_Registers_Bus(EB_Fifos_Reg)(EBMetadataFull_Flag) <=  EB_MetadataFull;
  Monitor_Registers_Bus(EB_Fifos_Reg)(20) <=  EB_MetadataFull;
  Monitor_Registers_Bus(LocalTX_Fifo_Reg)(TXFull_Flag) <=  FifoTX_Full;
  Monitor_Registers_Bus(LocalTX_Fifo_Reg)(11) <= FifoTX_Full;
  Monitor_Registers_Bus(LocalTX_Fifo_Reg)(TXRegFifoFull_Flag) <=  RegFifoTX_Full;
  Monitor_Registers_Bus(LocalTX_Fifo_Reg)(25) <= RegFifoTX_Full;
  Monitor_Registers_Bus(LocalRX_Fifos_Reg)(RXFull_Flag) <= FifoRX_Full;
  Monitor_Registers_Bus(LocalRX_Fifos_Reg)(9) <= FifoRX_Full;
  Monitor_Registers_Bus(LocalRX_Fifos_Reg)(RXAlmostFull_Flag) <= FifoRX_AlmostFull;
  
  -- Errors Output --
  Monitor_Registers_Bus (Errors_Reg)(31 downto 4) <= conv_std_logic_vector(0,28);
  Errors <= '0' when Monitor_Registers_Bus(Errors_Reg) = conv_std_logic_vector(0,32)
                else '1';
  
  -- Flags --
  TX_emptyFlag <= Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXEmpty_Flag);
  RX_almostFullFlag <= FifoRX_AlmostFull;
  
  ----  Components port map  ----
  
  Finite_State_Machine: Main_FSM
  port map(
    --Inputs
    Clock => Clock,
	 Reset => Reset,
	 To_State => Control_Registers_Bus(ToState_Reg)(1 downto 0),
	 Empty_Fifo => Monitor_Registers_Bus(EB_Fifos_Reg)(EBEmpty_Flag),
	 ReadingEvent => EB_ReadingEvent,
	 Time_Out => Time_Out,
	 Status => Status_Bus,
	 --Outputs
	 DAQIsRunning => internalDAQIsRunning,
	 DAQ_Reset => internalDAQ_Reset,
	 DAQ_Config => internalDAQ_Config
    );
  
  
    Registers : Register_File
    port map(
      Clock => Clock,
	   Reset => Reset,
	   Address => Register_Address,
	   Rdreq => Register_Rdreq,
	   Wrreq => Register_Wrreq,
	   DataIn => Register_DataWrite,
	   Data_ValidOut => Register_DataValid,
	   DataOut => Register_DataRead,
	   Selective_Reset => Register_SelectiveReset,
	   Monitor_RegistersIn => Monitor_Registers_Bus,
	   Control_RegistersOut => Control_Registers_Bus,
	   Reset_Errors => Reset_Errors,
	   Invalid_Address => Monitor_Registers_Bus (Errors_Reg)(InvalidAddress_Flag),
	   INOut_Both_Active => Monitor_Registers_Bus (Errors_Reg)(InOutBothActive_Flag)
    );
	 
	 
	 TriggerCtrl : Trigger_Control
	 port map (
      Clock => Clock,          
      Reset => Reset,              
      DAQIsRunning => internalDAQIsRunning,  
      DAQ_Reset => internalDAQ_Reset, 
      Reset_Errors => Reset_DAQErrors,		
      BCOClock => BCOClock,    
      BCOReset => BCOReset,    
      Trigger => Trigger,       
      Busy => EB_Busy,
      ClkCounter => ToEB_ClkCounter,    
      LSB_ClkCounter => ToEB_LSBClkCounter,    
      BCOCounter => ToEB_BCOCounter,     
      triggerCounter => ToEB_triggerCounter, 
      Internal_Trigger => internalTrigger,
      Busy_Out => Busy_Out,
      Error_notRunning => Monitor_Registers_Bus (Errors_Reg)(ErrorNotRunning_Flag),
      Error_busy => Monitor_Registers_Bus (Errors_Reg)(ErrorBusy_Flag) 
	 );	
	 
	 
	 EB : Event_Builder
	 port map (
      Clock => Clock,
	   Reset => Reset,
      Variable_Header => Control_Registers_Bus(VariableHeader_Reg),
	   DAQ_Reset => internalDAQ_Reset,
	   Data_Valid => Data_Valid,
	   endOfEvent => endOfEvent,
	   in_Data => in_Data,
	   outRequest => forEB_outRequest,
	   inTrigger => internalTrigger,
	   inBCOCounter => ToEB_BCOCounter,
	   inClkCounter => ToEB_ClkCounter,
	   inLSB_ClkCounter => ToEB_LSBClkCounter,
	   inTriggerCounter => ToEB_triggerCounter,
	   Busy_Mode => Control_Registers_Bus(BusyMode_Reg)(0),
      out_Data => EB_OutData,
	   outData_Valid => EB_outData_Valid ,
	   out_Ready => EB_Ready,
	   Empty_Fifo => Monitor_Registers_Bus(EB_Fifos_Reg)(EBEmpty_Flag),
	   AlmostFull => Monitor_Registers_Bus(EB_Fifos_Reg)(EBAlmostFull_Flag),
	   Busy => EB_Busy,
	   ReadingEvent => EB_ReadingEvent,
	   Fifo_Usage => Monitor_Registers_Bus(EB_Fifos_Reg)(10 downto 0),
	   EventsInTheFifo => Monitor_Registers_Bus(EB_Fifos_Reg)(19 downto 12),
      outTrigger => Trigger_Out,
	   outBCOCounter => FromEB_BCOCounter,
	   outClkCounter => FromEB_ClkCounter,
	   outLSB_ClkCounter => FromEB_LSBClkCounter,
	   outTriggerCounter => FromEB_triggerCounter,
	   FifoFull => EB_FifoFull,
	   MetadataFifoFull => EB_MetadataFull
    );
	 
	 LocalEthernetTX : Local_TX
	 port map(
      Clock => Clock,
	   Reset => Reset,
	   Ethernet_Rdreq => Ethernet_Rdreq,
		Ethernet_RegistersRdreq => Ethernet_RegistersRdreq,
	   Ethernet_DataOut => Ethernet_DataOut,
		Ethernet_RegistersOut => Ethernet_RegistersOut,
	   EventBuilder_Data => EB_OutData,
	   EventBuilder_DataValid => EB_outData_Valid,
	   EventBuilder_Ready => EB_Ready,
	   EventBuilder_OutRequest => forEB_outRequest,
	   LocalRX_Data => LocalRX_Data,
	   LocalRX_Ready => LocalRX_Ready,
	   LocalRX_Rdreq => forLocalRX_Rdreq,
	   Fifo_Usage => Monitor_Registers_Bus (LocalTX_Fifo_Reg) (10 downto 0),
	   Fifo_Empty => Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXEmpty_Flag),
	   Fifo_AlmostFull => Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXAlmostFull_Flag) ,
	   Fifo_Full => FifoTX_Full,
	   RegsFifo_Usage => Monitor_Registers_Bus (LocalTX_Fifo_Reg) (24 downto 16),
	   RegsFifo_Empty => Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXRegFifoEmpty_Flag),
	   RegsFifo_AlmostFull => Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXRegFifoAlmostFull_Flag) ,
	   RegsFifo_Full => RegFifoTX_Full
    );
	-- This is the FIFO control structure to HPS
	regfifostatus <=   x"000"& '0' 
		& RegFifoTX_Full & Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXRegFifoAlmostFull_Flag) & Monitor_Registers_Bus (LocalTX_Fifo_Reg)(TXRegFifoEmpty_Flag) & 
		"000000" & RegFifoTX_Full & Monitor_Registers_Bus (LocalTX_Fifo_Reg) (24 downto 16);

	
	
	 
	 LocalEthernet_RX : LocalRX
	 port map (
      Clock => Clock,
	   Reset => Reset,
	   Ethernet_wrreq => Ethernet_Wrreq,
	   Ethernet_Data => Ethernet_DataIn,
	   DAQ_Config => internalDAQ_config,
	   LocalTX_Rdreq => forLocalRX_Rdreq,
	   Register_DataValid => Register_DataValid,
	   Register_DataRead => Register_DataRead,
	   Register_Address => Register_Address,
	   Register_Wrreq => Register_Wrreq,
	   Register_Rdreq => Register_Rdreq,
	   Register_SelectiveReset  => Register_SelectiveReset,
	   Register_DataWrite =>  Register_DataWrite,
	   -- Data to LocalTX --
	   DataOut => LocalRX_Data,
	   Data_Ready => LocalRX_Ready,
	   -- FIFO stats --
	   FifoRX_Usage => Monitor_Registers_Bus(LocalRX_Fifos_Reg)(8 downto 0),
	   FifoRX_Empty => Monitor_Registers_Bus(LocalRX_Fifos_Reg)(RXEmpty_Flag),
	   FifoRX_AlmostFull => FifoRX_AlmostFull,
	   FifoRX_Full => FifoRX_Full,
	   FifoOut_Empty => Monitor_Registers_Bus(LocalRX_Fifos_Reg)(RX_outFifo_Empty_Flag),
	   FifoOut_Full =>  Monitor_Registers_Bus(LocalRX_Fifos_Reg)(RX_outFifo_Full_Flag)
    );
end Structural;
