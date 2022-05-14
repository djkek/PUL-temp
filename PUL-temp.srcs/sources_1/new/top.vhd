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
type stany is (Idle, Init, Heating, Measure, Correction, Maintain);
signal State, StateNext : stany := Idle;

signal timecounter : std_logic_vector(10 downto 0) := (others => '0');
signal timedone : std_logic := '0';

signal bitcounter : std_logic_vector(3 downto 0) := (others => '0');
signal bitdone : std_logic := '0';

signal temp : unsigned(11 downto 0) := (others => '-');
signal temp_old : unsigned(11 downto 0) := (others => '-');

signal pwm_period : std_logic_vector(16 downto 0) := "11000011010100000";
signal pwm_ff : std_logic_vector(16 downto 0) := (others => '0');
signal pwm_counter : std_logic_vector(16 downto 0) := (others => '0');

signal Clock500kHz : std_logic := '0';
signal clockcounter : std_logic_vector(13 downto 0) := (others => '0');
signal clockfrequency : integer := 500; --kHz

signal PWM_OUT : std_logic := '0';

signal slope_target : std_logic_vector(7 downto 0) := (others => '0');
signal slope : std_logic_vector(7 downto 0) := (others => '0');
-- jednostka - binarny odpopwiednik stopni na 1 pwm_period
-- np. 1 stopien C /s wychodzi
-- 19,5 = oko?o 20
-- czyli 10100
--
-- je?eli liczymy co 2 s to mamy ju? 40 bo mamy 2 stopnie ró?nicy
-- zatem trzeba znormalizowa?

-- zrobi? tak ?eby pomiar by? niezale?ny, non stop np. co 100 ms
-- tak aby temp, temp_old i slope by?y dostepne ca?y czas na bie??co


begin

clockgen: process(Clock100MHz)
begin
if rising_edge(Clock100MHz) then
    clockcounter <= clockcounter + "01";
    if clockcounter = (50000/clockfrequency) then --"11001000" then
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

count_time: process(Clock100MHz)
begin
if rising_edge(Clock100MHz) then
    if State = Heating then
        timecounter <= timecounter + "01";
        if timecounter = "11111111111" then
            timedone <= '1';
            timecounter <= (others => '0');
        end if;
    else timedone <= '0';
    end if;
end if;
end process count_time;

wyjscia: process(Clock100MHz)
begin
    case state is
        when Idle =>
            ADC_CLK <= '0';
            ADC_CS <= '1';
            PWM <= '0';
            
        when Init =>
            ADC_CS <= '1';
            ADC_CLK <= '0';
            
            
            
        when Heating =>
            ADC_CS <= '1';
            ADC_CLK <= '0';
            PWM <= PWM_OUT;
            if temp > 25 then
                LED0 <= '1';
            end if;
            if temp > 30 then
                LED1 <= '1';
            end if;
            if temp > 35 then
                LED2 <= '1';
            end if;
            if temp > 42 then
                LED0_R <= '1';
            end if;
            
        when Measure =>
            ADC_CLK <= Clock500kHz;
            ADC_CS <= '0';
            
        when Correction =>
            ADC_CLK <= '0';
            ADC_CS <= '1';
            
        when Maintain =>
            ADC_CLK <= '0';
            ADC_CS <= '1';
            LED0 <= '1';
            LED1 <= '1';
            LED2 <= '1';
            LED3 <= '1';
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
            
        when Heating => -- tu tylko kontrolujemy slopa
            if timedone = '1' then
                StateNext <= Measure;
            end if;
            
        when Measure =>
            if bitdone = '1' then
                StateNext <= Correction;
            end if;
            
        when Correction =>
            if temp > 38 and temp < 42 then
                StateNext <= Maintain;
            else
                StateNext <= Heating;
            end if;
            
            -- dostaje info o temperaturze obecnej
            -- je?eli w dobrym zakresie -> maintain
            -- je?eli w z?ym -> liczy slopa
            -- je?eli ok -> heating bez korekty
            -- je?eli nie -> korekta PWM a potem heating
            
            -- (30 - temp)/((temp-tempold)/okres)
            
        when Maintain =>
            if timedone = '1' then
                StateNext <= Measure;
            end if;
            if temp > 38 and temp < 42 then
                StateNext <= Maintain;
            else
                StateNext <= Heating;
            end if;
    end case;
    end if;
end if;
end process przejscia;

receive_temp: process(Clock500kHz)
begin
if rising_edge(Clock500kHz) then
    if State = Measure then
        if bitdone = '0' then
            if bitcounter = 0 then
                temp_old <= temp;
            end if;
            bitcounter <= bitcounter + "01";
            if bitcounter > 3 then
                temp <= shift_left(temp, 1);
                temp(11) <= ADC_DOUT;
            end if;
            if bitcounter = 15 then
                bitdone <= '1';
                bitcounter <= (others => '0');
            end if;
        end if;
    elsif State = Correction then
        bitdone <= '0';
    end if;
end if;
end process receive_temp;

Calculate_Slope: process(State)
begin
if rising_edge(Clock100MHz) and State = Correction and temp_old /= ("------------") then
    
    pwm_ff <= (others => '0'); -- korekta pwm
end if;
end process Calculate_Slope;

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