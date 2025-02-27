--[[

	Beduino
	=======

	Copyright (C) 2022 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	Example Files

]]--

local lib = beduino.lib

local techage_c = [[
// Read port number of the next Input Module port that
// received a command.
func get_next_inp_port() {
  system(0x100, 0);
}

// Send a command to a techage block
// 'topic' is a number, 'payload' is an array or string
func send_cmnd(port, topic, payload) {
  system(0x106, port, topic, payload);
}

// Read data from a techage block
// 'topic' is a number, 'payload' and 'resp' is arr[8]
func request_data(port, topic, payload, resp) {
  system(0x101, port, resp);
  system(0x107, port, topic, payload);
}

// Clear screen on a TA4 Display
func clear_screen(port) {
  system(0x103, port);
}

// Append a line on a TA4 Display
func append_line(port, text) {
  system(0x104, port, text);
}

// Write a line on a TA4 Display
func write_line(port, row, text) {
  system(0x105, port, row, text);
}
]]

local seg14_c = [[
import "sys/string.asm"
import "lib/techage.c"

static var Chars[] = {
  0x2237, 0x0A8F, 0x0039, 0x088F, 0x2039, 0x2031, 0x023D, 0x2236,
  0x0889, 0x001E, 0x2530, 0x0038, 0x0176, 0x0476, 0x003F, 0x2233,
  0x043F, 0x2633, 0x222D, 0x0881, 0x003E, 0x1130, 0x1436, 0x1540,
  0x0940, 0x1109 };

static var Numbers[] = {
  0x003F, 0x0106, 0x221B, 0x020F, 0x2226, 0x222D, 0x223D, 0x0901,
  0x223F, 0x222F};

func seg14_putchar(port, c) {
  var i;

  if(c > 96) {
    i = c - 97;  // a - z
    send_cmnd(port, 16, &Chars[i]);
  } else if(c > 64) {
    i = c - 65;  // A - Z
    send_cmnd(port, 16, &Chars[i]);
  } else if(c == 32) {
    send_cmnd(port, 16, "\000");
  } else {
    i = c - 48;  // 0 - 9
    send_cmnd(port, 16, &Numbers[i]);
  }
}

func seg14_putdigit(port, val) {
  send_cmnd(port, 16, &Numbers[val]);
}

func seg14_putstr(base_port, s) {
  var port = base_port;
  var len = strlen(s);
  var i;
  var c;

  for(i = 0; i < len; i++) {
    c = s[i];
    if(c > 255) {
      seg14_putchar(port, c / 256);
      port++;
      seg14_putchar(port, c % 256);
      port++;
    } else {
      seg14_putchar(port, c);
      port++;
    }
  }
}
]]

local example1_c = [[
// Output some characters on the
// programmer status line (system #0).
// Start program with: "Debug" -> "Run"

import "sys/stdlib.asm"

const MAX = 32;

func bin_to_ascii(i) {
  return 0x40 + i;
}

func init() {
  var i;

  for(i = 0; i < MAX; i++) {
    system(0, bin_to_ascii(i));
  }
}

func loop() {
  halt(); // abort execution
}
]]

local example2_c = [[
// Read button on port #0,
// light detector on port #1 and
// control signal tower on port #2.

import "lib/techage.c"

const OFF = 0;
const COLOR = 2;
const STATE = 131;
const LIGHT = 143;
const GREEN = 1;
const P_SWITCH = 0;
const P_DETECT = 1;
const P_STOWER = 2;

static var idx = 0;

func init() {
  send_cmnd(P_STOWER, COLOR, OFF);
}

func loop() {
  var resp;
  var color;
  var sts = request_data(P_SWITCH, STATE, 0, &resp); // Read switch

  if((sts == 0) and (resp == 1)) {
    sts = request_data(P_DETECT, LIGHT, 0, &resp);  // Read detector

    if((sts == 0) and (resp < 10)) { // turn on at night
      color = GREEN + idx;
      idx = (idx + 1) % 3;
      send_cmnd(P_STOWER, COLOR, &color);
    } else {
      send_cmnd(P_STOWER, COLOR, OFF);
    }
  } else {
    send_cmnd(P_STOWER, COLOR, OFF);
  }
}
]]

