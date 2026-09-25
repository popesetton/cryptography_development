
// Module name: IP Encryption Data Generator
// Description: Generates plaintext to be encrypted in XTEA module
module ip_enc_generator(input logic             clk,
                        input logic             reset_n,
                        input logic             grant1,
                        output logic [9:0]      data1,
                        output logic            req1
                        );
                        
    // Define FSM for enc generator
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
    
    // Hard-coded plaintext ROM
    // Plaintext: A5A5A5A5 01234567 FEDCBA98 5A5A5A5A
    always_comb begin
        case (byte_index)
            4'd0:  data = 8'hA5;
            4'd1:  data = 8'hA5;
            4'd2:  data = 8'hA5;
            4'd3:  data = 8'hA5;
            
            4'd4:  data = 8'h01;
            4'd5:  data = 8'h23;
            4'd6:  data = 8'h45;
            4'd7:  data = 8'h67;
            
            4'd8:  data = 8'hFE;
            4'd9:  data = 8'hDC;
            4'd10: data = 8'hBA;
            4'd11: data = 8'h98;
            
            4'd12: data = 8'h5A;
            4'd13: data = 8'h5A;
            4'd14: data = 8'h5A;
            4'd15: data = 8'h5A;
            
            default: data = 8'h00;
            
        endcase
    end
    
    // Sequential logic for state register, byre counter, outputs and LFSR
    always_ff @(posedge clk) begin
        // Reset high
        if (!reset_n) begin
            state_reg           <= IDLE;
            byte_index          <= 4'd0;
            lfsr                <= 4'b1011;     // non-zero starting point
            
        end else begin
            state_reg           <= state_next;
            
            case (state_reg)
            
                IDLE: begin
                    byte_index          <= '0;
                    lfsr                <= 4'b1011;

                end
                
                SEND: begin
                    if (grant1) begin
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
        data1   = 10'd0;
        req1    = 1'b0;         
        state_next      = state_reg;
        
        // Only request when waiting for grant
        if (state_reg == SEND && grant1 == 1'b0) begin
            data1   = {priority_bits, data};
            req1    = 1'b1;
        end
        
        case (state_reg)
        
            IDLE: begin
                state_next = SEND;
            end
            
            SEND: begin
                if (grant1 && (byte_index == 4'd15)) begin
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
