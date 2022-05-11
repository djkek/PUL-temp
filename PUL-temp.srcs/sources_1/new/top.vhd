-- PUL Projekt - Dominik Jankowski 250184

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity top is
Port (
     Clock100MHz : in std_logic;
     SW0 : in std_logic;
     ADC_DOUT : in std_logic;

     ADC_CLK : out std_logic;
     ADC_CS : out std_logic;
     PWM : out std_logic
     );
end top;

architecture Behavioral of top is
type stany is (Idle, Init, Heating, Measure, Calculate, Maintain);
signal State, StateNext : stany := Idle;

signal timecounter : std_logic_vector(10 downto 0) := (others => '0');
signal timedone : std_logic := '0';

signal bitcounter : std_logic_vector(3 downto 0) := (others => '0');
signal bitdone : std_logic := '0';

signal temp : unsigned(11 downto 0) := (others => '-');

signal pwm_period : std_logic_vector(10 downto 0) := "11111111111";
signal pwm_ff : std_logic_vector(5 downto 0) := "111111";

signal Clock500kHz : std_logic := '0';
signal clockcounter : std_logic_vector(7 downto 0) := (others => '0');

signal PWM_OUT : std_logic := '0';


begin

clockgen: process(Clock100MHz)
begin
if rising_edge(Clock100MHz) then
    clockcounter <= clockcounter + "01";
    if clockcounter = "11001000" then
        Clock500kHz <= not Clock500kHz;
        clockcounter <= (others => '0');
    end if;
end if;
end process clockgen;


reg: process(Clock100MHz)
begin
if SW0 = '0' then
    State <= Idle;
elsif SW0 = '1' then
    if rising_edge(Clock100MHz) then
        State <= StateNext;
    end if;
end if;
end process reg;


wyjscia: process(Clock100MHz)
begin
    case state is
        when Idle =>
            ADC_CLK <= '0';
            ADC_CS <= '1';
            PWM <= '0';
            timecounter <= (others => '0');
            bitcounter <= (others => '0');
            temp <= (others => '0');
            
        when Init =>
            ADC_CS <= '1';
        when Heating =>
            ADC_CS <= '1';
            PWM <= PWM_OUT;
        when Measure =>
            ADC_CLK <= Clock500kHz;
            ADC_CS <= '0';
        when Calculate =>
            ADC_CS <= '1';
        when Maintain =>
            ADC_CS <= '1';
    end case;
end process wyjscia;


receive_temp: process(Clock500kHz)
begin
if rising_edge(Clock500kHz) then
    if State = Measure then
        if bitdone = '0' then
                bitcounter <= bitcounter + "01";
                if bitcounter > 3 then
                    temp <= shift_left(temp, 1);
                    temp(11) <= ADC_DOUT;
                end if;
                if bitcounter = 15 then
                    bitdone <= '1';
                end if;
        end if;
    end if;
end if;
end process receive_temp;

end Behavioral;
