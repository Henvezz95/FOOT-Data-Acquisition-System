library IEEE;
use IEEE.std_logic_1164.all;
USE ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.DAQ_Package.all;

entity Local_TX is
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
end entity;

architecture description of Local_TX is

  ---- This FIFO is used to store data that have to be read via ethernet --- 
  component Fifo is
	 port(
		clock		: in std_logic ;
		data		: in STD_LOGIC_VECTOR (31 downto 0);
		rdreq		: in STD_LOGIC ;
		aclr		: in STD_LOGIC ;
		wrreq		: in STD_LOGIC ;
		almost_full	: out STD_LOGIC ;
		empty		: out STD_LOGIC ;
		full		: out STD_LOGIC ;
		q		: out STD_LOGIC_VECTOR (31 downto 0);
		usedw		: out STD_LOGIC_VECTOR (10 downto 0)
	 );
  end component;
  
  ---- Data from Registers that has to be read through ethernet ----
  component Fifo_TX_Regs is
	 PORT
	   (
		  clock		: IN STD_LOGIC ;
		  data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		  rdreq		: IN STD_LOGIC ;
		  aclr		: in STD_LOGIC ;
		  wrreq		: IN STD_LOGIC ;
		  almost_full		: OUT STD_LOGIC ;
		  empty		: OUT STD_LOGIC ;
		  full		: OUT STD_LOGIC ;
		  q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		  usedw		: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
	  );
  end component;
  
  ---- Internal Counter ----
  component Counter_nbit 
  generic ( nbit : natural := 12);  
  port(
    CLK: in std_logic;
    RESET: in std_logic;
    COUNT : out unsigned (nbit-1 downto 0)
  );
  end component;
   
	
  -- State --
  type state_data is (idle, EventBuilder_Length, readEventBuilder);
  type state_registerData is (idle, LocalRX_Length, readLocalRX);
  signal present_state, next_state : state_data := idle;
  signal actual_state, future_state : state_registerData := idle;
  -- Internal signals --
  signal internalData : std_logic_vector (31 downto 0);
  signal internalWrreq_FifoReg : std_logic;
  signal internalWrreq : std_logic;
  signal internalAlmostFull : std_logic;
  signal internalAlmostFull_FifoReg : std_logic;
  -- Length of the sequence --
  signal sequenceLength : unsigned (11 downto 0) := (others=>'0');
  signal sequenceLength_RX : unsigned (6 downto 0) := (others=>'0');
  -- Counter Signals for Event_Builder sequence --
  signal counterReset : std_logic;
  signal internalReset : std_logic;
  signal internalCounter : unsigned (11 downto 0);
  -- Counter Signals for Local_RX sequence --
  signal counterReset_RX : std_logic;
  signal internalReset_RX : std_logic;
  signal internalCounter_RX : unsigned (6 downto 0);
  
