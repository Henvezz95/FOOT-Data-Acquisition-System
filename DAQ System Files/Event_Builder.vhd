library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.DAQ_Package.all;

entity Event_Builder is
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
	 -- Empty is delayed by 6 clocks
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
end entity;

architecture behavior of Event_Builder is

  ---- This FIFO is used to store data from the stream --- 
  component SC_FIFO is
	 port(
		clock		: IN std_logic ;
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		almost_full	: OUT STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
	 );
  end component;
  
  ---- This FIFO is used to store data about time and length of every event --- 
  component metadata_Fifo 
    PORT(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (127 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (127 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
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
  
  ----  Internal Signals  ----
  
  type out_state is (idle, lengthDeclaration, header_1, header_2, trigCounter, BCOCounter, ClkCounter, sequence, footer_1, footer_2);
  signal present_state, next_state : out_state := idle;
  
  signal counterReset : std_logic;
  signal internalReset : std_logic;
  signal ResetAll: std_logic;
  signal internalCounter : unsigned (11 downto 0);
  -- internalRdreq indicates when the main FIFO has to output data --
  signal internalRdreq : std_logic;
  -- internalWrreq indicates when the main FIFO has to record data --
  signal internalWrreq : std_logic;
  signal internalFull : std_logic;
  signal internalAlmostFull : std_logic;
  signal internalEmpty : std_logic;
  signal internalEventsInTheFifo : std_logic_vector(7 downto 0);
  -- Ouput of main FIFO --
  signal FifoOut : std_logic_vector (31 downto 0);
  signal sequenceLength : unsigned (8 downto 0) := (others=>'0');
  --Signals of metadata FIFO --
  --Gives out informations --
  signal metadataRd : std_logic;
  --Records informations--
  signal metadataWr : std_logic; 
  signal inmetadata : std_logic_vector (127 downto 0);
  signal outmetadata : std_logic_vector (127 downto 0);
  
  signal pastDataValid : std_logic := '0';
  signal pastendOfEvent : std_logic := '0';
  --An Event is being read. The value is assigned sequentially--
  signal internalReadingEvent : std_logic :='0';
  -- Variable Header --
  signal Header2_Variable : unsigned (31 downto 0) := x"BECCBECC";
  -- In order to delay Empty_Fifo --
  constant ones : std_logic_vector := "111111";
  signal EmptyHistory : std_logic_vector(5 downto 0) := ones;
  
 
  
begin
  
  ResetAll <= Reset or DAQ_Reset;
  AlmostFull <= internalAlmostFull;
  Empty_Fifo <= '1' when EmptyHistory = ones
                    else '0';
  ReadingEvent <= internalReadingEvent;
  FifoFull <= internalFull;
  EventsInTheFifo <= internalEventsInTheFifo;
  inmetadata <= std_logic_vector(inClkCounter & inBCOCounter & inTriggerCounter & in_Data);
  
  ----  Components port map  ----

  FifoData : SC_FIFO 
  port map (
    clock => Clock,
    data => std_logic_vector(in_Data),
	 rdreq => internalRdreq,
	 sclr => ResetAll,
	 wrreq => internalWrreq,
	 almost_full => internalAlmostFull,
	 empty => internalEmpty,
	 full => internalFull,
	 q => FifoOut,
	 usedw => Fifo_Usage
  );
  FifoMetadata : metadata_Fifo 
  port map (
    clock => Clock,
	 data => inmetadata,
	 rdreq => metadataRd,
	 sclr => ResetAll,
	 wrreq => metadataWr,
	 Full => MetadataFifoFull,
	 q => outmetadata,
	 usedw => internalEventsInTheFifo
  ); 
  Counter : Counter_nbit
  generic map( nbit => 12)   
  port map (
	 CLK => Clock,
	 RESET => counterReset,
	 COUNT => internalCounter
  );
  
  --Reset Counter
  internalReset <= '1' when present_state = idle
	                    else '0';
  counterReset <= internalReset or ResetAll;
  
  ----  Process 1 : states flow  --
  
  States : process (
    outRequest, internalEmpty,internalCounter, internalReadingEvent,
    sequenceLength, present_state, internalEventsInTheFifo)
  begin
    case present_state is
	 
    when idle =>
	   if outRequest = '1' and (internalEventsInTheFifo > conv_std_logic_vector(1,8) or (internalEventsInTheFifo = conv_std_logic_vector(1,8) and internalReadingEvent = '0')) then
		  next_state<=lengthDeclaration;
		else
		  next_state<= idle;
		end if;
		
	 when lengthDeclaration =>
		next_state <= header_1;
		
	 when header_1 =>
		next_state <= header_2;
		
	 when header_2 =>
		next_state <= trigCounter;
		
	 when trigCounter =>
		next_state <= BCOCounter;
		
	 when BCOCounter =>
		next_state <= ClkCounter;
		
    when ClkCounter =>
		next_state <= sequence;
		
	 when sequence =>
      if internalCounter >= sequenceLength-conv_unsigned(3,12) then  
        next_state <= footer_1;  
      else
        next_state<=sequence;			 
      end if;
		
	 when footer_1 =>
	  next_state <= footer_2;
	  
	 when footer_2 =>
	  next_state <= idle; 
	  
    when others =>
		next_state<=idle;  
		
    end case;
  end process;
  
  ----  Process 2 : Decides the output data  ----
  
  Output : process (present_state, outmetadata, FifoOut,Header2_Variable )
  begin
    case present_state is
	 
	   when idle =>
		  out_Data <= conv_unsigned(0,32);
		  outData_Valid <= '0';
		  
	   when lengthDeclaration => 
		  out_Data <=unsigned(outmetadata(31 downto 0))+conv_unsigned(8,9);
		  outData_Valid <= '1';
		  
		when header_1 =>
		  out_Data <= unsigned(Header1_EB); 
		  outData_Valid <= '1';
		  
		when header_2 =>
		  out_Data <= unsigned(Header2_Variable); 
		  outData_Valid <= '1';
		  
		when trigCounter =>
		  out_Data <=unsigned(outmetadata(63 downto 32));
		  outData_Valid <= '1';
		  
		when BCOCounter =>
		  out_Data <=unsigned(outmetadata(95 downto 64));
		  outData_Valid <= '1';
		  
		when ClkCounter =>
		  out_Data <=unsigned(outmetadata(127 downto 96));
		  outData_Valid <= '1';
		  
		when sequence =>
		  out_Data <= unsigned(FifoOut);
		  outData_Valid <= '1';
		  
		when footer_1 =>
		  out_Data <= unsigned(Footer1_EB); 
		  outData_Valid <= '1';
		  
		when footer_2 =>
		  out_Data <= unsigned(Footer2_EB); 
		  outData_Valid <= '1';
		  
		when others => out_Data<=conv_unsigned(0,32);
		
	 end case;
  end process;
  
 ---- Process 3: Busy out ----
 
  process(Busy_Mode, internalWrreq, internalAlmostFull, internalEmpty, internalReadingEvent)
  Begin
    if Busy_Mode = '0' then
	   if internalReadingEvent = '0' and internalAlmostFull = '0' then
		  Busy <= '0';
		else
		  Busy <= '1';
		end if;
	 else
	   if internalEmpty = '1' then 
		  Busy <= '0';
		else
		  Busy <= '1';
		end if;
	 end if;
  end process;
							 
  --InternalRdRequest
  internalRdreq <= '1' when next_state = lengthDeclaration or (present_state = sequence and internalCounter <= sequenceLength-conv_unsigned(4,32))
                       else '0';
  --InternalWrreq
  internalWrreq <= Data_Valid;
  
  --metadataWr
  metadataWr <= '1' when pastDataValid = '0' and Data_Valid = '1' and internalReadingEvent = '0' 
                    else '0';
 
  --MetadataRd
  metadataRd <= '1' when next_state = lengthDeclaration
                    else '0';

  -- Out_Ready is high when there is a ready event in the fifo
  out_Ready <= '1' when (internalEventsInTheFifo > conv_std_logic_vector(1,8)) or (internalEventsInTheFifo = conv_std_logic_vector(1,8) and internalReadingEvent = '0')
		            else '0';
  ---- Process number 4 : sequential part	plus reset  ----
  
  process(Clock, ResetAll)
  begin
    if ResetAll = '1' then
	   present_state <= idle;
		pastDataValid <= '0';
		pastEndOfEvent <= '0';
		sequenceLength  <= conv_unsigned(0,9);
		internalReadingEvent <= '0';
    elsif (Clock'event and Clock='1') then
	   EmptyHistory <= EmptyHistory(4 downto 0) & internalEmpty;
      present_state <= next_state;
		pastDataValid <= Data_Valid;
		pastEndOfEvent <= endOfEvent;
		sequenceLength <= unsigned(outmetadata(8 downto 0))+conv_unsigned(8,9);
		--Decides if an event is being recorded--
		if pastendOfEvent = '1' and endOfEvent = '0' then
		  internalReadingEvent <= '0';
		elsif Data_Valid = '1' then
		  internalReadingEvent <= '1';
		end if;
		-- Variable Header --
		Header2_Variable <= unsigned(Variable_Header);
		-- Counters output --
		outTrigger <= inTrigger;
		outTriggerCounter <= inTriggerCounter;
		outBCOCounter <= inBCOCounter;
		outClkCounter <= inClkCounter;
		outLSB_ClkCounter <= inLSB_ClkCounter;
    end if;
  end process;
  
end architecture;