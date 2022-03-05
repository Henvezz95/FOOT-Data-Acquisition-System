library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;


entity Trigger_Control is
  port (
    --Inputs 
    Clock : in std_logic;          
    Reset : in std_logic;                
    --The Finite state machine is in Running State
    DAQIsRunning : in std_logic;  
    --Resets Counters preparing for run 
    DAQ_Reset : in std_logic;
	 -- Resets errors
    Reset_Errors: in std_logic;	 
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
end entity;


   
   ----Architecture of the Trigger Control ----
  
architecture Structural of Trigger_Control is

  --Declaration of components--
  --ClockCounter 38bit
  component Counter_nbit
  generic ( nbit : natural := 38);
    port(
      CLK: in std_logic;
      RESET: in std_logic;
      COUNT : out unsigned (nbit-1 downto 0)
    );
  end Component;
  --Used for BCOClockCounter and TriggerCounter
  component RisingEdge_Counter 
    port(
      clock    : in std_logic;
      reset    : in std_logic;
      eventToCount    : in std_logic;   
       --Output 
      counts : out unsigned (31 downto 0)
    );
    end Component;
  --Busy_Stretch--
  --Makes BusyOut='0' if Busy has been '0' for 16 or more clocks
  component Busy_Stretch 
    generic (nbit: natural := 16); 
    port (
     --Inputs
      Clock : in std_logic;
      Reset : in std_logic;
     Busy : in std_logic;
     --Outputs
      Busy_Out : out std_logic
    );
  end component;
    
  ----  Internal Signals  ----	 
                        
  signal Internal_Trigger_ForCounter : std_logic :='0';     
  -- Used if DaqReset acts like Reset  
  signal EveryReset : std_logic;                        
  -- Used if BCOReset acts like Reset
  signal BCOCounterReset : std_logic;                  
  signal past_trigger : std_logic := '0';                       
  
begin            --Structure description--
                                                  
  EveryReset <= Reset or DAQ_Reset;      
  BCOCounterReset <= Reset or BCOReset;   
                                                  
  -----Instantiation of components-----
  --Counts the number of clocks
  ClockCounter : Counter_nbit 
  port map(                                       
    CLK => Clock,
    RESET => EveryReset,
    COUNT(37 downto 6) => ClkCounter,
    COUNT(5 downto 0) =>  LSB_ClkCounter
  );
                                                   
   --Counts the number of main trigger
  MainTriggerCounter : RisingEdge_Counter 
  port map(                                       
    clock => Clock,
    reset => EveryReset,
    eventToCount => Internal_Trigger_ForCounter,
    counts => triggerCounter
  );  
                                                  
                                                
  --BCO_Counter--
  --Counts the number of BCOClocks
  BCO_Counter : RisingEdge_Counter
  port map(                                        
    clock => Clock,
    reset => BCOCounterReset,
    eventToCount => BCOClock,
    counts => BCOCounter
  );
   
  --Busy_Stretcher--
  --Busy_Out = '0' if Busy has been '0' for 16 or more clocks
  Busy_Stretcher : Busy_Stretch
  port map(                                        
    Clock => Clock,
    Reset => Reset,
    Busy => Busy,
    Busy_Out => Busy_Out
  );
   
  Trigger_Verify : process (Clock, EveryReset, Reset_Errors)  
  begin
    if EveryReset = '1' then      
      Error_Busy <='0';
      Error_notRunning <='0';
      Internal_Trigger_ForCounter<='0';   
      past_trigger<='0';
    elsif Reset_Errors = '1' then
      Error_Busy <='0';
      Error_notRunning <='0';	 
    elsif rising_edge(Clock) then   
      if Trigger = '1' and past_trigger = '0' then
        if Busy = '0' and DAQIsRunning = '1' then
          Internal_Trigger_ForCounter<='1';
        else
          Internal_Trigger_ForCounter<='0';
          if Busy = '1' then
            Error_Busy <= '1';
          end if;
          if DAQIsRunning = '0' then
            Error_notRunning <= '1';
          end if;
        end if;
      else
        Internal_Trigger_ForCounter<='0';
      end if;
      past_trigger<=Trigger;
    end if;
  end process;
   
  Internal_Trigger <= Internal_Trigger_ForCounter; 

end architecture;
     

     