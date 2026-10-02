class AiTutor {
  final String id;
  final String name;
  final String subtitle;
  final String accent;
  final String targetLanguage;
  final String voiceLocale;
  final String avatarAsset;
  final String personality;
  final List<String> specialties;
  final String teachingStyle;
  final String systemPrompt;

  const AiTutor({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.targetLanguage,
    required this.voiceLocale,
    required this.avatarAsset,
    required this.personality,
    required this.specialties,
    required this.teachingStyle,
    required this.systemPrompt,
  });

  static const defaultTutor = AiTutor(
    id: 'emma',
    name: 'Emma',
    subtitle: 'American',
    accent: 'American English',
    targetLanguage: 'English',
    voiceLocale: 'en-US',
    avatarAsset: 'assets/tutors/emma.svg',
    personality: 'Supportive • Patient • Methodical',
    specialties: ['General', 'Conversation'],
    teachingStyle: 'Warm, encouraging and practical',
    systemPrompt:
        'You are Emma, a warm American English tutor. Keep the learner speaking. '
        'Correct important grammar naturally, explain briefly, adapt to CEFR level, '
        'and finish most turns with one useful follow-up question.',
  );
}
