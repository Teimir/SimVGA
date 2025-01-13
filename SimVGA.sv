module SimVGA(
	input           clk,
	input           rst,
	output [2:0]    RGB,
	output [1:0]    HVsync,
	output [3:0]    leds
);

wire [9:0] HVpos [2];
wire video_on;
wire clk25;

PLL_clk10MHz U0(
.inclk0(clk),
.c0(clk25)
);

vga u0
(
    .clk(clk25),
    .rst(0),
    .hsync(HVsync[0]),
    .vsync(HVsync[1]),
    .display_on(display_on),
    .hpos(HVpos[0]),
    .vpos(HVpos[1]),
);


always_comb begin
	if (display_on) begin
		RGB[0] = HVpos[0] > 10'd320 ? 1 : 0;
		RGB[1] = HVpos[0] > 10'd320 ? 1 : 0;
		RGB[2] = HVpos[0] > 10'd320 ? 1 : 0;
		end
	else RGB = 3'd0;
end


assign leds[0] = !RGB[0];
assign leds[1] = !RGB[1];
assign leds[2] = !RGB[2];
assign leds[3] = !video_on;
endmodule