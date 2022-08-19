///////////////////////////////////////////
// srt.sv
//
// Written: David_Harris@hmc.edu, me@KatherineParry.com, Cedar Turek
// Modified:13 January 2022
//
// Purpose: Combined Divide and Square Root Floating Point and Integer Unit
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module srtfsm(
  input  logic clk, 
  input  logic reset, 
  input logic [`DIVb+3:0] NextWSN, NextWCN, WS, WC,
  input  logic XInfE, YInfE, 
  input  logic XZeroE, YZeroE, 
  input  logic XNaNE, YNaNE, 
  input  logic DivStart, 
  input  logic XsE,
  input  logic SqrtE,
  input  logic StallE,
  input  logic StallM,
  input  logic [`DIVb+3:0] StickyWSA,
  input  logic [`DURLEN-1:0] Dur,
  output logic [`DURLEN-1:0] EarlyTermShiftE,
  output logic DivSE,
  output logic DivDone,
  output logic NegSticky,
  output logic DivBusy
  );
  
  typedef enum logic [1:0] {IDLE, BUSY, DONE} statetype;
  statetype state;

  logic [`DURLEN-1:0] step;
  logic WZero;
  //logic [$clog2(`DIVLEN/2+3)-1:0] Dur;
  logic [`DIVb+3:0] W;

  //flopen #($clog2(`DIVLEN/2+3)) durflop(clk, DivStart, CalcDur, Dur);
  assign DivBusy = (state == BUSY);
  assign WZero = ((NextWSN^NextWCN)=={NextWSN[`DIVb+2:0]|NextWCN[`DIVb+2:0], 1'b0});
  // calculate sticky bit
  //    - there is a chance that a value is subtracted infinitly, resulting in an exact QM result
  //      this is only a problem on radix 2 (and pssibly maximally redundant 4) since minimally redundant
  //      radix-4 division can't create a QM that continually adds 0's
  if (`RADIX == 2)
    assign DivSE = |W&~(StickyWSA == WS);
  else
    assign DivSE = |W;
  assign DivDone = (state == DONE);
  assign W = WC+WS;
  assign NegSticky = W[`DIVb+3];
  assign EarlyTermShiftE = step;

  always_ff @(posedge clk) begin
      if (reset) begin
          state <= #1 IDLE; 
      end else if (DivStart&~StallE) begin 
          step <= Dur;
          if (XZeroE|(YZeroE&~SqrtE)|XInfE|YInfE|XNaNE|YNaNE|(XsE&SqrtE)) state <= #1 DONE;
          else         state <= #1 BUSY;
      end else if (state == BUSY) begin
          if ((~|step[`DURLEN-1:1]&step[0])|WZero) begin
              state <= #1 DONE;
          end
          step <= step - 1;
      end else if (state == DONE) begin
        if (StallM) state <= #1 DONE;
        else        state <= #1 IDLE;
      end 
  end
endmodule