library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Counter_nbit is
  generic ( nbit : natural := 16);
  port(
    CLK: in std_logic;
    RESET: in std_logic;
    COUNT : out unsigned (nbit-1 downto 0)
  );
end Counter_nbit;


architecture behavior of Counter_nbit is

  signal value_temp : unsigned (nbit-1 downto 0) := ( others =>'0'); -- 

begin 

  process(CLK, RESET)  
  begin					
    if RESET = '1' then
      value_temp <= ( others =>'0');
	elsif rising_edge(CLK) then
      value_temp <= value_temp + conv_unsigned(1,nbit); 
    end if;
  end process;

  COUNT <= value_temp;

end architecture;