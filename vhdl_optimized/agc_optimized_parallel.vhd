----------------------------------------------------------------------------------
-- Engineer: 		Niklas Aldn
-- 
-- Create Date:   	19:51:23 05/11/2015 
-- Design Name: 
-- Module Name:    	agc - Behavioral 
-- Project Name: 	Hardware implementation of AGC for active hearing protectors
-- Description: 	Master Thesis
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity agc is
    Port ( 	clk 			: in std_logic; 					-- clock
			rstn 			: in std_logic; 					-- reset, active low
			i_sample 		: in std_logic_vector(15 downto 0); -- input sample from AC97
			i_start 		: in std_logic; 					-- start signal from AC97
			i_gain 			: in std_logic_vector(14 downto 0);	-- gain fetched from LUT
			o_power 		: out std_logic_vector(7 downto 0);	-- sample power to LUT
			o_gain_fetch 	: out std_logic;					-- enable signal for LUT
			o_sample 		: out std_logic_vector(15 downto 0);-- output sample to equalizer filter
			o_done			: out std_logic
			);
end agc;

architecture Behavioral of agc is
	
	constant WIDTH 					: integer 				:= 32;				-- general register width
	signal delay_c, delay_n 		: std_logic				:= '0';				-- one bit delay counter
	signal inout_cnt_c, inout_cnt_n : unsigned(3 downto 0) 	:= (others => '0'); -- counter for latching input and output sample
	
	-- HIGH PASS FILTER
	-- high pass filter coefficients
	constant hp_b_0 : signed(WIDTH/2-1 downto 0) := to_signed(32250, WIDTH/2);
	constant hp_b_1 : signed(WIDTH/2-1 downto 0) := to_signed(-32250,WIDTH/2);
	constant hp_a_1 : signed(WIDTH/2-1 downto 0) := to_signed(31736, WIDTH/2);-- OBS changed sign
--	constant hp_b_0 : signed(WIDTH/2-1 downto 0) := to_signed(504, WIDTH/2);
--	constant hp_b_1 : signed(WIDTH/2-1 downto 0) := to_signed(-504,WIDTH/2);
--	constant hp_a_1 : signed(WIDTH/2-1 downto 0) := to_signed(496, WIDTH/2);-- OBS changed sign
	
	signal hp_x_c, hp_x_n 			: signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- current input sample
	signal hp_x_prev_c, hp_x_prev_n : signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- previous input sample
	signal hp_y_prev_c, hp_y_prev_n	: signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- previous output sample
	
	-- EQUALIZER FILTER
	-- equalizer filter coefficients
	constant eq_b_0 : signed(WIDTH-1 downto 0) := to_signed(3551068, WIDTH);
	constant eq_b_1 : signed(WIDTH-1 downto 0) := to_signed(-20015, WIDTH);
	constant eq_b_2 : signed(WIDTH-1 downto 0) := to_signed(-3527803, WIDTH);
	constant eq_a_1 : signed(WIDTH-1 downto 0) := to_signed(20015, WIDTH); 	-- OBS changed sign
	constant eq_a_2 : signed(WIDTH-1 downto 0) := to_signed(9657, WIDTH); 	-- OBS changed sign
--	constant eq_b_0 : signed(WIDTH-1 downto 0) := to_signed(55484, WIDTH);
--	constant eq_b_1 : signed(WIDTH-1 downto 0) := to_signed(-313, WIDTH);
--	constant eq_b_2 : signed(WIDTH-1 downto 0) := to_signed(-55123, WIDTH);
--	constant eq_a_1 : signed(WIDTH-1 downto 0) := to_signed(313, WIDTH); 	-- OBS changed sign
--	constant eq_a_2 : signed(WIDTH-1 downto 0) := to_signed(151, WIDTH); 	-- OBS changed sign
	
	
	signal eq_x_c, eq_x_n 						: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- current input sample
	signal eq_x_prev_c, eq_x_prev_n 			: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- previous input sample
	signal eq_x_prev_prev_c, eq_x_prev_prev_n 	: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- before last input sample
	signal eq_y_prev_c, eq_y_prev_n				: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- previous output sample
	signal eq_y_prev_prev_c, eq_y_prev_prev_n	: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- before last output sample
	
	-- AGC
	-- time parameters
	constant alpha 	: unsigned(15 downto 0) := to_unsigned(655, WIDTH/2); -- attack time
	constant beta 	: unsigned(15 downto 0) := to_unsigned(1, WIDTH/2); -- release time
	
	signal curr_sample_c, curr_sample_n 		: signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- current input sample
