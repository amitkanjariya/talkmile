class PracticeTopic {
  const PracticeTopic(this.title, this.category);
  final String title;
  final String category;
}

const practiceTopics = <PracticeTopic>[
  PracticeTopic('A good morning routine', 'Everyday'),
  PracticeTopic('Cooking a favorite meal', 'Everyday'),
  PracticeTopic('A small win this week', 'Everyday'),
  PracticeTopic('A place that feels peaceful', 'Everyday'),
  PracticeTopic('Planning a weekend', 'Everyday'),
  PracticeTopic('A useful habit', 'Everyday'),
  PracticeTopic('A memorable celebration', 'Everyday'),
  PracticeTopic('Helping someone', 'Everyday'),
  PracticeTopic('A hobby you want to try', 'Everyday'),
  PracticeTopic('Your ideal home', 'Everyday'),
  PracticeTopic('A favorite childhood memory', 'People'),
  PracticeTopic('Someone who inspires you', 'People'),
  PracticeTopic('A family tradition', 'People'),
  PracticeTopic('Making a new friend', 'People'),
  PracticeTopic('A thoughtful gift', 'People'),
  PracticeTopic('A funny misunderstanding', 'People'),
  PracticeTopic('A good conversation', 'People'),
  PracticeTopic('What makes a good neighbor', 'People'),
  PracticeTopic('A trip you remember', 'Travel'),
  PracticeTopic('Planning a dream trip', 'Travel'),
  PracticeTopic('Getting around a new city', 'Travel'),
  PracticeTopic('Trying local food', 'Travel'),
  PracticeTopic('A place you would revisit', 'Travel'),
  PracticeTopic('A travel problem solved', 'Travel'),
  PracticeTopic('A day at the beach', 'Travel'),
  PracticeTopic('Asking for directions', 'Travel'),
  PracticeTopic('Your first day at a job', 'Work'),
  PracticeTopic('A skill you use at work', 'Work'),
  PracticeTopic('Working well in a team', 'Work'),
  PracticeTopic('A polite way to disagree', 'Work'),
  PracticeTopic('A goal for this year', 'Work'),
  PracticeTopic('Learning from a mistake', 'Work'),
  PracticeTopic('A job you would enjoy', 'Work'),
  PracticeTopic('Making a good first impression', 'Work'),
  PracticeTopic('A technology you find useful', 'Ideas'),
  PracticeTopic('A book or film you recommend', 'Ideas'),
  PracticeTopic('What makes a city comfortable', 'Ideas'),
  PracticeTopic('A small change that helps nature', 'Ideas'),
  PracticeTopic('A skill everyone should learn', 'Ideas'),
  PracticeTopic('What a perfect day means to you', 'Ideas'),
];

class StoryPrompt {
  const StoryPrompt(this.title, this.genre, this.opening);
  final String title;
  final String genre;
  final String opening;
}

const storyPrompts = <StoryPrompt>[
  StoryPrompt(
    'The late train',
    'Everyday',
    'A stranger offers you the only empty seat.',
  ),
  StoryPrompt(
    'The new neighbor',
    'Everyday',
    'A package arrives with the wrong name.',
  ),
  StoryPrompt(
    'The family recipe',
    'Everyday',
    'One ingredient is missing before dinner.',
  ),
  StoryPrompt(
    'The first day',
    'Work',
    'Your new team has an unexpected tradition.',
  ),
  StoryPrompt(
    'The important meeting',
    'Work',
    'A surprising visitor changes the plan.',
  ),
  StoryPrompt(
    'The lost suitcase',
    'Travel',
    'You find a clue on the baggage tag.',
  ),
  StoryPrompt(
    'The hidden café',
    'Travel',
    'A side street leads to a tiny café.',
  ),
  StoryPrompt(
    'The missed bus',
    'Travel',
    'A local offers to show you another way.',
  ),
  StoryPrompt(
    'The quiet museum',
    'Mystery',
    'A note appears beside an old painting.',
  ),
  StoryPrompt(
    'The empty house',
    'Mystery',
    'A light turns on in a house no one visits.',
  ),
  StoryPrompt(
    'The old photograph',
    'Mystery',
    'Someone in the picture looks familiar.',
  ),
  StoryPrompt('The island map', 'Adventure', 'A hand-drawn map washes ashore.'),
  StoryPrompt(
    'The mountain path',
    'Adventure',
    'You hear music beyond the trail.',
  ),
  StoryPrompt(
    'The night market',
    'Adventure',
    'A seller offers you a curious invitation.',
  ),
  StoryPrompt(
    'The helpful robot',
    'Sci-fi',
    'It asks you to teach it one human custom.',
  ),
  StoryPrompt(
    'The quiet signal',
    'Sci-fi',
    'A message arrives from an unknown station.',
  ),
  StoryPrompt(
    'The garden gate',
    'Fantasy',
    'A new path appears behind the old gate.',
  ),
  StoryPrompt(
    'The borrowed umbrella',
    'Romance',
    'A note is tucked into its handle.',
  ),
  StoryPrompt(
    'The school reunion',
    'People',
    'An old friend remembers a different story.',
  ),
  StoryPrompt(
    'The surprise party',
    'People',
    'The guest of honor arrives early.',
  ),
];

