import 'package:flutter/material.dart';
import 'intro_content.dart';

/// The four-screen introduction shown before the existing Welcome page.
/// All slide texts and illustration paths are editable in intro_content.dart.
class IntroSlidesPage extends StatefulWidget {
  final VoidCallback onFinished;

  const IntroSlidesPage({super.key, required this.onFinished});

  @override
  State<IntroSlidesPage> createState() => _IntroSlidesPageState();
}

class _IntroSlidesPageState extends State<IntroSlidesPage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == IntroContent.slides.length - 1) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF111D4C);
    const orange = Color(0xFFFF963E);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                  child: Row(
                    children: [
                      const Text(
                        'Quoriv AI',
                        style: TextStyle(
                          color: navy,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (_index < IntroContent.slides.length - 1)
                        TextButton(
                          onPressed: widget.onFinished,
                          child: const Text('Skip'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: IntroContent.slides.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, i) {
                      final slide = IntroContent.slides[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Image.asset(
                                  slide.imagePath,
                                  fit: BoxFit.contain,
                                  semanticLabel: slide.imageSemanticLabel,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0E2),
                                        borderRadius: BorderRadius.circular(90),
                                      ),
                                      child: Icon(
                                        [
                                          Icons.auto_stories_rounded,
                                          Icons.calendar_month_rounded,
                                          Icons.menu_book_rounded,
                                          Icons.school_rounded,
                                        ][i],
                                        size: 94,
                                        color: orange,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: navy,
                                fontSize: 28,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF6D7280),
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 26),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    IntroContent.slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: i == _index ? 26 : 8,
                      decoration: BoxDecoration(
                        color: i == _index ? orange : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _index == IntroContent.slides.length - 1
                            ? 'Get Started'
                            : 'Continue',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
