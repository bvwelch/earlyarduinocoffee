// 4-chan TC w/ mcp3424 and mcp9800
// Author: William Welch Copyright (c) 2010, all rights reserved.
// MIT license: http://opensource.org/licenses/mit-license.php

char *banner = "logger04";

#include <PortsLCD.h>
#include <RF12.h>

#define MICROVOLT_TO_C 40.69

#define CFG 0x1C  // gain=1
// #define CFG 0x1D    // gain=2
// #define CFG 0x1E    // gain=4

// remember, the sample update rate is 2 seconds.
// we want to display degrees-per-minute (60 sec)
#define HSIZE 30

void get_samples();
void get_ambient();
void blinker();
void rise_calc();
void logger();
void lcd_display();

PortI2C p_measure(4);
DeviceI2C adc(p_measure, 0x68);
DeviceI2C amb(p_measure, 0x48);
PortI2C p_lcd(1);
LiquidCrystalI2C lcd(p_lcd);

MilliTimer hb_tmr; // heartbeat LED
MilliTimer adc_tmr; // sampling rate
MilliTimer rise_tmr; // rise-o-meter rate
MilliTimer log_tmr;  // logging rate
MilliTimer lcd_tmr;  // lcd update rate

int ledPin = 13;
char msg[80];

// updated every two seconds
int32_t samples[4];
int32_t temps[4];
int32_t hist[4][HSIZE+1];
int32_t rise[4];

int32_t ambient = 0;
int32_t amb_f = 0;

// which channels to display on lcd
byte ch0 = 0;
byte ch1 = 1;

void loop()
{
  get_samples();
  rise_calc();
  lcd_display();
  logger();
  blinker();
}

void rise_calc()
{
  int i,j;

  // wait for timer to expire
  if ( !rise_tmr.idle() ) {
    if ( rise_tmr.poll() == 0 ) return;
  }

  // same as sample update rate.
  rise_tmr.set(2000); // delta T for rise calculation

  // note: buffer size is HSIZE+1
  for (i=0; i<4; i++) {
    for (j=HSIZE; j>0; j--) {
      hist[i][j] = hist[i][j-1];
    }
    hist[i][0] = temps[i];
  }

  for (i=0; i<4; i++) {
    int32_t d;
    // note: buffer size is HSIZE+1
    d = temps[i] - hist[i][HSIZE];
    //rise[i] = d;
    rise[i] = d * (30/HSIZE);  // rise-per-minute
  }
}

void lcd_display()
{
  // wait for timer to expire
  if ( !lcd_tmr.idle() ) {
    if ( lcd_tmr.poll() == 0 ) return;
  }
  lcd_tmr.set(2000); // lcd update rate

  lcd.clear();

  //sprintf(msg, "%ld", samples[ch0]);
  //lcd.print(msg);
  //lcd.setCursor(0, 1);
  //sprintf(msg, "%ld %ld", temps[ch0], ambient);
  //lcd.print(msg);

  sprintf(msg, "%ld %ld", temps[ch0], rise[ch0]);
  lcd.print(msg);
  lcd.setCursor(0, 1);
  sprintf(msg, "%ld %ld", temps[ch1], rise[ch1]);
  lcd.print(msg);
}

void logger()
{
  unsigned long tod;

  // wait for timer to expire
  if ( !log_tmr.idle() ) {
    if ( log_tmr.poll() == 0 ) return;
  }
  log_tmr.set(2000); // log every two seconds

  tod = millis() / 1000;
  //sprintf(msg, "t=%ld, %ld, %ld, %ld", tod, samples[ch0], temps[ch0], ambient);
  Serial.print(tod);
  Serial.print(",");
//  Serial.print("\t");
  Serial.print(amb_f);
  Serial.print(",");
//  Serial.print("\t");
  for (int i=0; i<4; i++) {
    Serial.print(temps[i]);
    if (i < 3) Serial.print(",");
//    if (i < 3) Serial.print("\t");
  }
  Serial.println();
}

void get_samples()
{
  int stat;
  byte a, b, c, rdy, gain, chan, mode, ss;
  int32_t v;

  // wait for timer to expire
  if ( !adc_tmr.idle() ) {
    if ( adc_tmr.poll() == 0 ) return;
  }
  adc_tmr.set(500); // two second update rate (4 channels)

  adc.receive();
  a = adc.read(0);
  b = adc.read(0);
  c = adc.read(0);
  stat = adc.read(1);
  rdy = (stat >> 7) & 1;
  chan = (stat >> 5) & 3;
  mode = (stat >> 4) & 1;
  ss = (stat >> 2) & 3;
  gain = stat & 3;
  
  if (chan == 0) {
    get_ambient();
  }

  v = a;
  v <<= 24;
  v >>= 16;
  v |= b;
  v <<= 8;
  v |= c;
  
  // sprintf(msg, "0x%x, %x, %x, %x, %x, %x, %ld", stat, rdy, chan, mode, ss, gain, v);
  // Serial.print(msg);

  // convert to microvolts
  // divide by gain
  v = round(v * 15.625);
  v /= 1 << (CFG & 3);
  samples[chan] = v;  // units = microvolts

  // sprintf(msg, ", %ld", v);
  // Serial.print(msg);

  v = round(v / MICROVOLT_TO_C);

  v += ambient;

  // convert to F
  v = round(v * 1.8);
  v += 32;
  temps[chan] = v;

// FIXME
//if (chan == 0) {
  //static int32_t x = 0;
  //temps[chan] = x++;
//}

  // sprintf(msg, ", %ld", v);
  // Serial.println(msg);

  chan++;
  chan &= 3;
  adc.send();
  adc.write(CFG | (chan << 5) );
  adc.stop();
}

void get_ambient()
{
  byte a;
  int32_t v;

  amb.send();
  amb.write(0); // point to temp reg.
  amb.receive();
  a = amb.read(1);
  v = a;
  // FIXME: test temps below freezing.
  v <<= 24;
  v >>= 24;
  ambient = v;

  // convert to F
  v = round(v * 1.8);
  v += 32;
  amb_f = v;
}

void blinker()
{
  static char on = 0;
  if (hb_tmr.idle() || hb_tmr.poll() ) {
    if (on) {
      digitalWrite(ledPin, HIGH);
//      digitalWrite(ledPin, LOW);
      hb_tmr.set(950);
    } else {
      digitalWrite(ledPin, LOW);
//      digitalWrite(ledPin, HIGH);
      hb_tmr.set(50);
    }
    on ^= 1;
  }
}

void setup()
{
  byte a;
  pinMode(ledPin, OUTPUT);     
  Serial.begin(57600);
  lcd.begin(16, 1);

  while ( millis() < 3000) blinker();
  sprintf(msg, "\n# %s: 4-chan TC", banner);
  Serial.println(msg);
  Serial.println("# time,ambient,T0,T1,T2,T3");
 
  lcd.clear();
  lcd.print(banner);
  while ( millis() < 6000) blinker();

  // configure mcp3424
  adc.send();
  adc.write(CFG);
  adc.stop();
  adc.send();
  adc.write(1); // point to config reg
  adc.write(0); // 9-bit mode
  adc.stop();
  
  // configure mcp9800.
  amb.send();
  amb.write(1); // point to config reg
  amb.write(0); // 9-bit mode
  amb.stop();

  // see if we can read it back.
  amb.send();
  amb.write(1); // point to config reg
  amb.receive();
  a = amb.read(1);
  if (a != 0) {
    Serial.println("# Error configuring mcp9800");
  } else {
    Serial.println("# mcp9800 Config reg OK");
  }
}

