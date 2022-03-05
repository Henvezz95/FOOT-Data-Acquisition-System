library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.DAQ_Package.all;

entity DAQ_OnFPGA is
  port(
    Clock : in std_logic;
	 Reset : in std_logic;
	 Reset_Errors : in std_logic;
	  -- Input from Ethernet --
	 Ethernet_Rdreq : in std_logic;
	 Ethernet_RegistersRdreq : in std_logic;
	 Ethernet_Wrreq : in std_logic;
	 Ethernet_DataIn : in std_logic_vector(31 downto 0);
	 -- Signals from GPIO --
	 BCOClock : in std_logic;
	 BCOReset : in std_logic;
	 Trigger : in std_logic;
	
	 -- To State Signals --
	 TowardRun : in std_logic;
	 TowardIdle: in std_logic;
	 ReadAll: in std_logic;

	 -- Outputs --
	 Busy_Out : out std_logic;
	 Ethernet_DataOut : out std_logic_vector(31 downto 0);
	 Ethernet_RegistersOut : out std_logic_vector(31 downto 0);
	 regfifostatus : out std_logic_vector (31 downto 0);
	 TX_emptyFlag : out std_logic;
	 RX_almostFullFlag : out std_logic;
	 Errors : out std_logic;
	 -- Led State --
	 Led_State : out std_logic_vector ( 2 downto 0)
  );
end entity;

architecture structural of DAQ_OnFPGA is

  component DAQ_Module 
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
	   Ethernet_RegistersOut : out std_logic_vector(31 downto 0);
	   regfifostatus : out std_logic_vector (31 downto 0);
	   TX_emptyFlag : out std_logic;
	   RX_almostFullFlag : out std_logic;
	   Errors : out std_logic
    );
  end component;
  
  component Event_Simulator 
    generic ( 
      headerLength : natural := 4;        
	   footerLength : natural := 3       
	   );
    --Port declaration
    port (
      --Inputs
      Clock : in std_logic;
	   Reset : in std_logic;
	   --Trigger
	   Trigger : in std_logic;
      --Outputs
	   Data_Stream : out unsigned (31 downto 0);  
	   Data_Valid : out std_logic;
	   --Is '1' if that is the last word of the sequence
      EndOfEvent : out std_logic	 
    );
  end component;
 
 -- State of the DAQ Module --
  signal DAQ_State : std_logic_vector ( 2 downto 0);
  -- Internal Signals --
  signal internalData_valid : std_logic:='0';
  signal internalEndOfEvent : std_logic;
  signal dataFromSimulator : unsigned (31 downto 0);
  signal internalTrigger : std_logic;
  signal addressToRead : natural := 0;
   -- Virtual Ethernet Controls --
  signal Virtual_Ethernet_Wrreq :  std_logic:='0';
  signal Virtual_Ethernet_DataIn :  std_logic_vector(31 downto 0);
  -- Past Values --
  signal pastReadAll:  std_logic:='0';
  signal pastStateSignal:  std_logic:='0';
  signal StateSignal :std_logic:='0';
  -- States --
  type state_toState is (idle, writeLength, writeHeader, WriteState,
    lengthToRead, readHeader, writeAddresses, writeFooter);
  signal present_state, next_state : state_toState;
  
  constant nullVector : std_logic_vector(29 downto 0):=conv_std_logic_vector(0,30);
  
  
