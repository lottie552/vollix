interface IGameState {
  void enterGameState();
  void update(int nowMs);
  void render();
  void exitGameState();
}



