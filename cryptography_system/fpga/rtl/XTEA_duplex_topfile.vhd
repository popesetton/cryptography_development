-- Included libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Entity Name: XTEA Duplex Topfile
-- Description: Contains top for duplex XTEA implementation
--              Instantiates internal module blocks contained in other .vhd files within the project
entity XTEA_duplex_topfile is
    Port (clk:                  IN  STD_LOGIC;
          reset_n:              IN  STD_LOGIC;
         
          -- From mini router
          router_data_out:      IN  STD_LOGIC_VECTOR(8 downto 0);
          router_valid:         IN  STD_LOGIC;
          
          ciphertext_word_out:  OUT STD_LOGIC_VECTOR(31 downto 0);
          ciphertext_ready:     OUT STD_LOGIC;
          
          data_word_out:        OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
          data_ready:           OUT STD_LOGIC      
    );
end XTEA_duplex_topfile;

architecture Behavioral of XTEA_duplex_topfile is
    -- Hard-coded XTEA key
    constant KEY_0_C:           STD_LOGIC_VECTOR(31 downto 0) := x"DEADBEEF";
    constant KEY_1_C:           STD_LOGIC_VECTOR(31 downto 0) := x"01234567";
    constant KEY_2_C:           STD_LOGIC_VECTOR(31 downto 0) := x"89ABCDEF";
    constant KEY_3_C:           STD_LOGIC_VECTOR(31 downto 0) := x"DEADBEEF";
    
    -- Key signals    
    signal key_0:               unsigned(31 downto 0);
    signal key_1:               unsigned(31 downto 0);
    signal key_2:               unsigned(31 downto 0);
    signal key_3:               unsigned(31 downto 0);
    
    signal key_ready_internal:  STD_LOGIC;
    
    -- Router to XTEA conversion signals
    signal data_word_in_internal:           STD_LOGIC_VECTOR(31 downto 0);
    signal data_valid_internal:             STD_LOGIC;
    
    signal ciphertext_word_in_internal:     STD_LOGIC_VECTOR(31 downto 0);
    signal ciphertext_valid_internal:       STD_LOGIC;
    
    signal enc_word_buf:                    STD_LOGIC_VECTOR(31 downto 0);
    signal dec_word_buf:                    STD_LOGIC_VECTOR(31 downto 0);
    
    signal enc_byte_count:                  unsigned(1 downto 0);
    signal dec_byte_count:                  unsigned(1 downto 0);
       
   
    -- Encryption subkey signals
    signal enc_key_word_out:    unsigned(31 downto 0);
    signal enc_subkey_enable:   STD_LOGIC;
    
    -- Decryption subkey signals
    signal dec_key_word_out:    unsigned(31 downto 0);
    signal dec_subkey_enable:   STD_LOGIC;
    
    -- Encryption output signals
    signal enc_data_word_out:   unsigned(31 downto 0);
    signal enc_data_ready:      STD_LOGIC;
    
    -- Decryption output signals
    signal dec_data_word_out:   unsigned(31 downto 0);
    signal dec_data_ready:      STD_LOGIC;
    