begin 
 
  Led_State <= DAQ_State;
 
  DAQ_System : DAQ_Module 
  port map(
    Clock => Clock,
	 Reset => Reset,
	 Reset_Errors => Reset_Errors,
	 Data_Valid => internalData_Valid,
	 EndOfEvent => internalEndOfEvent,
	 In_Data => dataFromSimulator,
	 Ethernet_RegistersRdreq => Ethernet_RegistersRdreq,
	 Ethernet_Rdreq => Ethernet_Rdreq,
	 Ethernet_Wrreq => Virtual_Ethernet_Wrreq,
	 Ethernet_DataIn => Virtual_Ethernet_DataIn,
	 BCOClock => BCOClock,
	 BCOReset => BCOReset,
	 Trigger => Trigger,
	 Busy_Out => Busy_Out,
	 Trigger_Out => internalTrigger,
	 Status => DAQ_State,
	 Ethernet_DataOut => Ethernet_DataOut,
	 Ethernet_RegistersOut => Ethernet_RegistersOut,
	 regfifostatus => regfifostatus,
	 TX_emptyFlag => TX_EmptyFlag,
	 RX_almostFullFlag => RX_almostFullFlag,
	 Errors => Errors
    ); 
	 
  ES : Event_simulator
   port map(
      Clock => Clock,
	   Reset => Reset,
	   Trigger => internalTrigger,
	   Data_Stream => dataFromSimulator,
	   Data_Valid => internalData_Valid,
      EndOfEvent => internalEndOfEvent
    );
  
  StateSignal <= TowardRun or TowardIdle;
  
  process(present_state, StateSignal, pastStateSignal, pastReadAll, ReadAll, addressToRead)
  begin
    case present_state is
	  
	   when idle => 
		  if StateSignal = '1' and pastStateSignal = '0' then
	       next_state <= writeLength;
		  elsif ReadAll = '1' and pastReadAll = '0' then
		    next_state <= lengthToRead;
		  else
		    next_state <= idle;
		  end if;
	  
	   when writeLength =>
	     next_state <=writeHeader;
	
	   when writeHeader =>
	     next_state <= writeState;
		
		when writeState =>
	     next_state <= writeFooter;
		
		when lengthToRead =>
		  next_state <= readHeader;
		  
		when readHeader =>
		  next_state <= writeAddresses;
		
		when writeAddresses=>
		  if addressToRead >= N_MONITOR_REGS+N_CONTROL_REGS-1 then
		    next_state <= writeFooter;
		  else
		    next_state <= writeAddresses;
		  end if;
		
		when writeFooter =>
		  next_state <= idle;
	  
	   when others =>
	     next_state <= idle;
	
	 end case;
  end process;
  
  
  process(present_state, Ethernet_Wrreq, Ethernet_DataIn, TowardRun, TowardIdle, DAQ_State,addressToRead)
  begin
    case present_state is
	   
		when idle =>
        Virtual_Ethernet_Wrreq <= Ethernet_Wrreq;
        Virtual_Ethernet_DataIn <= Ethernet_DataIn;
		  
		when writeLength =>
        Virtual_Ethernet_Wrreq <= '1';
        Virtual_Ethernet_DataIn <= conv_std_logic_vector(4,32);
		
		when writeHeader =>
        Virtual_Ethernet_Wrreq <= '1';
        Virtual_Ethernet_DataIn <= Header_ChangeState;
		  
		when writeState =>
        Virtual_Ethernet_Wrreq <= '1';
		  if TowardRun = '1' then
		    if DAQ_State = "000" then --Idle--
            Virtual_Ethernet_DataIn <= nullVector & IdleToConfig;
			 else
			   Virtual_Ethernet_DataIn <= nullVector & ConfigToRun;
		    end if;
		  else --Must be TowardIdle = '1' --
		    if DAQ_State = "011" then --Run--
			   Virtual_Ethernet_DataIn <= nullVector &  RunToConfig;  
			 else
			   Virtual_Ethernet_DataIn <= nullVector &  ConfigToIdle;
          end if;
        end if;	
		
		when lengthToRead =>
		  Virtual_Ethernet_Wrreq <= '1';
        Virtual_Ethernet_DataIn <= conv_std_logic_vector(N_MONITOR_REGS+N_CONTROL_REGS+2,32); 
		 
	   when readHeader =>
		  Virtual_Ethernet_Wrreq <= '1';
        Virtual_Ethernet_DataIn <= Header_ReadRegs;
		
		when writeAddresses =>
		  Virtual_Ethernet_Wrreq <= '1';
        Virtual_Ethernet_DataIn <= std_logic_vector(conv_unsigned(addressToRead,32));  
		
		when writeFooter =>
		  Virtual_Ethernet_Wrreq <= '1';
        Virtual_Ethernet_DataIn <= Instruction_Footer;
		  
		when others =>
		  Virtual_Ethernet_Wrreq <= Ethernet_Wrreq;
        Virtual_Ethernet_DataIn <= Ethernet_DataIn;
		  
    end case;
  end process;
  
  process(Clock, Reset)
  begin
    if Reset = '1' then
      pastStateSignal <= '0';
		pastReadAll <= '0';
		addressToRead <= 0;
    elsif rising_edge(Clock) then
	   if present_state = writeAddresses then
		  addressToRead <= addressToRead+1;
		else
		  addressToRead <= 0;
		end if;
      present_state <= next_state;
		pastStateSignal <= StateSignal;
		pastReadAll <= ReadAll;
    end if;
  end process;
  
end architecture;