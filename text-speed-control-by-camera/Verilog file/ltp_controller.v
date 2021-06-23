module ltp_controller(
						iCLK, 				// LCD display clock
						iRST_n, 			// systen reset
						// SDRAM SIDE 
						iREAD_DATA1, 		// R and G  color data form sdram 	
						iREAD_DATA2,		// B color data form sdram
						oREAD_SDRAM_EN,		// read sdram data control signal
						//LCD SIDE
						oHD,				// LCD Horizontal sync 
						oVD,				// LCD Vertical sync 	
						oDEN,				// LCD Data Enable
						oLCD_R,				// LCD Red color data 
						oLCD_G,             // LCD Green color data  
						oLCD_B,             // LCD Blue color data  
						oSEG_R,			// for seven segment R component
						oSEG_G,			// for seven segment G component
						oSEG_B,			// for seven segment B component
						iclk_sec,
						iclk_100ms,
						iclk_10ms,
						iclk_1ms
						);

//============================================================================
// PARAMETER declarations
//============================================================================
parameter H_LINE = 1056; 
parameter V_LINE = 525;
parameter Hsync_Blank = 46;   //H_SYNC + H_Back_Porch
parameter Hsync_Front_Porch = 210;
parameter Vertical_Back_Porch = 23; //V_SYNC + V_BACK_PORCH
parameter Vertical_Front_Porch = 22;
//===========================================================================
// PORT declarations
//===========================================================================
input			iCLK,iclk_sec,iclk_100ms,iclk_10ms,iclk_1ms;   

input			iRST_n;
input	[15:0]	iREAD_DATA1;
input	[15:0]	iREAD_DATA2;
output			oREAD_SDRAM_EN;
output	[7:0]	oLCD_R;		
output  [7:0]	oLCD_G;
output  [7:0]	oLCD_B;
output			oHD;
output			oVD;
output			oDEN;
output reg [7:0]	oSEG_R;	// for seven segment R component
output reg [7:0]	oSEG_G;	// for seven segment G component
output reg [7:0]	oSEG_B;	// for seven segment B component

//=============================================================================
// REG/WIRE declarations
//=============================================================================
reg		[10:0]  x_cnt;  
reg		[9:0]	y_cnt; 
wire	[7:0]	read_red;
wire	[7:0]	read_green;
wire	[7:0]	read_blue; 
wire			display_area;
wire			oREAD_SDRAM_EN;
reg				mhd;
reg				mvd;
reg				mden;
reg				oHD;
reg				oVD;
reg				oDEN;
reg		[7:0]	oLCD_R;
reg		[7:0]	oLCD_G;	
reg		[7:0]	oLCD_B;

reg [10:0] x_pos_run = 11'd845;
integer run_left_edge = 1150;
integer speed = 2;

reg	[10:0]	x0 =446; 	//  define (x0, y0) point
reg	[9:0]		y0 = 263; 	//  define (x0, y0) point
reg	[7:0]		rpoint_R, rpoint_G, rpoint_B; // for seven segment

reg	[10:0]	color_x0 =800; 	//  define (color_x0, color_y0) point
reg	[9:0]		color_y0 = 50; 	//  define (color_x0, color_y0) point

reg	[20:0]	num_face,num_skin1,num_skin2;// count point numbers corresponding to the condition
reg	[1:0]		result_man_mask;	// 0X:no man; 10:man without mask; 11: man with mask

reg poss1 = 1'b0;
//reg poss2 = 1'b0;

wire clk_sec_edge;
reg [2:0] clk_sec_dly;
assign clk_sec_edge = (clk_sec_dly[2] && !clk_sec_dly[1]) ? 1'b1:1'b0;

