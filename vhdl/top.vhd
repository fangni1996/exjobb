----------------------------------------------------------------------------------
-- Engineer: 		Niklas Ald�n
-- 
-- Create Date:    	11:47:44 03/28/2015 
-- Module Name:    	top - Behavioral 
-- Project Name: 	Hardware implementation of AGC for active hearing protectors
-- Description: 	Master Thesis
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity top is
    Port ( 	clk 			: in std_logic;
			rstn 			: in std_logic;
			o_L_from_AGC 	: out std_logic_vector(15 downto 0);
			o_R_from_AGC 	: out std_logic_vector(15 downto 0);
			i_L_to_AGC 		: in std_logic_vector(15 downto 0);
			i_R_to_AGC 		: in std_logic_vector(15 downto 0);
			i_L_AGC_start 	: in std_logic;
			i_R_AGC_start 	: in std_logic
		);
end top;

architecture Behavioral of top is


	component high_pass_filter is
		Port ( 	clk 		: in std_logic;
				rstn 		: in std_logic;
				i_sample 	: in std_logic_vector(15 downto 0);
				i_start 	: in std_logic;
				o_sample 	: out std_logic_vector(15 downto 0);
				o_done 		: out std_logic
				);
	end component;

	component eq_filter is
		Port ( 	clk 		: in std_logic;
				rstn 		: in std_logic;
				i_sample 	: in std_logic_vector (15 downto 0);
				i_start 	: in std_logic;
				o_sample 	: out std_logic_vector (15 downto 0);
				o_done 		: out std_logic
				);
	end component;

	component agc is
		Port ( clk 			: in std_logic;
			   rstn 		: in std_logic;
			   i_sample		: in std_logic_vector(15 downto 0);
			   i_start 		: in std_logic;
			   i_gain 		: in std_logic_vector(14 downto 0);
			   o_gain_fetch : out std_logic;
			   o_power 		: out std_logic_vector(7 downto 0);
			   o_sample 	: out std_logic_vector(15 downto 0)
		);
	end component;

	component gain_lut is
		Port ( 	clk 		: in std_logic;
				rstn 		: in std_logic;
				i_L_enable 	: in std_logic;
				i_R_enable 	: in std_logic;
				i_L_dB 		: in std_logic_vector(7 downto 0);
				i_R_dB 		: in std_logic_vector(7 downto 0);
				o_L_gain 	: out std_logic_vector(14 downto 0);
				o_R_gain 	: out std_logic_vector(14 downto 0)
			);
	end component;

-- AC97 -> HIGH PASS FILTER
--	signal L_sample_ac97_hp, R_sample_ac97_hp 	: std_logic_vector(15 downto 0);
--	signal L_start_ac97_hp, R_start_ac97_hp 	: std_logic;
-- HIGH PASS FITLER -> EQUALIZER FILTER
	signal L_sample_hp_eq, R_sample_hp_eq 		: std_logic_vector(15 downto 0);
	signal L_start_hp_eq, R_start_hp_eq 		: std_logic;
-- EQUALIZER FILTER -> AGC
	signal L_sample_eq_agc, R_sample_eq_agc 	: std_logic_vector(15 downto 0);
	signal L_start_eq_agc, R_start_eq_agc 		: std_logic;
-- AGC <-> GAIN LUT
	signal L_power_agc_lut, R_power_agc_lut 	: std_logic_vector(7 downto 0);
	signal L_gain_lut_agc, R_gain_lut_agc 		: std_logic_vector(14 downto 0);
	signal L_fetch_agc_lut, R_fetch_agc_lut 	: std_logic;
	
	
begin

			
	gain_lut_inst : gain_lut
		port map (
			clk			=> clk,
			rstn		=> rstn,
			i_L_enable	=> L_fetch_agc_lut,
			i_R_enable	=> R_fetch_agc_lut,
			i_L_dB 		=> L_power_agc_lut,
			i_R_dB 		=> R_power_agc_lut,
			o_L_gain 	=> L_gain_lut_agc,
			o_R_gain 	=> R_gain_lut_agc
			);
			
----------------------------------------------------------------------------------
-- LEFT CHANNEL
----------------------------------------------------------------------------------
	L_hp_filter_inst : high_pass_filter
		port map (
			clk 		=> clk,
			rstn 		=> rstn,
			i_sample 	=> i_L_to_AGC,
			i_start 	=> i_L_AGC_start,
			o_sample 	=> L_sample_hp_eq,
			o_done 		=> L_start_hp_eq
			);
	
	L_eq_filter_inst : eq_filter
		port map (
			clk 		=> clk,
			rstn 		=> rstn,
			i_sample 	=> L_sample_hp_eq,
			i_start 	=> L_start_hp_eq,
			o_sample 	=> L_sample_eq_agc,
			o_done 		=> L_start_eq_agc
			);
			
	L_agc_inst : agc
		port map (
			clk 		=> clk,
			rstn 		=> rstn,
			i_sample 	=> L_sample_eq_agc,
			i_start 	=> L_start_eq_agc,
			i_gain 		=> L_gain_lut_agc,
			o_gain_fetch => L_fetch_agc_lut,
			o_power 	=> L_power_agc_lut,
			o_sample 	=> o_L_from_AGC
			);
			
----------------------------------------------------------------------------------
-- RIGHT CHANNEL
----------------------------------------------------------------------------------
	R_hp_filter_inst : high_pass_filter
		port map (
			clk 		=> clk,
			rstn 		=> rstn,
			i_sample 	=> i_R_to_AGC,
			i_start 	=> i_R_AGC_start,
			o_sample 	=> R_sample_hp_eq,
			o_done 		=> R_start_hp_eq
			);
	
	R_eq_filter_inst : eq_filter
		port map (
			clk 		=> clk,
			rstn 		=> rstn,
			i_sample 	=> R_sample_hp_eq,
			i_start 	=> R_start_hp_eq,
			o_sample 	=> R_sample_eq_agc,
			o_done 		=> R_start_eq_agc
			);
			
	R_agc_inst : agc
		port map (
			clk 		=> clk,
			rstn 		=> rstn,
			i_sample 	=> R_sample_eq_agc,
			i_start 	=> R_start_eq_agc,
			i_gain 		=> R_gain_lut_agc,
			o_gain_fetch => R_fetch_agc_lut,
			o_power 	=> R_power_agc_lut,
			o_sample 	=> o_R_from_AGC
			);

end Behavioral;
