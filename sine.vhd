library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.reg32.all;
    use work.float.all;
    use work.task.all;

entity sine is
    port (
        clk : in std_logic;
        reset : in std_logic;

        task_start : in std_logic;
        task_state : out work.task.State;

        step_size : in work.reg32.word;
        phase : in work.reg32.word;
        amplitude : in work.reg32.word;

        signal_write : out std_logic;
        signal_writedata : out std_logic_vector( 31 downto 0 )
    );
end entity sine;

architecture rtl of sine is

    type sine_state is (
		INIT,
		IDLE,
        DATA_VALID, -- 
        BUSY, 			-- float_sin generiert sin
        RESULT_VALID -- Sinus ausgeben
    );

    signal current_task_sine_state : sine_state;
    signal current_task_state : work.task.State;
    signal next_task_state : work.task.State;
    signal next_task_sine_state : sine_state;
    signal index : integer range 0 to work.task.STREAM_LEN;


	-- internal Signals used for float 	
	signal data_valid_float_sine : std_logic;
	signal busy_float_sine : std_logic;
	signal result_valid_float_sine : std_logic;
	signal angle_float_sine : signed(31 downto 0);
	signal output_value_float_sine : signed(31 downto 0);
	signal is_running : std_logic; -- signals that task is running now
	signal is_idle : std_logic; -- signals that task is running now

	constant offset_expo: signed(7 downto 0) := x"7F";

begin
    task_state_transitions : process ( current_task_state, task_start, index ) is
    begin
        next_task_state <= current_task_state;
        case current_task_state is
            when work.task.TASK_IDLE =>
                if ( task_start = '1' ) then
                    next_task_state <= work.task.TASK_RUNNING;
                end if;
            when work.task.TASK_RUNNING =>
                if ( index = work.task.STREAM_LEN ) then
                    next_task_state <= work.task.TASK_DONE;
                end if;
            when work.task.TASK_DONE =>
                if ( task_start = '1' ) then
                    next_task_state <= work.task.TASK_RUNNING;
                end if;
        end case;
    end process task_state_transitions;

-- Ablauf:
-- reset : data_valid = 1->0 --> IDLE  
-- data_valid triggert task_sine_state_transition: FSM:IDLE aber data_valid = 0 --> bleibe in IDLE
-- clk triggert sine_sync:  data_valid 0->1
-- data_valid triggert task_sine_state_transition: FSM:DATA_VALID weil data_valid = 1 --> wechsle  in DATA_VALID
-- clk triggert sine_sync: FSM:DATA_VALID: setze data_valid = 0 & angle = phase
-- data_valid triggert task_sine_state_transition: FSM:DATA_VALID data_valid = 0 --> wechsle  in BUSY
-- clk triggert sine_sync: FSM:BUSY:  <TBD was machen?>
-- busy triggert task_sine_state_transition: FSM:BUSY float_sine_busy = 0 ? --> wechsle in RESULT_VALID
-- clk triggert sine_sync: FSM:RESULT_VALID: Berechneter sinuswert wird mit A skalliert und in FIFO geschrieben


	task_sine_state_transitions : process (is_idle, is_running, result_valid_float_sine , data_valid_float_sine ,busy_float_sine, current_task_sine_state) is
    begin
        next_task_sine_state <= current_task_sine_state;
        case current_task_sine_state is
            when INIT =>
                	if (is_running = '1' ) then
						next_task_sine_state <= IDLE;
                	end if;
            when IDLE =>
                	if (is_running = '1' and data_valid_float_sine = '1') then
                    	next_task_sine_state <= DATA_VALID;
					elsif ( current_task_state = work.task.TASK_DONE ) then
                    	next_task_sine_state <= INIT;
                	end if;
            when DATA_VALID =>
                	if (data_valid_float_sine = '0') then
                    	next_task_sine_state <= BUSY;
                	end if;
            when BUSY =>
                if (busy_float_sine = '0' and  result_valid_float_sine  = '1' ) then
                    next_task_sine_state <= RESULT_VALID;
                end if;
            when RESULT_VALID =>
                if ( data_valid_float_sine = '0' ) then
                    next_task_sine_state <= IDLE;
                end if;
        end case;
    end process task_sine_state_transitions;

    -- Instance of float sine 
    u_float_sine: entity work.float_sine
		generic map(
			ITERATIONS=>8
		)
        port map
        (
            clk => clk,
            reset =>  reset,

        	data_valid => data_valid_float_sine, 
        	busy  => busy_float_sine,
        	result_valid => result_valid_float_sine, 
        	angle => angle_float_sine,
        	sine => output_value_float_sine
        );


    sync : process ( clk, reset ) is
    begin
        if ( reset = '1' ) then
            current_task_state <= work.task.TASK_IDLE;
			is_running <= '0';
        elsif ( rising_edge( clk ) ) then
            current_task_state <= next_task_state;
            case next_task_state is
            when work.task.TASK_IDLE =>
				is_running <= '0';
                --signal_write <= '0';

            when work.task.TASK_RUNNING =>
				is_running <= '1';

            when work.task.TASK_DONE =>
				is_running <= '0';
                -- signal_write <= '0';
            end case;

        end if;
    end process sync;

    sine_sync : process ( clk, reset ) is
    begin
        if ( reset = '1' ) then
            current_task_sine_state <= INIT;
			data_valid_float_sine <= '0';
            signal_write <= '0';
            index <= 0;
        elsif ( rising_edge( clk ) ) then
            current_task_sine_state <= next_task_sine_state;

            case next_task_sine_state is
			
			when INIT =>
				angle_float_sine <= signed(phase);

			when IDLE =>
            	signal_write <= '0'; -- wenn ich von RESULT_VALID komme muss signal write noch 0 gesetzt werden
                data_valid_float_sine <= '1';

            when DATA_VALID =>
				-- lege startphase fest und wechsle in busy
				angle_float_sine <=  angle_float_sine + signed(step_size);
				data_valid_float_sine <= '0';
				
            when BUSY =>

            when RESULT_VALID =>
                index <= index + 1;
                signal_write <= '1';
				signal_writedata <= std_logic_vector(output_value_float_sine);
                signal_writedata (30 downto 23) <= std_logic_vector( signed(output_value_float_sine(30 downto 23)) + signed( amplitude(30 downto 23) ) - offset_expo );
                data_valid_float_sine <= '0';
            end case;

        end if;
    end process sine_sync;

    task_state <= current_task_state;

end architecture rtl;