class CoachPersona {
  const CoachPersona(
    this.id,
    this.name,
    this.age,
    this.gender,
    this.role,
    this.style,
  );
  final String id;
  final String name;
  final String age;
  final String gender;
  final String role;
  final String style;
}

const coachPersonas = <CoachPersona>[
  CoachPersona(
    'mira',
    'Mira',
    '29',
    'female',
    'female friend',
    'warm, open, easygoing',
  ),
  CoachPersona('arun', 'Arun', '32', 'male', 'male friend', 'clear, practical'),
  CoachPersona(
    'leena',
    'Leena',
    '28',
    'female',
    'girlfriend',
    'affectionate, playful, respectful',
  ),
  CoachPersona(
    'kabir',
    'Kabir',
    '38',
    'male',
    'husband',
    'steady, caring, lightly humorous',
  ),
  CoachPersona(
    'nisha',
    'Nisha',
    '36',
    'female',
    'wife',
    'warm, supportive, direct',
  ),
  CoachPersona('dev', 'Dev', '25', 'male', 'college friend', 'casual, upbeat'),
  CoachPersona(
    'sara',
    'Sara',
    '33',
    'female',
    'ex-girlfriend and old friend',
    'mature, friendly, respectful',
  ),
  CoachPersona(
    'imran',
    'Imran',
    '44',
    'male',
    'office colleague',
    'kind, grounded, professional',
  ),
  CoachPersona(
    'tara',
    'Tara',
    '39',
    'female',
    'school friend',
    'nostalgic, lively, warm',
  ),
  CoachPersona(
    'rohan',
    'Rohan',
    '31',
    'male',
    'neighbor and friend',
    'playful, imaginative',
  ),
];

CoachPersona personaFor(String id) => coachPersonas.firstWhere(
  (persona) => persona.id == id,
  orElse: () => coachPersonas.first,
);

class DailyWord {
  const DailyWord(this.word, this.meaning, this.example);
  final String word;
  final String meaning;
  final String example;

  factory DailyWord.fromJson(Map<String, dynamic> json) => DailyWord(
    json['word'] as String,
    json['meaning'] as String,
    json['example'] as String,
  );
}

