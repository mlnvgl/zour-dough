#include "DHT.h"
#include <LiquidCrystal.h>
#define DHTTYPE DHT22
#define DHT22_Pin 2

DHT dht(DHT22_Pin, DHTTYPE);
const float max_temperature = 25;
float humidity, temperature;

const int rs = 12, en = 11, d4 = 5, d5 = 4, d6 = 3, d7 = 6;
LiquidCrystal lcd(rs, en, d4, d5, d6, d7);

void setup() {
  // put your setup code here, to run once:
  Serial.begin(9600);
  dht.begin();
  delay(500);
  pinMode(LED_BUILTIN, OUTPUT);

  lcd.begin(16, 2);
  lcd.print("hello, world!");

}

void loop() {
  // put your main code here, to run repeatedly:
  humidity = dht.readHumidity();
  temperature = dht.readTemperature();
  
  Serial.print("Luftfeuchte: ");
  Serial.print(humidity);
  Serial.println("%, ");
  Serial.print("Temperatur: ");
  Serial.print(temperature);
  Serial.println("°C");

  if(temperature >= max_temperature){
    digitalWrite(LED_BUILTIN, HIGH);
  }else{
    digitalWrite(LED_BUILTIN, LOW);
  }

  lcd.setCursor(0,1);
  lcd.print(millis() / 1000);

  delay(10000);
}
