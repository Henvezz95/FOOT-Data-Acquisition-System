library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

--Busy_Out equals to '0' if Busy has been '0' for "nbit" or more clocks

entity Busy_Stretch is
  --It's the number of bit of the shift register
  generic (nbit: natural := 16); 
  port (
   --Inputs
    Clock : in std_logic;
    Reset : in std_logic;
    --Busy Signal
    Busy : in std_logic;
   --Outputs
    Busy_Out : out std_logic
  );
end entity;

 
architecture behave of Busy_Stretch is

  constant nullRegister : std_logic_vector(nbit-1 downto 0) := (others=>'0'); 
  signal busyShiftRegister : std_logic_vector(nbit-1 downto 0) := (others=>'0'); 

begin 

  process (Clock, Reset) 
  begin 
    if (Reset='1') then 
      busyShiftRegister <= (others => '0'); 
    elsif rising_edge(Clock) then 
      busyShiftRegister <= busyShiftRegister(nbit-2 downto 0) & Busy; 
    end if; 
  end process; 

  Busy_Out <= '0' when busyShiftRegister = nullRegister 
                  else '1';

end behave;
  
  
  

                                                   
  
  

                                                   