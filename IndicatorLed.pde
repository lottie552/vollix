/**
  IndicatorLed
  Purpose:
    Project-level LED wrapper.
    Implements GpioDevice so it can live in the main ArrayList<GpioDevice> loop
    (mainly for shutdown ownership consistency).
*/
class IndicatorLed implements GpioDevice {
  final String name;
  final GpioOutputPinDriver driver;

  IndicatorLed(String name, GpioOutputPinDriver driver) {
    this.name = name;
    this.driver = driver;
  }

  void on() { driver.setHigh(); }
  void off() { driver.setLow(); }
  void set(boolean on) { if (on) on(); else off(); }

  @Override
  public void update() {
    // Outputs don't need polling.
  }

  @Override
  public void shutdown() {
    driver.shutdown();
  }

  String debugName() { return name; }
}