--	signal P_in_c, P_in_n 						: unsigned(WIDTH-1 downto 0)	:= (others => '0'); -- power of input sample
	signal P_w_fast_c, P_w_fast_n 				: unsigned(WIDTH-1 downto 0) 	:= (others => '0'); -- 
	signal P_w_fast_prev_c, P_w_fast_prev_n 	: unsigned(WIDTH-1 downto 0) 	:= (others => '0'); -- 
	signal P_weighted_c, P_weighted_n 			: unsigned(WIDTH-1 downto 0) 	:= (others => '0'); -- 
	signal P_weighted_prev_c, P_weighted_prev_n : unsigned(WIDTH-1 downto 0) 	:= (others => '0'); -- 
	signal P_dB_c, P_dB_n 						: signed(7 downto 0) 			:= (others => '0'); -- weighted power of input sample in decibel
--	signal P_prev_c, P_prev_n 					: unsigned(WIDTH-1 downto 0) 	:= (others => '0'); -- power of output sample
	signal agc_out_c, agc_out_n					: signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- attenuated sample
	
	-- MULTIPLIER AND ADDER
	signal mult_src1_c, mult_src1_n : signed(WIDTH-1 downto 0) 		:= (others => '0');
	signal mult_src2_c, mult_src2_n : signed(WIDTH-1 downto 0) 		:= (others => '0');
	signal mult_out_c, mult_out_n 	: signed(2*WIDTH-1 downto 0) 	:= (others => '0');
	signal add_src1_c, add_src1_n 	: signed(2*WIDTH-1 downto 0) 	:= (others => '0');
	signal add_src2_c, add_src2_n 	: signed(2*WIDTH-1 downto 0) 	:= (others => '0');
	signal add_out_c, add_out_n 	: signed(2*WIDTH-1 downto 0) 	:= (others => '0');
		
	-- states for FSM    
	type state_type is (HOLD, LATCH_IN_SAMPLE, HP_CALC1, HP_CALC2, HP_CALC3, HP_CALC4, 
						EQ_CALC1, EQ_CALC2, EQ_CALC3, EQ_CALC4, EQ_CALC5, EQ_CALC6, FINISH_CALC,
						P_CURR, P_W1, P_W2, P_W3, P_W4, P_W_INCR1, P_W_INCR2, P_W_DCR1, P_W_DCR2,
						--P_COMP, P_W_1A, P_W_1B, P_W_2A, P_W_2B, P_W_3, 
						P_dB, FETCH_GAIN, GAIN, P_OUT, LATCH_OUT_SAMPLE); 
	signal state_c, state_n : state_type := HOLD;
	
begin

-- clock process
----------------------------------------------------------------------------------
clk_proc : process(clk, rstn) is
begin
	if rstn = '0' then
		state_c 			<= HOLD;
		hp_x_c 				<= (others => '0');
		hp_x_prev_c 		<= (others => '0');
		hp_y_prev_c			<= (others => '0');
		eq_x_c 				<= (others => '0');
		eq_x_prev_c 		<= (others => '0');
		eq_x_prev_prev_c	<= (others => '0');
		eq_y_prev_c			<= (others => '0');
		eq_y_prev_prev_c 	<= (others => '0');
--		P_in_c 				<= (others => '0');
		P_w_fast_c			<= (others => '0');
		P_w_fast_prev_c		<= (others => '0');
		P_weighted_c		<= (others => '0');
		P_weighted_prev_c	<= (others => '0');
		P_dB_c 				<= (others => '0');
--		P_prev_c 			<= (others => '0');
		agc_out_c 			<= (others => '0');
		curr_sample_c 		<= (others => '0');
		mult_src1_c 		<= (others => '0');
		mult_src2_c			<= (others => '0');
		mult_out_c			<= (others => '0');
		add_src1_c			<= (others => '0');
		add_src2_c			<= (others => '0');
		add_out_c			<= (others => '0');
		delay_c				<= '0';
		inout_cnt_c			<= (others => '0');
	elsif rising_edge(clk) then
		state_c 			<= state_n;
		hp_x_c 				<= hp_x_n;
		hp_x_prev_c 		<= hp_x_prev_n;
		hp_y_prev_c 		<= hp_y_prev_n;
		eq_x_c 				<= eq_x_n;
		eq_x_prev_c 		<= eq_x_prev_n;
		eq_x_prev_prev_c 	<= eq_x_prev_prev_n;
		eq_y_prev_c 		<= eq_y_prev_n;
		eq_y_prev_prev_c 	<= eq_y_prev_prev_n;
