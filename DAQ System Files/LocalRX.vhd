library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use work.DAQ_Package.all;

entity LocalRX is
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
end entity;

architecture description of LocalRX is
 
  ---- This FIFO is used to store data from Ethernet --- 
  component FifoRX is
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
		usedw		: out STD_LOGIC_VECTOR (8 downto 0)
	 );
  end component;
  
  ---- This FIFO is used to store data that have to be read by LocalTX --- 
  component Internal_Fifo is
	 port (
		aclr		: IN STD_LOGIC ;
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	 );
  end component;

  ---- Internal Counter ----
  component Counter_nbitEN 
  generic ( nbit : natural := 12);  
  port(
    Clock: in std_logic;
    Reset: in std_logic;
	 Enable: in std_logic;
    Count : out unsigned (nbit-1 downto 0)
  );
  end component;
   
  
  -- State --
  type state is (idle, waiting, lengthCapture, decode, catchState, changeState,
    writeLength, header1, header2, addressToRead, waitToread, readRegister, footer1, footer2,
    addressToWrite, dataToWrite, writing, resetRegister,readFooter, erase);
	 
  signal present_state, next_state : state := idle; 
  
  -- Temporary Stored Informations --
  signal sequenceLength : unsigned(6 downto 0) := (others=>'0');
  signal whatToWrite : std_logic_vector (31 downto 0) := (others=>'0');
  signal address : natural := 0;
  -- Counter Signals --
  signal counterReset : std_logic;
  signal internalReset : std_logic;
  signal internalEnable : std_logic;
  signal internalCounter : unsigned (6 downto 0);
  -- FifoRX ports --
  signal internalFifoRX_Empty : std_logic;
  signal internalRdreq : std_logic;
  signal internalDataRX : std_logic_vector(31 downto 0);
  -- Data for FifoTX --
  signal internalDataTX : std_logic_vector(31 downto 0);
  signal internalWrreq : std_logic := '0';
  signal internalFifoOut_Empty : std_logic;
  -- Signal used temporary to store the length of the sequence read from Register to write in the LocalTX --
  signal lengthToWrite : unsigned (31 downto 0);

