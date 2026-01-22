/**
  CalibrationState - Center also needs scaling
*/
class CalibrationState implements IGameState {
  final App app;
  
  // Calibration phases
  static final int PHASE_CENTER = 0;
  static final int PHASE_TARGETS = 1;
  static final int PHASE_DONE = 2;
  
  int phase = PHASE_CENTER;
  int currentTargetIndex = -1;
  Target currentTarget = null;
  
  // Calibration values
  PVector centerPos;
  float centerScale = 1.0f;  // 🟢 ADD: Center scale
  ArrayList<PVector> targetPositions;
  ArrayList<Float> targetRotations;
  ArrayList<Float> targetScales;
  
  // Movement speed
  final float MOVE_SPEED = 5.0f;
  // Rotation speed for target calibration (degrees per frame)
  // Originally 15°, but reduced to 5° for finer control
  final float ROTATE_SPEED = radians(5);
  final float SCALE_SPEED = 0.1f;
  
  // Current transform being edited
  PVector currentPos;
  float currentRot = 0.0f;
  float currentScale = 1.0f;
  
  // Enter key debouncing
  int lastEnterPressFrame = 0;
  final int ENTER_DEBOUNCE_FRAMES = 10;
  
  CalibrationState(App app) {
    this.app = app;
  }
  
  @Override
  public void enterGameState() {
    println("=== CalibrationState.enterGameState() ===");
    println("  Keyboard controls only - physical buttons are IGNORED");
    println("  WASD: Move, Arrows: Rotate/Scale, ENTER: Confirm, ESC: Cancel");
    println("  NOTE: Center also scales with Up/Down arrows");
    
    // Initialize from current layout
    centerPos = app.layout.center.copy();
    centerScale = 1.0f;  // 🟢 Default center scale
    targetPositions = new ArrayList<PVector>();
    targetRotations = new ArrayList<Float>();
    targetScales = new ArrayList<Float>();
    
    // Copy current values
    for (int i = 0; i < app.layout.getTargetCount(); i++) {
      targetPositions.add(app.layout.getTargetPosition(i).copy());
      targetRotations.add(app.layout.getTargetRotation(i));
      targetScales.add(1.0f);
    }
    
    // Start with center calibration
    phase = PHASE_CENTER;
    currentPos = centerPos.copy();
    currentRot = 0.0f;  // Center doesn't rotate, but we keep the variable for consistency
    currentScale = centerScale;
    
    // Turn off all LEDs initially
    app.hardware.allLedsOff();
    
    println("  Starting with CENTER calibration (position and scale)");
  }
  
  @Override
  public void update(int nowMs) {
    // Check for ESC to cancel (immediate)
    if (isEscPressed()) {
      println("  ESC pressed - Calibration cancelled");
      app.gsm.setState(new IdleState(app));
      return;
    }
    
    // Process movement keys (WASD)
    processMovementKeys();
    
    // Process arrow keys
    processArrowKeys();
    
    // Process Enter key (with debouncing)
    processEnterKey();
  }
  
  @Override
  public void render() {
    background(20, 25, 40);
    
    // 🟢 UPDATED: Draw center with current calibration scale
    drawCenterWithCurrentCalibration();
    
    // Show current calibration item
    if (phase == PHASE_CENTER) {
      drawCenterCalibration();
    } else if (phase == PHASE_TARGETS && currentTarget != null) {
      drawTargetCalibration();
    } else if (phase == PHASE_DONE) {
      drawCompletion();
    }
  }
  
  @Override
  public void exitGameState() {
    println("=== CalibrationState.exitGameState() ===");
    app.hardware.allLedsOff();
  }
  
  // -----------------------------------------------------------------
  // Keyboard Processing Methods
  // -----------------------------------------------------------------
  
