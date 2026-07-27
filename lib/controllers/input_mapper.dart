/// Arcade / libretro control actions (mirrors NES ControlAction pattern).
enum ControlAction {
  up('UP', 'Joystick Up'),
  down('DOWN', 'Joystick Down'),
  left('LEFT', 'Joystick Left'),
  right('RIGHT', 'Joystick Right'),
  a('A', 'Button A'),
  b('B', 'Button B'),
  c('C', 'Button C'),
  d('D', 'Button D'),
  coin('COIN', 'Insert Coin (Select)'),
  start('START', 'Start'),
  saveState('SAVE', 'Quick Save State'),
  loadState('LOAD', 'Quick Load State'),
  pause('PAUSE', 'Pause / Resume'),
  reset('RESET', 'Soft Reset'),
  slotPrev('SLOT−', 'Previous Save Slot'),
  slotNext('SLOT+', 'Next Save Slot');

  const ControlAction(this.shortLabel, this.description);

  final String shortLabel;
  final String description;
}

const List<ControlAction> kMappableActions = ControlAction.values;
