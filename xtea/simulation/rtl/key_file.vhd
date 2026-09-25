-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: Key file
-- Description: Contains key registers
entity key_file is
    Port (clk:          IN  STD_LOGIC;
          reset_n:      IN  STD_LOGIC;
          
          -- Key data in
          key_word_in:  IN  unsigned(31 downto 0);
          
          -- Key in flag
          key_valid:    IN  STD_LOGIC;
          
          -- Key values
          key_0:        OUT unsigned(31 downto 0);
          key_1:        OUT unsigned(31 downto 0); 
          key_2:        OUT unsigned(31 downto 0); 
          key_3:        OUT unsigned(31 downto 0);
          
          -- Key ready flag
          key_ready:    OUT STD_LOGIC
          );
end key_file;

architecture Behavioral of key_file is
    -- Key registers
    signal key_reg_0:       unsigned(31 downto 0);
    signal key_reg_1:       unsigned(31 downto 0);
    signal key_reg_2:       unsigned(31 downto 0);
    signal key_reg_3:       unsigned(31 downto 0);
    
    -- Register to hold which key register to be written
    signal write_key_reg:   unsigned(1 downto 0);
    
    -- Key ready register
    signal key_ready_reg:   STD_LOGIC;
    
    -- Delay key ready by one cycle for testbench
    signal key_ready_delay: STD_LOGIC;
        
begin
    process (clk, reset_n) begin
        
        -- Active-low reset
        if reset_n = '0' then
            key_reg_0           <= (others => '0');
            key_reg_1           <= (others => '0');
            key_reg_2           <= (others => '0');
            key_reg_3           <= (others => '0');
            
            write_key_reg       <= (others => '0');
            key_ready_reg       <= '0';
            key_ready_delay     <= '0';
            
        -- Positive-edge clocked
        elsif rising_edge(clk) then
        
            -- Set key ready register to 0 when key writing commences
            if key_valid = '1' then
                key_ready_reg <= '0';
            end if;
            
            -- Delay key register by one cycle for testbench, reset delay register
            if key_ready_delay = '1' then
                key_ready_reg   <= '1';
                key_ready_delay <= '0';
            end if;
            
            
            -- Commence writing key when key valid flag is high
            if key_valid = '1' then
                
                case write_key_reg is
                    when "00" =>
                        key_reg_0               <= key_word_in;
                        write_key_reg           <= "01";
                            
                    when "01" =>
                        key_reg_1               <= key_word_in;
                        write_key_reg           <= "10";
                                
                    when "10" =>
                        key_reg_2               <= key_word_in;
                        write_key_reg           <= "11";
                                
                    when "11" =>
                        key_reg_3               <= key_word_in;
                                
                        -- Indicate 128-bit key has now been loaded
                        key_ready_delay          <= '1';
                                
                        -- Reset key loading counter
                        write_key_reg           <= "00";
                                
                    when others => 
                        write_key_reg           <= "00";
                        key_ready_reg           <= '0';
                        key_ready_delay         <= '0';
                end case;
            end if;
        end if;
    end process;
    
    -- Combinational assign to key values from registers
    key_0       <= key_reg_0;
    key_1       <= key_reg_1;
    key_2       <= key_reg_2;
    key_3       <= key_reg_3;
        
    key_ready   <= key_ready_reg;

end Behavioral;