  void processMovementKeys() {
    // When the game view is rotated 180° for projection, invert
    // the movement directions so that W/A/S/D controls feel the
    // same to the person calibrating from the projector side. Pressing
    // W will move the current position *down* in screen coordinates,
    // S will move it *up*, A will move it *right*, and D will move it
    // *left*. Without rotation these would have been the opposite.
    if (isKeyPressed('w') || isKeyPressed('W')) {
      currentPos.y += MOVE_SPEED;
    }
    if (isKeyPressed('s') || isKeyPressed('S')) {
      currentPos.y -= MOVE_SPEED;
    }
    if (isKeyPressed('a') || isKeyPressed('A')) {
      currentPos.x += MOVE_SPEED;
    }
    if (isKeyPressed('d') || isKeyPressed('D')) {
      currentPos.x -= MOVE_SPEED;
    }
    
    // Constrain to screen
    currentPos.x = constrain(currentPos.x, 0, width);
    currentPos.y = constrain(currentPos.y, 0, height);
  }
  
  void processArrowKeys() {
    // 🟢 UPDATED: Different behavior for center vs targets
    
    if (phase == PHASE_CENTER) {
      // CENTER PHASE: Only Up/Down arrows work (for scaling)
      // Center doesn't rotate, so Left/Right arrows do nothing
      
      // Up arrow: scale up center.  Increase max scale to allow
      // larger calibration positions for floor projection (was 3.0f).
      if (isKeyCodePressed(UP)) {
        currentScale += SCALE_SPEED;
        currentScale = constrain(currentScale, 0.5f, 4.0f);
        println("  Center Scale: " + nf(currentScale * 100, 0, 0) + "%");
      }
      
      // Down arrow: scale down center
      if (isKeyCodePressed(DOWN)) {
        currentScale -= SCALE_SPEED;
        currentScale = constrain(currentScale, 0.5f, 4.0f);
        println("  Center Scale: " + nf(currentScale * 100, 0, 0) + "%");
      }
      
      // Left/Right arrows do nothing for center (no rotation)
      
    } else if (phase == PHASE_TARGETS) {
      // TARGET PHASE: All arrows work (rotate and scale)
      
      // Left arrow: rotate counter-clockwise
      if (isKeyCodePressed(LEFT)) {
        currentRot -= ROTATE_SPEED;
        println("  Rotation: " + degrees(currentRot) + "°");
      }
      
      // Right arrow: rotate clockwise
      if (isKeyCodePressed(RIGHT)) {
        currentRot += ROTATE_SPEED;
        println("  Rotation: " + degrees(currentRot) + "°");
      }
      
      // Up arrow: scale up target.  Increase max scale to allow
      // larger foot targets (was 2.0f).
      if (isKeyCodePressed(UP)) {
        currentScale += SCALE_SPEED;
        currentScale = constrain(currentScale, 0.5f, 10.0f);
        println("  Scale: " + nf(currentScale * 100, 0, 0) + "%");
      }
      
      // Down arrow: scale down target
      if (isKeyCodePressed(DOWN)) {
        currentScale -= SCALE_SPEED;
        currentScale = constrain(currentScale, 0.5f, 10.0f);
        println("  Scale: " + nf(currentScale * 100, 0, 0) + "%");
      }
    }
  }
  
  void processEnterKey() {
    if (isEnterPressed() && (frameCount - lastEnterPressFrame) > ENTER_DEBOUNCE_FRAMES) {
      lastEnterPressFrame = frameCount;
      handleConfirm();
    }
  }
  
  // -----------------------------------------------------------------
  // Calibration Logic
  // -----------------------------------------------------------------
  
