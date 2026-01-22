/**
  Hardware
  Purpose:
    Project-level "hardware composition" (aka the place where pins become devices).

    This class is the bridge between:
      - PinMap's TABLE (data: which pins exist + what they mean)
      - The GPIO candy (CmdRunner, GpioPinRegistry, drivers, configs)
      - Project devices (IndicatorLed, PhysicalButton)
      - The main CanAnimate-style loop: ArrayList<GpioDevice>

    In other words:
      Pin table row  ->  create driver  ->  wrap into device  ->  register into gpioDevices  ->  usable by states.

  Owns:
    - The device objects (IndicatorLed / PhysicalButton) for THIS sketch
    - Group lists (life LEDs, target LEDs, target buttons, target ids)
    - Lookup maps by id (ledsById / buttonsById)
    - The pin claim registry (so duplicate pins explode early)

  Does NOT own:
    - The update loop (main owns `for (device : gpioDevices) device.update();`)
    - Game rules / state machine logic
    - Visual rendering

  Pin table contract (expected columns):
    - "id"    (String)  logical id, e.g. "life1", "start", "t1", "t2"
    - "kind"  (String)  "LED" or "BUTTON"
    - "role"  (String)  "LIFE" / "START" / "TARGET"  (you can extend later)
    - "pin"   (int)     BCM GPIO number
    - "group" (String)  "LEFT" / "RIGHT" / "" (optional, mainly for TARGET)

  Notes:
    - Active-low buttons with pull-up are assumed (pressed reads LOW).
    - If you later add other input types (sensors) or output types (servos),
      you add new config + new driver wrappers, without rewriting this file-just extend mapping rules.
*/
class Hardware {

  // --- "named" important devices (convenience) ---
  PhysicalButton startButton = null;

  // --- grouped devices (scales cleanly) ---
  final ArrayList<IndicatorLed> lifeLeds = new ArrayList<IndicatorLed>();          // should end up in order: life3, life2, life1
  final ArrayList<String> targetIds = new ArrayList<String>();                     // e.g. ["t1","t2",...]
  final ArrayList<IndicatorLed> targetLeds = new ArrayList<IndicatorLed>();        // target LEDs only
  final ArrayList<PhysicalButton> targetButtons = new ArrayList<PhysicalButton>(); // target buttons only
  final ArrayList<Target> targets = new ArrayList<Target>();   // playable targets (id + group + led + optional button)

  // --- lookup maps (fast + clean) ---
  final HashMap<String, IndicatorLed> ledsById = new HashMap<String, IndicatorLed>();
  final HashMap<String, PhysicalButton> buttonsById = new HashMap<String, PhysicalButton>();
  final HashMap<String, String> groupByTargetId = new HashMap<String, String>();  // "t1"->"LEFT"/"RIGHT"

  // --- candy internals ---
  final CmdRunner cmdRunner;
  final GpioPinRegistry pinRegistry;

  // --- configs (single instances reused for every pin of that type) ---
  final GpioButtonConfig buttonConfig;
  final GpioLedConfig ledConfigDefaultOff;

  // tweakable (keep here; states shouldn't care)
  final int defaultDebounceMs;

  Hardware(ArrayList<GpioDevice> gpioDevices, Table pinTable) {
    println("=== Hardware constructor ===");
    
    // Core candy objects
    cmdRunner = new CmdRunner();

    // Chip name: keep it boring and explicit.
    // If you ever want it configurable, add a PinMap constant or another table column.
    pinRegistry = new GpioPinRegistry(cmdRunner, "gpiochip0");

    // Input/output configs
    // Active-low + pull-up => pressed reads LOW, but driver.sampleIsActive() becomes true when pressed.
    buttonConfig = new GpioButtonConfig(true, "pull-up");

    // LED config: startOff + not inverted
    ledConfigDefaultOff = new GpioLedConfig(false, false);

    defaultDebounceMs = 35;

    // Build everything from the table
    buildFromTable(gpioDevices, pinTable);
    buildTargetsFromMaps();

    // Make sure life LEDs are in your preferred order (lose life3 first, life1 last).
    normalizeLifeLedOrder();

    // Debug output
    println("  Total LEDs in ledsById: " + ledsById.size());
    println("  Life LEDs count: " + lifeLeds.size());
    println("  Target LEDs count: " + targetLeds.size());
    println("  Targets count: " + targets.size());
    println("  Claimed pins: " + pinRegistry.claimedCount());
    
    // Safe initial state
    allLedsOff();
  }