begin
  
  Fifo_AlmostFull <= internalAlmostFull;
  RegsFifo_AlmostFull <= internalAlmostFull_FifoReg;
  
  ----  Components port map  ----

  Data_Fifo : Fifo 
  port map (
    clock => Clock,
    data => internalData,
	 rdreq => Ethernet_Rdreq,
	 aclr => Reset,
	 wrreq => internalWrreq,
	 almost_full => internalAlmostFull,
	 empty => Fifo_Empty,
	 full => Fifo_Full,
	 q => Ethernet_DataOut,
	 usedw => Fifo_Usage
  );
  
  RX_Fifo : Fifo_TX_Regs
  port map (
    clock => Clock,
    data => LocalRX_Data,
	 rdreq => Ethernet_RegistersRdreq,
	 aclr => Reset,
	 wrreq => internalWrreq_FifoReg,
	 almost_full => internalAlmostFull_FifoReg,
	 empty => RegsFifo_Empty,
	 full => RegsFifo_Full,
	 q => Ethernet_RegistersOut,
	 usedw => RegsFifo_Usage
  );
  
  Counter_EB : Counter_nbit
  generic map( nbit => 12)   
  port map (
	 CLK => Clock,
	 RESET => counterReset,
	 COUNT => internalCounter
  );
  
  Counter_RX : Counter_nbit
  generic map( nbit => 7)   
  port map (
	 CLK => Clock,
	 RESET => counterReset_RX,
	 COUNT => internalCounter_RX
  );
  
  --Reset Counter
  internalReset <= '1' when present_state = idle or present_state = EventBuilder_Length 
	                    else '0';
  counterReset <= internalReset or Reset;
  
  --Reset Counter_RX
  internalReset_RX <= '1' when actual_state = idle or actual_state = LocalRX_Length 
	                    else '0';
  counterReset_RX <= internalReset_RX or Reset;
  
  ----  Process 1 : Reading Event_Builder states --
  
  process(present_state, internalAlmostFull, EventBuilder_Ready,
    EventBuilder_DataValid, internalCounter, sequenceLength)
  begin
    case present_state is
	 
	   when idle =>
		  if internalAlmostFull = '0' then
		    -- If fifo is not almost full I can read new data --
			 if EventBuilder_Ready = '1' then
			   next_state <= EventBuilder_Length;
			 else
			   next_state <= idle;
			 end if;
		  else
		    next_state <= idle;
		  end if;
		
		when EventBuilder_Length =>
		-- Waits DataValid to go high to catch the length of the sequence --
		  if EventBuilder_DataValid = '1' then
		    next_state <= readEventBuilder;
		  else
		    next_state <= EventBuilder_Length;
		  end if;
		
		when readEventBuilder =>
		  if internalCounter >= sequenceLength-conv_unsigned(2,12) then
          next_state <= idle;
		  else
		    next_state <= readEventBuilder;
		  end if;
		  
		when others =>
		  next_state <= idle;
		  
    end case;
  end process;
  
  ----  Process 2 : Reading Local_RX states --
  
  process(actual_state, internalAlmostFull_FifoReg, LocalRX_Ready,
    internalCounter_RX, sequenceLength_RX)
  begin
    case actual_state is
	 
	   when idle =>
		  if internalAlmostFull_FifoReg = '0' then
		    -- If fifo is not almost full I can read new data --
			 if LocalRX_Ready = '1' then
			   future_state <= LocalRX_Length;
			 else
			   future_state <= idle;
			 end if;
		  else
		    future_state <= idle;
		  end if;
		
		when LocalRX_Length =>
		  future_state <= readLocalRX;
		
		when readLocalRX =>
		  if internalCounter_RX >= sequenceLength_RX-conv_unsigned(2,12) then
          future_state <= idle;
		  else
		    future_state <= readLocalRX;
		  end if;
		  
		when others =>
		  future_state <= idle;
		  
    end case;
  end process;
  
  ----  Process 3 : Decides which data put in the data_fifo  ----
  
  process(present_state, EventBuilder_DataValid, EventBuilder_Data)
  begin
    case present_state is
	 
	   when idle =>
	     internalWrreq <= '0';
	     internalData <= conv_std_logic_vector(0,32);
	
	   when EventBuilder_length =>
	     if EventBuilder_DataValid = '1' then
	       internalWrreq <= '1';
	       internalData <= std_logic_vector(EventBuilder_Data);
	     else
	       internalWrreq <= '0';
	       internalData <= conv_std_logic_vector(0,32);
	     end if;
	
	   when readEventBuilder =>
	     internalWrreq <= '1';
	     internalData <= std_logic_vector(EventBuilder_Data);
	  
	   when others =>
	     internalWrreq <= '0';
	     internalData <= conv_std_logic_vector(0,32);

    end case;
  end process;
 
  -- Fifo Register write request --
  internalWrreq_FifoReg <= '1' when actual_state = LocalRX_length or actual_state = readLocalRX
	                            else '0';
  
  -- Out Request for Event Builder --
  EventBuilder_OutRequest <= '1' when next_state = EventBuilder_Length
	                              else '0';
  -- Out Request for LocalRX --
  LocalRX_Rdreq <= '1' when future_state = LocalRX_length or future_state = readLocalRX
	                    else '0';

  ---- Process number 4 : sequential part	plus reset  ----
  process(Clock,Reset)
  begin
    if Reset = '1' then
	   present_state <= idle;
		actual_state <= idle;
		sequenceLength <= conv_unsigned(0,12);
		sequenceLength_RX <= conv_unsigned(0,7);
	 elsif rising_edge(Clock) then
	   if present_state = EventBuilder_Length then
		  sequenceLength <= EventBuilder_Data(11 downto 0);
		end if;
		if actual_state = LocalRX_Length then
		  sequenceLength_RX <= unsigned(LocalRX_Data(6 downto 0));
		end if;
	   present_state <= next_state;
		actual_state<=future_state;
	 end if;
  end process;
  
end architecture;
	 