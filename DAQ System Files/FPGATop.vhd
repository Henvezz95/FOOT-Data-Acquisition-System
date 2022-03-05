-- -----------------------------------------------------------------------
-- FPGA Top for DE0DAQ  application
-- -----------------------------------------------------------------------          

library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
			
-- ----------------------------------------------
entity FPGATop is
------------------------------------------------
  port (
	 Clock    : in     std_logic;                         -- System clock  1 (50 MHz)
    Reset    : in     std_logic;        
	 --      ///////// KEY /////////
	 KEY : in std_logic_vector(1 downto 0);
	 -- 		///////// LED /////////
    LED : out std_logic_vector(7 downto 0);
	 --		///////// SW /////////
    SW  : in  std_logic_vector(3 downto 0);	
	 --      ///////// GPIO /////////
    GPIO_0 :  inout   std_logic_vector(35 downto 0);
    GPIO_1 :  inout   std_logic_vector(35 downto 0);
	 -- To HPS
    f2h_stm_hw_events  : out  std_logic_vector(27 downto 0) := (others => 'X'); -- stm_hwevents
    button_pio         : out   std_logic_vector(3 downto 0)  := (others => 'X'); -- export
    dipsw_pio          : out   std_logic_vector(3 downto 0)  := (others => 'X'); -- export
    led_pio            : in   std_logic_vector(7 downto 0);                     -- export
--    fifo_data_export      : out   std_logic_vector(31 downto 0) := (others => 'X'); -- export
--    fifo_reg_export       : out   std_logic_vector(31 downto 0) := (others => 'X'); -- export
--    fifo_read_ack_export  : in   std_logic_vector(31 downto 0)                     -- export	
    iofifo_datain      : in    std_logic_vector(31 downto 0);                    -- datain
    iofifo_writereq    : in    std_logic;                                        -- writereq
    iofifo_instatus    : out   std_logic_vector(31 downto 0) := (others => 'X'); -- instatus
    iofifo_dataout     : out   std_logic_vector(31 downto 0) := (others => 'X'); -- dataout
    iofifo_readack     : in    std_logic;                                        -- readack
    iofifo_outstatus   : out   std_logic_vector(31 downto 0) := (others => 'X'); -- outstatus
	iofifo_regdataout  : out   std_logic_vector(31 downto 0) := (others => 'X'); -- regdataout
    iofifo_regreadack  : in    std_logic;                                        -- regreadack
    iofifo_regoutstatus  : out std_logic_vector(31 downto 0) := (others => 'X')  -- regoutstatus    
  );
end entity FPGATop;
	  
-----------------------------------------------------------------
architecture structural of FPGATop is
-----------------------------------------------------------------
  signal KEYD, nKEY : std_logic_vector(1 downto 0) := "00";   
  signal SWD : std_logic_vector(3 downto 0) := "0000";   

  signal MainTriggerExt, MainTriggerKey, MainTrigger : std_logic;
  signal BCOClock, BCOReset : std_logic;

  signal ledst   : std_logic_vector(7 downto 0);
  
  signal longerReadAck, longerEndOfEvent, longerTrigger : std_logic := '0';

  -- From DAQModule 
  signal Data_Stream : std_logic_vector (31 downto 0);  
  signal RegData_Stream : std_logic_vector (31 downto 0);
  signal readFromDAQ, writeReqToOutFifo : std_logic;
  signal readFromRegister, wrreqToOutFifo_reg : std_logic;
  signal Busy_Out : std_logic := '0';
  signal TX_Empty : std_logic;
  signal RegTX_Empty : std_logic;
  signal RX_AlmostFullFlag : std_logic; 
  signal Errors : std_logic;
  signal Led_State: std_logic_vector(2 downto 0);
  signal Ethernet_Wrreq : std_logic;
  signal Ethernet_DataIn : std_logic_vector(31 downto 0);
  
  -- for fifo IO
  signal fifo_readack : STD_LOGIC ;
  signal full, almost_full, empty : STD_LOGIC ;
  signal dataOut : STD_LOGIC_VECTOR (31 DOWNTO 0);
  signal usedw	 : STD_LOGIC_VECTOR (13 DOWNTO 0);
  
  -- for register fifo
  signal regfifostatus : std_Logic_vector (31 downto 0);
  signal regfifo_readack : std_logic := '0';
  signal regfull, regalmost_full, regempty : STD_LOGIC ;
  signal regdataOut : STD_LOGIC_VECTOR (31 DOWNTO 0);
  signal regusedw	 : STD_LOGIC_VECTOR (8 DOWNTO 0);
  
