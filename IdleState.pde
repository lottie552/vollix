
/**
  IdleState - Start button gestures with proper multi-click detection:
    - Waits to see if click becomes double/triple before processing
    - Single click: Go to PlayingState (after timeout)
    - Double click: Go to BootState (hardware test)
    - Triple click: Go to CalibrationState
    - Long press (≥3s): Power off
    
  Detection logic:
    1. Button press starts timer
    2. Button release registers a click
    3. Wait MULTI_CLICK_MS to see if another click comes
    4. After timeout, process highest click count
*/
class IdleState implements IGameState {
  final App app;
  
  // Start button gesture tracking
  PhysicalButton startBtn;
  boolean btnDown = false;
  int btnDownAtMs = 0;
  
  // Click detection with waiting
  int clickCount = 0;
  int lastClickAtMs = 0;
  final int MULTI_CLICK_MS = 500;  // Time window for multi-click
  final int CLICK_DEBOUNCE_MS = 50;
  
  // Long press detection
  final int LONG_PRESS_MS = 3000;
  boolean longPressTriggered = false;
  
  // Timer for processing clicks after timeout
  int clickTimeoutAtMs = 0;
  boolean waitingForMoreClicks = false;
  
  IdleState(App app) {
    this.app = app;
    this.startBtn = app.hardware.startButton;
  }

  @Override 
  public void enterGameState() {
    println("=== IdleState.enterGameState() ===");
    
    // Set LEDs: all 3 life LEDs ON, all targets OFF
    app.hardware.showLives(3);
    app.hardware.targetsOff();
    
    // Reset gesture state
    resetGestureState();
    
    println("  Life LEDs ON, Targets OFF");
    println("  Waiting for start button gestures...");
    // Update mapping: 1 click -> Playing, 2 clicks -> Measurement,
    // 3 clicks -> Boot/Test, 4 clicks -> Calibration, Long press -> shutdown & save
    println("  Single=Play, Double=Measurement, Triple=Boot/Test, Quadruple=Calibrate, Long=Power off");
  }

  @Override 
  public void update(int nowMs) {
    if (startBtn == null) {
      println("ERROR: IdleState - startButton is null!");
      return;
    }
    
    // Check for button press/release
    if (startBtn.justPressed()) {
      handleButtonPress(nowMs);
    }
    
    if (startBtn.justReleased()) {
      handleButtonRelease(nowMs);
    }
    
    // Long press check (immediate)
    if (btnDown && !longPressTriggered) {
      int holdDuration = nowMs - btnDownAtMs;
      
      if (holdDuration >= LONG_PRESS_MS) {
        triggerLongPress();
        return; // Stop processing other gestures
      }
    }
    
    // Check if we're waiting for more clicks and timeout has passed
    if (waitingForMoreClicks && nowMs >= clickTimeoutAtMs) {
      processClicksAfterTimeout();
    }
  }

  @Override 
  public void render() {
    background(15, 20, 30);
    
    // Big white circle with home icon
    app.layout.drawCenterMarkerWithIcon(app.homeIcon);
    
    // Optional: Show click count for debugging
    if (clickCount > 0) {
      fill(255, 200, 100);
      textAlign(CENTER);
      textSize(16);
      text("Clicks: " + clickCount, width/2, height - 30);
    }
  }

  @Override 
  public void exitGameState() {
    println("=== IdleState.exitGameState() ===");
  }
  
  // -----------------------------------------------------------------
  // Gesture Handling Methods (FIXED)
  // -----------------------------------------------------------------
  
  void resetGestureState() {
    btnDown = false;
    btnDownAtMs = 0;
    clickCount = 0;
    lastClickAtMs = 0;
    longPressTriggered = false;
    waitingForMoreClicks = false;
    clickTimeoutAtMs = 0;
  }
  
  void handleButtonPress(int nowMs) {
    println("IdleState: Start button pressed");
    
    // If this is the first press in a new sequence, reset click count
    if (!waitingForMoreClicks || (nowMs - lastClickAtMs) >= MULTI_CLICK_MS) {
      clickCount = 0;
      waitingForMoreClicks = false;
    }
    
    btnDown = true;
    btnDownAtMs = nowMs;
    longPressTriggered = false;
  }
  
  void handleButtonRelease(int nowMs) {
    println("IdleState: Start button released");
    
    if (!btnDown) {
      return; // Safety check
    }
    
    int holdDuration = nowMs - btnDownAtMs;
    btnDown = false;
    
    // If long press was already triggered, ignore this release
    if (longPressTriggered) {
      println("  Long press already handled, ignoring release");
      return;
    }
    
    // If it was a very short press (might be bounce), ignore
    if (holdDuration < CLICK_DEBOUNCE_MS) {
      println("  Too short (" + holdDuration + "ms), ignoring as bounce");
      return;
    }
    
    // Register a click
    clickCount++;
    lastClickAtMs = nowMs;
    
    println("  Click registered (hold: " + holdDuration + "ms), count: " + clickCount);
    
    // Start/restart the timeout timer
    waitingForMoreClicks = true;
    clickTimeoutAtMs = nowMs + MULTI_CLICK_MS;
    
    println("  Waiting " + MULTI_CLICK_MS + "ms for more clicks...");
  }
  
