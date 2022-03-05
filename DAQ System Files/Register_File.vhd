library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use work.DAQ_Package.all;

entity Register_File is
  port(
    Clock : in std_logic;
	 Reset : in std_logic;
	 --- Communication with Local Ethernet Interace ---
	 Address : in natural;
	 Rdreq : in std_logic;
	 Wrreq : in std_logic;
	 DataIn : in std_logic_vector (31 downto 0);
	 Data_ValidOut : out std_logic := '0';
	 DataOut: out std_logic_vector (31 downto 0) := (others => '0');
	 --- Selective Reset contains a Reset std_logic line for every Control Register ---
	 Selective_Reset : in std_logic_vector(N_CONTROL_REGS-1 downto 0);
	 --- Communication with Main_FSM ---
	 Monitor_RegistersIn : in MONITOR_REGS_T;
	 Control_RegistersOut : out CONTROL_REGS_T := default_CtrlRegisters;
	 --- Errors ---
	 Reset_Errors : in std_logic;
	 Invalid_Address : out std_logic := '0';
	 INOut_Both_Active : out std_logic := '0'
  );
end entity;

architecture behavior of Register_File is
  
  signal Monitor_Registers : MONITOR_REGS_T := default_MonRegisters;
  signal Control_Registers : CONTROL_REGS_T := default_CtrlRegisters;

begin
  
  --- Sequential Process ---
  process(Clock, Reset)
  begin
   
	if Reset = '1' then
	   Control_Registers <= default_CtrlRegisters;
	   Monitor_Registers <= default_MonRegisters; 
		INOut_Both_Active <= '0';
		Invalid_Address <= '0';
		DataOut <= (others => '0');
		Data_ValidOut <= '0';
    elsif rising_edge(Clock) then
	
	   --- Communication with Main_FSM ---
	   Monitor_Registers<=Monitor_RegistersIn; 
		Control_RegistersOut <= Control_Registers;
		
		--- Communication with Local Eth Interface ---
		
		-- Case 1 : Write a control Register
		if Wrreq = '1' and Rdreq = '0' then
		  if Address < N_CONTROL_REGS then
	       Control_Registers(Address) <= DataIn;
		  else
			 if Reset_Errors = '0' then
		      Invalid_Address <= '1';
			 end if;
		  end if;
		  DataOut <= (others => '0');
		  Data_ValidOut <= '0';
		
		-- Case 2 : Read a Register (LOW Adress = Control_Regs , HIGH Adress = Monitor_Regs) 
      elsif Wrreq = '0' and Rdreq = '1' then
	     if Address < N_CONTROL_REGS then
		    DataOut <= Control_Registers (Address);
			 Data_ValidOut <= '1';
		  elsif Address < N_MONITOR_REGS+N_CONTROL_REGS then
		    DataOut <= Monitor_Registers (Address-N_CONTROL_REGS);
			 Data_ValidOut <= '1';
		  else
		    DataOut <= (others => '0');
			 Data_ValidOut <= '0';
			 if Reset_Errors = '0' then
		      Invalid_Address <= '1';
			 end if;
		  end if;
		  
		-- Case 3 : Input sensitive only to Selective_Reset  
	   elsif Wrreq = '0' and Rdreq = '0' then
	     for I in 0 to N_CONTROL_REGS-1 loop
		    if Selective_Reset(I) = '1' then
		      Control_Registers(I) <= default_CtrlRegisters(I);
		    end if;
		  end loop;
		  Data_ValidOut <= '0';
		  DataOut <= (others => '0');
		  
		-- Case 4: Wrreq and RdReq are both active, this is not allowed 
	   else
		  if Reset_Errors = '0' then
	       INOut_Both_Active <= '1';
		  end if;
		  Data_ValidOut <= '0';
		  DataOut <= (others => '0');
	   end if;
	
	   -- Resets All Errors --
   	if Reset_Errors = '1' then
	     INOut_Both_Active <= '0';
		  Invalid_Address <= '0';
	   end if;
	 
	 end if;
  end process;
end architecture;