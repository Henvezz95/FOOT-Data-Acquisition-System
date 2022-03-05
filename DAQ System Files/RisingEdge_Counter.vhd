library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


-- Counts "eventToCount" signal rising edges


entity RisingEdge_Counter is			
  port(
    clock    : in std_logic;
    reset    : in std_logic;
    --  Signal where to count 
    eventToCount    : in std_logic;    
    -- Output: number of rising edges found in coincidence
    --         with the enable signal
    counts : out unsigned (31 downto 0) := conv_unsigned (0,32)
    );
end entity;


architecture behave of RisingEdge_Counter is

  signal localCounts   : unsigned (31 downto 0) := conv_unsigned (0,32) ;
  signal last_EventToCount : std_logic := '0';     						
  --Indicates the last value of the Event that we want to count
  --This assures that a multi-clock pulse is considered as one event 

  begin
  -- count on rising edge of eventToCount
  -- Asyncronous Reset
  
  process (clock, reset) is
  begin
    if reset='1' then				
      localCounts <= conv_unsigned(0,32);
      last_EventToCount <= '0';	        
      counts <= conv_unsigned(0,32);
    elsif rising_edge(clock) then
      counts <= localCounts;
      if eventToCount='1' and last_EventToCount= '0' then
        localCounts <= localCounts + conv_unsigned(1,32);  
      end if;
      last_EventToCount <= eventToCount; 
    end if;      
  end process;

end architecture behave;