begin


  --
  --    step 0: Get External input signals
  --      debounce KEY and SWITCH signals
  --  
  MainTriggerExt <= GPIO_0(3);
  BCOReset       <= GPIO_0(5);
  BCOClock       <= GPIO_0(7);

  -- debounce all input signals			
  -- debounce KEY - note usually in a high state -> invert logic
  nKey <= not(KEY);
  dbc0: entity work.Debounce  
    port map( Clk=>Clock, Reset=>Reset,   button=>nKEY(0),   pulse=>KEYD(0) );
  dbc1: entity work.Debounce  
    port map( Clk=>Clock, Reset=>Reset,   button=>nKEY(1),   pulse=>KEYD(1) );
  
  -- debounce switches  
  dbc2: entity work.Debounce  
    port map(Clk=> Clock, Reset=>Reset,   button=>SW(0),     pulse=>SWD(0) );
  dbc3: entity work.Debounce  
    port map(Clk=> Clock, Reset=>Reset,   button=>SW(1),     pulse=>SWD(1) );
  dbc4: entity work.Debounce  
    port map(Clk=> Clock, Reset=>Reset,   button=>SW(2),     pulse=>SWD(2) );
  dbc5: entity work.Debounce  
    port map(Clk=> Clock, Reset=>Reset,   button=>SW(3),     pulse=>SWD(3) );  

  --
  --    step 1: Make some DAQ-like signals
  --  
  -- When TX fifo is not empty, data are sent to Event FIFO
  -- MainTrigger is key 0
  --
  process(Clock)
    variable oldKey0 : std_logic;
  begin
    if ( rising_edge(Clock) ) then
	  WriteReqToOutFifo <= readFromDAQ and not(TX_Empty);
     if TX_Empty = '0' and almost_full = '0' then
	    readFromDAQ <= '1';
	  else
	    readFromDAQ <= '0';
	  end if;
	  if( keyd(0)='1' and oldkey0='0' )then
	    MainTriggerKey <= '1';
	  else
	    MainTriggerKey <= '0';
	  end if;
	  oldKey0 := KeyD(0);
	end if;
  end process;
  
  RegTX_Empty <= regfifostatus(16);
  
  process(Clock)
  begin
    if ( rising_edge(Clock) ) then
	  wrreqToOutFifo_reg <= readFromRegister and not(regTX_Empty);
     if RegTX_Empty = '0' and regalmost_full = '0' then
	    readFromRegister <= '1';
	  else
	    readFromRegister <= '0';
	  end if;
	end if;
  end process;

  MainTrigger <= MainTriggerKey or MainTriggerExt; -- trigger is an OR!! FOR THE MOMENT ONLY!!
  
  --
  --    step 2: Port map of the DAQ Module
  --  
  -- Process generate Event  
  EvSim: entity work.DAQ_OnFPGA 
    port map(
      Clock => Clock,
	  Reset => Reset,
	  
	  Reset_Errors => KEYD(1),
	  BCOClock => BCOClock,
	  BCOReset => BCOReset,
	  Trigger => MainTrigger,
	
      -- To State Signals --
	  TowardRun => SWD(0),
	  TowardIdle => SWD(1),
	  ReadAll => SWD(2),

      -- input RX fifo
	  Ethernet_Wrreq => Ethernet_Wrreq,
	  Ethernet_DataIn => Ethernet_DataIn,
	  RX_almostFullFlag => RX_AlmostFullFlag,

	  --output TX data fifo
	  Ethernet_DataOut => Data_Stream,
	  TX_emptyFlag => TX_Empty,
	  Ethernet_Rdreq => readFromDAQ,

	  
	  --output TX register fifo
	  Ethernet_RegistersOut => regData_Stream,
	  Ethernet_RegistersRdreq => readFromRegister,
     regfifostatus => regfifostatus,
		
	  -- Outputs --
	  Busy_Out => Busy_Out,
	  Errors => Errors,
	  -- Led State --
	  Led_State => Led_State
    );
	
  --
  --    step 3: Input commands from RX
  --  

  InCmd: entity work.InputFifoControl
    port map(
      Clk => Clock,
	   Reset => Reset,
 	   -- From HPS signal
      iofifo_datain      => iofifo_datain, 
      iofifo_writereq    => iofifo_writereq,
      iofifo_instatus    => iofifo_instatus,
      -- To DAQ Module
	  RX_almostFullFlag  => RX_almostFullFlag,
--	  RX_almostFullFlag  => almost_full,
      Ethernet_Wrreq     => Ethernet_Wrreq, 
	  Ethernet_DataIn    => Ethernet_DataIn
	 );

  --
  --    step 4: Fifo for output; TX
  --  
	

  EVF: entity work.EventFifo 
  port map (
	 clock		=> Clock,
-- hack to see some data!!	 
--	 data		=> Ethernet_DataIn,
--	 wrreq		=> Ethernet_Wrreq,
	 data		=> Data_Stream,
	 wrreq		=> WriteReqToOutFifo,
	 rdreq		=> fifo_readack,      -- it's a read-ahead fifo
	 q		    => dataOut,		-- goes to HPS
	 almost_full	=> almost_full,
	 empty		=> empty,
	 full		=> full,
	 usedw		=> usedw
  );
  
  RegEVF: entity work.RegEventFifo
  port map (
	 clock		=> Clock,
	 data		=> RegData_Stream,
	 wrreq		=> wrreqToOutFifo_reg,
	 rdreq		=> regfifo_readack,      
	 q		    => regdataOut,		-- goes to HPS
	 almost_full	=> regalmost_full,
	 empty		=> regempty,
	 full		=> regfull,
	 usedw		=> regusedw
  );
  


  --
  --    step 5: FIFO reading acknowledge provided by HPS
  --  
  process(Clock, reset)
    variable oldReadack, oldRegReadack: std_logic := '0';
  begin
	if( reset='1') then
	  fifo_readack <= '0';
      regfifo_readack <= '0';
	  oldReadack := '0';
	  oldRegReadack := '0';
    elsif ( rising_edge(Clock) ) then
      -- data fifo
	  if( (iofifo_readack='1') and (oldReadack='0') )then
	    fifo_readack <= '1';
	  else
	    fifo_readack <= '0';
	  end if;
	  oldReadack := iofifo_readack;
	  -- reg fifo
	  if( (iofifo_regreadack='1') and (oldRegReadack='0') )then
	    regfifo_readack <= '1';
	  else
	    regfifo_readack <= '0';
	  end if;
	  oldRegReadack := iofifo_regreadack;
	end if;
  end process;
  
  

  --
  --    step 6: provide output signals to HPS
  --  

   
  -- Register Fifo status
  iofifo_regoutstatus <= x"000"& '0' 
		& Regfull & Regalmost_full & Regempty & 
		"000000" & Regfull & Regusedw;

  -- fifo data
  iofifo_dataout <= DataOut;
  iofifo_regdataout <= RegDataOut;
  -- This is the FIFO control structure to HPS
  iofifo_outstatus <=   x"000"& '0' & full & almost_full & empty & '0' & full & usedw;
  -- This contains keys and most important FIFO bits -> goes to HPS
  button_pio <= almost_full & empty & keyd; -- key extended: contains push button and fifo flags
  -- switch status
  dipsw_pio <= SWD;

  -- stm_hwevents:  how these information is used??
  f2h_stm_hw_events <=  "000" & full & almost_full & empty & '0' & full & usedw & swd & keyd;  
			
  --
  --    step 7: provide some output signals to LED and GPIO
  --  

  -- make some signals longer so that they become suitable for LED pulses
  lp1: entity work.LongerPulse
       port map( Clk=>Clock, Reset=>Reset,  pulse=>MainTrigger,   longPulse=>longerTrigger );
  lp2: entity work.LongerPulse
       port map( Clk=>Clock, Reset=>Reset,  pulse=>fifo_readack,  longPulse=>longerReadAck );
 	
  -- Out to LEDs
  ledst <= longerReadAck & almost_full & not(empty) & longerTrigger & Led_State & Errors;
  led <= ledst or led_pio;
	 
  -- output of some key signals to GPIO_0
  GPIO_0(2 downto 0) <= "000";
  GPIO_0(3) <='Z';
  GPIO_0(4) <='0';
  GPIO_0(5) <='Z';
  GPIO_0(6) <='0';
  GPIO_0(7) <='Z';
  GPIO_0(8) <='0';
  GPIO_0(9) <= Busy_Out;
  GPIO_0(18 downto 10) <= (others=>'0');
  GPIO_0(35 downto 19) <= iofifo_readack & Errors & MainTrigger & swd & keyd & ledst;
  GPIO_1(35 downto 0) <=  (others=>'0');
 
						
end architecture structural;
