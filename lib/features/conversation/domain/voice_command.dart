enum VoiceCommand {
  repeat,
  slower,
  hint,
  simpler,
  changeTopic,
  continueStory,
  anotherQuestion,
  harder,
  easier,
  male,
  female,
  mistake,
}

VoiceCommand? interpretVoiceCommand(String utterance) {
  final input = utterance
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), '')
      .trim();
  if (RegExp(r'^(please )?(repeat|say that again|repeat that)').hasMatch(input)) {
    return VoiceCommand.repeat;
  }
  if (input.contains('more slowly') || input.contains('slow down')) {
    return VoiceCommand.slower;
  }
  if (input.contains('hint')) return VoiceCommand.hint;
  if (input.contains('explain it simply') || input.contains('simpler words')) {
    return VoiceCommand.simpler;
  }
  if (input.contains('change the topic') || input.contains('new topic')) {
    return VoiceCommand.changeTopic;
  }
  if (input.contains('continue the story')) return VoiceCommand.continueStory;
  if (input.contains('another question')) return VoiceCommand.anotherQuestion;
  if (input.contains('more difficult') || input.contains('make it harder')) {
    return VoiceCommand.harder;
  }
  if (input.contains('make it easier') || input.contains('too difficult')) {
    return VoiceCommand.easier;
  }
  if (input.contains('female voice')) return VoiceCommand.female;
  if (input.contains('male voice')) return VoiceCommand.male;
  if (input.contains('my mistake') || input.contains('correct me')) {
    return VoiceCommand.mistake;
  }
  return null;
}
