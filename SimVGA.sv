module SimVGA(
	input           clk,
	input           rst,
	output [2:0]    RGB, 
	output [1:0]    HVsync,
	output [3:0]    leds,
	inout ps_clk,
	inout ps_data,
	output [3:0] DIG,
	output [6:0] code
);

wire [9:0] HVpos [2];
wire display_on;
wire clk25;
wire [2:0]    RGBw;

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
    .vpos(HVpos[1])
);

 ps2 u1(
	.clk(clk)           ,
	.rst_n(1)         ,
	.ps2_clk(ps_clk)       ,
	.ps2_data(ps_data)      ,	//data sent from the keyboard
	.DIG(DIG)           ,
    .code(code)           
);

reg [2:0] charf [4800];
logic sel;
logic [2:0] out;
logic [2:0] in;
wire [7:0] xcord, ycord; 
reg [31:0] cnt;
logic wr = 0;


//закрашивалка
always_ff @( posedge clk ) begin
	wr <= '0;
	if (cnt >= 32'd50_000_000) begin
		wr <= '1;
		if (xcord == 8'd80) begin
			xcord <= 8'd0;
			if (ycord == 8'd60) begin
				ycord <= 8'd0;
			end
			else ycord <= ycord + 8'd1;
		end
		else xcord <= xcord + 8'd1;
	end
	else cnt <= cnt + 32'd1;
end

//Олвейс для видеопамяти
always_ff @(posedge clk) begin
	if (wr) begin
		charf[{xcord, ycord}] <= sel ? in : 3'd0;
	end
	out <= charf[{HVpos[0]>>3, HVpos[1]>>3}];
end


//Генератор флага
always_comb begin
	in = 3'b000;
	if (ycord < 20) in = 3'b111;
	else if (ycord <= 20*2) in = 3'b001;
	else if (ycord > 20*2) in = 3'b100;
end



assign sel = rst;
assign leds[0] = !RGB[0];
assign leds[1] = !RGB[1];
assign leds[2] = !RGB[2];
assign leds[3] = !display_on;
assign RGB = display_on ? out : 0;

endmodule