--		P_in_c 				<= P_in_n;
		P_w_fast_c			<= P_w_fast_n;
		P_w_fast_prev_c		<= P_w_fast_prev_n;
		P_weighted_c		<= P_weighted_n;
		P_weighted_prev_c	<= P_weighted_prev_n;
		P_dB_c 				<= P_dB_n;
--		P_prev_c 			<= P_prev_n;
		agc_out_c 			<= agc_out_n;
		curr_sample_c 		<= curr_sample_n;
		mult_src1_c 		<= mult_src1_n;
		mult_src2_c			<= mult_src2_n;
		mult_out_c			<= mult_out_n;
		add_src1_c			<= add_src1_n;
		add_src2_c			<= add_src2_n;
		add_out_c			<= add_out_n;
		delay_c				<= delay_n;
		inout_cnt_c			<= inout_cnt_n;
	end if;
end process;

fsm_proc : process(	state_c, i_start, i_sample, hp_x_c, hp_x_prev_c, hp_y_prev_c, eq_x_c, eq_x_prev_c, eq_x_prev_prev_c, eq_y_prev_c, eq_y_prev_prev_c, 
					curr_sample_c, P_w_fast_c, P_w_fast_prev_c, P_weighted_c, P_weighted_prev_c, P_dB_c, 
					i_gain, agc_out_c, mult_src1_c, mult_src2_c, mult_out_c, add_src1_c, add_src2_c, add_out_c, delay_c, inout_cnt_c
					) is
begin
	-- default values
	state_n				<= state_c;
	hp_x_n 				<= hp_x_c;
	hp_x_prev_n 		<= hp_x_prev_c;
	hp_y_prev_n 		<= hp_y_prev_c;
	eq_x_n				<= eq_x_c;
	eq_x_prev_n 		<= eq_x_prev_c;
	eq_x_prev_prev_n 	<= eq_x_prev_prev_c;
	eq_y_prev_n 		<= eq_y_prev_c;
	eq_y_prev_prev_n 	<= eq_y_prev_prev_c;
--	P_in_n 				<= P_in_c;
	P_w_fast_n			<= P_w_fast_c;
	P_w_fast_prev_n		<= P_w_fast_prev_c;
	P_weighted_n		<= P_weighted_c;
	P_weighted_prev_n	<= P_weighted_prev_c;
	P_dB_n 				<= P_dB_c;
	curr_sample_n 		<= curr_sample_c;
--	P_prev_n 			<= P_prev_c;
	agc_out_n 			<= agc_out_c;
	mult_src1_n 		<= mult_src1_c;
	mult_src2_n 		<= mult_src2_c;
	mult_out_n			<= mult_out_c;
	add_src1_n 			<= add_src1_c;
	add_src2_n 			<= add_src2_c;
	add_out_n			<= add_out_c;
	delay_n				<= delay_c;
	inout_cnt_n			<= inout_cnt_c;
	o_done				<= '0';
--	o_sample			<= '0';
	o_sample			<= std_logic_vector(agc_out_c);
	o_power 			<= std_logic_vector(P_dB_n); 	-- output power to LUT
	o_gain_fetch 		<= '0'; 						-- don't enable LUT

	
	case state_c is
----------------------------------------------------------------------------------	
-- HIGH PASS FILTER
----------------------------------------------------------------------------------	
		-- wait for start signal before latching input sample
		when HOLD =>
			if i_start = '1' then
				state_n	<= LATCH_IN_SAMPLE;
			else
				state_n <= HOLD;
			end if;
	
		-- latch in serial input sample
		when LATCH_IN_SAMPLE =>
