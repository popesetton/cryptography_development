-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: XTEA Encryption
-- Description: Contains encryption logic, calculates encrypted value with given subkey
--              (dx << 4 ^ dx >> 5) + dx) ^ subkey
entity xtea_enc is
    Port (clk:                  IN  STD_LOGIC;
          reset_n:              IN  STD_LOGIC;
          
          -- Key ready flag
          key_ready:            IN  STD_LOGIC;
          
          --  Encryption subkey in
          enc_key_word_in:      IN  unsigned(31 downto 0);
          
          -- Plaintext in flag from testbench stimulation
          data_valid:           IN  STD_LOGIC;
          
          -- Plaintext data in from testbench stimulation
          data_word_in:         IN  unsigned(31 downto 0);
          
          -- Subkey enable flag
          enc_subkey_enable:    OUT STD_LOGIC;
          
          -- Ciphertext ready
          data_ready:           OUT STD_LOGIC;
          
          -- Ciphertext out
          data_word_out:        OUT unsigned(31 downto 0)
    );
end xtea_enc;

architecture Behavioral of xtea_enc is
    
    -- FSM for XTEA encryption
    type state_t is (
        IDLE,
        LOAD_WORDS,
        ROUNDS,
        OUTPUT_WORDS
        );
        
    -- FSM register
    signal state_reg:                   state_t;
    
    -- 128-bit plaintext in 32-bit registers
    signal y0_reg:                      unsigned(31 downto 0);
    signal z0_reg:                      unsigned(31 downto 0); 
    signal y1_reg:                      unsigned(31 downto 0); 
    signal z1_reg:                      unsigned(31 downto 0);
    
    -- Register select flag for plaintext in
    signal write_words_reg:             unsigned(1 downto 0);
    
    -- Register select flag for ciphertext out
    signal output_count:                unsigned(1 downto 0);
    
    -- XTEA round counter
    signal round_count:                 unsigned(5 downto 0);
    
    -- Round half tracker
    signal round_half_reg:              STD_LOGIC;
    
    -- Subkey enable flag for subkey calculator
    signal subkey_enable_reg:           STD_LOGIC;
    
    -- Ciphertext out 
    signal data_word_out_reg:           unsigned(31 downto 0);
    
    -- Ciphertext out ready flag
    signal data_ready_reg:              STD_LOGIC;
      
