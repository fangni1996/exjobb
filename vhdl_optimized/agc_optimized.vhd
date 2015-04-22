----------------------------------------------------------------------------------
-- Engineer: 		Niklas Ald�n
-- 
-- Create Date:   	13:51:53 04/21/2015 
-- Design Name: 
-- Module Name:    	agc_optimized - Behavioral 
-- Project Name: 	Hardware implementation of AGC for active hearing protectors
-- Description: 	Master Thesis
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity agc is
    Port ( 	clk 		: in std_logic; 					-- clock
			rstn 		: in std_logic; 					-- reset, active low
			i_sample 	: in std_logic_vector(15 downto 0); -- input sample from AC97
			i_start 	: in std_logic; 					-- start signal from AC97
			o_sample 	: out std_logic_vector(15 downto 0);-- output sample to equalizer filter
			o_done 		: out std_logic						-- done signal to equalizer filter
			);
end agc;

architecture Behavioral of agc is
	
	constant WIDTH					: integer := 32;
	
	-- filter coefficients
	constant hp_b_0 : signed(WIDTH/2-1 downto 0) := to_signed(504, WIDTH/2);
	constant hp_b_1 : signed(WIDTH/2-1 downto 0) := to_signed(-504,WIDTH/2);
	constant hp_a_1 : signed(WIDTH/2-1 downto 0) := to_signed(496, WIDTH/2); -- OBS changed sign
	
	constant eq_b_0 : signed(WIDTH-1 downto 0) := to_signed(55484, WIDTH);
	constant eq_b_1 : signed(WIDTH-1 downto 0) := to_signed(-313, WIDTH);
	constant eq_b_2 : signed(WIDTH-1 downto 0) := to_signed(-55123, WIDTH);
	constant eq_a_1 : signed(WIDTH-1 downto 0) := to_signed(313, WIDTH); -- OBS changed sign
	constant eq_a_2 : signed(WIDTH-1 downto 0) := to_signed(151, WIDTH); -- OBS changed sign
	
	signal hp_x_c, hp_x_n 			: signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- current input sample
	signal hp_x_prev_c, hp_x_prev_n : signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- previous input sample
	signal hp_y_c, hp_y_n 			: signed(WIDTH-1 downto 0)		:= (others => '0');	-- current output sample
	signal hp_y_prev_c, hp_y_prev_n	: signed(WIDTH/2-1 downto 0) 	:= (others => '0'); -- previous output sample
	
	signal eq_x_c, eq_x_n 						: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- current input sample
	signal eq_x_prev_c, eq_x_prev_n 			: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- previous input sample
	signal eq_x_prev_prev_c, eq_x_prev_prev_n 	: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- previous input sample
	signal eq_y_c, eq_y_n 						: signed(WIDTH/2-1 downto 0):= (others => '0');	-- current output sample
	signal eq_y_prev_c, eq_y_prev_n				: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- previous output sample
	signal eq_y_prev_prev_c, eq_y_prev_prev_n	: signed(WIDTH-1 downto 0) 	:= (others => '0'); -- previous output sample
	
--	signal mult_src1_c, mult_src1_n : signed(WIDTH-1 downto 0) := (others => '0');
--	signal mult_src2_c, mult_src2_n : signed(WIDTH-1 downto 0) := (others => '0');
--	signal mult_out_c, mult_out_n 	: signed(2*WIDTH-1 downto 0) := (others => '0');
--	signal add_src1_c, add_src1_n 	: signed(2*WIDTH-1 downto 0) := (others => '0');
--	signal add_src2_c, add_src2_n 	: signed(2*WIDTH-1 downto 0) := (others => '0');
--	signal add_out_c, add_out_n 	: signed(2*WIDTH-1 downto 0) := (others => '0');
	
	signal mult_src1 	: signed(WIDTH-1 downto 0) := (others => '0');
	signal mult_src2 	: signed(WIDTH-1 downto 0) := (others => '0');
	signal mult_out		: signed(2*WIDTH-1 downto 0) := (others => '0');
	signal add_src1 	: signed(2*WIDTH-1 downto 0) := (others => '0');
	signal add_src2 	: signed(2*WIDTH-1 downto 0) := (others => '0');
	signal add_out 		: signed(2*WIDTH-1 downto 0) := (others => '0');
	
	
	type state_type is (HOLD, HP_CALC1, HP_CALC2, HP_CALC3, HP_CALC4, 
						EQ_CALC1, EQ_CALC2, EQ_CALC3, EQ_CALC4, EQ_CALC5, EQ_CALC6, FINISH_CALC, SEND); -- states for FSM    
	signal state_c, state_n 		: state_type := HOLD;
	
begin