--			hp_x_n(15 - to_integer(inout_cnt_c))	<= i_sample;
--			inout_cnt_n 							<= inout_cnt_c + 1;
--			if inout_cnt_c = 15 then
--				state_n <= HP_CALC1;
--				inout_cnt_n <= (others => '1');
--			else
--				state_n <= LATCH_IN_SAMPLE;
--			end if;
			hp_x_n <= signed(i_sample);
			state_n <= HP_CALC1;
					
		-- multiply current input sample with filter coefficient
		when HP_CALC1 =>
			mult_src1_n <= resize(hp_x_c, WIDTH);
			mult_src2_n <= resize(hp_b_0, WIDTH);
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n	<= HP_CALC1;
			else
				delay_n <= '0';
				state_n	<= HP_CALC2;
			end if;
		
		-- multiply previous input sample with filter coefficient
		when HP_CALC2 =>
			mult_src1_n <= resize(hp_x_prev_c, WIDTH);
			mult_src2_n <= resize(hp_b_1, WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= HP_CALC2;
			else
				delay_n <= '0';	
				state_n <= HP_CALC3;
			end if;
		
		-- multiply previous output sample with filter coefficient
		when HP_CALC3 =>
			mult_src1_n <= resize(hp_y_prev_c, WIDTH);
			mult_src2_n <= resize(hp_a_1, WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= add_out_c;
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= HP_CALC3;
			else
				delay_n <= '0';
				state_n <= HP_CALC4;
			end if;
		
		-- sum up to get output sample from high pass filter
		when HP_CALC4 =>
			mult_src1_n <= (others => '0');
			mult_src2_n <= (others => '0');
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= add_out_c;
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= HP_CALC4;
			else
				delay_n <= '0';
				state_n <= EQ_CALC1;
			end if;

----------------------------------------------------------------------------------
-- EQUALIZER FILTER
----------------------------------------------------------------------------------
		-- save input and output sample as previous samples for high pass filter
		-- multiply current input sample with filter coefficient
		when EQ_CALC1 =>
			hp_x_prev_n <= hp_x_c;
--			hp_y_prev_n <= add_out_c(WIDTH/2-1 downto 0);
--			eq_x_n		<= add_out_c(WIDTH-1 downto 0);
--			mult_src1_n <= add_out_c(WIDTH-1 downto 0);
			hp_y_prev_n <= add_out_c(WIDTH/2-1+15 downto 15);
			eq_x_n		<= add_out_c(WIDTH-1+15 downto 15);
			mult_src1_n <= add_out_c(WIDTH-1+15 downto 15);
			mult_src2_n <= eq_b_0;
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= EQ_CALC1;
			else
				delay_n <= '0';
				state_n <= EQ_CALC2;
			end if;
		
		-- multiply previous input sample with filter coefficient
		when EQ_CALC2 =>
			mult_src1_n <= eq_x_prev_c;
			mult_src2_n <= eq_b_1;
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= EQ_CALC2;
			else
				delay_n <= '0';
				state_n	<= Eq_CALC3;
			end if;
		
		-- multiply before last input sample with filter coefficient
		when EQ_CALC3 =>
			mult_src1_n <= eq_x_prev_prev_c;
			mult_src2_n <= eq_b_2;
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= add_out_c;
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= EQ_CALC3;
			else
				delay_n <= '0';
				state_n	<= EQ_CALC4;
			end if;
		
		-- multiply previous output sample with filter coefficient
		when EQ_CALC4 =>
			mult_src1_n <= eq_y_prev_c;
			mult_src2_n <= eq_a_1;
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= add_out_c;
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= EQ_CALC4;
			else
				delay_n <= '0';
				state_n	<= EQ_CALC5;
			end if;
		
		-- multiply before last ouput sample with filter coefficient
		when EQ_CALC5 =>
			mult_src1_n <= eq_y_prev_prev_c;
			mult_src2_n <= eq_a_2;
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= add_out_c;
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= EQ_CALC5;
			else
				delay_n <= '0';
				state_n	<= EQ_CALC6;
			end if;
		
		-- sum up to get output sample from high pass filter
		when EQ_CALC6 =>
			mult_src1_n <= (others => '0');
			mult_src2_n <= (others => '0');
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);
--			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 9), 2*WIDTH);
			add_src1_n 	<= mult_out_c;
			add_src2_n 	<= add_out_c;
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= EQ_CALC6;
			else
				delay_n <= '0';
				state_n	<= FINISH_CALC;
			end if;
		
		-- save input and output sample as previous and before last samples for equalizer filter
		-- latch in current sample to AGC
		when FINISH_CALC =>
			eq_x_prev_n			<= eq_x_c;
			eq_x_prev_prev_n	<= eq_x_prev_c;