begin
    
    -- Hard-coded key and key ready
    key_0               <= unsigned(KEY_0_C);
    key_1               <= unsigned(KEY_1_C);
    key_2               <= unsigned(KEY_2_C);
    key_3               <= unsigned(KEY_3_C);
    
    key_ready_internal  <= '1';
    
    -- Encryption output maps to ciphertext output ports
    ciphertext_word_out <= std_logic_vector(enc_data_word_out);
    ciphertext_ready    <= enc_data_ready;
    
    -- Decryption output maps to plaintext output ports
    data_word_out       <= std_logic_vector(dec_data_word_out);
    data_ready          <= dec_data_ready;
    
    -- Router to XTEA byte-to-word converter
    process (clk, reset_n)
        variable next_enc_word:         STD_LOGIC_VECTOR(31 downto 0);
        variable next_dec_word:         STD_LOGIC_VECTOR(31 downto 0);
        variable data_byte:             STD_LOGIC_VECTOR(7 downto 0);
        variable mode_bit:              STD_LOGIC;
    begin
        
        -- Active-low reset
        if reset_n = '0' then
            
            enc_word_buf                        <= (others => '0');
            dec_word_buf                        <= (others => '0');
            
            enc_byte_count                      <= (others => '0');
            dec_byte_count                      <= (others => '0');
            
            data_word_in_internal               <= (others => '0');
            ciphertext_word_in_internal         <= (others => '0');
            
            data_valid_internal                 <= '0';
            ciphertext_valid_internal           <= '0';
            
        elsif rising_edge(clk) then
            
            -- Default: valid pulses last one clock cycle
            data_valid_internal                 <= '0';
            ciphertext_valid_internal           <= '0';
            
            data_byte                           := router_data_out(7 downto 0);
            mode_bit                            := router_data_out(8);
            
            if router_valid = '1' then
            
                -- Encryption input stream
                if mode_bit = '0' then
                    next_enc_word := enc_word_buf;
                    
                    case enc_byte_count is
                        when "00" =>
                            next_enc_word(31 downto 24) := data_byte;
                            enc_word_buf                 <= next_enc_word;
                            enc_byte_count               <= "01";

                        when "01" =>
                            next_enc_word(23 downto 16) := data_byte;
                            enc_word_buf                 <= next_enc_word;
                            enc_byte_count               <= "10";

                        when "10" =>
                            next_enc_word(15 downto 8)  := data_byte;
                            enc_word_buf                 <= next_enc_word;
                            enc_byte_count               <= "11";

                        when "11" =>
                            next_enc_word(7 downto 0)   := data_byte;

                            data_word_in_internal        <= next_enc_word;
                            data_valid_internal          <= '1';

                            enc_word_buf                 <= (others => '0');
                            enc_byte_count               <= "00";

                        when others =>
                            enc_byte_count               <= "00";

                    end case;
            
                -- Decryption input stream            
                else     
                
                    next_dec_word := dec_word_buf;
                    
                    case dec_byte_count is

                        when "00" =>
                            next_dec_word(31 downto 24)     := data_byte;
                            dec_word_buf                    <= next_dec_word;
                            dec_byte_count                  <= "01";

                        when "01" =>
                            next_dec_word(23 downto 16)     := data_byte;
                            dec_word_buf                    <= next_dec_word;
                            dec_byte_count                  <= "10";

                        when "10" =>
                            next_dec_word(15 downto 8)      := data_byte;
                            dec_word_buf                    <= next_dec_word;
                            dec_byte_count                  <= "11";

                        when "11" =>
                            next_dec_word(7 downto 0)       := data_byte;

                            ciphertext_word_in_internal     <= next_dec_word;
                            ciphertext_valid_internal       <= '1';

                            dec_word_buf                    <= (others => '0');
                            dec_byte_count                  <= "00";

                        when others =>
                            dec_byte_count                  <= "00";

                    end case;            
                end if;             
            end if;   
        end if;
    end process;
   
    -- Instantiate subkey calculation module for encryption
    subkey_calc_enc: entity work.subkey_calc_enc
        port map (
            clk                 => clk,
            reset_n             => reset_n,
            key_ready           => key_ready_internal,
            key_0               => key_0,
            key_1               => key_1,
            key_2               => key_2,
            key_3               => key_3,
            enc_subkey_enable   => enc_subkey_enable,
            enc_key_word_out    => enc_key_word_out
            );

    -- Instantiate subkey calculation module for decryption
    subkey_calc_dec: entity work.subkey_calc_dec
        port map (
            clk                 => clk,
            reset_n             => reset_n,
            key_ready           => key_ready_internal,
            key_0               => key_0,
            key_1               => key_1,
            key_2               => key_2,
            key_3               => key_3,
            dec_subkey_enable   => dec_subkey_enable,
            dec_key_word_out    => dec_key_word_out
            );
            
    -- Instantiate XTEA encryption block
    xtea_enc: entity work.xtea_enc
        port map (
            clk                 => clk,
            reset_n             => reset_n,        
            
            key_ready           => key_ready_internal,
            enc_key_word_in     => enc_key_word_out,   
                
            data_valid          => data_valid_internal,
            data_word_in        => unsigned(data_word_in_internal),
            
            enc_subkey_enable   => enc_subkey_enable,
            
            data_ready          => enc_data_ready,
            data_word_out       => enc_data_word_out
            );

    -- Instantiate XTEA decryption block
    xtea_dec: entity work.xtea_dec
        port map (
            clk                 => clk,
            reset_n             => reset_n,     
               
            key_ready           => key_ready_internal,
            dec_key_word_in     => dec_key_word_out,
               
            data_valid          => ciphertext_valid_internal,
            data_word_in        => unsigned(ciphertext_word_in_internal),
            
            dec_subkey_enable   => dec_subkey_enable,
            
            data_ready          => dec_data_ready,
            data_word_out       => dec_data_word_out
            );
end Behavioral;
