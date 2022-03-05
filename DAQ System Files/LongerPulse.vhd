-- -----------------------------------------------------------------------
-- LongerPulse
-- -----------------------------------------------------------------------          

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity LongerPulse is
  generic(DURATION : natural := 2000000); -- 0.1 s
  port(
    clk    : in  std_logic;  
    reset  : in  std_logic;  
	-- input signal
	pulse       : in std_logic; 
	longPulse   : out std_logic
	);
end entity LongerPulse;

architecture logic of LongerPulse is

begin

  process(clk, reset)
    variable counter : natural := DURATION;
  begin
	if( reset='1') then
      longPulse<='0';
    elsif rising_edge(clk) then
      if( pulse='1') then
	    counter := DURATION;
        longPulse <= '1';
	  elsif counter>0 then
	    counter := counter-1;
        longPulse <= '1';
	  else
	    counter := 0;
        longPulse <= '0';
	  end if;	  
    end if;
  end process;
  
end architecture logic;