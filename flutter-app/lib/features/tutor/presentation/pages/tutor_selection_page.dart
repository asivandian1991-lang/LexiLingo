import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/tutor_catalog.dart';
import '../../domain/ai_tutor.dart';
import '../../../lexi_chat/presentation/pages/lexi_chat_page.dart';

class TutorSelectionPage extends StatefulWidget {
  const TutorSelectionPage({super.key});

  @override
  State<TutorSelectionPage> createState() => _TutorSelectionPageState();
}

class _TutorSelectionPageState extends State<TutorSelectionPage> {
  static const _preferenceKey = 'selected_ai_tutor_id';
  AiTutor _selected = AiTutor.defaultTutor;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  Future<void> _restoreSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _selected = TutorCatalog.byId(prefs.getString(_preferenceKey)));
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, _selected.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LexiChatPage(tutor: _selected)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF17233A);
    const blue = Color(0xFF3E9CF4);

    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 54,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select Your Tutor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: const RadialGradient(
                        center: Alignment(0, -.15),
                        radius: .9,
                        colors: [Color(0xFF3765AD), navy],
                      ),
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SvgPicture.asset(
                      _selected.avatarAsset,
                      height: 260,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 30,
                    bottom: 18,
                    child: Text(
                      _selected.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 28,
                    bottom: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          _selected.accent,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 7,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  itemCount: TutorCatalog.tutors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final tutor = TutorCatalog.tutors[index];
                    final selected = tutor.id == _selected.id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () => setState(() => _selected = tutor),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFEAF5FF) : Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: selected ? blue : const Color(0xFFE4E7EB),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: navy,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: SvgPicture.asset(tutor.avatarAsset, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tutor.name,
                                    style: const TextStyle(
                                      color: Color(0xFF07507E),
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    tutor.subtitle,
                                    style: const TextStyle(
                                      color: Color(0xFF8A8F98),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    tutor.personality,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: tutor.specialties
                                        .map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEAF5FF),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              tag,
                                              style: const TextStyle(
                                                color: Color(0xFF07507E),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: const Color(0xFFF4F5F7),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: SizedBox(
            height: 58,
            child: FilledButton(
              onPressed: _continue,
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                'Continue with ${_selected.name}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