  // ---------------------------------------------------------------------------
  // Build phase
  // ---------------------------------------------------------------------------

  void buildFromTable(ArrayList<GpioDevice> gpioDevices, Table pinTable) {
    println("Building from pin table, rows: " + pinTable.getRowCount());
    
    for (TableRow row : pinTable.rows()) {
      String id = safeUpperOrEmpty(row.getString("id"));      // we keep original id casing separately
      String kind = safeUpperOrEmpty(row.getString("kind"));
      String role = safeUpperOrEmpty(row.getString("role"));
      int pin = row.getInt("pin");
      String group = safeUpperOrEmpty(row.getString("group"));

      // Keep ids as the original "human" id (lowercase is nicer).
      // If you already used lowercase ids, keep them.
      String cleanId = row.getString("id");
      if (cleanId == null) cleanId = "";
      cleanId = cleanId.trim();

      // Track group for target ids (even if only LED exists for now)
      if (role.equals("TARGET")) {
        rememberTarget(cleanId, group);
      }

      if (kind.equals("LED")) {
        IndicatorLed led = createLedDevice(cleanId, pin);
        gpioDevices.add(led);
        ledsById.put(cleanId, led);

        // Group routing
        if (role.equals("LIFE")) {
          lifeLeds.add(led);
          println("  Created LIFE LED: " + cleanId + " on pin " + pin);
        }
        if (role.equals("TARGET")) {
          targetLeds.add(led);
          println("  Created TARGET LED: " + cleanId + " on pin " + pin);
        }
      }
      else if (kind.equals("BUTTON")) {
        PhysicalButton btn = createButtonDevice(cleanId, pin);
        gpioDevices.add(btn);
        buttonsById.put(cleanId, btn);

        // Group routing
        if (role.equals("START")) {
          startButton = btn;
          println("  Created START BUTTON: " + cleanId + " on pin " + pin);
        }
        if (role.equals("TARGET")) {
          targetButtons.add(btn);
          println("  Created TARGET BUTTON: " + cleanId + " on pin " + pin);
        }
      }
      else {
        // Unknown kind: ignore rather than crash, but print so you notice.
        println("Hardware: Unknown kind '" + kind + "' for id=" + cleanId + " pin=" + pin + " (row skipped)");
      }
    }

    // Sanity: start button should exist
    if (startButton == null) {
      println("Hardware WARNING: startButton not found in pin table (role=START kind=BUTTON).");
    }
  }

  void buildTargetsFromMaps() {
    targets.clear();

    for (int i = 0; i < targetIds.size(); i++) {
      String id = targetIds.get(i);

      IndicatorLed led = ledsById.get(id);
      if (led == null) {
        println("Hardware WARNING: Target id '" + id + "' has no LED row; skipping target.");
        continue;
      }

      PhysicalButton btn = buttonsById.get(id);

      String group = groupByTargetId.get(id);
      if (group == null) group = "";

      targets.add(new Target(id, group, led, btn));
      println("  Created Target: " + id + ", hasButton=" + (btn != null));
    }
  }

  IndicatorLed createLedDevice(String id, int bcmPin) {
    // The registry is where the pin becomes "output" and becomes owned/claimed.
    GpioOutputPinDriver driver = pinRegistry.createOutputDriver(
      "led:" + id,
      bcmPin,
      ledConfigDefaultOff
    );
    return new IndicatorLed("led:" + id, driver);
  }

  PhysicalButton createButtonDevice(String id, int bcmPin) {
    // The registry is where the pin becomes "input" and becomes owned/claimed.
    GpioInputPinDriver driver = pinRegistry.createInputDriver(
      "btn:" + id,
      bcmPin,
      buttonConfig
    );
    return new PhysicalButton("btn:" + id, driver, defaultDebounceMs);
  }

