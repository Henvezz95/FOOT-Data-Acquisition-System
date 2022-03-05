library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Counter_nbitEN is
  generic ( nbit : natural := 16);
  port(
    Clock : in std_logic;
    Reset : in std_logic;
	 Enable : in std_logic;
    Count : out unsigned (nbit-1 downto 0)
  );
end Counter_nbitEN;


architecture behavior of Counter_nbitEN is

  signal value_temp : unsigned (nbit-1 downto 0) := ( others =>'0'); -- 

begin 

  process(Clock, Reset, Enable)  
  begin					
    if Reset = '1' then
      value_temp <= ( others =>'0');
	elsif rising_edge(Clock) and Enable = '1' then
      value_temp <= value_temp + conv_unsigned(1,nbit); 
    end if;
  end process;

  COUNT <= value_temp;

end architecture;



