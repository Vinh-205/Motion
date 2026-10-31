import 'package:flutter/material.dart';

/// Hiệu ứng đánh máy: chữ hiện dần từng ký tự. Phần chưa hiện vẫn được vẽ
/// (trong suốt) nên bố cục không bị nhảy dòng và công cụ đọc màn hình vẫn
/// nhận đủ nội dung. Tự chạy lại khi [text] đổi.
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.delay = Duration.zero,
    this.charDuration = const Duration(milliseconds: 35),
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration delay;
  final Duration charDuration;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  void _run() {
    final total = widget.delay + widget.charDuration * widget.text.length;
    _c.duration = total == Duration.zero ? const Duration(milliseconds: 1) : total;
    _c.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _run();
    }
  }

  @override
  void didUpdateWidget(TypewriterText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _run();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final total = _c.duration!.inMilliseconds;
        final elapsed = _c.value * total - widget.delay.inMilliseconds;
        final n = (elapsed / widget.charDuration.inMilliseconds).floor().clamp(
          0,
          widget.text.length,
        );
        return Text.rich(
          TextSpan(
            style: base,
            children: [
              TextSpan(text: widget.text.substring(0, n)),
              TextSpan(
                text: widget.text.substring(n),
                style: const TextStyle(color: Color(0x00000000)),
              ),
            ],
          ),
          textAlign: widget.textAlign,
        );
      },
    );
  }
}
