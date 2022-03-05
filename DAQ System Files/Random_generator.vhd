library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Random_generator is

  port (
    Clock : in std_logic;
	 Reset : in std_logic;
	 Enable : in std_logic;
	 
	 Random_Data : out unsigned (15 downto 0)
  );
  
 end entity;
  
  architecture behavior of Random_generator is
      begin
		
		-- finds a new 16 bits random value
  
  process(Clock,Reset) is
    variable randomnumber : std_logic_vector(15 downto 0) :=  x"C0A1";
  begin
	if(Reset = '1') then
      Random_Data <= (others=>'0');
	  randomnumber :=  x"C0A1";
	elsif rising_edge(Clock) then
      if Enable='1' then
        --This creates a pseudo-random number from the previous value of randomNumber
  	    randomnumber :=   randomnumber(14 downto 10)
                          & (not randomnumber(15) xor randomnumber(9))
                          &       randomnumber(8 downto 5)
                          & (not randomnumber(15) xor randomnumber(4))
                          & randomnumber(3 downto 2)
                          & (not randomnumber(15) xor randomnumber(1))
                          & randomnumber(0)
                          & (not randomnumber(15) xor randomnumber(2)); 
								  
		Random_Data <= unsigned(randomnumber);  -- main process output
		
	  end if;
    end if;
  end process;	
  
 
  
  end behavior;