  void handleConfirm() {
    println("  ENTER pressed - confirming calibration");
    
    if (phase == PHASE_CENTER) {
      // 🟢 UPDATED: Save center position AND scale
      centerPos = currentPos.copy();
      centerScale = currentScale;
      // Save the calibrated center position and scale into VisualLayout
      app.layout.setCenter(centerPos);
      app.layout.setCenterScale(centerScale);
      
      println("  ✓ Center calibrated:");
      println("    Position: " + centerPos.x + ", " + centerPos.y);
      println("    Scale: " + nf(centerScale * 100, 0, 0) + "%");
      
      startNextTarget();
      
    } else if (phase == PHASE_TARGETS && currentTarget != null) {
      int index = app.hardware.targets.indexOf(currentTarget);
      targetPositions.set(index, currentPos.copy());
      targetRotations.set(index, currentRot);
      targetScales.set(index, currentScale);
      
      app.layout.setTargetPosition(index, currentPos);
      app.layout.setTargetRotation(index, currentRot);
      // Save calibrated scale into VisualLayout so PlayingState can use it
      app.layout.setTargetScale(index, currentScale);
      
      println("  ✓ Target " + currentTarget.id + " calibrated:");
      println("    Position: " + currentPos.x + ", " + currentPos.y);
      println("    Rotation: " + degrees(currentRot) + "°");
      println("    Scale: " + nf(currentScale * 100, 0, 0) + "%");
      
      currentTarget.off();
      startNextTarget();
    }
  }
  
  void startNextTarget() {
    ArrayList<Target> targets = app.hardware.targets;
    
    if (currentTargetIndex < targets.size() - 1) {
      currentTargetIndex++;
      currentTarget = targets.get(currentTargetIndex);
      
      currentPos = targetPositions.get(currentTargetIndex).copy();
      currentRot = targetRotations.get(currentTargetIndex);
      currentScale = targetScales.get(currentTargetIndex);
      
      app.hardware.allLedsOff();
      currentTarget.on();
      
      println("  ➤ Calibrating target: " + currentTarget.id + 
              " (group: " + currentTarget.group + ")");
      println("    Use WASD=move, ←→=rotate, ↑↓=scale, ENTER=confirm");
      
      phase = PHASE_TARGETS;
    } else {
      phase = PHASE_DONE;
      currentTarget = null;
      app.hardware.allLedsOff();
      
      // 🟢 UPDATED: Save all calibration data (including scales)
      saveCalibrationData();
      
      println("  ✅ All calibration complete!");
      println("  Returning to IdleState in 2 seconds...");
      
      // Return to IdleState after delay
      // Start a new thread to return to idle after a short delay
new Thread(new Runnable() {
  public void run() {
    try {
      Thread.sleep(2000);
    } catch (InterruptedException e) {
      // ignore
    }
    app.gsm.setState(new IdleState(app));
  }
}).start();

    }
  }
  
  // 🟢 NEW: Save calibration data (including scales)
  void saveCalibrationData() {
    println("  Saving calibration data...");
    
    // For now, we just print it. Later you could save to a file:
    println("  Center: pos(" + centerPos.x + ", " + centerPos.y + "), scale=" + centerScale);
    
    for (int i = 0; i < app.hardware.targets.size(); i++) {
      Target t = app.hardware.targets.get(i);
      println("  Target " + t.id + ": pos(" + targetPositions.get(i).x + ", " + 
              targetPositions.get(i).y + "), rot=" + degrees(targetRotations.get(i)) + 
              "°, scale=" + targetScales.get(i));
    }
    
    // 🟢 TODO: In the future, save to a JSON or text file
    // saveJSONObject(calibrationData, "data/calibration.json");
  }
  
  // -----------------------------------------------------------------
  // Rendering Methods
  // -----------------------------------------------------------------
  
  void drawCenterWithCurrentCalibration() {
    // 🟢 UPDATED: Draw center with current scale during calibration
    noStroke();
    fill(255);
    
    // Use currentScale when in CENTER phase, otherwise use saved centerScale
    float drawScale = (phase == PHASE_CENTER) ? currentScale : centerScale;
    float baseRadius = app.layout.centerRadius() * 0.8;
    float scaledRadius = baseRadius * drawScale;
    
    circle(centerPos.x, centerPos.y, scaledRadius * 2);
    
    // Adjust icon on top (also scaled)
    float iconSize = app.layout.iconSize() * drawScale;
    shape(app.adjustIcon, centerPos.x, centerPos.y, iconSize, iconSize);
  }
  
