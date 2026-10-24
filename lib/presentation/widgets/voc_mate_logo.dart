import 'package:flutter/material.dart';

class VocMateLogo extends StatelessWidget {
  const VocMateLogo({super.key, this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.23),
    child: Image.asset('assets/icons/voc_mate.png', width: size, height: size,
      fit: BoxFit.contain, semanticLabel: 'VoC Mate'),
  );
}
