------------------------------------------------------------------------
-- fft
--
-- calculation of FFT magnitude
--
-- Inputs:
-- 32-Bit Floating Point number in range +-16 expected (loaded from FIFO)
--
-- Outputs
-- 32-Bit Floating Point number in range +-16 calculated (stored in FIFO)
--
-----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.reg32.all;
use work.task.all;
use work.float.all;

entity fft is
		generic (

	  -- input data width of real/img part
						input_data_width : integer := 32;

	  -- output data width of real/img part
						output_data_width : integer := 32

				);
		port (
					 clk : in std_logic;
					 reset : in std_logic;

					 task_start : in std_logic;
					 task_state : out work.task.State;

					 signal_read : out std_logic;
					 signal_readdata : in std_logic_vector( 31 downto 0 );

					 signal_write : out std_logic;
					 signal_writedata : out std_logic_vector( 31 downto 0 )
			 );
end entity fft;

architecture rtl of fft is

	-- FFT FSM 
		type fft_state is (
		IDLE,
		IN_FFT,
		WAIT_FFT,
		OUT_FFT,
		IN_MAG,
		WAIT_MAG,
		OUT_MAG
);

signal current_task_state : work.task.State;
signal next_task_state : work.task.State;
signal index : integer range 0 to work.task.STREAM_LEN;
signal in_cnt : integer range 0 to work.task.STREAM_LEN;
signal out_cnt : integer range 0 to work.task.STREAM_LEN;

signal current_task_state_fft : fft_state;
signal next_task_state_fft : fft_state;
	-- signals add that TASK_DONE  --> continue at task_start
signal task_done : std_logic; 

	-- Internal signals for FFT 
signal i_re 		: std_logic_vector( 31 downto 0 );
signal i_im 		: std_logic_vector( 31 downto 0 );
signal i_en 	 	: std_logic;

signal o_re 		: std_logic_vector( 31 downto 0 );
signal o_im 		: std_logic_vector( 31 downto 0 );
signal o_en 	 	: std_logic;

	-- internal Signals for Mag
signal i_valid 	 	: std_logic;
signal o_valid 	 	: std_logic;
signal o_mag 		: std_logic_vector( 31 downto 0 );

constant expo: signed(7 downto 0) :=  x"7E";