  void drawCenterCalibration() {
    // Draw editing crosshair at current position
    noStroke();
    fill(100, 255, 100, 150);
    
    // Crosshair
    float crossSize = 20;
    line(currentPos.x - crossSize, currentPos.y, currentPos.x + crossSize, currentPos.y);
    line(currentPos.x, currentPos.y - crossSize, currentPos.x, currentPos.y + crossSize);
    
    // Circle around editing position
    noFill();
    stroke(100, 255, 100, 200);
    strokeWeight(2);
    circle(currentPos.x, currentPos.y, 40);
    noStroke();
    
    // Scale indicator
    fill(100, 255, 255, 200);
    textAlign(CENTER);
    textSize(14);
    text("Scale: " + nf(currentScale * 100, 0, 0) + "%", currentPos.x, currentPos.y - 50);
    
    // Instructions
    fill(255, 255, 100);
    textSize(12);
    text("WASD: Move   ↑↓: Scale   ENTER: Confirm", width/2, height - 40);
    text("Center position and scale (no rotation)", width/2, height - 25);
  }
  
  void drawTargetCalibration() {
    if (currentTarget == null) return;
    
    // Choose correct foot icon
    PShape footIcon = getFootIconForTarget(currentTarget);
    
    // Draw foot guide at current calibration
    shapeMode(CENTER);
    
    pushMatrix();
    translate(currentPos.x, currentPos.y);
    rotate(currentRot);
    scale(currentScale);
    
    tint(255, 255, 100, 230);  // Yellow during calibration
    
    float footSize = 80;
    shape(footIcon, 0, 0, footSize, footSize);
    noTint();
    popMatrix();
    
    // Draw crosshair at position
    noStroke();
    fill(255, 200, 100, 150);
    float crossSize = 15;
    line(currentPos.x - crossSize, currentPos.y, currentPos.x + crossSize, currentPos.y);
    line(currentPos.x, currentPos.y - crossSize, currentPos.x, currentPos.y + crossSize);
    
    // Calibration info
    fill(100, 255, 255, 200);
    textAlign(CENTER);
    textSize(14);
    text("Target: " + currentTarget.id + " (" + currentTarget.group + ")", 
         currentPos.x, currentPos.y - 60);
    text("Rot: " + nf(degrees(currentRot), 0, 0) + "°  Scale: " + 
         nf(currentScale * 100, 0, 0) + "%", currentPos.x, currentPos.y - 45);
    
    // Instructions
    fill(255, 255, 100);
    textSize(12);
    text("WASD: Move   ←→: Rotate   ↑↓: Scale   ENTER: Confirm", width/2, height - 40);
    text("Calibrating " + (currentTarget.group.equals("LEFT") ? "RIGHT" : "LEFT") + 
         " foot for " + currentTarget.group + " target", width/2, height - 25);
  }
  
  void drawCompletion() {
    // Flash all targets
    if (frameCount % 30 < 15) {
      for (Target t : app.hardware.targets) {
        t.on();
      }
    } else {
      app.hardware.allLedsOff();
    }
    
    // Completion message
    fill(100, 255, 100);
    textAlign(CENTER);
    textSize(20);
    text("✓ Calibration Complete!", width/2, height/2);
    textSize(14);
    text("Returning to IdleState...", width/2, height/2 + 30);
  }
  
  PShape getFootIconForTarget(Target target) {
    if (target.group.equals("LEFT")) {
      return app.cupcakeIcon;  // RIGHT foot for LEFT target
    } else if (target.group.equals("RIGHT")) {
      return app.candyIcon;    // LEFT foot for RIGHT target
    }
    return app.candyIcon;
  }
}




