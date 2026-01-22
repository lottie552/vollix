class GameStateMachine {
  IGameState current;

  void setState(IGameState next) {
    if (current != null) current.exitGameState();
    current = next;
    if (current != null) current.enterGameState();
  }

  void update(int nowMs) {
    if (current != null) current.update(nowMs);
  }

  void render() {
    if (current != null) current.render();
  }
}



