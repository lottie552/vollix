/**
  PhysicalButton
  Purpose:
    Project-level device: debounced input + edges.
    Implements GpioDevice so it can live in the main ArrayList<GpioDevice> loop.
*/
class PhysicalButton implements GpioDevice {
  final String name;
  final GpioInputPinDriver driver;

  final GpioDebouncer debouncer;
  final GpioEdgeTracker edges;

  boolean stableDown = false;

  PhysicalButton(String name, GpioInputPinDriver driver, int debounceMs) {
    this.name = name;
    this.driver = driver;

    debouncer = new GpioDebouncer(debounceMs);
    edges = new GpioEdgeTracker();

    int now = millis();
    boolean raw = driver.sampleIsActive();
    stableDown = raw;

    debouncer.reset(stableDown, now);
    edges.reset(stableDown);
  }

  @Override
  public void update() {
    int now = millis();
    boolean raw = driver.sampleIsActive();
    stableDown = debouncer.update(raw, now);
    edges.update(stableDown);
  }

  @Override
  public void shutdown() {
    driver.shutdown();
  }

  boolean isDown() { return stableDown; }
  boolean justPressed() { return edges.justActivated; }
  boolean justReleased() { return edges.justDeactivated; }

  String debugName() { return name; }
}




