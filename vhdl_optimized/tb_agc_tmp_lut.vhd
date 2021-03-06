--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:54:19 04/23/2015
-- Design Name:   
-- Module Name:   D:/Google Drive/Exjobb/vhdl_optimized/hp_filter/tb_agc_tmp_lut.vhd
-- Project Name:  hp_filter
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: agc_optimized_top
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use IEEE.std_logic_textio.all;
use std.textio.all;
 
ENTITY tb_agc_tmp_lut IS
END tb_agc_tmp_lut;
 
ARCHITECTURE behavior OF tb_agc_tmp_lut IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT agc_optimized_top
    PORT(
         clk : IN  std_logic;
         rstn : IN  std_logic;
         i_sample : IN  std_logic_vector(15 downto 0);
         i_start : IN  std_logic;
         o_sample : OUT  std_logic_vector(15 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rstn : std_logic := '0';
   signal i_sample : std_logic_vector(15 downto 0) := (others => '0');
   signal i_start : std_logic := '0';

 	--Outputs
   signal o_sample : std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: agc_optimized_top PORT MAP (
          clk => clk,
          rstn => rstn,
          i_sample => i_sample,
          i_start => i_start,
          o_sample => o_sample
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

 -- Stimulus process
   stim_proc: process
    
 	file stimulus : text is in "SIMULATION_DATA.txt";
	variable in_line : line;
	variable in_data : integer;
   
   begin		
		rstn <= '0';
      wait for 10 ns;	
		rstn <= '1';
      wait for clk_period;
		i_sample <= (others => '0');
			
		wait for clk_period;
		
		while not endfile(stimulus) loop
          -- read digital data from input file
			i_start <= '1';
			readline(stimulus, in_line);
			read(in_line, in_data);
			i_sample <= std_logic_vector(to_signed(in_data,16));
			wait for clk_period;
			i_start <= '0';
			wait for clk_period*45;
						
		end loop;
		
		wait for clk_period*5;
		i_sample <= (others => '0');
		
		wait;
   end process;

END;