//assign	draw_aim = (x_cnt>color_x0+ 1 && x_cnt<color_x0+20 && y_cnt>color_y0- 1 && y_cnt<color_y0+ 1) 
//				  || (x_cnt>color_x0-20 && x_cnt<color_x0- 1 && y_cnt>color_y0- 1 && y_cnt<color_y0+ 1)
//				  || (x_cnt>color_x0- 1 && x_cnt<color_x0+ 1 && y_cnt>color_y0+ 1 && y_cnt<color_y0+20)
//				  || (x_cnt>color_x0- 1 && x_cnt<color_x0+ 1 && y_cnt>color_y0-20 && y_cnt<color_y0- 1)
//				?	1'b1 : 1'b0;

//判斷完後的圈圈及叉叉				

assign btrect = x_cnt >= 46 && x_cnt <= 845 && y_cnt >= 350 && y_cnt<=502;
assign sur_btrect = x_cnt >= 44 && x_cnt <= 847 && y_cnt >= 348 && y_cnt<=504;
//assign right_rect = x_cnt >= 46 && x_cnt <= 246 && y_cnt >= 350 && y_cnt<=502; 
//assign sur_right_rect = x_cnt >= 44 && x_cnt <= 248 && y_cnt >= 348 && y_cnt<=504; 

//assign cent_rect = x_cnt >= 346 && x_cnt <= 546 && y_cnt >= 187 && y_cnt<=377; 					
//assign sur_cent_rect = x_cnt >= 344 && x_cnt <= 548 && y_cnt >= 185 && y_cnt<=341; 					

//判斷臉及口罩的範圍	verilog沒有小數所以要正規化取
//老師講義口罩接近皮膚有差，自己在正規

assign	if_skin1_color = (8*read_red > 10*read_green) && (8*read_red < 16*read_green)
							&& (8*read_blue > 7*read_green) && (8*read_blue < 10*read_green)
							? 1'b1:1'b0;

//=============================================================================
// Structural coding
//=============================================================================

// This signal control reading data form SDRAM , if high read color data form sdram  .
assign	oREAD_SDRAM_EN = (	(x_cnt>Hsync_Blank-2)&& //214
							(x_cnt<(H_LINE-Hsync_Front_Porch-1))&& //1015
							(y_cnt>(Vertical_Back_Porch-1))&& // //34
							(y_cnt<(V_LINE - Vertical_Front_Porch)) //515
						 )?  1'b1 : 1'b0;
						
// This signal indicate the lcd display area .
assign	display_area = ((x_cnt>(Hsync_Blank-1)&& //>215
						(x_cnt<(H_LINE-Hsync_Front_Porch))&& //< 1016
						(y_cnt>(Vertical_Back_Porch-1))&& 
						(y_cnt<(V_LINE - Vertical_Front_Porch-1))
						))  ? 1'b1 : 1'b0;

assign	read_red 	= display_area ? iREAD_DATA2[9:2] : 8'b0;
assign	read_green 	= display_area ? {iREAD_DATA1[14:10],iREAD_DATA2[14:12]}: 8'b0;
assign	read_blue 	= display_area ? iREAD_DATA1[9:2] : 8'b0;	

///////////////////////// x  y counter  and lcd hd generator //////////////////
always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
		begin
			x_cnt <= 11'd0;	
			mhd  <= 1'd0;  	
		end	
		else if (x_cnt == (H_LINE-1))
		begin
			x_cnt <= 11'd0;
			mhd  <= 1'd0;
		end	   
		else
		begin
			x_cnt <= x_cnt + 11'd1;
			mhd  <= 1'd1;
		end	
	end

always@(posedge iCLK or negedge iRST_n)
	begin
		if (!iRST_n)
			y_cnt <= 10'd0;
		else if (x_cnt == (H_LINE-1))
		begin
			if (y_cnt == (V_LINE-1))
				y_cnt <= 10'd0;
			else
				y_cnt <= y_cnt + 10'd1;	
		end
	end
