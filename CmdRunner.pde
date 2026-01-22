/**
  CmdRunner
  Purpose:
    Run shell commands and capture stdout/stderr (merged) as a single string.

  Notes:
    - Generic utility, but used primarily by GPIO backend drivers.
    - Throws GpioCommandException on non-zero exit or execution failure.
*/
class CmdRunner {

  /** Run a command and return stdout (stderr merged) as a trimmed string. */
  String run(String[] command, String debugLabel) {
    try {
      ProcessBuilder pb = new ProcessBuilder(command);
      pb.redirectErrorStream(true);
      Process p = pb.start();

      java.io.BufferedReader br =
        new java.io.BufferedReader(new java.io.InputStreamReader(p.getInputStream()));

      StringBuilder out = new StringBuilder();
      String line;
      while ((line = br.readLine()) != null) {
        out.append(line).append("\n");
      }

      int exitCode = p.waitFor();
      String output = out.toString().trim();

      if (exitCode != 0) {
        throw new GpioCommandException(
          debugLabel + " failed (exit " + exitCode + "): " + String.join(" ", command) + "\n" + output
        );
      }

      return output;
    } catch (Exception e) {
      if (e instanceof GpioCommandException) throw (GpioCommandException)e;
      throw new GpioCommandException(debugLabel + " failed: " + String.join(" ", command), e);
    }
  }

  /**
    Start a long-running process (e.g., gpioset holding a line).
    Caller owns the Process and must destroy it later.
  */
  Process start(String[] command, String debugLabel) {
    try {
      ProcessBuilder pb = new ProcessBuilder(command);
      pb.redirectErrorStream(true);
      return pb.start();
    } catch (Exception e) {
      throw new GpioCommandException(debugLabel + " start failed: " + String.join(" ", command), e);
    }
  }
}



