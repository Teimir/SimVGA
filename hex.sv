module hex (
    input      [3:0] in ,
    input            clk, 
    output reg [6:0] out
);

    always_ff @(posedge clk) begin
        case (in)
            /* print a hexadecimal digit on the 7SEG display */
            4'd0:  out <= 7'b0111111;
            4'd1:  out <= 7'b0000110;
            4'd2:  out <= 7'b1011011;
            4'd3:  out <= 7'b1001111;
            4'd4:  out <= 7'b1100110;
            4'd5:  out <= 7'b1101101;
            4'd6:  out <= 7'b1111101;
            4'd7:  out <= 7'b0000111;
            4'd8:  out <= 7'b1111111;
            4'd9:  out <= 7'b1101111;
            4'd10: out <= 7'b1110111;
            4'd11: out <= 7'b1111100;
            4'd12: out <= 7'b0111001;
            4'd13: out <= 7'b1011110;
            4'd14: out <= 7'b1111011;
            4'd15: out <= 7'b1110001;
        endcase
    end

endmodule