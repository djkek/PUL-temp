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
     PWM : out std_logic;
     LED0 : out std_logic; -- low temp
     LED1 : out std_logic;
     LED2 : out std_logic;
     LED3 : out std_logic; -- docelowa temp
     LED0_R : out std_logic -- powy?ej docelowej
     );
end top;

architecture Behavioral of top is
type stany is (Idle, Init, Heating, Measure, TooHot);
signal State, StateNext : stany := Idle;

signal timecounter : std_logic_vector(10 downto 0) := (others => '0');
signal timedone : std_logic := '0';
signal timetocount : integer := 100; --ms - czas od rozpoczecia grzania do wykonania pomiaru

signal bitcounter : std_logic_vector(3 downto 0) := (others => '0');
signal bitdone : std_logic := '0';

signal temp : integer := 0; -- stopnie C

signal pwm_period : std_logic_vector(13 downto 0) := "10011100010000";
signal pwm_ff : std_logic_vector(13 downto 0) := (others => '0');
signal pwm_counter : std_logic_vector(13 downto 0) := (others => '0');

signal Clock_kHz : std_logic := '0';
signal clockcounter : std_logic_vector(13 downto 0) := (others => '0');

signal clockfrequency : integer := 500; --kHz
signal measureperiod : integer := 10; --ms

signal PWM_OUT : std_logic := '0';

signal slope_target : std_logic_vector(7 downto 0) := (others => '0');
signal slope : std_logic_vector(7 downto 0) := (others => '0');

begin

clockgen: process(Clock100MHz)
begin
if rising_edge(Clock100MHz) then
    clockcounter <= clockcounter + "01";
    if clockcounter = (50000/clockfrequency) then --"11001000" then
        Clock_kHz <= not Clock_kHz;
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

count_time: process(Clock100MHz)
begin
if rising_edge(Clock100MHz) then
    if State = Heating or State = TooHot then
        timecounter <= timecounter + "01";
        if timecounter = 1000 then
            timedone <= '1';
            timecounter <= (others => '0');
        end if;
    else timedone <= '0';
    end if;
end if;
end process count_time;

lampki: process(temp)
begin

LED0 <= '0';
LED1 <= '0';
LED2 <= '0';
LED3 <= '0';
LED0_R <= '0';

if State /= Idle then
    if temp > 25 then
        LED0 <= '1';
    end if;
    if temp > 30 then
        LED1 <= '1';
    end if;
    if temp > 35 then
        LED2 <= '1';
    end if;
    if temp > 39 then
        LED3 <= '1';
    end if;
    if State = TooHot then
        LED0_R <= '1';
    end if;
        
end if;
end process;

wyjscia: process(Clock100MHz)
begin
    ADC_CLK <= Clock_kHz;
    ADC_CS <= '1';
    PWM <= '0';
    
    case state is
        when Idle =>
            ADC_CLK <= '0';
            
        when Init =>

        when Heating =>
            PWM <= PWM_OUT;

        when Measure =>
            ADC_CS <= '0';
            
        when TooHot =>

    end case;
end process wyjscia;

przejscia: process(Clock100MHz)
begin
if rising_edge(Clock100Mhz) then
    StateNext <= State;
    if SW0 = '0' then
        StateNext <= Idle;
    else
    case State is
        when Idle =>
            if SW0 = '1' then
                StateNext <= Init;
            end if;
            
        when Init =>
            StateNext <= Heating;
            
        when Heating =>
            if timedone = '1' then
                StateNext <= Measure;
            end if;

        when TooHot =>
            if timedone = '1' then
                StateNext <= Measure;
            end if;
            
        when Measure =>
            if bitdone = '1' then
                if (temp >= 41) then
                    StateNext <= TooHot;
                else StateNext <= Heating;
                end if;
            end if;
    end case;
    end if;
end if;
end process przejscia;

receive_temp: process(Clock_kHz)

variable temp_ADC : unsigned(11 downto 0);

begin
if rising_edge(Clock_kHz) then
    if State = Measure then
        if bitdone = '0' then
            
            bitcounter <= bitcounter + "01";

            if bitcounter >= 3 then
                temp_ADC := shift_right(temp_ADC, 1);
                temp_ADC(11) := ADC_DOUT;
            end if;
            if bitcounter = 14 then
                bitdone <= '1';
                temp <= ((to_integer(temp_ADC)) - 400)/20;
            end if;
        end if;
    else
        bitdone <= '0';
        bitcounter <= (others => '0');
    end if;
end if;
end process receive_temp;

FF_control: process(temp)
begin
    if (temp < 25) then
        pwm_ff <= "01111101000000"; -- 80%
    elsif (temp < 30) then
        pwm_ff <= "01011101110000"; -- 60%
    elsif (temp < 35) then
        pwm_ff <= "01001110001000"; -- 50%
    elsif (temp > 35) then
        pwm_ff <= "01000110010100"; -- 45%
    end if;
end process FF_control;

PWM_gen: process(Clock100MHz)
begin
if rising_edge(Clock100MHz) and State /= Idle then
    pwm_counter <= pwm_counter + "01";
    if pwm_counter < pwm_ff then
        PWM_OUT <= '1';
    elsif pwm_counter < pwm_period then
        PWM_OUT <= '0';
    elsif pwm_counter = pwm_period then
        pwm_counter <= (others => '0');
    end if;
end if;
end process PWM_gen;

end Behavioral;