  void processClicksAfterTimeout() {
    println("=== CLICK TIMEOUT REACHED ===");
    println("  Processing " + clickCount + " click(s)");
    
    waitingForMoreClicks = false;
    
    switch (clickCount) {
      case 1:
        triggerSingleClick();
        break;
      case 2:
        triggerDoubleClick();
        break;
      case 3:
        triggerTripleClick();
        break;
      case 4:
        triggerQuadrupleClick();
        break;
      default:
        println("  Warning: Unexpected click count: " + clickCount);
        if (clickCount == 4) {
          triggerQuadrupleClick();
        } else if (clickCount == 3) {
          triggerTripleClick();
        } else if (clickCount == 2) {
          triggerDoubleClick();
        } else {
          triggerSingleClick();
        }
        break;
    }
    
    // Reset for next gesture sequence
    resetGestureState();
  }
  
  void triggerLongPress() {
    println("=== LONG PRESS DETECTED (" + LONG_PRESS_MS + "ms) ===");
    println("  Powering off...");
    
    longPressTriggered = true;
    
    // Before shutting down, save any accumulated measurement log to CSV
    try {
      app.saveMeasurementLogToCSV();
    } catch (Exception e) {
      println("  Error saving measurement log: " + e);
    }
    // Visual feedback: blink all LEDs
    for (int i = 0; i < 3; i++) {
      app.hardware.allLedsOff();
      delay(100);
      app.hardware.showLives(3);
      delay(100);
    }
    app.hardware.allLedsOff();
    // Shutdown all GPIO devices
    shutdownAllGpioDevices();
    // Kill any remaining gpioset processes
    killStrayGpiosetProcesses();
    // Brief delay to ensure cleanup completes
    delay(100);
    println("=== EXITING APPLICATION ===");
    exit();
  }
  
  void triggerSingleClick() {
    println("=== SINGLE CLICK DETECTED ===");
    println("  Transitioning to PlayingState");
    app.gsm.setState(new PlayingState(app));
  }
  
  void triggerDoubleClick() {
    println("=== DOUBLE CLICK DETECTED ===");
    // 2-click -> MeasurementState
    println("  Transitioning to MeasurementState");
    app.gsm.setState(new MeasurementState(app));
  }
  
  void triggerTripleClick() {
    println("=== TRIPLE CLICK DETECTED ===");
    // 3-click -> Boot/Test
    println("  Transitioning to BootState");
    app.gsm.setState(new BootState(app));
  }

  // Handle quadruple click
  void triggerQuadrupleClick() {
    println("=== QUADRUPLE CLICK DETECTED ===");
    println("  Transitioning to CalibrationState");
    app.gsm.setState(new CalibrationState(app));
  }
  
  // ... (shutdown methods remain the same - keep from previous version) ...
  
  void shutdownAllGpioDevices() {
    println("  Shutting down all GPIO devices...");
    
    for (int i = 0; i < app.hardware.lifeLeds.size(); i++) {
      try { app.hardware.lifeLeds.get(i).shutdown(); } catch (Exception e) {}
    }
    
    for (int i = 0; i < app.hardware.targetLeds.size(); i++) {
      try { app.hardware.targetLeds.get(i).shutdown(); } catch (Exception e) {}
    }
    
    if (app.hardware.startButton != null) {
      try { app.hardware.startButton.shutdown(); } catch (Exception e) {}
    }
    
    for (int i = 0; i < app.hardware.targetButtons.size(); i++) {
      try { app.hardware.targetButtons.get(i).shutdown(); } catch (Exception e) {}
    }
    
    println("  GPIO devices shutdown complete");
  }
  
  void killStrayGpiosetProcesses() {
    println("  Killing stray gpioset processes...");
    
    try {
      Process p = Runtime.getRuntime().exec("pkill gpioset");
      int exitCode = p.waitFor();
      
      if (exitCode != 0) {
        Process p2 = Runtime.getRuntime().exec("pkill -9 gpioset");
        p2.waitFor();
        println("  Used SIGKILL (pkill -9) for gpioset processes");
      } else {
        println("  pkill gpioset executed successfully");
      }
      
    } catch (Exception e) {
      println("  Error killing gpioset processes: " + e);
      
      try {
        Process p3 = Runtime.getRuntime().exec("killall gpioset");
        p3.waitFor();
        println("  Tried killall as fallback");
      } catch (Exception e2) {
        println("  killall also failed: " + e2);
      }
    }
  }
}



