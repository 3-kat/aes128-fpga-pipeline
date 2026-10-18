`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 03:25:00 PM
// Design Name: 
// Module Name: myip_axi_slave_stream_v1_0_S00_AXIS
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module myip_axi_slave_stream_v1_0_S00_AXIS #
(
// Users to add parameters here

// User parameters ends
// Do not modify the parameters beyond this line

// AXI4Stream sink: Data Width
parameter integer C_S_AXIS_TDATA_WIDTH = 64
)
(
// Users to add ports here

// User ports ends
// Do not modify the ports beyond this line

// AXI4Stream sink: Clock
input wire  S_AXIS_ACLK,
// AXI4Stream sink: Reset
input wire  S_AXIS_ARESETN,
// Ready to accept data in
output wire  S_AXIS_TREADY,
// Data in
input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
// Byte qualifier
input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
// Indicates boundary of last packet
input wire  S_AXIS_TLAST,
// Data is in valid
input wire  S_AXIS_TVALID,
  
input wire valid_from_aes


);
// function called clogb2 that returns an integer which has the 
// value of the ceiling of the log base 2.
function integer clogb2 (input integer bit_depth);
  begin
    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
      bit_depth = bit_depth >> 1;
  end
endfunction

// Total number of input data.
localparam NUMBER_OF_INPUT_WORDS  = 128;
// bit_num gives the minimum number of bits needed to address 'NUMBER_OF_INPUT_WORDS' size of FIFO.
localparam bit_num  = clogb2(NUMBER_OF_INPUT_WORDS-1);
// Define the states of state machine
// The control state machine oversees the writing of input streaming data to the FIFO,
// and outputs the streaming data from the FIFO
parameter [1:0] IDLE = 1'b0,        // This is the initial/idle state 

                WRITE_FIFO  = 1'b1; // In this state FIFO is written with the
                                    // input stream data S_AXIS_TDATA 
wire  axis_tready;
// State variable
reg mst_exec_state;  
// FIFO implementation signals
genvar i;     
// FIFO write enable
wire fifo_wren;
// FIFO full flag
reg fifo_full_flag;
// FIFO write pointer
reg [bit_num-1:0] write_pointer;
reg [bit_num-1:0] read_pointer;
reg [bit_num:0] count;//it has bit_num onlt and not -1 because it needs that extra bit to not wrap around 
// sink has accepted all the streaming data and stored in FIFO
  reg writes_done;
// I/O Connections assignments

assign S_AXIS_TREADY = axis_tready;
// Control state machine implementation
always @(posedge S_AXIS_ACLK) 
begin  
  if (!S_AXIS_ARESETN) 
  // Synchronous reset (active low)
    begin
      mst_exec_state <= IDLE;
    end  
  else
    case (mst_exec_state)
      IDLE: 
        // The sink starts accepting tdata when 
        // there tvalid is asserted to mark the
        // presence of valid streaming data 
          if (S_AXIS_TVALID)
            begin
              mst_exec_state <= WRITE_FIFO;
            end
          else
            begin
              mst_exec_state <= IDLE;
            end
      WRITE_FIFO: 
        // When the sink has accepted all the streaming input data,
        // the interface swiches functionality to a streaming master
        if (writes_done)
          begin
            mst_exec_state <= IDLE;
          end
        else
          begin
            // The sink accepts and stores tdata 
            // into FIFO
            mst_exec_state <= WRITE_FIFO;
          end

    endcase
end
// AXI Streaming Sink 
// 
// The example design sink is always ready to accept the S_AXIS_TDATA  until
// the FIFO is not filled with NUMBER_OF_INPUT_WORDS number of input words.
wire empty_two;
reg max_reach;
wire fifo_rden;
  assign empty_two = (count <= 1);//les than or equal to one and not two becuase this empty two must be 0 by the next cycle so that aes can read the data
assign axis_tready = ((mst_exec_state == WRITE_FIFO) && (write_pointer <= NUMBER_OF_INPUT_WORDS-1));
  
  
always@(posedge S_AXIS_ACLK)
begin
  if(!S_AXIS_ARESETN)
    begin
      write_pointer <= 0;
      read_pointer <= 0;
      writes_done <= 1'b0;
      count <= 0;
     
    end  
  else 
    begin // <-- ADDED: begin for the else block
          
      case ({fifo_wren, fifo_rden && !empty_two})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 2;
        default: count <= count; // both or neither — net zero
      endcase

      if (write_pointer <= NUMBER_OF_INPUT_WORDS-1)
        begin
          case({fifo_wren, fifo_rden && !empty_two})
            2'b10: begin
                     write_pointer <= write_pointer + 1;
                     writes_done <= 1'b0;
                   end
            2'b01: begin // <-- ADDED: begin to match your closing end
                     read_pointer <= read_pointer + 2;
                   end   // <-- FIXED: This end now correctly closes the 2'b01 block
            default: begin
                       read_pointer <= read_pointer;
                       write_pointer <= write_pointer; 
                     end
          endcase
          //if (fifo_wren)
          //begin
            // write pointer is incremented after every write to the FIFO
            // when FIFO write signal is enabled.
            //write_pointer <= write_pointer + 1;
            //writes_done <= 1'b0;
          //end
          if ((write_pointer == NUMBER_OF_INPUT_WORDS-1) || S_AXIS_TLAST)
            begin
              writes_done <= 1'b1;
            end
          //if(fifo_rden&&!empty_two)
          //begin
          //read_pointer<=read_pointer + 2;
          //end
        end
    end // <-- ADDED: end to close the else block
end // <-- Correctly closes the always block


// FIFO write enable generation
assign full = write_pointer == NUMBER_OF_INPUT_WORDS-1;
assign fifo_wren = S_AXIS_TVALID && axis_tready;
assign fifo_rden = valid_from_aes&&(/*(count==NUMBER_OF_INPUT_WORDS)||!(count==0)*/!empty_two);

reg [C_S_AXIS_TDATA_WIDTH*2-1 : 0] aes_data[0:64];
reg  [(C_S_AXIS_TDATA_WIDTH)-1:0] stream_data_fifo [0 : NUMBER_OF_INPUT_WORDS-1];
// FIFO Implementation

generate 
  for(i=0; i< C_S_AXIS_TDATA_WIDTH/2; i=i+1)
  begin:FIFO_GEN

    

    // Streaming input data is stored in FIFO

    always @( posedge S_AXIS_ACLK )
    
        begin
          /*case({fifo_wren,fifo_rden&&!empty_two})
              2'b10:stream_data_fifo[write_pointer] <= S_AXIS_TDATA;
              2'b01: begin
                aes_data[i*2]<=stream_data_fifo[read_pointer];
                aes_data[i*2+1]<=stream_data_fifo[read_pointer+1];
                //read_pointer<=read_pointer + 2;
                     end 
                default:begin 
                        aes_data<=aes_data;
                        stream_data_fifo <= stream_data_fifo ;
                        end
          endcase*/
        if(fifo_rden&&!empty_two)
            begin
              aes_data[i*2]<=stream_data_fifo[read_pointer];
              aes_data[i*2+1]<=stream_data_fifo[read_pointer+1];
            end
        else if (fifo_wren)// && S_AXIS_TSTRB[byte_index])
            begin
              stream_data_fifo[write_pointer] <= S_AXIS_TDATA/*[(byte_index*8+7) -: 8]*/;
            end
        else 
            begin
            aes_data<=aes_data;
            stream_data_fifo <= stream_data_fifo ;
            end
         end 
  end
endgenerate

// Add user logic here

// User logic ends

endmodule



