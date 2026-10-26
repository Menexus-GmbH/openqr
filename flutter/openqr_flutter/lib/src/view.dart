/// Renders validated public links with a quiet zone and a selectable alternative.
library;

import 'package:flutter/material.dart';
import 'package:openqr/openqr.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class OpenQrView extends StatelessWidget {
  const OpenQrView({
    super.key,
    required this.link,
    required this.policy,
    required this.semanticLabel,
    required this.errorBuilder,
    this.size = 256,
  });

  final OpenQrLink link;
  final OpenQrPolicy policy;
  final String semanticLabel;
  final WidgetBuilder errorBuilder;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String data;
    final QrImage image;
    try {
      if (!size.isFinite || size <= 0) return errorBuilder(context);
      data = encode(link, policy: policy).toString();
      image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.H),
      );
    } catch (_) {
      // Payloads and exception messages must stay out of global diagnostics.
      return errorBuilder(context);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: semanticLabel,
          image: true,
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: size,
              child: PrettyQrView(
                qrImage: image,
                decoration: const PrettyQrDecoration(
                  background: Colors.white,
                  shape: PrettyQrSquaresSymbol(color: Colors.black),
                  quietZone: PrettyQrQuietZone.modules(4),
                ),
              ),
            ),
          ),
        ),
        SelectableText(data),
      ],
    );
  }
}