-- clock process
----------------------------------------------------------------------------------
clk_proc : process(clk, rstn) is
begin
	if rstn = '0' then
		state_c 		<= HOLD;
		hp_x_c 			<= (others => '0');
		hp_x_prev_c 	<= (others => '0');
		hp_y_c 			<= (others => '0');
		hp_y_prev_c		<= (others => '0');
		eq_x_c 			<= (others => '0');
		eq_x_prev_c 	<= (others => '0');
		eq_x_prev_prev_c <= (others => '0');
		eq_y_c 			<= (others => '0');
		eq_y_prev_c		<= (others => '0');
		eq_y_prev_prev_c <= (others => '0');
--		mult_src1_c 	<= (others => '0');
--		mult_src2_c		<= (others => '0');
--		mult_out_c		<= (others => '0');
--		add_src1_c		<= (others => '0');
--		add_src2_c		<= (others => '0');
--		add_out_c		<= (others => '0');
	elsif rising_edge(clk) then
		state_c 		<= state_n;
		hp_x_c 			<= hp_x_n;
		hp_x_prev_c 	<= hp_x_prev_n;
		hp_y_c 			<= hp_y_n;
		hp_y_prev_c 	<= hp_y_prev_n;
		eq_x_c 			<= eq_x_n;
		eq_x_prev_c 	<= eq_x_prev_n;
		eq_x_prev_prev_c <= eq_x_prev_prev_n;
		eq_y_c 			<= eq_y_n;
		eq_y_prev_c 	<= eq_y_prev_n;
		eq_y_prev_prev_c <= eq_y_prev_prev_n;
--		mult_src1_c 	<= mult_src1_n;
--		mult_src2_c		<= mult_src2_n;
--		mult_out_c		<= mult_out_n;
--		add_src1_c		<= add_src1_n;
--		add_src2_c		<= add_src2_n;
--		add_out_c		<= add_out_n;
	end if;
end process;

fsm_proc : process(state_c, i_start, hp_x_c, hp_x_prev_c, hp_y_prev_c, eq_x_c, eq_x_prev_c, eq_x_prev_prev_c, eq_y_prev_c, eq_y_prev_prev_c, mult_src1, mult_src2, add_src1, add_src2) is
--, mult_out, add_out

begin
	-- default values
	state_n			<= state_c;
	
	hp_x_n 			<= hp_x_c;
	hp_x_prev_n 	<= hp_x_prev_c;
	hp_y_prev_n 	<= hp_y_prev_c;
	
	eq_x_n			<= eq_x_c;
	eq_x_prev_n 	<= eq_x_prev_c;
	eq_x_prev_prev_n <= eq_x_prev_prev_c;
	eq_y_prev_n 	<= eq_y_prev_c;
	eq_y_prev_prev_n <= eq_y_prev_prev_c;
	
--	add_src1_n 	<= (others => '0');
--	add_src2_n 	<= (others => '0');
--	mult_src1_n <= (others => '0');
--	mult_src2_n <= (others => '0');
	
	add_src1 	<= (others => '0');
	add_src2 	<= (others => '0');
	mult_src1 	<= (others => '0');
	mult_src2 	<= (others => '0');
		
	o_done 		<= '0';
--	o_sample 	<= std_logic_vector(add_out_c(31 downto 16));
	o_sample 	<= std_logic_vector(eq_y_c);
--	o_sample 	<= (others => '0');
	
	case state_c is
		when HOLD =>
			if i_start = '1' then
				hp_x_n	<= signed(i_sample);
				state_n	<= HP_CALC1;
			end if;

-- HOGH PASS FILTER
----------------------------------------------------------------------------------			
		when HP_CALC1 =>
--			mult_src1_n <= resize(hp_x_c, WIDTH);
			mult_src1 <= resize(hp_x_c, WIDTH);
--			mult_src2_n <= resize(hp_b_0, WIDTH);
			mult_src2 <= resize(hp_b_0, WIDTH);
			state_n 	<= HP_CALC2;
			
		when HP_CALC2 =>
--			mult_src1_n <= resize(hp_x_prev_c, WIDTH);
			mult_src1 <= resize(hp_x_prev_c, WIDTH);
--			mult_src2_n <= resize(hp_b_1, WIDTH);
			mult_src2 <= resize(hp_b_1, WIDTH);
--			add_src1_n 	<= mult_out_c;
			add_src1 	<= mult_out;
			state_n 	<= HP_CALC3;
			
		when HP_CALC3 =>
--			mult_src1_n <= resize(hp_y_prev_c, WIDTH);
			mult_src1 <= resize(hp_y_prev_c, WIDTH);
--			mult_src2_n <= resize(hp_a_1, WIDTH);
			mult_src2 <= resize(hp_a_1, WIDTH);
--			add_src1_n 	<= mult_out_c;
			add_src1 	<= mult_out;