const vocabularyBank = <DailyWord>[
  DailyWord(
    'considerate',
    'thoughtful of others',
    'It was considerate to call ahead.',
  ),
  DailyWord(
    'reliable',
    'able to be trusted',
    'She is reliable and arrives on time.',
  ),
  DailyWord(
    'overwhelmed',
    'feeling that there is too much to handle',
    'I felt overwhelmed by all the work this week.',
  ),
  DailyWord(
    'postpone',
    'to arrange for something to happen later',
    'We had to postpone dinner because I was working late.',
  ),
  DailyWord(
    'clarify',
    'to make an idea or detail easier to understand',
    'Could you clarify what time we are meeting?',
  ),
  DailyWord(
    'sort out',
    'to solve a problem or put things in order',
    'I need to sort out a few things before the trip.',
  ),
  DailyWord(
    'compromise',
    'an agreement where each person gives up something',
    'We reached a compromise about where to spend the holiday.',
  ),
  DailyWord(
    'reassure',
    'to help someone feel less worried',
    'She reassured me that everything was under control.',
  ),
  DailyWord(
    'worthwhile',
    'useful or valuable enough to justify the time or effort',
    'The extra practice was worthwhile before my interview.',
  ),
  DailyWord(
    'keep track of',
    'to stay informed about or remember something',
    'I use a note to keep track of my weekly expenses.',
  ),
  DailyWord(
    'appreciate',
    'to feel thankful for',
    'I appreciate your honest advice.',
  ),
  DailyWord(
    'reluctant',
    'not willing or eager to do something',
    'I was reluctant to cancel our plans at the last minute.',
  ),
  DailyWord(
    'bring up',
    'to start talking about a subject',
    'He brought up the travel plan during lunch.',
  ),
  DailyWord(
    'opportunity',
    'a good chance to do something',
    'The course gave me an opportunity to speak.',
  ),
  DailyWord(
    'awkward',
    'slightly uncomfortable or difficult to handle',
    'It felt awkward to bring up the problem with my friend.',
  ),
  DailyWord(
    'manageable',
    'easy enough to deal with successfully',
    'The workload feels manageable if I plan ahead.',
  ),
  DailyWord(
    'hesitant',
    'uncertain about doing or saying something',
    'I was hesitant to ask for a later appointment.',
  ),
  DailyWord(
    'recommendation',
    'advice about a good choice',
    'My colleague gave me a useful recommendation for lunch.',
  ),
  DailyWord(
    'crucial',
    'extremely important to a result',
    'Getting enough sleep is crucial before a long drive.',
  ),
  DailyWord(
    'coordinate',
    'to arrange people or plans so they work together',
    'I coordinated the pickup time with my family.',
  ),
  DailyWord(
    'unexpected',
    'not planned or predicted',
    'An unexpected call changed our evening plans.',
  ),
  DailyWord(
    'regardless',
    'without being affected by something',
    'We went for a walk regardless of the light rain.',
  ),
  DailyWord(
    'point out',
    'to draw attention to a detail',
    'She pointed out a quieter route to the station.',
  ),
  DailyWord(
    'elaborate',
    'to add useful detail to an explanation',
    'Could you elaborate on what happened at work?',
  ),
  DailyWord(
    'eventually',
    'after some time or effort',
    'We eventually found a table near the window.',
  ),
  DailyWord(
    'overlook',
    'to fail to notice or consider something',
    'I overlooked one detail when I booked the tickets.',
  ),
  DailyWord(
    'promptly',
    'without delay',
    'She replied promptly and confirmed the meeting.',
  ),
  DailyWord(
    'run into',
    'to meet someone by chance',
    'I ran into an old classmate near the market.',
  ),
  DailyWord(
    'on behalf of',
    'as a representative of someone',
    'I called on behalf of my team to confirm the booking.',
  ),
  DailyWord(
    'although',
    'despite the fact that',
    'Although it was late, we kept talking.',
  ),
  DailyWord(
    'trade-off',
    'a balance where gaining one thing means giving up another',
    'Working closer to home is a trade-off for a smaller flat.',
  ),
  DailyWord(
    'figure out',
    'to understand or solve something',
    'We figured out how to split the bill fairly.',
  ),
  DailyWord(
    'take into account',
    'to consider something before making a decision',
    'We took the travel time into account before choosing a restaurant.',
  ),
  DailyWord(
    'follow through',
    'to do what you said you would do',
    'He followed through and sent the documents that afternoon.',
  ),
  DailyWord(
    'commute',
    'a regular journey between home and work',
    'My commute is easier when I leave before rush hour.',
  ),
  DailyWord(
    'reschedule',
    'to arrange something for a different time',
    'Could we reschedule our appointment for Thursday?',
  ),
  DailyWord(
    'make up for',
    'to balance or replace something that was missed or lost',
    'I made up for the missed class by practising at home.',
  ),
  DailyWord(
    'priority',
    'something that is more important than other things',
    'Getting home safely is my priority tonight.',
  ),
  DailyWord(
    'distinguish',
    'to recognize the difference between things',
    'It is hard to distinguish the two phone models at a glance.',
  ),
  DailyWord(
    'reasonable',
    'fair and sensible for the situation',
    'The repair shop gave us a reasonable estimate.',
  ),
  DailyWord(
    'workaround',
    'a temporary way to deal with a problem',
    'We found a workaround until the new system is ready.',
  ),
  DailyWord(
    'convenient',
    'easy to use or reach in a particular situation',
    'The new bus stop is convenient for getting to work.',
  ),
  DailyWord(
    'come across',
    'to find or meet something by chance',
    'I came across a quiet café near the station.',
  ),
  DailyWord(
    'preference',
    'the option someone likes more',
    'My preference is to meet earlier in the day.',
  ),
  DailyWord(
    'put into words',
    'to explain a thought or feeling clearly',
    'I could not put into words how relieved I felt.',
  ),
  DailyWord(
    'tactful',
    'careful not to upset someone when speaking',
    'She was tactful when she gave me feedback.',
  ),
  DailyWord(
    'mention',
    'to refer to something briefly',
    'He mentioned that the meeting might run late.',
  ),
  DailyWord(
    'make an effort',
    'to try hard to do something',
    'I am making an effort to speak up in meetings.',
  ),
  DailyWord(
    'prioritize',
    'to decide what is most important and do it first',
    'I prioritize urgent tasks before checking messages.',
  ),
  DailyWord(
    'strike a balance',
    'to find a suitable mix between two things',
    'I am trying to strike a balance between work and family time.',
  ),
  DailyWord(
    'reference',
    'a source of information you can check',
    'I kept the booking email as a reference.',
  ),
  DailyWord(
    'rephrase',
    'to say the same idea differently',
    'Could you rephrase that more simply?',
  ),
  DailyWord(
    'efficiently',
    'in a way that avoids wasting time or effort',
    'We handled the change efficiently over the phone.',
  ),
  DailyWord(
    'thoughtful',
    'showing care in what you do',
    'That was a thoughtful message.',
  ),
  DailyWord(
    'flexible',
    'able to change easily',
    'Our travel plans are flexible.',
  ),
  DailyWord(
    'on top of that',
    'used to add another point, often an extra problem or benefit',
    'The train was delayed, and on top of that, it started raining.',
  ),
  DailyWord(
    'circumstance',
    'a fact or condition that affects a situation',
    'Under the circumstances, leaving early was sensible.',
  ),
  DailyWord(
    'relieved',
    'less worried after a problem or concern ends',
    'I was relieved when the doctor said it was nothing serious.',
  ),
  DailyWord(
    'in the long run',
    'over a long period of time',
    'Cooking at home saves money in the long run.',
  ),
  DailyWord(
    'precise',
    'exact and carefully stated',
    'Could you give me a more precise time for the pickup?',
  ),
  DailyWord(
    'accountable',
    'expected to explain or take responsibility for an action',
    'I am accountable for sending the final schedule.',
  ),
  DailyWord(
    'pitch in',
    'to help with a task or activity',
    'Everyone pitched in to get dinner ready.',
  ),
  DailyWord(
    'layover',
    'a wait between connecting parts of a journey',
    'We have a two-hour layover in Singapore.',
  ),
  DailyWord(
    'acknowledge',
    'to show that you have noticed or accepted something',
    'She acknowledged my message before calling me back.',
  ),
  DailyWord(
    'subtle',
    'small or not immediately obvious',
    'There was a subtle change in his tone.',
  ),
  DailyWord(
    'perspective',
    'a way of thinking about a situation',
    'From my perspective, we should confirm the details first.',
  ),
  DailyWord(
    'tend to',
    'to usually behave or happen in a particular way',
    'I tend to take the train when traffic is heavy.',
  ),
  DailyWord(
    'distracted',
    'unable to give full attention',
    'I get distracted when I check messages during work.',
  ),
  DailyWord(
    'refreshing',
    'pleasant in a way that gives you new energy',
    'A short walk outside feels refreshing after lunch.',
  ),
  DailyWord(
    'accommodating',
    'willing to adjust plans to help someone',
    'The receptionist was accommodating when I needed to change rooms.',
  ),
  DailyWord(
    'rush hour',
    'the busy time when many people travel to or from work',
    'I avoid driving during rush hour if I can.',
  ),
  DailyWord(
    'heads-up',
    'a short warning or useful piece of advance information',
    'Thanks for the heads-up about the road closure.',
  ),
  DailyWord(
    'walk someone through',
    'to explain a process one step at a time',
    'Could you walk me through the steps to change my booking?',
  ),
];
