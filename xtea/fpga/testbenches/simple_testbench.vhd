-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Entity Name: Simple testbench
-- Description: Only drives clock and reset to debug FPGA wrapper
entity simple_testbench is
end simple_testbench;

architecture Behavioral of simple_testbench is
    -- DUT signals
    signal clk:             STD_LOGIC := '0';
    signal reset:           STD_LOGIC := '1';
    signal led:             STD_LOGIC_VECTOR(15 downto 0);
    signal uart_rx:         STD_LOGIC;
    signal uart_tx:         STD_LOGIC;

    -- 100 MHz clock = 10 ns period
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the top file
    uut : entity work.XTEA_FPGA_topfile
        port map (
            clk         => clk,
            reset       => reset,
            led         => led,
            uart_rx     => uart_rx,
            uart_tx     => uart_tx
            );
            
    -- Clock generation
    clk_process : process begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
            
        end loop;
    end process;
    
    -- Reset_only stimulus
    stim_process : process begin
        -- Hold reset active for some clock cycles
        reset <= '1';
        wait for 50 ns;
        
        -- Release reset
        reset <= '0';
        
        -- Let the RTL run
        wait for 1000ns;
        
        -- End simulation
        assert false report "Simulation finished" severity failure;
    end process;
end Behavioral;
