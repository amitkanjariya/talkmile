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
    '28',
    'female',
    'friendly neighbor',
    'warm, relaxed',
  ),
  CoachPersona('arun', 'Arun', '32', 'male', 'colleague', 'clear, practical'),
  CoachPersona(
    'leena',
    'Leena',
    '24',
    'female',
    'travel friend',
    'curious, lively',
  ),
  CoachPersona(
    'kabir',
    'Kabir',
    '35',
    'male',
    'supportive mentor',
    'patient, thoughtful',
  ),
  CoachPersona(
    'nisha',
    'Nisha',
    '42',
    'female',
    'older cousin',
    'easygoing, encouraging',
  ),
  CoachPersona('dev', 'Dev', '22', 'male', 'new friend', 'casual, upbeat'),
  CoachPersona(
    'sara',
    'Sara',
    '30',
    'female',
    'café regular',
    'gentle, observant',
  ),
  CoachPersona(
    'imran',
    'Imran',
    '47',
    'male',
    'community volunteer',
    'kind, grounded',
  ),
  CoachPersona(
    'tara',
    'Tara',
    '55',
    'female',
    'family friend',
    'warm, story-loving',
  ),
  CoachPersona(
    'rohan',
    'Rohan',
    '27',
    'male',
    'creative teammate',
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
    'convenient',
    'easy and useful in a situation',
    'The nearby shop is convenient.',
  ),
  DailyWord(
    'recommend',
    'to suggest something good',
    'I recommend trying the local tea.',
  ),
  DailyWord(
    'curious',
    'eager to learn or know',
    'I am curious about your new hobby.',
  ),
  DailyWord(
    'manage',
    'to succeed in doing something',
    'We managed to catch the early bus.',
  ),
  DailyWord(
    'available',
    'free or ready to use',
    'Are you available this evening?',
  ),
  DailyWord(
    'improve',
    'to become or make better',
    'A little practice can improve fluency.',
  ),
  DailyWord('probably', 'very likely', 'It will probably rain this afternoon.'),
  DailyWord(
    'instead',
    'as an alternative',
    'We walked instead of taking a taxi.',
  ),
  DailyWord(
    'appreciate',
    'to feel thankful for',
    'I appreciate your honest advice.',
  ),
  DailyWord(
    'confident',
    'sure of your ability',
    'She felt confident during the talk.',
  ),
  DailyWord('prepare', 'to get ready', 'I prepare lunch the night before.'),
  DailyWord(
    'opportunity',
    'a good chance to do something',
    'The course gave me an opportunity to speak.',
  ),
  DailyWord(
    'familiar',
    'known from earlier experience',
    'That street looks familiar.',
  ),
  DailyWord(
    'comfortable',
    'relaxed and at ease',
    'I feel comfortable asking questions.',
  ),
  DailyWord(
    'patient',
    'able to wait calmly',
    'Please be patient while I explain.',
  ),
  DailyWord(
    'suggest',
    'to offer an idea',
    'Could you suggest a quiet restaurant?',
  ),
  DailyWord(
    'necessary',
    'needed or important',
    'A passport is necessary for the trip.',
  ),
  DailyWord(
    'organize',
    'to arrange in a clear way',
    'We organized a small family dinner.',
  ),
  DailyWord(
    'ordinary',
    'usual or not special',
    'It was an ordinary day with good company.',
  ),
  DailyWord(
    'especially',
    'more than usual or others',
    'I enjoy fruit, especially mangoes.',
  ),
  DailyWord(
    'notice',
    'to see or become aware of',
    'Did you notice the new sign?',
  ),
  DailyWord(
    'explain',
    'to make an idea clear',
    'Can you explain how this works?',
  ),
  DailyWord('perhaps', 'possibly; maybe', 'Perhaps we can meet after work.'),
  DailyWord(
    'avoid',
    'to stay away from',
    'I avoid checking my phone while driving.',
  ),
  DailyWord(
    'patiently',
    'in a calm way while waiting',
    'He patiently answered every question.',
  ),
  DailyWord('recently', 'not long ago', 'I recently started learning to cook.'),
  DailyWord('instead of', 'in place of', 'We had soup instead of sandwiches.'),
  DailyWord(
    'although',
    'despite the fact that',
    'Although it was late, we kept talking.',
  ),
  DailyWord(
    'decision',
    'a choice you make',
    'It was a difficult decision to move.',
  ),
  DailyWord(
    'experience',
    'something that happens to you',
    'The trip was a wonderful experience.',
  ),
  DailyWord(
    'describe',
    'to say what something is like',
    'Describe your favorite place.',
  ),
  DailyWord(
    'conversation',
    'a talk between people',
    'We had a pleasant conversation.',
  ),
  DailyWord(
    'neighborhood',
    'the area where you live',
    'There is a park in my neighborhood.',
  ),
  DailyWord(
    'schedule',
    'a plan of times and activities',
    'My schedule is busy on Mondays.',
  ),
  DailyWord(
    'comfortable',
    'pleasant and not difficult',
    'These shoes are comfortable for walking.',
  ),
  DailyWord(
    'purpose',
    'the reason for doing something',
    'The purpose of the meeting is to plan.',
  ),
  DailyWord(
    'compare',
    'to notice similarities or differences',
    'We compared the two travel routes.',
  ),
  DailyWord(
    'suitable',
    'right for a particular need',
    'This café is suitable for a quiet chat.',
  ),
  DailyWord(
    'solution',
    'an answer to a problem',
    'We found a simple solution together.',
  ),
  DailyWord(
    'local',
    'from or belonging to this area',
    'A local guide showed us the market.',
  ),
  DailyWord(
    'discover',
    'to find something new',
    'I discovered a lovely walking path.',
  ),
  DailyWord(
    'choice',
    'the act of choosing',
    'You have a choice of three desserts.',
  ),
  DailyWord(
    'express',
    'to share a thought or feeling',
    'It can be hard to express an opinion.',
  ),
  DailyWord(
    'polite',
    'showing respect and good manners',
    'It is polite to listen without interrupting.',
  ),
  DailyWord(
    'share',
    'to tell or give something to others',
    'She shared a funny story with us.',
  ),
  DailyWord(
    'practice',
    'to do something repeatedly to improve',
    'I practice English during my commute.',
  ),
  DailyWord(
    'focus',
    'to give attention to one thing',
    'Let us focus on one idea at a time.',
  ),
  DailyWord(
    'balance',
    'a healthy mix of different things',
    'He tries to balance work and rest.',
  ),
  DailyWord(
    'resource',
    'something useful that can help',
    'The library is a useful resource.',
  ),
  DailyWord(
    'rephrase',
    'to say the same idea differently',
    'Could you rephrase that more simply?',
  ),
  DailyWord(
    'patiently',
    'without becoming annoyed',
    'She patiently waited for her friend.',
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
    'furthermore',
    'in addition to what was said',
    'Furthermore, the hotel is near the station.',
  ),
  DailyWord(
    'occasion',
    'a particular event or time',
    'We save this dish for a special occasion.',
  ),
  DailyWord(
    'delighted',
    'very pleased',
    'I was delighted to meet your family.',
  ),
  DailyWord(
    'gradually',
    'slowly over a period of time',
    'My confidence grew gradually.',
  ),
  DailyWord(
    'specific',
    'clearly defined or exact',
    'Could you give me a specific example?',
  ),
  DailyWord(
    'responsible',
    'having a duty to take care of something',
    'I am responsible for booking the tickets.',
  ),
  DailyWord(
    'contribute',
    'to give help or ideas',
    'Everyone contributed an idea.',
  ),
  DailyWord(
    'destination',
    'the place you are going to',
    'Our destination is a small hill town.',
  ),
  DailyWord(
    'celebrate',
    'to show happiness about an event',
    'We celebrate the festival together.',
  ),
  DailyWord(
    'noticeable',
    'easy to see or recognize',
    'There was a noticeable change in the weather.',
  ),
  DailyWord(
    'opinion',
    'what someone thinks about something',
    'In my opinion, the second plan is better.',
  ),
  DailyWord(
    'prefer',
    'to like one thing more than another',
    'I prefer taking the train.',
  ),
  DailyWord(
    'concentrate',
    'to give all your attention',
    'It is easier to concentrate in a quiet room.',
  ),
  DailyWord(
    'peaceful',
    'quiet and free from worry',
    'The garden is peaceful in the morning.',
  ),
  DailyWord(
    'generous',
    'happy to give or share',
    'Our host was generous with her time.',
  ),
  DailyWord(
    'traffic',
    'vehicles moving on a road',
    'Traffic is lighter on Sundays.',
  ),
  DailyWord(
    'suggestion',
    'an idea offered for consideration',
    'Thanks for the helpful suggestion.',
  ),
  DailyWord(
    'describe',
    'to explain the features of something',
    'Describe what happened on your trip.',
  ),
];
