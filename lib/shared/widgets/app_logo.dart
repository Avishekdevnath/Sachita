import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 28,
    this.fit = BoxFit.contain,
    super.key,
  });

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context)).toInt();
    return Image.asset(
      'assets/branding/sanchita-logo.png',
      width: size,
      height: size,
      cacheWidth: pixelSize,
      cacheHeight: pixelSize,
      fit: fit,
      errorBuilder: (context, _, __) {
        return Icon(Icons.account_balance_wallet_outlined, size: size);
      },
    );
  }
}

class AppLogoTitle extends StatelessWidget {
  const AppLogoTitle({
    this.text = 'Sanchita',
    this.logoSize = 24,
    super.key,
  });

  final String text;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppLogo(size: logoSize),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}