////////////////////////////// touch panel timing //////////////////	
always@(posedge iCLK  or negedge iRST_n)
	begin
		if (!iRST_n)
			mvd  <= 1'b1;
		else if (y_cnt == 10'd0)
			mvd  <= 1'b0;
		else
			mvd  <= 1'b1;
	end

always@(posedge iCLK  or negedge iRST_n)
	begin
		if (!iRST_n)
			mden  <= 1'b0;
		else if (display_area)
			mden  <= 1'b1;
		else
			mden  <= 1'b0;
	end
	
// RGB值送出module外	
always@(negedge mvd)		// when y_cnt == 0, mvd = 0, else mvd = 1, show data
	begin
		oSEG_R<= rpoint_R;
		oSEG_G<= rpoint_G;
		oSEG_B<= rpoint_B;
	end
	
 always@(posedge iCLK or negedge iRST_n )
 	begin
 		if (!iRST_n)
 			begin
 				oHD	<= 1'd0;
 				oVD	<= 1'd0;
 				oDEN <= 1'd0;
 				oLCD_R <= 8'd0;
 				oLCD_G <= 8'd0;
 				oLCD_B <= 8'd0;
 			end

		else if (win(x_pos_run,512'd263)); //CONGRATULATIONS
		else if (score(speed/100,(speed%100)/10,(speed%100)%10)); //SCORE: XXX

		else if (x_cnt==x0 && y_cnt==y0)		// save the data 讀到螢幕中心的時候把值送出去
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= read_red;
				oLCD_G <= read_green;
				oLCD_B <= read_blue;
				rpoint_R <= read_red;			
				rpoint_G <= read_green;
				rpoint_B <= read_blue;
			end
		
		else if (if_skin1_color && btrect)		// left skin color
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd255;
				oLCD_G <= 8'd255;
				oLCD_B <= 8'd255;
			end
//		else if (if_skin2_color && right_rect)		// right skin color
//			begin
//				oHD	<= mhd;
//				oVD	<= mvd;
//				oDEN <= mden;
//				oLCD_R <= 8'd255;
//				oLCD_G <= 8'd255;
//				oLCD_B <= 8'd255;
//			end

			
		else if (btrect)		// left
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= read_red;
 				oLCD_G <= read_green;
 				oLCD_B <= read_blue;		
			end
//		else if (right_rect)		// right
//			begin
//				oHD	<= mhd;
//				oVD	<= mvd;
//				oDEN <= mden;
//				oLCD_R <= read_red;
// 				oLCD_G <= read_green;
// 				oLCD_B <= read_blue;		
//			end
		else if (sur_btrect)		// sur left
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 0;
				oLCD_G <= 0;
				oLCD_B <= 0;	
			end

		else if (x_cnt==color_x0 && y_cnt==color_y0)		// save the data
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= read_red;
				oLCD_G <= read_green;
				oLCD_B <= read_blue;
				rpoint_R <= read_red;			
				rpoint_G <= read_green;
				rpoint_B <= read_blue;
			end

 		else
 			begin
 				oHD	<= mhd;
 				oVD	<= mvd;
 				oDEN <= mden;
 				oLCD_R <= read_red;//預設的地方，把不是臉的地方調暗50%加上˙:7
 				oLCD_G <= read_green;
 				oLCD_B <= read_blue;
 			end		
 	end	

always@(posedge iCLK) // ...or negedge iRST_n
begin
 clk_sec_dly <= {clk_sec_dly[1:0], iclk_10ms};
  if(clk_sec_edge)
  begin
   if(poss1 == 1'b1)
	begin
	if(x_pos_run>=run_left_edge)
    x_pos_run <= x_pos_run-run_left_edge;
	else
    x_pos_run <= x_pos_run + speed;
	end
  end
end
	
function [0:0] SEG16;			//	   ──[0]── ──[1]──  
	input [15:0] light_up;		//	  |  ╲    |    ╱  | 
	input [11:0] x_pos;			//	 [2] [3] [4] [5] [6]
	input [10:0]  y_pos;		//	  |    ╲  |  ╱    | 
	input [7:0]color_r;			//	   ──[7]── ──[8]──    <= [bit of light_up]
	input [7:0]color_g;			//	  |    ╱  |  ╲    | 
	input [7:0]color_b;			//	 [9][10][11][12][13] 
								//	  |  ╱    |    ╲  | 
	begin						//	   ─[14]── ──[15]─  
		if(
			(light_up[0] && ((100*(y_cnt-y_pos)+7260<=4030 && 100 *(y_cnt-y_pos)+7260>=3230 && 1000 *(y_cnt-y_pos-46)+72600>=-1850 *(x_cnt-x_pos)-17400 && 1000 *(y_cnt-y_pos-89)+72600<=-1850 *(x_cnt-x_pos)-17400 && 1000 *(y_cnt-y_pos-30)+72600<=1275 *(x_cnt-x_pos)+10600 && 1000 *(y_cnt-y_pos-1)+72600>=1275 *(x_cnt-x_pos)+10600)|| //block 1- shift by block 5
			(100 *(y_cnt-y_pos)+7260<=4030 && 100 *(y_cnt-y_pos)+7260>=3230 && 1000 *(y_cnt-y_pos-46)+72600<=-1850 *(x_cnt-x_pos)-17400 && 1000 *(y_cnt-y_pos+5)<=8000 *(x_cnt-x_pos)))) //block 1- Triangle
			||(light_up[1] && 100*(y_cnt-y_pos)>=-4030 && 100 *(y_cnt-y_pos)<=-400 && 100 *(y_cnt-y_pos)<=-3230 && 1000 *(y_cnt-y_pos+89)>=-1850 *(x_cnt-x_pos) && 1000 *(y_cnt-y_pos+46)<=-1850 *(x_cnt-x_pos) && 1000 *(y_cnt-y_pos+1)<=1275 *(x_cnt-x_pos) && 1000 *(y_cnt-y_pos-5)>=8000 *(x_cnt-x_pos)) //block2
			||(light_up[2] && 1000*(y_cnt-y_pos-226)<=8000*(x_cnt-x_pos)-391920 && 1000*(y_cnt-y_pos-166)>=8000*(x_cnt-x_pos)-391920 && 1000*(y_cnt-y_pos+89)>=-1850*(x_cnt-x_pos) +89984 && 1000*(y_cnt-y_pos+46)<=-1850*(x_cnt-x_pos) +89984 && 1000*(y_cnt-y_pos-30)<=1275*(x_cnt-x_pos)-62106 && 1000*(y_cnt-y_pos-1)>=1275*(x_cnt-x_pos)-62106 ) //block7- shift by block 11
			||(light_up[3] && 100*(y_cnt-y_pos)<=-510 && 100*(y_cnt-y_pos)>=-3120 && 1000*(y_cnt-y_pos+40)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+156)>=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+9)>=-1850*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-9)<=-1850*(x_cnt-x_pos)) //block13
			||(light_up[4] && 1000*(y_cnt-y_pos-226)<=8000*(x_cnt-x_pos)-195960 && 1000*(y_cnt-y_pos-166)>=8000*(x_cnt-x_pos)-195960 && 1000*(y_cnt-y_pos+89)>=-1850*(x_cnt-x_pos) +44992 && 1000*(y_cnt-y_pos+46)<=-1850*(x_cnt-x_pos)+44992 && 1000 *(y_cnt-y_pos-30)<=1275*(x_cnt-x_pos)-31008 && 1000*(y_cnt-y_pos-1)>=1275*(x_cnt-x_pos)-31008 ) //block 9- shift by block 11
			||(light_up[5] && 100*(y_cnt-y_pos)<=-510 && 100*(y_cnt-y_pos)>=-3120 && 1000*(y_cnt-y_pos-156)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-40)>=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-7)<=1275*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+7)>=1275*(x_cnt-x_pos)) //block14
			||(light_up[6] && 1000*(y_cnt-y_pos-226)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-166)>=8000 *(x_cnt-x_pos) && 1000*(y_cnt-y_pos+89)>=-1850 *(x_cnt-x_pos) && 1000*(y_cnt-y_pos+46)<=-1850*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-30)<=1275 *(x_cnt-x_pos) && 1000*(y_cnt-y_pos-1)>=1275*(x_cnt-x_pos)) //block11
			||(light_up[7] && 100*(y_cnt-y_pos)+3630<=4030 && 100 *(y_cnt-y_pos)+3630>=3230 && 1000*(y_cnt-y_pos-46)+36300>=-1850*(x_cnt-x_pos)-8700 && 1000*(y_cnt-y_pos-89)+36300<=-1850*(x_cnt-x_pos)-8700 && 1000*(y_cnt-y_pos-30)+36300<=1275 *(x_cnt-x_pos)+5300 && 1000 *(y_cnt-y_pos-1)+36300>=1275 *(x_cnt-x_pos)+5300) //block 3- shift by block 5
			||(light_up[8] && 100*(y_cnt-y_pos)-3630>=-4030 && 100 *(y_cnt-y_pos)-3630<=-3230 && 1000*(y_cnt-y_pos+89)-36300>=-1850*(x_cnt-x_pos)+8700 && 1000*(y_cnt-y_pos+46)-36300<=-1850*(x_cnt-x_pos)+8700 && 1000*(y_cnt-y_pos+1)-36300<=1275*(x_cnt-x_pos)-5300 && 1000*(y_cnt-y_pos+30)-36300>=1275*(x_cnt-x_pos)-5300) //block 4- shift by block 2
			||(light_up[9] && 1000*(y_cnt-y_pos+166)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+226)>=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-46)>=-1850 *(x_cnt-x_pos) && 1000*(y_cnt-y_pos-89)<=-1850*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+1)<=1275*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+30)>=1275*(x_cnt-x_pos)) //block8
			||(light_up[10] && 100*(y_cnt-y_pos)<=3120 && 100*(y_cnt-y_pos)>=510 && 1000*(y_cnt-y_pos+40)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+156)>=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-7)<=1275*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+7)>=1275*(x_cnt-x_pos)) //block15
			||(light_up[11] && 1000*(y_cnt-y_pos+166)<=8000*(x_cnt-x_pos)+195960 && 1000*(y_cnt-y_pos+226)>=8000*(x_cnt-x_pos)+195960 && 1000*(y_cnt-y_pos-46)>=-1850*(x_cnt-x_pos) -44992 && 1000*(y_cnt-y_pos-89)<=-1850*(x_cnt-x_pos)-44992 && 1000 *(y_cnt-y_pos+1)<=1275*(x_cnt-x_pos)+31008 && 1000*(y_cnt-y_pos+30)>=1275*(x_cnt-x_pos)+31008 ) //block 10- shift by block 8
			||(light_up[12] && 100*(y_cnt-y_pos)<=3120 && 100*(y_cnt-y_pos)>=510 && 1000*(y_cnt-y_pos-156)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-40)>=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+9)>=-1850*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-9)<=-1850*(x_cnt-x_pos)) //block16
			||(light_up[13] && 1000*(y_cnt-y_pos+166)<=8000*(x_cnt-x_pos)+391920 && 1000*(y_cnt-y_pos+226)>=8000*(x_cnt-x_pos)+391920 && 1000*(y_cnt-y_pos-46)>=-1850*(x_cnt-x_pos) -89984 && 1000*(y_cnt-y_pos-89)<=-1850*(x_cnt-x_pos)-89984 && 1000*(y_cnt-y_pos+1)<=1275*(x_cnt-x_pos)+62106 && 1000*(y_cnt-y_pos+30)>=1275*(x_cnt-x_pos)+62106 ) //block 12- shift by block 8
			||(light_up[14] && 100*(y_cnt-y_pos)<=4030 && 100 *(y_cnt-y_pos)>=3230 && 1000*(y_cnt-y_pos-46)>=-1850 *(x_cnt-x_pos) && 1000*(y_cnt-y_pos-89)<=-1850*(x_cnt-x_pos) && 1000*(y_cnt-y_pos+5)<=8000*(x_cnt-x_pos) && 1000*(y_cnt-y_pos-1)>=1275*(x_cnt-x_pos)) //block 5
			||(light_up[15] && ((100*(y_cnt-y_pos)-7260>=-4030 && 100 *(y_cnt-y_pos)-7260<=-3230 && 1000 *(y_cnt-y_pos+89)-72600>=-1850 *(x_cnt-x_pos)+17400 &&  1000 *(y_cnt-y_pos+46)-72600<=-1850*(x_cnt-x_pos)+17400 && 1000*(y_cnt-y_pos+1)-72600<=1275*(x_cnt-x_pos)-10600 && 1000*(y_cnt-y_pos+30)-72600>=1275*(x_cnt-x_pos)-10600)|| //block 6- shift by block 2
			(100 *(y_cnt-y_pos)-7260>=-4030 && 100 *(y_cnt-y_pos)-7260<=-3230 && 1000*(y_cnt-y_pos+46)-72600>=-1850 *(x_cnt-x_pos)+17400 && 1000 *(y_cnt-y_pos-5)>=8000 *(x_cnt-x_pos)))) //block 6-2- Triangle
			)
			begin
				SEG16 = 1'b1;
				oHD	= mhd;
				oVD	= mvd;
				oDEN = mden;
				oLCD_R = color_r;
				oLCD_G = color_g;
				oLCD_B = color_b;
			end
		else
			SEG16 = 1'b0;
	end