  void rememberTarget(String targetId, String group) {
    if (targetId == null) return;
    String t = targetId.trim();
    if (t.length() == 0) return;

    if (!targetIds.contains(t)) targetIds.add(t);

    if (group != null && group.length() > 0) {
      groupByTargetId.put(t, group);
    }
  }

  // ---------------------------------------------------------------------------
  // Public helpers used by states
  // ---------------------------------------------------------------------------

  /** Turn every LED off (safe state). */
  void allLedsOff() {
    for (int i = 0; i < lifeLeds.size(); i++) lifeLeds.get(i).off();
    for (int i = 0; i < targetLeds.size(); i++) targetLeds.get(i).off();
  }

  /** Convenience: set all targets off. */
  void targetsOff() {
    for (int i = 0; i < targetLeds.size(); i++) targetLeds.get(i).off();
  }

  /** Convenience: turn exactly one target LED on by target id ("t1", "t2", ...). */
  void setTargetLed(String targetId, boolean on) {
    IndicatorLed led = ledsById.get(targetId);
    if (led != null) led.set(on);
  }

  /** Show lives on life LEDs using your preferred ordering: life3,life2,life1. */
  void showLives(int lives) {
    lives = constrain(lives, 0, 3);

    // lifeLeds order is [life3, life2, life1]
    for (int i = 0; i < lifeLeds.size(); i++) {
      int remaining = 3 - i; // i=0 => 3, i=1 => 2, i=2 => 1
      boolean shouldBeOn = (lives >= remaining);
      lifeLeds.get(i).set(shouldBeOn);
    }
  }

  /** Return group for a target id ("LEFT"/"RIGHT"/"") */
  String getTargetGroup(String targetId) {
    String g = groupByTargetId.get(targetId);
    if (g == null) return "";
    return g;
  }

  /** Debug: list claimed pins (helps spot double-claims). */
  String debugClaimedPins() {
    return pinRegistry.claimedPinsDebug();
  }

  // ---------------------------------------------------------------------------
  // Internal utilities
  // ---------------------------------------------------------------------------

  /** Make sure lifeLeds ends up as [life3, life2, life1] even if table row order drifts. */
  void normalizeLifeLedOrder() {
    println("Normalizing life LED order...");
    println("  Current lifeLeds size: " + lifeLeds.size());
    
    if (lifeLeds.size() < 3) {
      println("  WARNING: Only " + lifeLeds.size() + " life LEDs, cannot normalize");
      return;
    }

    // First, let's see what we have
    for (int i = 0; i < lifeLeds.size(); i++) {
      println("  Before sort: lifeLeds[" + i + "] = " + lifeLeds.get(i).debugName());
    }

    // Check for life1, life2, life3 in the map
    IndicatorLed l1 = ledsById.get("life1");
    IndicatorLed l2 = ledsById.get("life2");
    IndicatorLed l3 = ledsById.get("life3");

    println("  Found in map - life1: " + (l1 != null) + 
            ", life2: " + (l2 != null) + 
            ", life3: " + (l3 != null));

    // If any missing, do nothing and keep whatever order we built.
    if (l1 == null || l2 == null || l3 == null) {
      println("  Some life LEDs not found, keeping current order");
      return;
    }

    // Clear and rebuild in correct order
    lifeLeds.clear();
    lifeLeds.add(l3);  // life3 first (first to lose)
    lifeLeds.add(l2);  // life2 second  
    lifeLeds.add(l1);  // life1 last (last life)
    
    println("  Normalized order set to: life3, life2, life1");
    
    // Verify
    for (int i = 0; i < lifeLeds.size(); i++) {
      println("  After sort: lifeLeds[" + i + "] = " + lifeLeds.get(i).debugName());
    }
  }

  String safeUpperOrEmpty(String s) {
    if (s == null) return "";
    return s.trim().toUpperCase();
  }
}



