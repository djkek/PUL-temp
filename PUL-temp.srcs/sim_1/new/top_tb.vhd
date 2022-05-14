library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_tb is
--  Port ( );
end top_tb;

architecture Behavioral of top_tb is

component top is
    Port (
     Clock100MHz : in std_logic;
     SW0 : in std_logic;
     ADC_DOUT : in std_logic;

     ADC_CLK : out std_logic;
     ADC_CS : out std_logic;
     PWM : out std_logic;
     LED0 : out std_logic; -- low temp
     LED1 : out std_logic;
     LED2 : out std_logic;
     LED3 : out std_logic; -- docelowa temp
     LED0_R : out std_logic -- powy?ej docelowej
		);
end component;

signal Clock100MHz  : STD_LOGIC;
constant ClockPeriod	: time := 10 ns; 

signal SW0 : std_logic := '0';
signal ADC_DOUT : std_logic := '0';

signal ADC_CLK : std_logic := '0';
signal ADC_CS : std_logic := '0';
signal PWM : std_logic := '0';
signal LED0 : std_logic := '0'; -- low temp
signal LED1 : std_logic := '0';
signal LED2 : std_logic := '0';
signal LED3 : std_logic := '0'; -- docelowa temp
signal LED0_R : std_logic := '0'; -- powy?ej docelowej


begin

p_Clock : process
begin
	Clock100MHz <= '0';
	wait for ClockPeriod/2;
	Clock100MHz <= '1';
	wait for ClockPeriod - (ClockPeriod/2);
end process;

p_Stimulus : process
begin
	wait for 3 us;
	--assert false severity failure;
end process;

top_i : top
port map (
Clock100MHz => Clock100MHz,
SW0 => SW0,
ADC_DOUT => ADC_DOUT, 

ADC_CLK => ADC_CLK,
ADC_CS => ADC_CS,
PWM => PWM,
LED0 => LED0,
LED1 => LED1,
LED2 => LED2,
LED3 => LED3,
LED0_R => LED0_R
);

end Behavioral;
