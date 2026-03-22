import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

enum AppNotificationType { info, error }

class AppNotifications {
  AppNotifications._();

  static final AppNotifications instance = AppNotifications._();

  final List<_ActiveNotification> _active = [];

  void showInfo(String message) {
    _show(message, AppNotificationType.info);
  }

  void showError(String message) {
    _show(message, AppNotificationType.error);
  }

  void _show(String message, AppNotificationType type) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }

    late final _ActiveNotification active;
    active = _ActiveNotification(
      message: message,
      type: type,
      onClose: () => _beginDismiss(active),
    );
    _active.insert(0, active);
    _rebuild();
  }

  void _beginDismiss(_ActiveNotification notification) {
    if (notification.closing) {
      return;
    }
    notification.closing = true;
    notification.entry.markNeedsBuild();
    notification.timer?.cancel();
    notification.timer = Timer(const Duration(milliseconds: 220), () {
      _remove(notification);
    });
  }

  void _remove(_ActiveNotification notification) {
    notification.timer?.cancel();
    final removed = _active.remove(notification);
    if (!removed) {
      return;
    }
    notification.entry.remove();
    _rebuild();
  }

  void _rebuild() {
    for (var i = 0; i < _active.length; i++) {
      _active[i].index = i;
      _active[i].entry.markNeedsBuild();
      if (!_active[i].inserted) {
        final overlay = appNavigatorKey.currentState?.overlay;
        if (overlay != null) {
          overlay.insert(_active[i].entry);
          _active[i].inserted = true;
        }
      }
    }
  }
}

class _ActiveNotification {
  final String message;
  final AppNotificationType type;
  final VoidCallback onClose;
  int index = 0;
  bool inserted = false;
  bool closing = false;
  Timer? timer;

  late final OverlayEntry entry = OverlayEntry(
    builder: (context) => _NotificationCard(
      message: message,
      type: type,
      index: index,
      closing: closing,
      onClose: onClose,
    ),
  );

  _ActiveNotification({
    required this.message,
    required this.type,
    required this.onClose,
  });
}

class _NotificationCard extends StatefulWidget {
  final String message;
  final AppNotificationType type;
  final int index;
  final bool closing;
  final VoidCallback onClose;

  const _NotificationCard({
    required this.message,
    required this.type,
    required this.index,
    required this.closing,
    required this.onClose,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  static const _displayDuration = Duration(seconds: 4);
  late final AnimationController _progressController;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _displayDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !widget.closing) {
          widget.onClose();
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
      _progressController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.closing && widget.closing) {
      setState(() => _visible = false);
      _progressController.stop();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = switch (widget.type) {
      AppNotificationType.info => SciFiColors.primaryYel,
      AppNotificationType.error => SciFiColors.errorRed,
    };

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      top: 20.0 + (widget.index * 76),
      right: 20,
      child: IgnorePointer(
        ignoring: false,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            offset: _visible ? Offset.zero : const Offset(0.12, -0.04),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: _visible ? 1 : 0,
              child: Container(
                width: 360,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: SciFiColors.surface,
                  border: Border.all(color: accent),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 4,
                      height: 36,
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, _) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: FractionallySizedBox(
                              heightFactor: 1 - _progressController.value,
                              child: Container(color: accent),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textMain,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: widget.onClose,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: SciFiColors.textDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
