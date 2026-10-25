import 'package:flutter/material.dart';
import 'package:talkmile/core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.brass,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(
          Icons.graphic_eq_rounded,
          size: size * .66,
          color: AppColors.ink,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'talkmile',
        style: TextStyle(
          fontSize: size * .65,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
      ),
    ],
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      letterSpacing: 2.0,
      fontWeight: FontWeight.w700,
      color: AppColors.brass,
    ),
  );
}
