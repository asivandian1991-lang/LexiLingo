/// Editable copy and image paths for the pre-welcome introduction.
///
/// Place your exported Figma PNG/WebP images in assets/onboarding/ using
/// the file names below. The UI falls back to icons when a file is absent.
class IntroSlideContent {
  final String title;
  final String description;
  final String imagePath;
  final String imageSemanticLabel;

  const IntroSlideContent({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.imageSemanticLabel,
  });
}

abstract final class IntroContent {
  static const slides = <IntroSlideContent>[
    IntroSlideContent(
      title: 'Learn a language your way',
      description: 'Personalized language lessons designed around your goals.',
      imagePath: 'assets/onboarding/intro_01.png',
      imageSemanticLabel: 'Language learning illustration',
    ),
    IntroSlideContent(
      title: 'Learn on your schedule',
      description: 'Build your skills with short lessons, whenever you have time.',
      imagePath: 'assets/onboarding/intro_02.png',
      imageSemanticLabel: 'Flexible study schedule illustration',
    ),
    IntroSlideContent(
      title: 'Discover courses you love',
      description: 'Explore vocabulary, grammar, listening, and speaking practice.',
      imagePath: 'assets/onboarding/intro_03.png',
      imageSemanticLabel: 'Courses illustration',
    ),
    IntroSlideContent(
      title: 'Ready to start learning?',
      description: 'Practice every day and grow your confidence with your AI tutor.',
      imagePath: 'assets/onboarding/intro_04.png',
      imageSemanticLabel: 'Start learning illustration',
    ),
  ];
}