--			eq_y_prev_n			<= add_out_c(WIDTH-1 downto 0);
--			eq_y_prev_n			<= resize(add_out_c(WIDTH-1 downto 9), WIDTH);
			eq_y_prev_n			<= resize(add_out_c(WIDTH-1+15 downto 15), WIDTH);
			eq_y_prev_prev_n	<= eq_y_prev_c;			
--			curr_sample_n		<= add_out_c(22 downto 7);
--			curr_sample_n		<= add_out_c(31 downto 16);
			curr_sample_n		<= add_out_c(WIDTH/2-1+22 downto 22);
			state_n				<= P_CURR;
			
----------------------------------------------------------------------------------			
-- AGC
----------------------------------------------------------------------------------
		
		-- calculate power of current sample
		when P_CURR =>
			mult_src1_n <= resize(abs(curr_sample_c), WIDTH);
			mult_src2_n	<= resize(abs(curr_sample_c), WIDTH);
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= P_CURR;
			else
				delay_n <= '0';
				state_n <= P_W1;
			end if;
		
--		-- compare the power of the current sample against previous sample to determine increasing or decreasing power
--		when P_COMP =>
--			P_in_n <= unsigned(abs(mult_out_c(WIDTH-1 downto 0)));
--			
--			if unsigned(abs(mult_out_c(WIDTH-1 downto 0))) > P_prev_c then
--				state_n <= P_W_1A;
--			else
--				state_n <= P_W_1B;
--			end if;
		
		when P_W1 =>
			mult_src1_n	<= resize(signed(alpha), WIDTH);
			mult_src2_n	<= mult_out_c(WIDTH-1 downto 0);--signed(mult_out_c(46 downto 15));
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= P_W1;
			else
				delay_n <= '0';
				state_n <= P_W2;
			end if;		
			
		when P_W2 =>
			mult_src1_n	<= resize(signed(32767 - alpha), WIDTH);--to_signed(32767 - alpha, WIDTH);
			mult_src2_n	<= signed(P_w_fast_prev_c);
			add_src1_n 	<= resize(mult_out_c(2*WIDTH-1 downto 15), 2*WIDTH);--mult_out_c;
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= P_W2;
			else
				delay_n <= '0';
				state_n <= P_W3;
			end if;
			
		when P_W3 =>
			mult_src1_n	<= (others => '0');
			mult_src2_n	<= (others => '0');
			add_src1_n 	<= add_out_c;
			add_src2_n 	<= resize(signed(mult_out_c(2*WIDTH-1 downto 15)), 2*WIDTH);
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= P_W3;
			else
				delay_n <= '0';
				state_n <= P_W4;
			end if;
			
		when P_W4 =>
			mult_src1_n	<= resize(signed(32767 - beta), WIDTH);--to_signed(32767 - beta, WIDTH);
			mult_src2_n	<= add_out_c(WIDTH-1 downto 0); -- (P_w_fast_c)
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			P_w_fast_n <= unsigned(add_out_c(WIDTH-1 downto 0));
			if unsigned(add_out_c(WIDTH-1 downto 0)) > P_weighted_prev_c then 
				state_n <= P_W_INCR1;
			else
				state_n <= P_W_DCR1;
			end if;
			
		when P_W_INCR1 =>
			mult_src1_n	<= (others => '0');
			mult_src2_n	<= (others => '0');
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			P_weighted_n <= P_w_fast_c;
			if P_w_fast_prev_c > P_w_fast_c then
				state_n <= P_W_DCR2;
			else
				state_n <= P_W_INCR2;
			end if;
			
		when P_W_DCR1 =>
			mult_src1_n	<= (others => '0');
			mult_src2_n	<= (others => '0');
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			P_weighted_n <= P_weighted_prev_c;
			if P_w_fast_prev_c > P_w_fast_c then
				state_n <= P_W_DCR2;
			else
				state_n <= P_W_INCR2;
			end if;
			
		when P_W_INCR2 =>
			mult_src1_n	<= (others => '0');
			mult_src2_n	<= (others => '0');
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			state_n <= P_dB;
						
		when P_W_DCR2 =>
			mult_src1_n	<= (others => '0');
			mult_src2_n	<= (others => '0');
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			P_weighted_n <= unsigned(mult_out_c(46 downto 15));
			state_n <= P_dB;
		

