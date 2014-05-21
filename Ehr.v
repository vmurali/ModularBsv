module mkEHR(CLK, RST_N, r0, RDY_r0, w0_x, EN_w0, RDY_w0, r1, RDY_r1, w1_x, EN_w1, RDY_w1, r2, RDY_r2, w2_x, EN_w2, RDY_w2);
	parameter size = 1'b1;
	parameter init = 0;
	input CLK, RST_N, EN_w0, EN_w1, EN_w2;
	output RDY_r0, RDY_w0, RDY_r1, RDY_w1, RDY_r2, RDY_w2; 
	input [size-1:0] w0_x;
	input [size-1:0] w1_x;
	input [size-1:0] w2_x;
	output [size-1:0] r0;
	output [size-1:0] r1;
	output [size-1:0] r2;

	reg [size-1:0] d;
	assign RDY_r0 = 1;
	assign RDY_r1 = 1;
	assign RDY_r2 = 1;
	assign RDY_w0 = 1;
	assign RDY_w1 = 1;
	assign RDY_w2 = 1;
	assign r0 = d;
	assign r1 = EN_w0? w0_x: r0;
	assign r2 = EN_w1? w1_x: r1;

	always@(posedge CLK)
	begin
		if(!RST_N)
			d <= init;
		else
			if(EN_w2 == 1'b1)
				d <= w2_x;
			else if(EN_w1 == 1'b1)
				d <= w1_x;
			else if(EN_w0 == 1'b1)
				d <= w0_x;
	end
endmodule

module mkRegFile(CLK, RST_N, sub_x, sub, EN_sub, RDY_sub, upd_x, upd_y, EN_upd, RDY_upd);
	parameter size = 1'b1;
	parameter width = 1'b1;
	parameter file = "";
	input CLK, RST_N, EN_sub, EN_upd;
	output RDY_sub, RDY_upd;
	input [size-1:0] sub_x;
	input [size-1:0] upd_x;
	input [width-1:0] upd_y;
	output [width-1:0] sub;

	reg [width-1:0] d[0:(1<<size)-1];
	assign RDY_sub = 1;
	assign RDY_upd = 1;
	assign sub = d[sub_x];

	always@(posedge CLK)
	begin
		if(!RST_N)
      $readmemh(file, d, 0, (1<<size)-1);
		else
			if(EN_upd)
				d[upd_x] <= upd_y;
	end
endmodule
