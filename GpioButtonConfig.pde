/**
  GpioButtonConfig
  Purpose:
    Configuration for a GPIO input pin sampled via gpioget.

  Fields:
    - activeLow: true when wiring reads LOW when pressed (GPIO -> button -> GND)
    - bias: gpioget bias setting ("pull-up", "pull-down", "disabled")

  Notes:
    - No static factory helpers because Processing treats .pde classes as inner classes.
*/
class GpioButtonConfig {
  final boolean activeLow;
  final String bias;

  GpioButtonConfig(boolean activeLow, String bias) {
    this.activeLow = activeLow;
    this.bias = bias;
  }
}




