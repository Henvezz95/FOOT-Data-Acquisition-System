-- -----------------------------------------------------------------------
-- FifoControl
-- -----------------------------------------------------------------------          

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity FifoControl is
  port(
    clk    : in  std_logic;  
    reset  : in  std_logic;  
	 -- avalon interface
	 avs_read      : in std_logic; 
	 avs_write     : in std_logic; 
	 avs_address   : in std_logic_vector(1 downto 0); 
	 avs_readdata  : out std_logic_vector(31 downto 0); 
	 avs_writedata : in std_logic_vector(31 downto 0); 
	 -- fifo interface
	 fifo_data  : in std_logic_vector(31 downto 0); 
	 fifo_reg   : in std_logic_vector(31 downto 0) 
  );
end entity FifoControl;