endfunction

function [0:0] win;
	input [10:0] x_pos;
	input [9:0]  y_pos;

	begin
		if ((SEG16(16'b1100001000000111,x_pos_correction(x_pos+67*14),y_pos,8'd255,8'd0  ,8'd0  ))|| //C
			(SEG16(16'b1110001001000111,x_pos_correction(x_pos+67*13),y_pos,8'd255,8'd102,8'd0  ))|| //O
			(SEG16(16'b0011001001001100,x_pos_correction(x_pos+67*12),y_pos,8'd255,8'd204,8'd0  ))|| //N
			(SEG16(16'b1110001100000111,x_pos_correction(x_pos+67*11),y_pos,8'd204,8'd255,8'd0  ))|| //G
			(SEG16(16'b0001001111000111,x_pos_correction(x_pos+67*10),y_pos,8'd102,8'd255,8'd0  ))|| //R
			(SEG16(16'b0010001111000111,x_pos_correction(x_pos+67* 9),y_pos,8'd0  ,8'd255,8'd0  ))|| //A
			(SEG16(16'b0000100000010011,x_pos_correction(x_pos+67* 8),y_pos,8'd0  ,8'd255,8'd102))|| //T
			(SEG16(16'b1110001001000100,x_pos_correction(x_pos+67* 7),y_pos,8'd0  ,8'd255,8'd204))|| //U
			(SEG16(16'b1100001000000100,x_pos_correction(x_pos+67* 6),y_pos,8'd0  ,8'd204,8'd255))|| //L
			(SEG16(16'b0010001111000111,x_pos_correction(x_pos+67* 5),y_pos,8'd0  ,8'd102,8'd255))|| //A
			(SEG16(16'b0000100000010011,x_pos_correction(x_pos+67* 4),y_pos,8'd0  ,8'd0  ,8'd255))|| //T
			(SEG16(16'b1100100000010011,x_pos_correction(x_pos+67* 3),y_pos,8'd102,8'd0  ,8'd255))|| //I
			(SEG16(16'b1110001001000111,x_pos_correction(x_pos+67* 2),y_pos,8'd204,8'd0  ,8'd255))|| //O
			(SEG16(16'b0011001001001100,x_pos_correction(x_pos+67* 1),y_pos,8'd255,8'd0  ,8'd204))|| //N
			(SEG16(16'b1110000110000111,x_pos_correction(x_pos+67* 0),y_pos,8'd255,8'd0  ,8'd102))   //S
			)
			win=1'b1;
		else
			win=1'b0;
	end