--			add_src2_n 	<= add_out_c;
			add_src2 	<= add_out;
			state_n 	<= HP_CALC4;
			
		when HP_CALC4 =>
--			add_src1_n 	<= mult_out_c;
			add_src1 	<= mult_out;
--			add_src2_n 	<= add_out_c;
			add_src2 	<= add_out;
			state_n 	<= EQ_CALC1;

-- EQUALIZER FILTER
----------------------------------------------------------------------------------
		when EQ_CALC1 =>
			hp_x_prev_n <= hp_x_c;
--			hp_y_prev_n <= add_out_c(24 downto 9);
			hp_y_prev_n <= add_out(24 downto 9);
--			eq_x_n		<= resize(add_out_c(WIDTH-1 downto 9), WIDTH);
			eq_x_n		<= resize(add_out(WIDTH-1 downto 9), WIDTH);
--			mult_src1_n <= resize(add_out_c(WIDTH-1 downto 9), WIDTH);
			mult_src1 <= resize(add_out(WIDTH-1 downto 9), WIDTH);
--			mult_src2_n <= eq_b_0;
			mult_src2 <= eq_b_0;
			state_n 	<= EQ_CALC2;
			
		when EQ_CALC2 =>
--			mult_src1_n <= eq_x_prev_c;
			mult_src1 <= eq_x_prev_c;
--			mult_src2_n <= eq_b_1;
			mult_src2 <= eq_b_1;
--			add_src1_n 	<= mult_out_c;
			add_src1 	<= mult_out;
--			add_src2_n 	<= 
			state_n		<= Eq_CALC3;
		
		when EQ_CALC3 =>
--			mult_src1_n <= eq_x_prev_prev_c;
			mult_src1 <= eq_x_prev_prev_c;
--			mult_src2_n <= eq_b_2;
			mult_src2 <= eq_b_2;
--			add_src1_n 	<= add_out_c;
			add_src1 	<= add_out;
--			add_src2_n 	<= mult_out_c;
			add_src2 	<= mult_out;
			state_n		<= EQ_CALC4;
		
		when EQ_CALC4 =>
--			mult_src1_n <= eq_y_prev_c;
			mult_src1 <= eq_y_prev_c;
--			mult_src2_n <= eq_a_1;
			mult_src2 <= eq_a_1;
--			add_src1_n 	<= add_out_c;
			add_src1 	<= add_out;
--			add_src2_n 	<= mult_out_c;
			add_src2 	<= mult_out;
			state_n		<= EQ_CALC5;
		
		when EQ_CALC5 =>
--			mult_src1_n <= eq_y_prev_prev_c;
			mult_src1 <= eq_y_prev_prev_c;
--			mult_src2_n <= eq_a_2;
			mult_src2 <= eq_a_2;
--			add_src1_n 	<= add_out_c;
			add_src1 	<= add_out;
--			add_src2_n 	<= mult_out_c;
			add_src2 	<= mult_out;
			state_n		<= EQ_CALC6;
		
		when EQ_CALC6 =>
--			mult_src1_n <= 
--			mult_src2_n <= 
--			add_src1_n 	<= add_out_c;
			add_src1 	<= add_out;
--			add_src2_n 	<= mult_out_c;
			add_src2 	<= mult_out;
			state_n		<= FINISH_CALC;
		
		when FINISH_CALC =>
			eq_x_prev_n			<= eq_x_c;
			eq_x_prev_prev_n	<= eq_x_prev_c;
--			eq_y_prev_n			<= add_out_c(40 downto 9);
			eq_y_prev_n			<= add_out(40 downto 9);
			eq_y_prev_prev_n	<= eq_y_prev_c;
--			state_n				<= SEND;
			
			state_n		<= HOLD;			
			o_done 		<= '1';
--			o_sample 	<= std_logic_vector(add_out_c(31 downto 16));
			o_sample 	<= std_logic_vector(add_out(31 downto 16));
--			eq_y_n		<= add_out_c(31 downto 16);
			eq_y_n		<= add_out(31 downto 16);

			
		when SEND =>
--			o_done 		<= '1';
--			o_sample 	<= std_logic_vector(add_out_c(31 downto 16));
--			o_sample 	<= std_logic_vector(add_out(31 downto 16));
--			eq_y_n		<= add_out_c(31 downto 16);
--			eq_y_n		<= add_out(31 downto 16);
			state_n		<= HOLD;	
			
	end case;
	
--	add_out_n 	<= add_src1_c + add_src2_c;
--	muladd_out_n 	<= add_src1_c + add_src2_c;
	add_out 	<= add_src1 + add_src2;
	mult_out 	<= mult_src1 * mult_src2;
	
end process;

end Behavioral;
