// --------------------------------------------------------------------
// Copyright (c) 2007 by Terasic Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Terasic Technologies Inc
//                     356 Fu-Shin E. Rd Sec. 1. JhuBei City,
//                     HsinChu County, Taiwan
//                     302
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// --------------------------------------------------------------------
//
// Major Functions:	DE2 LTM module Timing control and output image data
//					form sdram 
//
// --------------------------------------------------------------------
//
// Revision History :
// --------------------------------------------------------------------
//   Ver  :| Author            		:| Mod. Date :| Changes Made:
//   V1.0 :| Johnny Fan				:| 07/06/30  :| Initial Revision
// --------------------------------------------------------------------

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
input			iCLK;   
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

always@(posedge iCLK or negedge iRST_n)
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

		else if (1*(x_cnt-250)*(x_cnt-250)+30*(y_cnt-165)*(y_cnt-165)>=1250 && 1*(x_cnt-250)*(x_cnt-250)+30*(y_cnt-165)*(y_cnt-165)<=2250)	// GOD_RING
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd255;
				oLCD_G <= 8'd255;
				oLCD_B <= 8'd0;
			end
		else if (5*(x_cnt-154)*(x_cnt-154)+1*(y_cnt-456)*(y_cnt-456)<=28)	// BONE
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd255;
				oLCD_G <= 8'd255;
				oLCD_B <= 8'd255;
			end
		else if (5*(x_cnt-154)*(x_cnt-154)+1*(y_cnt-457)*(y_cnt-457)<=140)	// ANKLE
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd255;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (4*(x_cnt-154)*(x_cnt-154)+1*(y_cnt-457)*(y_cnt-457)<=160)	// ANKLE_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (2*x_cnt+y_cnt>=735 && 2*x_cnt+y_cnt<=785 && -1*x_cnt+y_cnt<=79 && -1*x_cnt+y_cnt>=10)	// STICKMAN_LEFT_ARM
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (2*x_cnt+y_cnt>=735 && 2*x_cnt+y_cnt<=785 && -1*x_cnt+y_cnt<=79 && -1*x_cnt+y_cnt>=10)	// STICKMAN_LEFT_ARM
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (3*x_cnt+10*y_cnt>=3632 && 3*x_cnt+10*y_cnt<=3849 && ((x_cnt-287)*(x_cnt-287)+(y_cnt-285)*(y_cnt-285))<=4850)	// STICKMAN_LEFT_LOWER_ARM
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if ((x_cnt-250)*(x_cnt-250)+(y_cnt-215)*(y_cnt-215) <= 1250)	// draw circle: STICKMAN_HEAD
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (2*x_cnt + y_cnt <= 957 && 2*x_cnt + y_cnt >= 900 && -1*x_cnt + y_cnt <= 225 && -1*x_cnt + y_cnt >= 80) // draw quadrangle: STICKMAN_LEFT_LEG
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt >= 154 && x_cnt <= 244 && y_cnt >= 444 && y_cnt <= 469) // draw quadrangle: STICKMAN_LEFT_LOWER_LEG
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (-3*x_cnt+1*y_cnt<=-415 && -35*x_cnt+1*y_cnt>=-9500 && y_cnt<=360 && (x_cnt-254)*(x_cnt-254)+(y_cnt-314)*(y_cnt-314)<=3500)	// STICKMAN_BODY
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 46;
				oLCD_G <= 46;
				oLCD_B <= 46;
			end
		else if (-3*x_cnt+1*y_cnt<=-400 && -35*x_cnt+1*y_cnt>=-9650 && y_cnt<=360 && (x_cnt-254)*(x_cnt-254)+(y_cnt-314)*(y_cnt-314)<=4100)	// STICKMAN_BODY_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (3*x_cnt+10*y_cnt>=5370 && y_cnt<=462 && x_cnt<=413 && x_cnt>=355 && (!(x_cnt>=387 && y_cnt<=445))) // shoe
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd222;
				oLCD_G <= 8'd156;
				oLCD_B <= 8'd0;
			end
		else if (3*x_cnt+10*y_cnt>=5320 && y_cnt<=467 && x_cnt<=418 && x_cnt>=350 && (!(x_cnt>=392 && y_cnt<=440))) // shoe_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if ((x_cnt-600)*(x_cnt-600)-1250*(y_cnt-300)<=0 && (x_cnt-600)*(x_cnt-600)-800*(y_cnt-300)>=0 && x_cnt<=600) // GROUND
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd255;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt >= 260 && x_cnt <= 367 && y_cnt >= 360 && y_cnt <= 384) // draw quadrangle: STICKMAN_RIGHT_LEG
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (-20*x_cnt+y_cnt<=-6700 && -20*x_cnt+y_cnt>=-7200 && y_cnt<=462 && y_cnt>=372) // draw quadrangle: STICKMAN_RIGHT_LOWER_LEG
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if ((x_cnt-367)*(x_cnt-367)+(y_cnt-372)*(y_cnt-372) <= 135) // draw circle: STICKMAN_RIGHT_KNEE
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end

		else if (x_cnt>=524 && x_cnt<=529 && y_cnt<=260 && y_cnt >= 217) // draw circle: RPG_HEAD_MIDDLE_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (3*x_cnt+10*y_cnt>=3770 && 3*x_cnt+10*y_cnt<=4155 && -3*x_cnt+10*y_cnt>=610 && -3*x_cnt+10*y_cnt<=995 && x_cnt<=590 && x_cnt>=463)	// RPG_HEAD
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd86;
				oLCD_G <= 8'd96;
				oLCD_B <= 8'd71;
			end
		else if (3*x_cnt+10*y_cnt<=3855 && -3*x_cnt+10*y_cnt>=910 && x_cnt>=463 && y_cnt >= 200) // RPG_HEAD_T
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd86;
				oLCD_G <= 8'd96;
				oLCD_B <= 8'd71;
			end
		else if (3*x_cnt+10*y_cnt<=3905 && -3*x_cnt+10*y_cnt>=860 && x_cnt>=458 && y_cnt >= 200) // RPG_HEAD_T_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end	
		else if (3*x_cnt+10*y_cnt>=3720 && 3*x_cnt+10*y_cnt<=4205 && -3*x_cnt+10*y_cnt>=560 && -3*x_cnt+10*y_cnt<=1045 && x_cnt<=595 && x_cnt>=463)	// RPG_HEAD_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt>=311 && x_cnt<=374 && y_cnt>=228 && y_cnt<=249 && (!(x_cnt>=316 && y_cnt<=244)))	// RPG_BODY_SURFACE_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt>=374 && x_cnt<=458 && y_cnt>=233 && y_cnt<=244)	// RPG_part1
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd78;
				oLCD_G <= 8'd68;
				oLCD_B <= 8'd69;
			end
		else if (x_cnt>=255 && x_cnt<=369 && y_cnt>=228 && y_cnt<=249)	// RPG_part2
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd169;
				oLCD_G <= 8'd78;
				oLCD_B <= 8'd33;
			end
		else if (x_cnt>=240 && x_cnt<=255 && y_cnt>=233 && y_cnt<=244)	// RPG_part3
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd169;
				oLCD_G <= 8'd78;
				oLCD_B <= 8'd33;
			end
		else if (x_cnt>=197 && x_cnt<=235 && y_cnt>=233 && y_cnt<=244)	// RPG_part4
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd169;
				oLCD_G <= 8'd78;
				oLCD_B <= 8'd33;
			end
		else if (x_cnt>=145 && x_cnt<=193 && 2*x_cnt+10*y_cnt<=2825 && -2*x_cnt+10*y_cnt>=1945 && y_cnt >= 200) // RPG_part5
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd78;
				oLCD_G <= 8'd68;
				oLCD_B <= 8'd69;
			end
		
		else if (x_cnt>=384 && x_cnt<=416 && y_cnt >=249 && y_cnt<=302 && (!(x_cnt>=395 && y_cnt >=255)))	// RPG_part6
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd169;
				oLCD_G <= 8'd78;
				oLCD_B <= 8'd33;
			end
		else if (x_cnt>=379 && x_cnt<=421 && y_cnt >=244 && y_cnt<=307 && (!(x_cnt>=400 && y_cnt >=260))) // RPG_part6_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt>=326 && x_cnt<=384 && y_cnt >=249 && y_cnt<=291 && (!(x_cnt>=338 && y_cnt >=255)))	// RPG_part7
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd169;
				oLCD_G <= 8'd78;
				oLCD_B <= 8'd33;
			end
		else if (x_cnt>=321 && x_cnt<=384 && y_cnt >=244 && y_cnt<=296 && (!(x_cnt>=343 && y_cnt >=260))) // RPG_part7_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt>=140 && x_cnt<=198 && 2*x_cnt+10*y_cnt<=2875 && -2*x_cnt+10*y_cnt>=1895 && y_cnt >= 200) // RPG_part5_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt>=272 && x_cnt<=374 && y_cnt>=223 && y_cnt<=254)	// RPG-2_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (x_cnt>=192 && x_cnt<=463 && y_cnt>=228 && y_cnt<=249)	// RPG-L_SKETCH
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end

		else if (-1*x_cnt+20*y_cnt>=4832 && -1*x_cnt+20*y_cnt<=5209 && (x_cnt-330)*(x_cnt-330)+(y_cnt-255)*(y_cnt-255)<=7050)	// STICKMAN_RIGHT_ARM
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if ((x_cnt-265)*(x_cnt-265)+(y_cnt-372)*(y_cnt-372)<=255)	// STICKMAN_BOTTOM
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= 8'd0;
				oLCD_G <= 8'd0;
				oLCD_B <= 8'd0;
			end
		else if (-1*(x_cnt-840)*(x_cnt-840)+3*(y_cnt-240)*(y_cnt-240)>=5250) // LIGHT
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= (x_cnt<=255)? x_cnt : 511-x_cnt+read_red-255;
				oLCD_G <= (y_cnt<=255)? y_cnt : 511-y_cnt+read_green-255;
				oLCD_B <= (y_cnt<=255)? y_cnt : 511-y_cnt+read_blue-255;
			end

		else if (x_cnt >= 46 && x_cnt <= 845 && y_cnt >= 23 && y_cnt<=502)	// draw rectangular box: BACKGROUND
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= (x_cnt[2]) ? 511-read_red : read_red;
				oLCD_G <= 8'd255;
				oLCD_B <= 2*x_cnt[1]+ y_cnt[2] ? 255-read_blue : read_blue;
			end
			
		else
			begin
				oHD	<= mhd;
				oVD	<= mvd;
				oDEN <= mden;
				oLCD_R <= read_red;
				oLCD_G <= read_green;
				oLCD_B <= read_blue;
			end
	end
				
endmodule
