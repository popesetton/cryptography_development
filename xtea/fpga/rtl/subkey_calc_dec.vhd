-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: Decryption subkey calculator
-- Description: Calculates subkey for XTEA decryption
--              (sum + *k[sum & 3]) and (sum + *k[sum>>11 & 3]) depending on operation half
entity subkey_calc_dec is
    Port (clk:                  IN  STD_LOGIC;
          reset_n:              IN  STD_LOGIC;

          -- Goes high when all key words have been loaded
          key_ready:            IN  STD_LOGIC;
          
          -- Key values obtained from key file
          key_0:                IN unsigned(31 downto 0);
          key_1:                IN unsigned(31 downto 0);
          key_2:                IN unsigned(31 downto 0);
          key_3:                IN unsigned(31 downto 0);
              
          
          -- Control signal from decryption FSM
          -- Goes high for one clock cycle when xtea_dec has used the current subkey
          dec_subkey_enable:    IN  STD_LOGIC;
          
          -- Output decryption subkey calculation
          dec_key_word_out:     OUT unsigned(31 downto 0)
    );
end subkey_calc_dec;

architecture Behavioral of subkey_calc_dec is
    -- Declare constants for sum and delta
    constant delta:             unsigned(31 downto 0) := x"9E3779B9";
    constant sum0:              unsigned(31 downto 0) := x"C6EF3720";

    -- Sum hold register
    signal sum_reg:             unsigned(31 downto 0);
    
    -- Hold register that tracks which half of operation is happening
    signal operation_half_reg:  STD_LOGIC;
    
    -- Key selection logic
    signal key_mux_select:      unsigned(1 downto 0);
    signal selected_key:        unsigned(31 downto 0);

begin

    process (clk, reset_n)
    begin
        -- Active-low reset
        if reset_n = '0' then
            sum_reg             <= sum0;
            operation_half_reg  <= '0';
            
        -- Positive-edge clocked
        elsif rising_edge(clk) then
            -- Hold/reset subkey sequence until a valid key starts
            if key_ready = '0' then
                sum_reg             <= sum0;
                operation_half_reg  <= '0';
                
            -- Calculate next sum with delta value once key is ready
            elsif dec_subkey_enable = '1' then
            
                if operation_half_reg = '0' then
                    -- After first encryption half-round, increment sum
                    sum_reg                 <= sum_reg - delta;
                    operation_half_reg      <= '1';
                else
                    -- After second half-round, move to next round first half
                    operation_half_reg      <= '0';
                end if;        
           end if;
        end if;
    end process;
    
    -- Select logic for shift of sum depending on operation half
    key_mux_select <= sum_reg(12 downto 11) when operation_half_reg = '0' else
                      sum_reg(1 downto 0);
                      
    -- 4-input multiplexer for key selection based on sum
    with key_mux_select select
        selected_key <= key_0 when "00",
                        key_1 when "01",
                        key_2 when "10",
                        key_3 when "11",
                        (others => '0') when others;
                      
    -- Add sum and selected key
    dec_key_word_out <= sum_reg + selected_key;
    
end Behavioral;
