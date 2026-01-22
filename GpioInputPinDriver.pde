/**
  GpioInputPinDriver
  Purpose:
    Driver for ONE input pin. Only input. No output responsibilities.

  Does:
    - Samples the pin using gpioget with an explicit bias.
    - Parses output formats robustly.
    - Returns "active" meaning "pressed" after applying activeLow correction.

  Notes:
    - No long-running process is held for inputs.
*/
class GpioInputPinDriver {
  final CmdRunner cmdRunner;
  final String chipName;
  final int bcmPin;
  final GpioButtonConfig config;
  final String name;

  GpioInputPinDriver(CmdRunner cmdRunner, String chipName, int bcmPin, GpioButtonConfig config, String name) {
    this.cmdRunner = cmdRunner;
    this.chipName = chipName;
    this.bcmPin = bcmPin;
    this.config = (config == null) ? new GpioButtonConfig(true, "pull-up") : config;
    this.name = name;
  }

  /** Returns true when the input should be considered "active" (pressed). */
  boolean sampleIsActive() {
    String[] cmd = new String[] {
      "gpioget",
      "-c", chipName,
      "-b", config.bias,
      String.valueOf(bcmPin)
    };

    String out = cmdRunner.run(cmd, "gpioget (" + name + ")");
    boolean rawHigh = parseHigh(out);

    // rawHigh means: pin reads as 1/high.
    // activeLow means: pressed reads low => active = !rawHigh.
    return config.activeLow ? !rawHigh : rawHigh;
  }

  void shutdown() {
    // Inputs do not hold OS resources in this approach.
  }

  // ---------------------------------------------------------------------------
  // Parsing: gpioget output can look like:
  //   "0"
  //   "1"
  //   "18=active"
  //   "\"18\"=inactive"
  //   "gpiochip0 18=active" (some variants)
  // ---------------------------------------------------------------------------
  boolean parseHigh(String output) {
    if (output == null) return false;

    String s = output.trim().toLowerCase();

    if (s.equals("0")) return false;
    if (s.equals("1")) return true;

    // Normalize
    s = s.replace("\"", "").replace("'", "").replace(" ", "");

    if (s.contains("=active")) return true;
    if (s.contains("=inactive")) return false;

    // Rare variants
    if (s.contains("active")) return true;
    if (s.contains("inactive")) return false;

    // Fallback: last digit 0/1
    for (int i = s.length() - 1; i >= 0; i--) {
      char c = s.charAt(i);
      if (c == '0') return false;
      if (c == '1') return true;
    }

    println("GPIO parse warning (" + name + "): could not parse gpioget output: " + output);
    return false;
  }
}