--		-- decreasing power, weigh against previous sample
--		when P_W_1B =>
--			mult_src1_n <= to_signed(32767 - beta, WIDTH); -- 32767 - beta(3) = 32764
--			mult_src2_n	<= signed(P_prev_c);
--			add_src1_n 	<= (others => '0');
--			add_src2_n 	<= (others => '0');
--			if delay_c = '0' then
--				delay_n <= '1';
--				state_n <= P_W_1B;
--			else
--				delay_n <= '0';
--				state_n <= P_W_2B;
--			end if;
--		
--		-- increasing power, weigh in current sample
--		when P_W_2A =>
--			mult_src1_n	<= resize(signed(alpha), WIDTH);
--			mult_src2_n	<= signed(P_in_c);
--			add_src1_n 	<= mult_out_c;
--			add_src2_n 	<= (others => '0');
--			if delay_c = '0' then
--				delay_n <= '1';
--				state_n <= P_W_2A;
--			else
--				delay_n <= '0';
--				state_n <= P_W_3;
--			end if;
--		
--		-- decreasing power, weigh in current sample
--		when P_W_2B =>
--			mult_src1_n	<= resize(signed(beta), WIDTH);
--			mult_src2_n	<= signed(P_in_c);
--			add_src1_n 	<= mult_out_c;
--			add_src2_n 	<= (others => '0');
--			if delay_c = '0' then
--				delay_n <= '1';
--				state_n <= P_W_2B;
--			else
--				delay_n <= '0';
--				state_n <= P_W_3;
--			end if;
--	
--		-- sum up to get weighted power of current sample
--		when P_W_3 =>
--			mult_src1_n	<= (others => '0');
--			mult_src2_n	<= (others => '0');
--			add_src1_n	<= add_out_c;
--			add_src2_n	<= mult_out_c;
--			if delay_c = '0' then
--				delay_n <= '1';
--				state_n <= P_W_3;
--			else
--				delay_n <= '0';
--				state_n	<= P_dB;
--			end if;
		
		-- convert the weighted power to decibel 
		when P_dB =>

			if unsigned(P_weighted_c) > x"69fe63f3" then -- >92.5dB
				P_dB_n <= to_signed(11, 8);
			elsif unsigned(P_weighted_c) > x"54319cc9" then -- >91.5dB
				P_dB_n <= to_signed(10, 8);
			elsif unsigned(P_weighted_c) > x"42e0a497" then -- >90.5dB
				P_dB_n <= to_signed(9, 8);
			elsif unsigned(P_weighted_c) > x"351f68fb" then -- >89.5dB
				P_dB_n <= to_signed(8, 8);
			elsif unsigned(P_weighted_c) > x"2a326539" then -- >88.5dB
				P_dB_n <= to_signed(7, 8);
			elsif unsigned(P_weighted_c) > x"2184a5ce" then -- >87.5dB
				P_dB_n <= to_signed(6, 8);
			elsif unsigned(P_weighted_c) > x"1a9fd9c9" then -- >86.5dB
				P_dB_n <= to_signed(5, 8);
			elsif unsigned(P_weighted_c) > x"152605ce" then -- >85.5dB
				P_dB_n <= to_signed(4, 8);
			elsif unsigned(P_weighted_c) > x"10cc82d6" then -- >84.5dB
				P_dB_n <= to_signed(3, 8);
			elsif unsigned(P_weighted_c) > x"d580472" then -- >83.5dB
				P_dB_n <= to_signed(2, 8);
			elsif unsigned(P_weighted_c) > x"a997066" then -- >82.5dB
				P_dB_n <= to_signed(1, 8);
			elsif unsigned(P_weighted_c) > x"86b5c7b" then -- >81.5dB
				P_dB_n <= to_signed(0, 8);
			elsif unsigned(P_weighted_c) > x"6b01076" then -- >80.5dB
				P_dB_n <= to_signed(-1, 8);
			elsif unsigned(P_weighted_c) > x"54ff0e6" then -- >79.5dB
				P_dB_n <= to_signed(-2, 8);
			elsif unsigned(P_weighted_c) > x"4383d53" then -- >78.5dB
				P_dB_n <= to_signed(-3, 8);
			elsif unsigned(P_weighted_c) > x"35a1095" then -- >77.5dB
				P_dB_n <= to_signed(-4, 8);
			elsif unsigned(P_weighted_c) > x"2a995c8" then -- >76.5dB
				P_dB_n <= to_signed(-5, 8);
			elsif unsigned(P_weighted_c) > x"21d66fb" then -- >75.5dB
				P_dB_n <= to_signed(-6, 8);
			elsif unsigned(P_weighted_c) > x"1ae0d16" then -- >74.5dB
				P_dB_n <= to_signed(-7, 8);
			elsif unsigned(P_weighted_c) > x"1559a0c" then -- >73.5dB
				P_dB_n <= to_signed(-8, 8);
			elsif unsigned(P_weighted_c) > x"10f580b" then -- >72.5dB
				P_dB_n <= to_signed(-9, 8);
			elsif unsigned(P_weighted_c) > x"d78940" then -- >71.5dB
				P_dB_n <= to_signed(-10, 8);
			elsif unsigned(P_weighted_c) > x"ab34d9" then -- >70.5dB
				P_dB_n <= to_signed(-11, 8);
			elsif unsigned(P_weighted_c) > x"87fe7e" then -- >69.5dB
				P_dB_n <= to_signed(-12, 8);
			elsif unsigned(P_weighted_c) > x"6c0622" then -- >68.5dB
				P_dB_n <= to_signed(-13, 8);
			elsif unsigned(P_weighted_c) > x"55ce76" then -- >67.5dB
				P_dB_n <= to_signed(-14, 8);
			elsif unsigned(P_weighted_c) > x"442894" then -- >66.5dB
				P_dB_n <= to_signed(-15, 8);
			elsif unsigned(P_weighted_c) > x"3623e6" then -- >65.5dB
				P_dB_n <= to_signed(-16, 8);
			elsif unsigned(P_weighted_c) > x"2b014f" then -- >64.5dB
				P_dB_n <= to_signed(-17, 8);
			elsif unsigned(P_weighted_c) > x"222902" then -- >63.5dB
				P_dB_n <= to_signed(-18, 8);
			elsif unsigned(P_weighted_c) > x"1b2268" then -- >62.5dB
				P_dB_n <= to_signed(-19, 8);
			elsif unsigned(P_weighted_c) > x"158dba" then -- >61.5dB
				P_dB_n <= to_signed(-20, 8);
			elsif unsigned(P_weighted_c) > x"111ee3" then -- >60.5dB
				P_dB_n <= to_signed(-21, 8);
			elsif unsigned(P_weighted_c) > x"d9973" then -- >59.5dB
				P_dB_n <= to_signed(-22, 8);
			elsif unsigned(P_weighted_c) > x"acd6a" then -- >58.5dB
				P_dB_n <= to_signed(-23, 8);
			elsif unsigned(P_weighted_c) > x"894a6" then -- >57.5dB
				P_dB_n <= to_signed(-24, 8);
			elsif unsigned(P_weighted_c) > x"6d0dc" then -- >56.5dB
				P_dB_n <= to_signed(-25, 8);
			elsif unsigned(P_weighted_c) > x"569fe" then -- >55.5dB
				P_dB_n <= to_signed(-26, 8);
			elsif unsigned(P_weighted_c) > x"44cef" then -- >54.5dB
				P_dB_n <= to_signed(-27, 8);
			elsif unsigned(P_weighted_c) > x"36a81" then -- >53.5dB
				P_dB_n <= to_signed(-28, 8);
			elsif unsigned(P_weighted_c) > x"2b6a4" then -- >52.5dB
				P_dB_n <= to_signed(-29, 8);
			elsif unsigned(P_weighted_c) > x"227c6" then -- >51.5dB
				P_dB_n <= to_signed(-30, 8);
			elsif unsigned(P_weighted_c) > x"1b64a" then -- >50.5dB
				P_dB_n <= to_signed(-31, 8);
			elsif unsigned(P_weighted_c) > x"15c26" then -- >49.5dB
				P_dB_n <= to_signed(-32, 8);
			elsif unsigned(P_weighted_c) > x"1148b" then -- >48.5dB
				P_dB_n <= to_signed(-33, 8);
			elsif unsigned(P_weighted_c) > x"dbab" then -- >47.5dB
				P_dB_n <= to_signed(-34, 8);
			elsif unsigned(P_weighted_c) > x"ae7d" then -- >46.5dB
				P_dB_n <= to_signed(-35, 8);
			elsif unsigned(P_weighted_c) > x"8a9a" then -- >45.5dB
				P_dB_n <= to_signed(-36, 8);
			elsif unsigned(P_weighted_c) > x"6e18" then -- >44.5dB
				P_dB_n <= to_signed(-37, 8);
			elsif unsigned(P_weighted_c) > x"5774" then -- >43.5dB
				P_dB_n <= to_signed(-38, 8);
			elsif unsigned(P_weighted_c) > x"4577" then -- >42.5dB
				P_dB_n <= to_signed(-39, 8);
			elsif unsigned(P_weighted_c) > x"372e" then -- >41.5dB
				P_dB_n <= to_signed(-40, 8);
			elsif unsigned(P_weighted_c) > x"2bd5" then -- >40.5dB
				P_dB_n <= to_signed(-41, 8);
			elsif unsigned(P_weighted_c) > x"22d1" then -- >39.5dB
				P_dB_n <= to_signed(-42, 8);
			elsif unsigned(P_weighted_c) > x"1ba8" then -- >38.5dB
				P_dB_n <= to_signed(-43, 8);
			elsif unsigned(P_weighted_c) > x"15f8" then -- >37.5dB
				P_dB_n <= to_signed(-44, 8);
			
			else												-- >=0dB
				P_dB_n <= to_signed(-82, 8);
			end if;			
			state_n <= FETCH_GAIN;
		
		-- enable LUT and wait for returned gain
		when FETCH_GAIN =>
			if delay_c = '0' then
				o_gain_fetch	<= '1'; 		-- enable LUT
				delay_n 		<= '1';
				state_n 		<= FETCH_GAIN;
			else
				delay_n 		<= '0';
				state_n 		<= GAIN;
			end if;

			
		-- multiply current sample with the gain fetched from LUT
		when GAIN =>
			mult_src1_n	<= resize(curr_sample_c, WIDTH);
			mult_src2_n	<= signed(x"0000" & '0' & i_gain);
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= GAIN;
			else
				delay_n <= '0';
				state_n <= P_OUT;
			end if;
		
		-- calculate power of output sample 
		when P_OUT =>
			mult_src1_n	<= (others => '0');--abs(mult_out_c(46 downto 15));
			mult_src2_n	<= (others => '0');--abs(mult_out_c(46 downto 15));
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
			agc_out_n 	<= mult_out_c(30 downto 15);
			if delay_c = '0' then
				delay_n <= '1';
				state_n <= P_OUT;
			else
				delay_n <= '0';
				state_n <= LATCH_OUT_SAMPLE;
			end if;
			
		-- save power of output sample for comparison and weighting with next input sample
		-- latch out processed sample and signal when done
		when LATCH_OUT_SAMPLE =>
			mult_src1_n <= (others => '0');
			mult_src2_n <= (others => '0');
			add_src1_n 	<= (others => '0');
			add_src2_n 	<= (others => '0');
--			inout_cnt_n <= inout_cnt_c - 1;
--			o_sample	<= agc_out_c(to_integer(inout_cnt_c));
----			o_sample	<= agc_out_c(15 - to_integer(inout_cnt_c));
--			if inout_cnt_c = 15 then --0
--				P_w_fast_prev_n <= P_w_fast_c;
--				P_weighted_prev_n <= P_weighted_c;		
----				P_prev_n 	<= unsigned(mult_out_c(WIDTH-1 downto 0));
--				state_n		<= LATCH_OUT_SAMPLE;
--			elsif inout_cnt_c = 0 then --15
--			  inout_cnt_n <= (others => '0');
--				o_done		<= '1';
--				state_n		<= HOLD;
--			else
--				state_n 	<= LATCH_OUT_SAMPLE;
--			end if;
			P_w_fast_prev_n <= P_w_fast_c;
			P_weighted_prev_n <= P_weighted_c;		
--			o_sample <= std_logic_vector(agc_out_c);
			o_done <= '1';
			state_n <= HOLD;

	end case;
	
	mult_out_n 	<= mult_src1_c * mult_src2_c;
	add_out_n 	<= add_src1_c + add_src2_c;
	
end process;

end Behavioral;

