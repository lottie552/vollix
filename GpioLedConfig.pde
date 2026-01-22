/**
  GpioLedConfig
  Purpose:
    Device-level configuration for a GPIO LED.

  Fields:
    - startOn: whether the LED should be driven ON immediately at construction
    - inverted: whether logical ON should drive the pin LOW

  Notes:
    - No static factory helpers because Processing treats .pde classes as inner classes.
*/
class GpioLedConfig {
  final boolean startOn;
  final boolean inverted;

  GpioLedConfig(boolean startOn, boolean inverted) {
    this.startOn = startOn;
    this.inverted = inverted;
  }
}




