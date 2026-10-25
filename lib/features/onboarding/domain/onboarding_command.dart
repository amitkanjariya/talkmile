enum OnboardingCommand { next, back, repeat }

OnboardingCommand? interpretOnboardingCommand(String words) {
  final input = words.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
  if (RegExp(r'\b(back|previous|go back)\b').hasMatch(input)) {
    return OnboardingCommand.back;
  }
  if (RegExp(r'\b(repeat|again|say that again)\b').hasMatch(input)) {
    return OnboardingCommand.repeat;
  }
  if (RegExp(r'\b(next|continue|choose|done|finish)\b').hasMatch(input)) {
    return OnboardingCommand.next;
  }
  return null;
}
