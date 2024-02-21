// Author      	: ChongHao_Xu
// Description 	: 
//	
//
//
// 
// 
// 
//

`timescale 1ps/1ps
module LASER (
	input CLK,
	input RST,
	input [3:0] X,
	input [3:0] Y,
	output reg [3:0] C1X,
	output reg [3:0] C1Y,
	output reg [3:0] C2X,
	output reg [3:0] C2Y,
	output DONE
);




parameter State_Data_Read									= 0,
					State_Calculate_Cover 					= 1,
					State_Next_Circle 							= 2,
					State_Refresh_Max_Cover_Circle	= 3,
					State_Data_Out 									= 4;

reg [2:0] State;
reg [3:0] DATA [39:0][1:0]; // [n][0:x 1:y]
reg [3:0] CNT_X,CNT_Y;
reg [5:0] CNT;
reg [2:0] STEP_CNT;
reg [8:0] Calculate_REG;
reg [3:0] Distance1,Distance2,Distance3,Distance4;

//Select 
//0:C1 Replace
//1:C2 Replace
reg S;
wire [3:0] Set_Circle [1:0];
reg [4:0] Max_Cover,Cover;
reg [3:0] Max_Cover_X,Max_Cover_Y;
reg inC1,inC2;
reg [7:0] sqrd1,sqrd2,sqrd3,sqrd4;

assign Set_Circle[0] = S ? C1X:C2X;
assign Set_Circle[1] = S ? C1Y:C2Y;
assign DONE = State== State_Data_Out ? 1'b1:1'b0;

always@(posedge CLK or posedge RST)begin
	if(RST)begin
		State <= State_Data_Read;	
		S<=0;
		{CNT_Y,CNT_X} <= 0;
		CNT <= 0;
		STEP_CNT <= 0;
		{Cover,Max_Cover} <= 0;
		{C1X,C1Y,C2X,C2Y} <= 0;
		{Max_Cover_Y,Max_Cover_X} <= 0; 
	end
	else begin
		case(State)
	
			State_Data_Read								:begin
				if(CNT>=39) begin
					State <= State_Calculate_Cover;
					CNT <= 0;
				end
				else CNT <= CNT+1;
				DATA[CNT][0] <= X;
				DATA[CNT][1] <= Y;
			end
			
			
			
			State_Calculate_Cover 				:begin // 1 Frame 
				// CNT and Circle Calculate Cover
				//$display("Circle[%d %d][%d %d] STEP_CNT:%d",CNT_X,CNT_Y,Set_Circle[0],Set_Circle[1],STEP_CNT);
				if(CNT>=39)begin
					State <= State_Next_Circle;
					CNT <= 0;
				end
				else begin
					CNT <= CNT+1;
				end
				
				if(inC1||inC2)begin
					Cover <= Cover+1;
				end
			end
			
			
			
			State_Next_Circle 						:begin // 16*16 Frame 
				//$display("Cover:%d Circle[%d %d][%d %d]",Cover,CNT_X,CNT_Y,Set_Circle[0],Set_Circle[1]);
				//ReFresh
				if(Cover>=Max_Cover)begin
					Max_Cover <= Cover;
					Max_Cover_Y <= CNT_Y;
					Max_Cover_X <= CNT_X;
				end

				if(Cover<=3)begin
					if(CNT_Y==15 && (CNT_X+10)>15)begin
						State <= State_Refresh_Max_Cover_Circle;
						CNT_Y <= 0;
						CNT_X <= 0;
					end
					else if((CNT_X+10)>15)begin
						CNT_Y <= CNT_Y+1;
						CNT_X <= 0;
						State <= State_Calculate_Cover;
					end
					else begin
						CNT_X <= CNT_X+10;
						State <= State_Calculate_Cover;
					end
				end
				else if(Cover<=10)begin
					if(CNT_Y==15 && (CNT_X+7)>15)begin
						State <= State_Refresh_Max_Cover_Circle;
						CNT_Y <= 0;
						CNT_X <= 0;
					end
					else if((CNT_X+7)>15)begin
						CNT_Y <= CNT_Y+1;
						CNT_X <= 0;
						State <= State_Calculate_Cover;
					end
					else begin
						CNT_X <= CNT_X+7;
						State <= State_Calculate_Cover;
					end
				end
				else if(Cover<=20)begin
					if(CNT_Y==15 && (CNT_X+3)>15)begin
						State <= State_Refresh_Max_Cover_Circle;
						CNT_Y <= 0;
						CNT_X <= 0;
					end
					else if((CNT_X+3)>15)begin
						CNT_Y <= CNT_Y+1;
						CNT_X <= 0;
						State <= State_Calculate_Cover;
					end
					else begin
						CNT_X <= CNT_X+3;
						State <= State_Calculate_Cover;
					end
				end
				else begin
					{CNT_Y,CNT_X}<= &{CNT_Y,CNT_X} ? 0:{CNT_Y,CNT_X}+1 ;
					State <= &{CNT_Y,CNT_X} ? State_Refresh_Max_Cover_Circle : State_Calculate_Cover;
				end
				Cover<=0;
				//$display("set new circle[%d %d]",CNT_X,CNT_Y);
			end
			
			
			State_Refresh_Max_Cover_Circle 	:begin 
				if(  (S&&{Max_Cover_Y,Max_Cover_X}=={C2Y,C2X}) ||
				 			(~S&&{Max_Cover_Y,Max_Cover_X}=={C1Y,C1X}) ) State <= State_Data_Out;
				else begin 
					if(S) {C2Y,C2X} <= {Max_Cover_Y,Max_Cover_X};
					else {C1Y,C1X} <= {Max_Cover_Y,Max_Cover_X};
					State <= State_Calculate_Cover ; 
					//#1
					//$display("C%d Replace C:[%d %d][%d %d] Max_Cover:%d",S,C1X,C1Y,C2X,C2Y,Max_Cover);
				end
				{CNT_Y,CNT_X} <= 0;
				CNT <= 0;
				STEP_CNT <= 0;
				Cover<=0;
				S <= ~S;
			end
			
			
			State_Data_Out 								:begin 
				State <= State_Data_Read;	
				{CNT_Y,CNT_X} <= 0;
				S <= 0;
				CNT <= 0;
				STEP_CNT <= 0;
				{Cover,Max_Cover} <= 0;
				{C1X,C1Y,C2X,C2Y} <= 0;
				{Max_Cover_Y,Max_Cover_X} <= 0; 
			end
		endcase
	end
end




always@(*)begin
	if(State==State_Calculate_Cover)begin
		Distance1 = (CNT_X>DATA[CNT][0]) ? (CNT_X-DATA[CNT][0]):(DATA[CNT][0]-CNT_X);
		Distance2 = (CNT_Y>DATA[CNT][1]) ? (CNT_Y-DATA[CNT][1]):(DATA[CNT][1]-CNT_Y);	
		sqrd1 = Distance1*Distance1;
		sqrd2 = Distance2*Distance2;
		if( (sqrd1+sqrd2)<=16) inC1 = 1;
		else inC1 = 0;
		
		Distance3 = (Set_Circle[0]>DATA[CNT][0]) ? (Set_Circle[0]-DATA[CNT][0]):(DATA[CNT][0]-Set_Circle[0]);
		Distance4 = (Set_Circle[1]>DATA[CNT][1]) ? (Set_Circle[1]-DATA[CNT][1]):(DATA[CNT][1]-Set_Circle[1]);
		sqrd4 = Distance3*Distance3;
    sqrd3 = Distance4*Distance4;
		if( (sqrd3+sqrd4)<=16) inC2 = 1;
		else inC2 = 0;
	end
	else {Distance1,Distance2,inC1,inC2} = 0;
end

endmodule
