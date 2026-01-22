Hardware hardware;
VisualLayout layout;
App app;

// Icons (loaded directly in main)
PShape homeIcon;
PShape adjustIcon;
PShape hintIcon;      // For BootState (lightbulb)
PShape candyIcon;    // For PlayingState (LEFT foot placeholder)
PShape cupcakeIcon;  // For PlayingState (RIGHT foot placeholder)

// CanAnimate-style list: main owns the update loop
ArrayList<GpioDevice> gpioDevices = new ArrayList<GpioDevice>();

// 🟢 ADD: Global keyboard state for CalibrationState
boolean[] keyStates = new boolean[256];  // For regular keys
boolean[] keyCodeStates = new boolean[256];  // For special keys (arrows, etc.)
char lastKey = 0;
int lastKeyCode = 0;

void setup() {
  println("=== SETUP START ===");
  
  // For floor projection with beamer - use full screen
  // If developing on desktop, you might want to use size() instead
   fullScreen();  // Uncomment for final projection

  shapeMode(CENTER);

  // Load all SVGs from /data
  println("Loading icons...");
  homeIcon = loadShape("Home.svg");
  adjustIcon = loadShape("Ajust.svg");
  hintIcon = loadShape("Hint.svg");       // Hint icon for BootState
  candyIcon = loadShape("Foot L.svg");    // LEFT foot icon
  cupcakeIcon = loadShape("Foot R.svg");   // RIGHT foot icon

  candyIcon.disableStyle();
  cupcakeIcon.disableStyle();
  candyIcon.setFill(color(255, 0, 255));  // Magenta for visibility
  cupcakeIcon.setFill(color(255, 0, 255));  // Magenta
  candyIcon.setStroke(color(255, 0, 255));
  cupcakeIcon.setStroke(color(255, 0, 255));
  println("Icons loaded: home=" + (homeIcon != null) + 
          ", adjust=" + (adjustIcon != null) +
          ", hint=" + (hintIcon != null) +
          ", candy=" + (candyIcon != null) + 
          ", cupcake=" + (cupcakeIcon != null));

  // Layout = positions
  layout = new VisualLayout(width, height);

  // Hardware from table
  println("Building pin map...");
  Table pinTable = buildPinMap();
  println("Pin table has " + pinTable.getRowCount() + " rows");
  
  hardware = new Hardware(gpioDevices, pinTable);
  
  // Setup target positions in layout (after hardware knows target groups)
  layout.setupTargets(hardware.targets);  // Pass targets for group-aware positioning

  // App with all icons
  app = new App(hardware, layout, homeIcon, adjustIcon, hintIcon, candyIcon, cupcakeIcon);

  // Start in BootState (LED sweep -> auto to IdleState)
  println("Starting BootState...");
  app.gsm.setState(new BootState(app));
  
  println("=== SETUP COMPLETE ===");
  println("GPIO devices: " + gpioDevices.size());
  println("Frame rate: " + frameRate);
}

void draw() {
  // DEBUG: Print frame info once per second
  if (millis() % 1000 < 16) {
    println("Frame: " + frameCount + ", Time: " + millis() + "ms, FPS: " + round(frameRate));
  }
  
  // 1) Update all GPIO devices (buttons/leds) once per frame
  for (int i = 0; i < gpioDevices.size(); i++) {
    gpioDevices.get(i).update();
  }

  // 2) Update state logic
  app.update(millis());

  // 3) Render current state (boot/idle/playing visuals)
  // Rotate the entire scene 180 degrees for floor projection. By translating
  // to (width,height) and rotating PI radians, we flip the drawing space so
  // that the top of the sketch appears at the bottom when projected.
  pushMatrix();
  translate(width, height);
  rotate(PI);
  app.render();

  // Show FPS and calibration text inside the rotated coordinate system
  fill(255);
  textSize(12);
  textAlign(RIGHT);
  text("FPS: " + round(frameRate), width - 10, 20);
  if (app.gsm.current instanceof CalibrationState) {
    fill(255, 200, 100);
    textAlign(LEFT);
    textSize(10);
    text("CALIBRATION ACTIVE - Use WASD, Arrows, Enter, ESC", 10, height - 20);
  }
  popMatrix();
}

// 🟢 ADD: Global key pressed handler
void keyPressed() {
  // Prevent ESC from quitting the sketch.  Processing will exit the sketch
  // automatically when ESC is received unless key and keyCode are cleared.
  if (key == ESC || keyCode == ESC) {
    // Mark the ESC key as pressed in the global state so that states can
    // detect it (e.g. CalibrationState cancelling on ESC).  Use the
    // special keyCode index because ESC is a coded key.
    if (keyCode >= 0 && keyCode < keyCodeStates.length) {
      keyCodeStates[keyCode] = true;
      lastKeyCode = keyCode;
    }
    // Neutralize Processing's default ESC behaviour by clearing key/keyCode
    key = 0;
    keyCode = 0;
    return;
  }

  // Store regular key
  if (key != CODED) {
    keyStates[key] = true;
    lastKey = key;
  }
  
  // Store special key
  if (keyCode != 0) {
    keyCodeStates[keyCode] = true;
    lastKeyCode = keyCode;
  }
  
  // Debug output
  if (app.gsm.current instanceof CalibrationState) {
    println("Key pressed: key=" + key + " (" + int(key) + "), keyCode=" + keyCode);
  }
}

// 🟢 ADD: Global key released handler  
void keyReleased() {
  // Prevent ESC from quitting the sketch.  As in keyPressed(), clear
  // the ESC event and mark it as released.
  if (key == ESC || keyCode == ESC) {
    // Clear ESC in global key state arrays
    if (keyCode >= 0 && keyCode < keyCodeStates.length) {
      keyCodeStates[keyCode] = false;
    }
    // Neutralize Processing's default ESC behaviour
    key = 0;
    keyCode = 0;
    return;
  }

  // Clear regular key
  if (key != CODED) {
    keyStates[key] = false;
  }
  
  // Clear special key
  if (keyCode != 0) {
    keyCodeStates[keyCode] = false;
  }
  
  // Debug output
  if (app.gsm.current instanceof CalibrationState) {
    println("Key released: key=" + key + " (" + int(key) + "), keyCode=" + keyCode);
  }
}

// 🟢 ADD: Helper method to check if a key is pressed (for states)
boolean isKeyPressed(char checkKey) {
  return keyStates[checkKey];
}

// 🟢 ADD: Helper method to check if a keyCode is pressed (for states)
boolean isKeyCodePressed(int checkKeyCode) {
  return keyCodeStates[checkKeyCode];
}

// 🟢 ADD: Helper to get Enter key
boolean isEnterPressed() {
  return keyCodeStates[ENTER] || keyCodeStates[RETURN];
}

// 🟢 ADD: Helper to get Escape key  
boolean isEscPressed() {
  return keyCodeStates[ESC];
}

// No custom exit() or stop() functions - cleanup is done in IdleState


