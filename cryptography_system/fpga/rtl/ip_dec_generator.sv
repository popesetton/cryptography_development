
// Module name: IP Decryption Data Generator
// Description: Generates ciphertext to be decrypted in XTEA module
module ip_dec_generator(input logic             clk,
                        input logic             reset_n,
                        input logic             grant2,
                        output logic [9:0]      data2,
                        output logic            req2
                        );

                        
    // Define FSM for dec generator
    typedef enum logic [1:0] {
        IDLE,
        SEND,
        DONE
    } state_t;

    // Instantiate state register and next state
    state_t state_reg, state_next;
    
    // Internal signals
    // 16 bytes in XTEA block
    logic [3:0]     byte_index;
    
    // Data for router
    logic [7:0]     data;
    logic [1:0]     priority_bits;
    
    // Shift register for pseudo-random priority bits
    logic [3:0]     lfsr;
     
    assign priority_bits = lfsr[1:0];
    
    // Hard-coded ciphertext ROM
    // Ciphertext: 7409807B CC3B0E75 9EFD53A8 AEA16A76
    always_comb begin
        case (byte_index)
            4'd0:  data = 8'h74;
            4'd1:  data = 8'h09;
            4'd2:  data = 8'h80;
            4'd3:  data = 8'h7B;
            
            4'd4:  data = 8'hCC;
            4'd5:  data = 8'h3B;
            4'd6:  data = 8'h0E;
            4'd7:  data = 8'h75;
            
            4'd8:  data = 8'h9E;
            4'd9:  data = 8'hFD;
            4'd10: data = 8'h53;
            4'd11: data = 8'hA8;
            
            4'd12: data = 8'hAE;
            4'd13: data = 8'hA1;
            4'd14: data = 8'h6A;
            4'd15: data = 8'h76;
            
            default: data = 8'h00;
            
        endcase
    end
    
    // Sequential logic for state register, byre counter, outputs and LFSR
    always_ff @(posedge clk) begin
        // Active-low reset
        if (!reset_n) begin
            state_reg           <= IDLE;
            byte_index          <= 4'd0;
            lfsr                <= 4'b1101;     // non-zero starting point
            
        end else begin
            state_reg           <= state_next;
            
            case (state_reg)
            
                IDLE: begin
                    byte_index          <= '0;
                    lfsr                <= 4'b1101;
                    
                end
                
                SEND: begin                 
                    if (grant2) begin
                        // Shift LFSR
                        lfsr <= {lfsr[2:0], lfsr[3] ^ lfsr [2]};
                        
                        // Move to next byte after grant
                        if (byte_index != 4'd15) begin
                            byte_index      <= byte_index + 1;
                        end
                    end
                end  
                
                DONE: begin
                    byte_index      <= byte_index;
                    lfsr            <= lfsr;
                end
                    
                default: begin
                    byte_index      <= 4'd0;
                    lfsr            <= 4'b1011;
                end
            endcase
        end
    end
    
    // Next state FSM combinational logic
    always_comb begin
        data2   = 10'd0;
        req2    = 1'b0;
        state_next      = state_reg;
        
        if (state_reg == SEND && grant2 == 1'b0) begin
            data2   = {priority_bits, data};
            req2    = 1'b1;
        end
        
        case (state_reg)
        
            IDLE: begin
                state_next = SEND;
            end
            
            SEND: begin
                if (grant2 && (byte_index == 4'd15)) begin
                    state_next = DONE;
                end
            end
            
            DONE: begin
                state_next = DONE;
            end
            
            default: begin
                state_next = IDLE;
            end
        endcase
    end
    
endmodule