endfunction

function [11:0] x_pos_correction;
 input [11:0] x_pos;
 begin
  if(x_pos >= run_left_edge)
   x_pos_correction = x_pos-run_left_edge;
  else
   x_pos_correction =  x_pos;
 end
endfunction

function [0:0] number; // number 0~9
	input [4:0] num;
	input [10:0] x_pos;
	input [9:0]  y_pos;
	input [7:0]color_r;
	input [7:0]color_g;
	input [7:0]color_b;
	begin
		if(num=='d0)
			number=SEG16(16'b1110011001100111,x_pos,y_pos,color_r,color_g,color_b); //0
		else if(num=='d1)
			number=SEG16(16'b0010000001100000,x_pos,y_pos,color_r,color_g,color_b); //1
		else if(num=='d2)
			number=SEG16(16'b1100001111000011,x_pos,y_pos,color_r,color_g,color_b); //2
		else if(num=='d3)
			number=SEG16(16'b1110000101000011,x_pos,y_pos,color_r,color_g,color_b); //3
		else if(num=='d4)
			number=SEG16(16'b0010000111000100,x_pos,y_pos,color_r,color_g,color_b); //4
		else if(num=='d5)
			number=SEG16(16'b1110000110000111,x_pos,y_pos,color_r,color_g,color_b); //5
		else if(num=='d6)
			number=SEG16(16'b1110001110000101,x_pos,y_pos,color_r,color_g,color_b); //6
		else if(num=='d7)
			number=SEG16(16'b0010000001000011,x_pos,y_pos,color_r,color_g,color_b); //7
		else if(num=='d8)
			number=SEG16(16'b1110001111000111,x_pos,y_pos,color_r,color_g,color_b); //8
		else if(num=='d9)
			number=SEG16(16'b1010000111000111,x_pos,y_pos,color_r,color_g,color_b); //9
		else
			number=1'b0;
	end
endfunction

function [0:0] score;
	input [4:0] num_100;
	input [4:0] num_10;
	input [4:0] num_1;
	begin
		if 	 ((SEG16(16'b1110000110000111,1024'd766,512'd119,8'd255,8'd51 ,8'd153)) //S
			||(SEG16(16'b0000001111000111,1024'd686,512'd119,8'd255,8'd51 ,8'd153)) //P
			||(SEG16(16'b1100001110000111,1024'd606,512'd119,8'd255,8'd51 ,8'd153)) //E
			||(SEG16(16'b1100001110000111,1024'd526,512'd119,8'd255,8'd51 ,8'd153)) //E
			||(SEG16(16'b1110100001010011,1024'd446,512'd119,8'd255,8'd51 ,8'd153)) //D
			||(SEG16(16'b0001010000101000,1024'd366,512'd119,8'd255,8'd255,8'd255)) //x
			||(number(num_100,'d286,'d119,'d0,'d255,'d255))
			||(number(num_10,'d206,'d119,'d0,'d255,'d255))
			||(number(num_1,'d126,'d119,'d0,'d255,'d255))
			)
			score=1'b1;
		else
			score=1'b0;
	end
endfunction

//在外判斷再帶回畫出1
always@(posedge iCLK)
	begin
				if (!iRST_n)//left
					begin
						num_skin1	<= 20'd0; 		
					end	
				else if (y_cnt == (V_LINE-1))		// 畫面結束,分類結果
					begin
						if (num_skin1 > 90000)  
							begin
								poss1 <= 1'b1;
								speed <= 2 + num_skin1/1000 ;
							end
						
						else if (num_skin1 < 1000)
							begin
								poss1 <= 1'b0;
								speed <= 0;
							end
						else if (num_skin1 > 1000 && num_skin1 < 90000)
							begin
								if(speed != 2)
									speed <= num_skin1/10000;
							end
					end

				else if (y_cnt == 0)			// 畫面開始顯全部清為0
					begin
						num_skin1	<= 20'd0;
					end
				else if (if_skin1_color && btrect)			//計數 符合定義就加1
					begin
						num_skin1 <= num_skin1 + 1;
					end
	end
endmodule
