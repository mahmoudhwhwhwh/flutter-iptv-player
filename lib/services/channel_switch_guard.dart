class ChannelSwitchGuard {
  int _generation = 0;

  int begin() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  int get currentGeneration => _generation;
}
