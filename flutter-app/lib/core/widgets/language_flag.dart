import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lexilingo_app/core/l10n/app_localizations.dart';

class LanguageFlag extends StatelessWidget {
  const LanguageFlag({
    required this.languageCode,
    required this.width,
    required this.height,
    this.assetPath,
    super.key,
  });

  final String languageCode;
  final double width;
  final double height;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final path = assetPath ?? AppLocales.flagAssetOf(languageCode);

    final Widget flag = path.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(
            path,
            width: width,
            height: height,
            fit: BoxFit.cover,
          )
        : Image.asset(
            path,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => SizedBox(
              width: width,
              height: height,
              child: const Icon(Icons.flag_outlined),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: height,
        child: flag,
      ),
    );
  }
}