begin

  FifoRX_Empty <= internalFifoRX_Empty;
  FifoOut_Empty <= internalFifoOut_Empty;
  lengthToWrite <= conv_unsigned(0,24) & (('0' & sequenceLength)+('0' & sequenceLength)-conv_unsigned(1,8)); --sequenceLength*2-1
  
  ----  Components port map  ----

  Fifo_RX : FifoRX
  port map (
    clock => Clock,
    data => Ethernet_Data ,
	 rdreq => internalRdreq,
	 aclr => Reset,
	 wrreq => Ethernet_Wrreq,
	 almost_full => FifoRX_AlmostFull,
	 empty => internalFifoRX_Empty,
	 full => FifoRX_Full,
	 q => internalDataRX,
	 usedw => FifoRX_Usage
  );
  
  OutFifo : Internal_Fifo
  port map (
    aclr	=> Reset,
    clock => Clock,
    data	=> internalDataTX,
    rdreq =>  LocalTX_Rdreq,
    wrreq => internalWrreq,
    empty => internalFifoOut_Empty,
    full	=> FifoOut_Full,
    q	=> DataOut
  );
    
  Counter : Counter_nbitEN
  generic map( nbit => 7 )   
  port map (
	 Clock => Clock,
	 Reset => counterReset,
	 Enable => internalEnable,
	 Count => internalCounter
  );
  
  -- Internal Counter Controls: Enable and Reset --
  internalEnable <= '1' when present_state = waiting or present_state = writeLength or present_State = header1 or present_State = header2 or 
    present_state = addressToRead or present_state = addressToWrite or present_state = dataToWrite or present_state=resetRegister or present_state = erase or present_state = readFooter
                        else '0';
  internalReset <= '1' when present_state = idle or present_state = lengthCapture or present_state = decode
	                    else '0';
  counterReset <= internalReset or Reset;
  
  --/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////--
  
  ----  Process 1 : states flow  --
  
  -- Starts with "Idle" state
  -- When The RX Fifo is not empty waits for some cycles (constant Timeout in DAQ_Package)
  -- Then in "lengthCapture" stores the length of the sequence in the sequenceLength Register
  -- During Decode the machine decides what's the instruction to perform
  -- Case 1: Change the internal state of the FS machine
  --   During catchState the signal of the next_state is stored in "whatToWrite" register
  --   During changeState the whatToWrite register is written at the address 1 (dedicated to next_state)
  -- Case 2 : Read some registers
  --   First the length of the sequence read is stored in the out Fifo
  --   Then the header1 and the header2 (header are needed to differentiate a register sequence from an event sequence)
  --   During "addressToRead" the address to read is stored in the Address Register
  --   Then waits one clock to be sure the register file provides the right data (waitToRead)
  --   During "readRegister" the data is read and sent to the Out Fifo. Then if there are othere registers to read next_state=addressToRead again 
  --   This cycle continues for every address requested by the input sequence. Then writes the footer sequence and then back to idle
  -- Case 3: Write some registers
  --   AddressToWrite: the address is stored in the Address Register
  --   DataToWrite: the data is stored in the "whatToWrite" register
  --   Writing: the data is written at the provided address
  -- Case 4: Reset Registers
  --   Resets the Register at the given address
  --
  -- Then footer sequence is read from the fifo (readFooter state)... it's like erase state
  --
  -- Finally if a Write request or a Reset request arrives when DAQ_Config='0' the instruction is erased
  -- During Erase state the sequence is read till the end without performing any action
  --   
  --//////////////////////////////////////////////////////////////////////////////////////////////////////////////7//////////////////////////////-- 
  
  process(present_state, internalFifoRX_Empty, internalCounter,internalDataRX, DAQ_Config,
    Register_DataValid, internalFifoOut_Empty, sequenceLength)
  begin
    case present_state is
	 
	   when idle =>
		  if internalFifoRX_Empty = '0' and internalFifoOut_Empty = '1' then
		    next_state <= waiting;
		  else
		    next_state <= idle;
		  end if;
		  
		when waiting =>
		  if internalCounter >= conv_unsigned(Timeout-1,12) then
		    next_state <= lengthCapture;
		  else
		    next_state <= waiting;
		  end if;
		
		when lengthCapture =>
		  next_state <= decode;
		
		when decode =>
		  if internalDataRX = Header_ChangeState then
		    next_state <= catchState;
		  elsif internalDataRX = Header_ReadRegs then
		    next_state <= writeLength;
		  elsif internalDataRX = Header_WriteRegs then
          if DAQ_Config = '1' then
			   next_state <= addressToWrite;
		    else
			   next_state <= erase;
			 end if;
		  elsif internalDataRX = Header_ResetRegs then
		    if DAQ_Config = '1' then
		      next_state <= resetRegister;
		    else
			   next_state <= erase;
			 end if;
		  else
		    next_state <= idle;
		  end if;
		
		when catchState =>
		  next_state <= changeState;
		  
		when changeState =>
		  next_state <= readFooter;
		
		when writeLength =>
		  next_state <= header1;
		
		when header1 =>
		  next_state <= header2;
		
		when header2 =>
		  next_state <= addressToRead;
		
		when addressToRead =>
		  next_state <= waitToRead;
		
		when waitToRead =>
		  if Register_DataValid = '1' then
		    next_state <= readRegister;
		  else
		    next_state <= waitToRead;
		  end if;
		
		when readRegister =>
		  if internalCounter >= sequenceLength then
		    next_state <= footer1;
		  else
		    next_state <= addressToRead;
		  end if;
		
		when footer1 =>
		  next_state <= footer2;
		
		when footer2 =>
		  next_state <= readFooter;
		
		when addressToWrite =>
		  next_state <= dataToWrite;
		
		when dataToWrite =>
		  next_state <= writing;
		
		when writing =>
		  if internalCounter >= sequenceLength-conv_unsigned(4,32) then
		    next_state <= readFooter;
		  else
		    next_state <= addressToWrite;
		  end if;
		
      when resetRegister =>
		  if internalCounter >= sequenceLength-conv_unsigned(4,32) then
		    next_state <= readFooter;
		  else
		    next_state <= resetRegister;
		  end if;
		
		when erase =>
		  if internalCounter >= sequenceLength-conv_unsigned(3,32) then
		    next_state <= idle;
		  else
		    next_state <= erase;
		  end if;
		
		when readFooter =>
		  next_state <= idle;
		
		when others =>
		  next_state <= idle;
		    
    end case;
  end process;
  
  ----  Process 2 : Decides which data put in the fifo  ----
  
  process(present_State, address, Register_DataRead, Register_DataValid, whatToWrite, lengthToWrite)
  begin
    case present_state is
	   
		when idle =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
	 --	Init Sequence --  
		when waiting =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		
		when lengthCapture =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		  
		when decode =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
    -- Change State sequence -- 
		when catchState =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		 		  
		when changeState =>
		  Register_Wrreq <= '1';
		  Register_Rdreq <= '0';
		  Register_Address <= 1;
		  Register_DataWrite <= whatToWrite;
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
    -- Read registers sequence -- 
		when writeLength =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= std_logic_vector(lengthToWrite);
		  internalWrreq <= '1';
		
	   when header1 =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= Header1_RF;
		  internalWrreq <= '1';

		when header2 =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= Header2_RF;
		  internalWrreq <= '1';
		
		when addressToRead =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';

		when waitToRead =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '1';
		  Register_Address <= address;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(address,32);
		  if Register_DataValid = '1' then
		    internalWrreq <= '1';
		  else
		    internalWrreq <= '0';
		  end if;
		
	   when readRegister =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '1';
		  Register_Address <= address;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= Register_DataRead;
		  internalWrreq <= '1';
		  
	   when footer1 =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= Footer1_RF;
		  internalWrreq <= '1';

		when footer2 =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= Footer2_RF;
		  internalWrreq <= '1';
    -- Write sequence -- 
		when addressToWrite =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		  
		when dataToWrite =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= address;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		  
		when writing =>
		  Register_Wrreq <= '1';
		  Register_Rdreq <= '0';
		  Register_Address <= address;
		  Register_DataWrite <= whatToWrite;
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
    -- Reset Registers sequence --
		when resetRegister =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
	-- Erase an "impossible to perform" action --	  
		when erase =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
	  	
		when readFooter =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		
	  when others =>
		  Register_Wrreq <= '0';
		  Register_Rdreq <= '0';
		  Register_Address <= 0;
		  Register_DataWrite <= conv_std_logic_vector(0,32);
		  internalDataTX <= conv_std_logic_vector(0,32);
		  internalWrreq <= '0';
		  
	 end case;
  end process;
  
  -- Before which states do I have to read my RX Fifo? --
  internalRdreq <= '1' when next_state = lengthCapture or next_state = decode or next_state=catchState or next_state = addressToRead or
     next_state = addressToWrite or next_state = dataToWrite or next_state = resetRegister or next_state = erase or next_state = readFooter
	                    else '0';
	
  ---- Process number 3 : sequential part	plus reset  ----
  process(Clock,Reset)
  begin
    if Reset = '1' then
	   present_state <= idle;
		sequenceLength <= conv_unsigned(0,7);
		whatToWrite <= conv_std_logic_vector(0,32);
		Address <= 0;
		Data_Ready<='0';
	 elsif rising_edge(clock) then
	   -- During LengthCapture length can be read from FifoRx and it is stored in the sequenceLength Register --
		if present_state = lengthCapture then
		  sequenceLength <= unsigned(internalDataRX(6 downto 0));
		end if;
		-- The address is taken from FifoRx and stored in the Address Register before read/write --
		if present_state = addressToRead or present_state = addressToWrite then
		  Address <= conv_integer(internalDataRX);
		end if;
      -- The data I have to write are stored in the "what to write" register before a write or a change of state --
		if present_state = dataToWrite or present_State = catchState then
		  whatToWrite <= internalDataRX;
		end if;
      -- The address is decoded to reset the right register using Slective_Reset --
	   if present_state = resetRegister then
		  for I in 0 to N_CONTROL_REGS-1 loop
		    if conv_integer(internalDataRX) = I then
		      Register_SelectiveReset(I) <= '1';
			 else
			   Register_SelectiveReset(I) <= '0';
		    end if;
		  end loop;
	   elsif present_state = idle then
	    Register_SelectiveReset <= (others=>'0');
      end if;
	   -- LocalRx informs LocalTX data are ready when the read process has terminated --
	   if present_state = idle and internalFifoOut_Empty = '0' then
	     Data_Ready <= '1';
	   else
		  Data_Ready <= '0';
	   end if;
    
	 present_state <= next_state;
		
    end if;
  end process; 
end architecture;	 
	 