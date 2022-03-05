-- -----------------------------------------------------------------------
-- FifoControl
-- -----------------------------------------------------------------------          

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity EvFifoControl is
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
	fifo_reg   : in std_logic_vector(31 downto 0); 
   fifo_read_ack : out std_logic
	);
end entity EvFifoControl;


architecture logic of EvFifoControl is
  signal oldack : std_logic := '0'; 
  signal gotdata : std_logic_vector(31 downto 0) := (others=>'1');
begin

  process(clk, reset)
  begin
    if( reset='1' ) then
	  avs_readdata <= x"aa55aa55";
      fifo_read_ack <= '0';
	elsif( rising_edge(clk) ) then
--      fifo_read_ack <= '0';
      fifo_read_ack <= avs_read or avs_write;
      if( avs_read='1' ) then
        case avs_address is
        when "00"=> 
          avs_readdata <= fifo_data;
          fifo_read_ack <= '1';
        when "01"=>
          avs_readdata <= fifo_reg;
        when "10"=>
          avs_readdata <= x"80"&fifo_reg(23 downto 0);
        when "11"=>
          avs_readdata <= x"c0"&gotdata(23 downto 0);
        end case;
      end if;
      if( avs_write='1' ) then
        gotdata <= avs_writedata;
      end if;
    end if;
  end process;
end logic;


