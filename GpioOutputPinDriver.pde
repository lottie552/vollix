/**
  GpioOutputPinDriver
  Purpose:
    Driver for ONE output pin. Only output. No input responsibilities.

  Critical behavior:
    - Uses gpioset to drive the line.
    - gpioset holds the line as long as the process lives.
    - To change value, we destroy the previous process and start a new one.
    - We DO NOT use gpioset -z (daemon mode).

  Owns:
    - The currently running gpioset process for this pin (if any).

  Notes:
    - This driver remains generic: it only knows "drive high/low".
    - LED preferences (startOn/inverted) are passed via GpioLedConfig so future
      output devices do not collide with LED behavior.
*/
class GpioOutputPinDriver {
  final CmdRunner cmdRunner;
  final String chipName;
  final int bcmPin;
  final String name;
  final GpioLedConfig ledConfig;

  Process holdProcess = null;
  
  boolean currentHigh = false;
  boolean hasValue = false;

  GpioOutputPinDriver(CmdRunner cmdRunner, String chipName, int bcmPin, String name, GpioLedConfig ledConfig) {
    this.cmdRunner = cmdRunner;
    this.chipName = chipName;
    this.bcmPin = bcmPin;
    this.name = name;
    this.ledConfig = (ledConfig == null) ? new GpioLedConfig(false, false) : ledConfig;

    // Apply initial state
    if (this.ledConfig.startOn) {
      setHighInternal();
    } else {
      setLowInternal();
    }
  }

  void setHigh() {
    if (ledConfig.inverted) setLowInternal();
    else setHighInternal();
  }

  void setLow() {
    if (ledConfig.inverted) setHighInternal();
    else setLowInternal();
  }

  void shutdown() {
    stopHoldProcess();
  }

  // Physical-level helpers (no inversion here)
  void setHighInternal() {
    setValuePhysical(true);
  }

  void setLowInternal() {
    setValuePhysical(false);
  }

  void setValuePhysical(boolean high) {
    if (hasValue && currentHigh == high) return;

    stopHoldProcess();

    String value = high ? "1" : "0";
    String[] cmd = new String[] {
      "gpioset",
      "-c", chipName,
      String.valueOf(bcmPin) + "=" + value
    };

    holdProcess = cmdRunner.start(cmd, "gpioset (" + name + ")");
    currentHigh = high;
    hasValue = true;
  }

  void stopHoldProcess() {
    if (holdProcess == null) return;

    try {
      holdProcess.destroy();
      try { holdProcess.waitFor(); } catch (Exception ignore) {}
    } catch (Exception e) {
      println("GPIO output shutdown warning (" + name + "): " + e);
    } finally {
      holdProcess = null;
    }
  }
}



