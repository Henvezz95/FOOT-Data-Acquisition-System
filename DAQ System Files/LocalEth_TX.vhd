library IEEE;
use IEEE.std_logic_1164.all;
USE ieee.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.DAQ_Package.all;

entity LocalEth_TX is
  port(
    Clock : in std_logic;
	 Reset : in std_logic;
	 -- Ethernet request of reading stored Data --
	 Ethernet_Rdreq : in std_logic;
	 Ethernet_DataOut : out std_logic_vector (31 downto 0);
	 -- Communication with Event_Builder --
	 EventBuilder_Data : in unsigned (31 downto 0);
	 EventBuilder_DataValid : in std_logic;
	 EventBuilder_Ready : in std_logic;
	 EventBuilder_OutRequest : out std_logic;
	 -- Communication With Local Ethernet Interface RX --
	 LocalRX_Data : in std_logic_vector (31 downto 0);
	 LocalRX_Ready: in std_logic;
	 LocalRX_Rdreq : out std_logic;
	 -- Internal Fifo stats --
	 Fifo_Usage : out std_logic_vector (10 downto 0);
	 Fifo_Empty : out std_logic;
	 Fifo_AlmostFull : out std_logic;
	 Fifo_Full : out std_logic
  );
end entity;

architecture description of LocalEth_TX is

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
  type state is (idle, EventBuilder_Length, readEventBuilder, LocalRX_Length, readLocalRX);
  signal present_state, next_state : state := idle;
  -- Internal signals --
  signal internalData : std_logic_vector (31 downto 0);
  signal internalWrreq : std_logic;
  signal internalAlmostFull : std_logic;
  -- Length of the sequence --
  signal sequenceLength : unsigned (11 downto 0) := (others=>'0');
  -- Counter Signals --
  signal counterReset : std_logic;
  signal internalReset : std_logic;
  signal internalCounter : unsigned (11 downto 0);
  
begin
  
  Fifo_AlmostFull <= internalAlmostFull;
  
  ----  Components port map  ----

  FifoTX : Fifo 
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
  
  Counter : Counter_nbit
  generic map( nbit => 12)   
  port map (
	 CLK => Clock,
	 RESET => counterReset,
	 COUNT => internalCounter
  );
  
  --Reset Counter
  internalReset <= '1' when present_state = idle or present_state = EventBuilder_Length or present_state = LocalRX_Length
	                    else '0';
  counterReset <= internalReset or Reset;
  
  ----  Process 1 : states flow  --
  
  process(present_state, internalAlmostFull, EventBuilder_Ready, LocalRX_Ready,
    EventBuilder_DataValid, internalCounter, sequenceLength)
  begin
    case present_state is
	 
	   when idle =>
		  if internalAlmostFull = '0' then
		    -- If fifo is not almost full I can read new data --
			 if EventBuilder_Ready = '1' then
			   next_state <= EventBuilder_Length;
			 elsif LocalRX_Ready = '1' then
			   next_state <= LocalRX_Length;
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
		
		when LocalRX_Length =>
		    next_state <= readLocalRX;
		
		when readEventBuilder =>
		  if internalCounter >= sequenceLength-conv_unsigned(2,12) then
		    if LocalRX_Ready = '1' and internalAlmostFull = '0' then
			   next_state <= LocalRX_Length;
			 else
			   next_state <= idle;
			 end if;
		  else
		    next_state <= readEventBuilder;
		  end if;
		
		when readLocalRX =>
		  if internalCounter >= sequenceLength-conv_unsigned(2,12) then
		    next_state <= idle;
		  else
		    next_state <= readLocalRX;
		  end if;
		  
		when others =>
		  next_state <= idle;
		  
    end case;
  end process;
  
  ----  Process 2 : Decides which data put in the fifo  ----
  
  process(present_state, EventBuilder_DataValid, EventBuilder_Data, LocalRX_Data)
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
	
	   when LocalRX_length =>
	     internalWrreq <= '1';
	     internalData <= LocalRX_Data;
	
	   when readEventBuilder =>
	     internalWrreq <= '1';
	     internalData <= std_logic_vector(EventBuilder_Data);
	
	   when readLocalRX =>
	     internalWrreq <= '1';
	     internalData <= LocalRX_Data;
	  
	   when others =>
	     internalWrreq <= '0';
	     internalData <= conv_std_logic_vector(0,32);

    end case;
  end process;
  
  -- Out Request for Event Builder --
  EventBuilder_OutRequest <= '1' when next_state = EventBuilder_Length
	                              else '0';
  -- Out Request for LocalRX --
  LocalRX_Rdreq <= '1' when next_state = LocalRX_Length or next_state = readLocalRX
	                         else '0';

  ---- Process number 3 : sequential part	plus reset  ----
  process(Clock,Reset)
  begin
    if Reset = '1' then
	   present_state <= idle;
		sequenceLength <= conv_unsigned(0,12);
	 elsif rising_edge(Clock) then
	   if present_state = EventBuilder_Length then
		  sequenceLength <= EventBuilder_Data(11 downto 0);
		elsif present_state = LocalRX_Length then
		  sequenceLength <= unsigned(LocalRX_Data(11 downto 0));
		end if;
	   present_state <= next_state;
	 end if;
  end process;
  
end architecture;
	 