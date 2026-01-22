/**
  GpioPinRegistry
  Purpose:
    Candy-store "claim pins + build drivers" registry.

    This is the GPIO equivalent of "registering objects into a system":
      - claim pin (mark used)
      - create the correct driver type (input vs output)
      - return the driver to the project layer

  Owns:
    - claimedPins list

  Uses:
    - CmdRunner + chipName to construct pin drivers

  Notes:
    - This registry does NOT create project devices (IndicatorLed / PhysicalButton).
    - It only constructs backend drivers.
*/
class GpioPinRegistry {
  final CmdRunner cmdRunner;
  final String chipName;

  final ArrayList<Integer> claimedPins = new ArrayList<Integer>();

  GpioPinRegistry(CmdRunner cmdRunner, String chipName) {
    this.cmdRunner = cmdRunner;
    this.chipName = chipName;
  }

  boolean isClaimed(int bcmPin) {
    return claimedPins.contains(bcmPin);
  }

  void claim(int bcmPin, String ownerName) {
    if (claimedPins.contains(bcmPin)) {
      throw new GpioPinClaimException(
        "GPIO pin already claimed: BCM " + bcmPin + " (attempted by " + ownerName + ")"
      );
    }
    claimedPins.add(bcmPin);
  }

  int claimedCount() {
    return claimedPins.size();
  }

  String claimedPinsDebug() {
    return claimedPins.toString();
  }

  // ---------------------------------------------------------------------------
  // Driver factories (this is where a pin is "told what it is")
  // ---------------------------------------------------------------------------

  GpioOutputPinDriver createOutputDriver(String name, int bcmPin, GpioLedConfig ledConfig) {
    claim(bcmPin, name);
    return new GpioOutputPinDriver(cmdRunner, chipName, bcmPin, name, ledConfig);
  }

  GpioInputPinDriver createInputDriver(String name, int bcmPin, GpioButtonConfig buttonConfig) {
    claim(bcmPin, name);
    return new GpioInputPinDriver(cmdRunner, chipName, bcmPin, buttonConfig, name);
  }
}