local example3_c = [[
// SmartLine Display/Player Detector example.
// Connect detector to port #0 and display to port #1.
// If the detector is "on", read and output the player
// name to the display (row 3).

import "lib/techage.c"

const STATE = 142;
const PLAYER = 144;

static var buff[32];

func init() {
  clear_screen(1);
  write_line(1, 2, "Hello");
}

func loop() {
  var sts;

  sts = request_data(0, STATE, 0, buff);
  if((sts == 0) and (buff[0] == 1)) {
    request_data(0, PLAYER, 0, buff);
    write_line(1, 3, buff);
  } else {
    write_line(1, 3, "~");
  }
  sleep(5);
}
]]

local example4_c = [[
// Read input ports from one or more
// Input Modules and output the data to
// the Programmer's internal terminal.

import "sys/stdio.asm"
import "lib/techage.c"

func init() {
  setstdout(1);  // use terminal windows for stdout
  putchar('\b'); // clear entire screen
}

func loop() {
  var port;
  var val;

  port = get_next_inp_port();
  if(port != 0xffff) {
    val = input(port);
    putnum(port);
    putstr(" = ");
    putnum(val);
    putchar('\n');
  }
}
]]

local example5_c = [[
// Programmer Terminal Window example
import "sys/stdio.asm"
import "sys/os.c"

func timerstamp() {
    putchar('[');
    putnumf(get_day_count());
    putchar(':');
    putnumf(get_timeofday());
    putchar('] ');
}

func init() {
  setstdout(1);  // use terminal windows for stdout
  putchar('\b'); // clear entire screen
  putstr("+----------------------------------------------------------+\n");
  putstr("|                Terminal Window Demo V1.0                 |\n");
  putstr("+----------------------------------------------------------+\n");
  putstr("\n");
}

func loop() {
    timerstamp();
    putstr("Something strange happend!\n");
    sleep(10);
    timerstamp();
    putstr("These Romans are crazy!\n");
    sleep(10);
    timerstamp();
    putstr("Cogito, ergo sum!\n");
    sleep(10);
    timerstamp();
    putstr("Lorem ipsum dolor sit amet, consetetur sadipscing elitr.\n");
    sleep(10);
}
]]

local example1_asm = [[
; Read button on IOM port #0 and
; turn on/off lamp on port #1.

  jump 8
  .org 8       ; the first 8 words are reserved

loop:
  nop          ; 100 ms delay
  nop          ; 100 ms delay
  in   A, #0   ; read switch value
  skne  A, B   ; data changed?
  jump loop    ; no change: read again

  move B, A    ; store value in B
  out  #01, A  ; output value
  jump loop
]]

local iot_demo1_c = [[
// Demo for a IOT sensor,
// a Player Detector on the right (#2),
// and a Techage Color Lamp 2 above (#1).

import "lib/techage.c"

const STATE = 142; // player detector state
const COLOR = 22;  // color lamp command
var OFF = "\377";

static var data;

func init() {
  send_cmnd(1, COLOR, OFF); // Turn color lamp off
}

func loop() {
  var resp;
  var sts;

  sts = request_data(2, STATE, 0, &resp);
  if((sts == 0) and (resp == 1)) {
    // Turn color lamp on
    send_cmnd(1, COLOR, &data);
    data = (data + 1) % 256;
  } else {
    send_cmnd(1, COLOR, OFF);
  }
  sleep(2);
}
]]

vm16.register_ro_file("beduino", "lib/techage.c",   techage_c)
vm16.register_ro_file("beduino", "lib/seg14.c",     seg14_c)
vm16.register_ro_file("beduino", "demo/example1.c", example1_c)
vm16.register_ro_file("beduino", "demo/example2.c", example2_c)
vm16.register_ro_file("beduino", "demo/example3.c", example3_c)
vm16.register_ro_file("beduino", "demo/example4.c", example4_c)
vm16.register_ro_file("beduino", "demo/example5.c", example5_c)
vm16.register_ro_file("beduino", "demo/example1.asm", example1_asm)
vm16.register_ro_file("beduino", "demo/iot_demo1.c", iot_demo1_c)