begin

    process (clk, reset_n)
        -- Variables for XTEA calculation
        variable f0:                    unsigned(31 downto 0);
        variable f1:                    unsigned(31 downto 0);
        
    begin
        
        -- Active-low reset
        if reset_n = '0' then
            
            state_reg                   <= IDLE;
            
            y0_reg                      <= (others => '0');
            z0_reg                      <= (others => '0');
            y1_reg                      <= (others => '0');
            z1_reg                      <= (others => '0');
            
            write_words_reg             <= (others => '0');
            output_count                <= (others => '0');
            round_count                 <= (others => '0');
            
            round_half_reg              <= '0';
            
            data_word_out_reg           <= (others => '0');
            data_ready_reg              <= '0';
            subkey_enable_reg           <= '0';
            
        -- Positive-edge clocked
        elsif rising_edge(clk) then
            
            -- Default outputs
            data_ready_reg              <= '0';
            subkey_enable_reg           <= '0';
            
            -- FSM case statement
            case state_reg is
            
                -- IDLE FSM State
                when IDLE =>
                    write_words_reg     <= (others => '0');
                    output_count        <= (others => '0');
                    round_count         <= (others => '0');
                    round_half_reg      <= '0';
                    
                    -- Load first key word if key has been loaded in and testbench is in "writing data" phase
                    if key_ready = '1' and data_valid = '1' then
                        -- Load first word immediately
                        y0_reg          <= data_word_in;
                        write_words_reg      <= "01";
                        
                        -- Go to next state in FSM
                        state_reg       <= LOAD_WORDS;
                    end if;
                
                when LOAD_WORDS =>
                    -- Load words during data valid phase
                    if data_valid = '1' then
                        case write_words_reg is
                            when "01" =>
                                z0_reg              <= data_word_in;
                                write_words_reg     <= "10";
                                
                            when "10" =>
                                y1_reg              <= data_word_in;
                                write_words_reg     <= "11";
                                
                            when "11" =>
                                z1_reg              <= data_word_in;
                                
                                -- All words loaded, proceed to encryption rounds
                                round_count         <= (others => '0');
                                round_half_reg      <= '0';
                                
                                -- Change FSM state
                                state_reg <= ROUNDS;
                                
                            when others =>
                                -- Default
                                write_words_reg     <= "00";
                                
                        end case;
                    end if;
                    
                when ROUNDS =>
                    
                    -- First half of encryption round
                    -- y0  += ((z0 << 4 ^ z0 >> 5) + z0) ^ (sum + *k[sum & 3]);
                    -- y1  += ((z1 << 4 ^ z1 >> 5) + z1) ^ (sum + *k[sum & 3]);
                    if round_half_reg = '0' then
                        f0 := (((z0_reg sll 4) xor (z0_reg srl 5)) + z0_reg);
                        f1 := (((z1_reg sll 4) xor (z1_reg srl 5)) + z1_reg);
                        
                        y0_reg <= y0_reg + (f0 xor enc_key_word_in);
                        y1_reg <= y1_reg + (f1 xor enc_key_word_in);
                        
                        -- Prepare second half of subkey
                        subkey_enable_reg   <= '1';
                        
                        round_half_reg      <= '1';
                    
                    -- Second half of encryption round
                    -- z0  += ((y0 << 4 ^ z0 >> 5) + y0) ^ (sum + *k[sum & 3]);
                    -- z1  += ((y1 << 4 ^ z1 >> 5) + y1) ^ (sum + *k[sum & 3]);                   
                    else
                        f0 := (((y0_reg sll 4) xor (y0_reg srl 5)) + y0_reg);
                        f1 := (((y1_reg sll 4) xor (y1_reg srl 5)) + y1_reg);
                        
                        z0_reg <= z0_reg + (f0 xor enc_key_word_in);
                        z1_reg <= z1_reg + (f1 xor enc_key_word_in);
                        
                        -- Prepare next round's first half subkey
                        subkey_enable_reg   <= '1';
                        
                        round_half_reg      <= '0';
                        
                        -- Round counter for 32 encryption rounds
                        if round_count = to_unsigned(31, round_count'length) then
                            output_count        <= (others => '0');
                            state_reg           <= OUTPUT_WORDS;
                        else
                            round_count <= round_count + 1;
                        end if;
                    end if;
                    
                    -- Output words FSM state
                    when OUTPUT_WORDS => 
                        data_ready_reg      <= '1';
                        
                        case output_count is
                            
                            when "00" =>
                                data_word_out_reg   <= y0_reg;
                                output_count        <= "01";
                                
                            when "01" =>
                                data_word_out_reg   <= z0_reg;
                                output_count        <= "10";
                                
                            when "10" =>
                                data_word_out_reg   <= y1_reg;
                                output_count        <= "11";
                                
                            when "11" =>
                                data_word_out_reg   <= z1_reg;
                                
                                -- Reset output count
                                output_count        <= "00";
                                
                                -- Encryption finished, set encryption as idle
                                state_reg           <= IDLE;
                            
                            when others =>
                                --Defaults
                                output_count        <= "00";
                                state_reg           <= IDLE;
                        end case;
                        
                    when others =>
                        state_reg   <= IDLE;
                end case;
        end if;
    end process;
    
    -- Combinational logic
    data_word_out       <= data_word_out_reg;
    data_ready          <= data_ready_reg;
    enc_subkey_enable   <= '1' when state_reg = ROUNDS else '0';
end Behavioral;
