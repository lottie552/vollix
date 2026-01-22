class App {
  final Hardware hardware;
  final VisualLayout layout;
  final GameStateMachine gsm;

  final PShape homeIcon;
  final PShape adjustIcon;
  final PShape hintIcon;      // 🟢 CHANGED: For BootState (lightbulb)
  final PShape candyIcon;     // For PlayingState (LEFT foot)
  final PShape cupcakeIcon;   // For PlayingState (RIGHT foot)

  // ======================================================================
  // Measurement logging
  //
  // A global Table used to accumulate reaction speed diagnostic runs.
  // Each row corresponds to a single measurement session (10 balls).
  // The columns include:
  //   - datetime (string)  : ISO timestamp of when measurement started
  //   - subject_id (int)   : ID entered via numeric keypad
  //   - measurement_moment (string): "before" or "after" depending on B/A input
  //   - test_condition (string): "game" or "real" depending on G/R input
  //   - rt1..rt10 (float)  : reaction times in milliseconds for each ball
  //
  // The table is kept in memory during the application run.  On shutdown
  // (long press in IdleState) the table is appended to a CSV file on disk.
  Table measurementLog;

  // 🟢 CHANGED: Updated constructor to include hint icon
  App(Hardware hardware, VisualLayout layout,
    PShape homeIcon, PShape adjustIcon,
    PShape hintIcon, PShape candyIcon, PShape cupcakeIcon) {
    this.hardware = hardware;
    this.layout = layout;
    this.homeIcon = homeIcon;
    this.adjustIcon = adjustIcon;
    this.hintIcon = hintIcon;       // 🟢 CHANGED
    this.candyIcon = candyIcon;
    this.cupcakeIcon = cupcakeIcon;
    gsm = new GameStateMachine();

    // Initialise measurement log
    initMeasurementLog();
  }

  void update(int nowMs) {
    gsm.update(nowMs);
  }
  void render() {
    gsm.render();
  }

  // -------------------------------------------------------------------
  // Measurement logging helpers
  //
  // Initialise the measurement table if it hasn't been created yet.
  void initMeasurementLog() {
    if (measurementLog == null) {
      measurementLog = new Table();
      measurementLog.addColumn("datetime");
      measurementLog.addColumn("subject_id");
      // Use string columns for measurement moment and test condition.  These
      // store words ("before"/"after" and "game"/"real") instead of booleans.
      measurementLog.addColumn("measurement_moment");
      measurementLog.addColumn("test_condition");
      for (int i = 1; i <= 10; i++) {
        measurementLog.addColumn("rt" + i);
      }
    }
  }

  // Append all rows currently in measurementLog to the CSV file on disk.
  // If the file exists, load it and append new rows; otherwise create it.
  // After saving, the measurementLog is left intact so additional
  // measurements can be appended during the same run.
  void saveMeasurementLogToCSV() {
    // Nothing to save
    if (measurementLog == null || measurementLog.getRowCount() == 0) {
      println("No measurement log entries to save");
      return;
    }

    String filename = "measurement_log.csv";
    Table existing = null;
    // Try loading existing file with header
    try {
      existing = loadTable(filename, "header");
    } catch (Exception e) {
      existing = null;
    }

    if (existing != null) {
      // Append all rows from measurementLog
      for (int r = 0; r < measurementLog.getRowCount(); r++) {
        TableRow srcRow = measurementLog.getRow(r);
        TableRow newRow = existing.addRow();
        // Copy each column by name
        for (String col : measurementLog.getColumnTitles()) {
          newRow.setString(col, srcRow.getString(col));
        }
      }
      saveTable(existing, filename);
      println("Appended " + measurementLog.getRowCount() + " measurement(s) to " + filename);
    } else {
      // No existing file, write new
      saveTable(measurementLog, filename);
      println("Saved measurement log to new file " + filename);
    }
  }
}