component FFTMAIN is
		port(   
					clock : in std_logic;
					reset : in std_logic;
					di_en :  in std_logic;
					di_re :  in std_logic_vector(31 downto 0);
					di_im :  in std_logic_vector(31 downto 0);
					do_en :  out std_logic;
					do_re :  out std_logic_vector(31 downto 0);
					do_im :  out std_logic_vector(31 downto 0)

);
end component;
begin
	------------------------------ Instance IP ---------------------------------------
		u_fft: FFTMAIN
		port map(
						clock   => clk,
						reset   => reset,
						di_en   => i_en,
						di_re   => i_re,
						di_im   => i_im,
						do_en   => o_en,
						do_re   => o_re,	
						do_im   => o_im
				);

		u_mag: entity work.fft_magnitude_calc
		port map (
						 clk  => clk,
						 reset => reset,

						 input_valid => i_valid,
						 input_re  => o_re,
						 input_im  => o_im,

						 output_valid => o_valid,
						 output_magnitude => o_mag
				 );
	----------------------------------------------------------------------------------

	------------------------------- Task FSM ---------------------------------------
		task_state_transitions : process ( current_task_state_fft, task_start, index ) is
		begin
				next_task_state <= current_task_state;
				case current_task_state is
						when work.task.TASK_IDLE =>
								if ( task_start = '1' ) then
										next_task_state <= work.task.TASK_RUNNING;
								end if;
						when work.task.TASK_RUNNING =>
								if ( index = work.task.STREAM_LEN - 1 ) then
										next_task_state <= work.task.TASK_DONE;
								end if;
						when work.task.TASK_DONE =>
								if ( task_start = '1' ) then
										next_task_state <= work.task.TASK_RUNNING;
								end if;
				end case;
		end process task_state_transitions;

	------------------------------- Task Proc ---------------------------------------
		sync : process ( clk, reset ) is
		begin
				if ( reset = '1' ) then
						current_task_state <= work.task.TASK_IDLE;
						index <= 0;
				elsif ( rising_edge( clk ) ) then
						current_task_state <= next_task_state;
						case next_task_state is
								when work.task.TASK_IDLE =>
										index <= 0;
								when work.task.TASK_RUNNING =>
										task_done <= '0';
										if ( current_task_state_fft = OUT_MAG) then
												index <= index + 1;
										end if;
								when work.task.TASK_DONE =>
										task_done <= '1';
										index <= 0;
						end case;
				end if;
		end process sync;
	--------------------------------------------------------------------------------

	------------------------------- FFT FSM ---------------------------------------
		fft_state_transitions : process ( current_task_state_fft, task_start, in_cnt, out_cnt, o_en, o_valid, task_done) is
		begin

				next_task_state_fft <= current_task_state_fft;
				case current_task_state_fft is
						when IDLE =>
								if ( task_start = '1' ) then
										next_task_state_fft <= IN_FFT;
								end if;
						when IN_FFT =>
								if ( in_cnt = work.task.STREAM_LEN - 1 ) then
										next_task_state_fft <= WAIT_FFT;
								elsif ( task_done = '1' ) then
										next_task_state_fft <= IDLE;
								end if;
			-- wait for out enable of FFT-IP
						when WAIT_FFT =>
								if ( o_en = '1' ) then
										next_task_state_fft <= OUT_FFT;
								elsif ( task_done = '1' ) then
										next_task_state_fft <= IDLE;
								end if;
			-- scale o_re for MAG-IP
						when OUT_FFT =>
								if ( task_done = '1' ) then
										next_task_state_fft <= IDLE;
								else
										next_task_state_fft <= IN_MAG;
								end if;
			-- set in valid
						when IN_MAG =>
								if ( task_done = '1' ) then
										next_task_state_fft <= IDLE;
								else
										next_task_state_fft <= WAIT_MAG;
								end if;
			-- wait for o_valid 
						when WAIT_MAG =>
								if ( o_valid = '1' ) then
										next_task_state_fft <= OUT_MAG;
								elsif ( task_done = '1' ) then
										next_task_state_fft <= IDLE;
								end if;
			-- scale back o_mag for signal_writedata
						when OUT_MAG =>
								if ( task_done = '1' ) then
										next_task_state_fft <= IDLE;
								elsif ( out_cnt = work.task.STREAM_LEN - 1 ) then
										next_task_state_fft <= IN_FFT;
								else
										next_task_state_fft <= IN_MAG;
								end if;
				end case;
		end process fft_state_transitions;

	------------------------------- FFT Proc ---------------------------------------
		fft_sync : process ( clk, reset ) is

				variable v_read_data : std_logic_vector(31 downto 0); 
				variable v_write_data : std_logic_vector(31 downto 0); 
		begin
				if ( reset = '1' ) then
						current_task_state_fft <= IDLE;
						signal_write <= '0';
						signal_read <= '0';
						i_en <= '0';
						in_cnt <= 0;
						out_cnt <= 0;
						i_valid <= '0';
						v_read_data := x"00000000";
				elsif ( rising_edge( clk ) ) then
						current_task_state_fft <= next_task_state_fft;
						case next_task_state_fft is
								when IDLE =>
										signal_write <= '0';
										signal_read <= '0';
										i_en <= '0';
										in_cnt <= 0;
										out_cnt <= 0;
								when IN_FFT =>
				-- Signal einlesen
										out_cnt <= 0;
										signal_write <= '0';
										signal_read <= '1';
				-- wenn ich von OUT_MAG aus komme
										i_en <= '1';
				-- In der Float welt teilen
										v_read_data := signal_readdata;
										v_read_data(30 downto 23) := std_logic_vector( signed(v_read_data(30 downto 23)) - 4 );
										i_re <= to_fixed( v_read_data );
										i_im <= x"00000000";
										in_cnt <= in_cnt + 1; 
								when WAIT_FFT =>
				-- Wait for o_en
										in_cnt <= 0;
								when OUT_FFT =>
										signal_read <= '0';
								when IN_MAG =>
										i_valid <= '1';
										out_cnt <= out_cnt + 1;
								when WAIT_MAG =>
			-- Wait for o_valid
								when OUT_MAG =>
										signal_write <= '1';
										v_write_data := to_float(o_mag);
										v_write_data(30 downto 23) := std_logic_vector( signed(v_write_data(30 downto 23)) + 4 );

										signal_writedata(31) <= v_write_data(0);
										signal_writedata(30) <= v_write_data(1);
										signal_writedata(29) <= v_write_data(2);
										signal_writedata(28) <= v_write_data(3);
										signal_writedata(27) <= v_write_data(4);
										signal_writedata(26) <= v_write_data(5);
										signal_writedata(25) <= v_write_data(6);
										signal_writedata(24) <= v_write_data(7);
										signal_writedata(23) <= v_write_data(8);
										signal_writedata(22) <= v_write_data(9);
										signal_writedata(21) <= v_write_data(10);
										signal_writedata(20) <= v_write_data(11);
										signal_writedata(19) <= v_write_data(12);
										signal_writedata(18) <= v_write_data(13);
										signal_writedata(17) <= v_write_data(14);
										signal_writedata(16) <= v_write_data(15);

										signal_writedata(15) <= v_write_data(16);
										signal_writedata(14) <= v_write_data(17);
										signal_writedata(13) <= v_write_data(18);
										signal_writedata(12) <= v_write_data(19);
										signal_writedata(11) <= v_write_data(20);
										signal_writedata(10) <= v_write_data(21);
										signal_writedata(9) <= v_write_data(22);
										signal_writedata(8) <= v_write_data(23);
										signal_writedata(7) <= v_write_data(24);
										signal_writedata(6) <= v_write_data(25);
										signal_writedata(5) <= v_write_data(26);
										signal_writedata(4) <= v_write_data(27);
										signal_writedata(3) <= v_write_data(28);
										signal_writedata(2) <= v_write_data(29);
										signal_writedata(1) <= v_write_data(30);
										signal_writedata(0) <= v_write_data(31);

						end case;
				end if;
		end process fft_sync;
	--------------------------------------------------------------------------------
		task_state <= current_task_state;

end architecture rtl;
