import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/tech_panel.dart';
import 'dashboard.dart';
import 'library.dart';
import 'settings.dart';
import 'player.dart';
import '../widgets/tech_grid_bg.dart';
import '../../src/rust/api/player_api.dart';
import '../../state/app_state.dart';
import 'dart:async';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  Timer? _statusPoller;
  bool _isMiniProgressHovered = false;

  @override
  void initState() {
    super.initState();
    // Initialize the native audio backend once on startup
    AudioPlayer.initEngine();
    // Poll the Rust engine global state every 500ms
    _statusPoller = Timer.periodic(const Duration(milliseconds: 250), (
      _,
    ) async {
      try {
        final state = await AudioPlayer.getState();
        final progress = await AudioPlayer.getProgress();
        if (mounted) {
          AppState().syncPlaybackSnapshot(state: state, progress: progress);
        }
      } catch (_) {
        // Engine may not be ready yet on first call; ignore
      }
    });
  }

  @override
  void dispose() {
    _statusPoller?.cancel();
    super.dispose();
  }

  final List<Widget> _pages = [
    const DashboardView(key: ValueKey('dashboard')),
    const LibraryView(key: ValueKey('library')),
    const SettingsView(key: ValueKey('settings')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SciFiColors.background,
      body: TechGridBg(
        child: SafeArea(
          child: Column(
            children: [
              // Main Split: Sidebar + Routing View
              Expanded(
                child: Row(
                  children: [
                    // Side Navigation
                    _buildSideNav(),
                    // Main Routing Content Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 24.0,
                          right: 24.0,
                          bottom: 24.0,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: _pages[_currentIndex],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Persistent Bottom Mini-Player
              _buildMiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          _NavButton(
            icon: Icons.dashboard_outlined,
            label: 'HOME',
            isActive: _currentIndex == 0,
            onTap: () => setState(() => _currentIndex = 0),
          ),
          const SizedBox(height: 24),
          _NavButton(
            icon: Icons.folder_special_outlined,
            label: 'PLAYLIST',
            isActive: _currentIndex == 1,
            onTap: () => setState(() => _currentIndex = 1),
          ),
          const Spacer(),
          _NavButton(
            icon: Icons.settings_outlined,
            label: 'SETTINGS',
            isActive: _currentIndex == 2,
            onTap: () => setState(() => _currentIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final appState = AppState();
        final currentTrack = appState.currentTrack;
        final playbackError = appState.playbackErrorMessage;
        final playbackState = appState.playbackState;
        final isPlaying = playbackState is PlaybackState_Playing;
        final isLoading = appState.isTrackLoading;
        final progress = appState.playbackProgress;
        final hasTrack = currentTrack != null;
        final hasProgress = hasTrack && appState.playbackDurationMs > 0;

        return TechPanel(
          padding: EdgeInsets.zero,
          backgroundColor: SciFiColors.surfaceLight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasTrack)
                MouseRegion(
                  onEnter: (_) => setState(() => _isMiniProgressHovered = true),
                  onExit: (_) {
                    if (!appState.isSeeking) {
                      setState(() => _isMiniProgressHovered = false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: hasProgress ? 12 : 4,
                    padding: EdgeInsets.only(
                      top: hasProgress ? 4 : 0,
                      bottom: hasProgress ? 4 : 0,
                    ),
                    child: _MiniProgressBar(
                      value: progress ?? 0,
                      semanticValue:
                          '${_formatMs(appState.displayedPlaybackPositionMs)} / ${_formatMs(appState.playbackDurationMs)}',
                      isHovered: _isMiniProgressHovered,
                      onChangeStart: hasProgress
                          ? (_) => appState.beginSeekPreview()
                          : null,
                      onChanged: hasProgress
                          ? (value) => appState.updateSeekPreview(value)
                          : null,
                      onChangeEnd: hasProgress
                          ? (_) async {
                              await appState.commitSeekPreview();
                              if (mounted) {
                                setState(() => _isMiniProgressHovered = false);
                              }
                            }
                          : null,
                    ),
                  ),
                ),
              SizedBox(
                height: 72,
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: currentTrack == null
                            ? null
                            : () => Navigator.of(context).push(_playerRoute()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isLoading
                                        ? SciFiColors.primaryYel
                                        : SciFiColors.gridLines,
                                  ),
                                ),
                                child: isLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: SciFiColors.primaryYel,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.music_note,
                                        color: SciFiColors.textDim,
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _MarqueeText(
                                      text: currentTrack?.title ??
                                          playbackState.when(
                                            stopped: () => 'NO TRACK PLAYING',
                                            playing: () => 'NATIVE DECODER ACTIVE',
                                            paused: () => 'PLAYBACK INTERRUPTED',
                                            error: (msg) => 'ENGINE FAULT',
                                          ),
                                      style: const TextStyle(
                                        color: SciFiColors.textMain,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _MarqueeText(
                                      text: isLoading
                                          ? 'BUFFERING REMOTE AUDIO...'
                                          : playbackError ??
                                                (currentTrack != null
                                                    ? '${currentTrack.artist} // ${currentTrack.album}'
                                                    : playbackState.when(
                                                        stopped: () =>
                                                            'AWAITING PLAYLIST SELECTION',
                                                        playing: () =>
                                                            'STREAMING FROM WEBDAV HUB',
                                                        paused: () =>
                                                            'AWAITING RESUME SIGNAL',
                                                        error: (msg) =>
                                                            'DIAGNOSTIC: $msg',
                                                      )),
                                      style: const TextStyle(
                                        color: SciFiColors.textDim,
                                        fontSize: 10,
                                        letterSpacing: 2.0,
                                      ),
                                      velocity: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        onTap: currentTrack == null
                            ? null
                            : () => Navigator.of(context).push(_playerRoute()),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasTrack) ...[
                                  Text(
                                    '${_formatMs(appState.displayedPlaybackPositionMs)}/${_formatMs(appState.playbackDurationMs)}',
                                    style: const TextStyle(
                                      color: SciFiColors.textDim,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                _RectToolbarButton(
                                  icon: Icons.skip_previous,
                                  onPressed: currentTrack == null
                                      ? null
                                      : () => AppState().playPrevious(),
                                ),
                                const SizedBox(width: 8),
                                _RectToolbarButton(
                                  icon: isLoading
                                      ? Icons.hourglass_top
                                      : (isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow),
                                  color: SciFiColors.primaryYel,
                                  backgroundColor: SciFiColors.primaryYelGlow,
                                  borderColor: SciFiColors.primaryYel,
                                  onPressed: currentTrack == null || isLoading
                                      ? null
                                      : () => AppState().togglePlayPause(),
                                ),
                                const SizedBox(width: 8),
                                _RectToolbarButton(
                                  icon: Icons.skip_next,
                                  onPressed: currentTrack == null
                                      ? null
                                      : () => AppState().playNext(),
                                ),
                                const SizedBox(width: 16),
                                _RectToolbarButton(
                                  icon: switch (AppState().playbackMode) {
                                    PlaybackMode.listLoop => Icons.repeat,
                                    PlaybackMode.singleLoop => Icons.repeat_one,
                                    PlaybackMode.shuffle => Icons.shuffle,
                                  },
                                  color: SciFiColors.primaryYel,
                                  onPressed: currentTrack == null
                                      ? null
                                      : AppState().cyclePlaybackMode,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMs(int ms) {
    if (ms <= 0) {
      return '00:00';
    }
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Route<void> _playerRoute() {
    return PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const PlayerView(),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizeTransition(
            sizeFactor: curved,
            axisAlignment: 1,
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _RectToolbarButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  const _RectToolbarButton({
    required this.icon,
    this.color = SciFiColors.textMain,
    this.backgroundColor,
    this.borderColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.14),
        splashColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor ?? Colors.transparent),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity;

  const _MarqueeText({
    required this.text,
    required this.style,
    this.velocity = 24,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MiniProgressBar extends StatelessWidget {
  final double value;
  final String? semanticValue;
  final bool isHovered;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  const _MiniProgressBar({
    required this.value,
    this.semanticValue,
    required this.isHovered,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      slider: true,
      label: 'Mini player progress',
      value: semanticValue,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double toFraction(double dx) {
              if (constraints.maxWidth <= 0) {
                return 0;
              }
              return (dx / constraints.maxWidth).clamp(0.0, 1.0);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onChanged == null
                  ? null
                  : (details) {
                      final fraction = toFraction(details.localPosition.dx);
                      onChangeStart?.call(fraction);
                      onChanged?.call(fraction);
                      onChangeEnd?.call(fraction);
                    },
              onHorizontalDragStart: onChanged == null
                  ? null
                  : (details) =>
                        onChangeStart?.call(toFraction(details.localPosition.dx)),
              onHorizontalDragUpdate: onChanged == null
                  ? null
                  : (details) =>
                        onChanged?.call(toFraction(details.localPosition.dx)),
              onHorizontalDragEnd: onChanged == null
                  ? null
                  : (_) => onChangeEnd?.call(value.clamp(0.0, 1.0)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                height: 4,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  height: isHovered ? 5 : 3,
                  decoration: const BoxDecoration(color: SciFiColors.gridLines),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(color: SciFiColors.primaryYel),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final overflow = painter.width - constraints.maxWidth;
        if (overflow <= 0) {
          _controller.stop();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: widget.style,
          );
        }

        final durationMs = ((overflow + 40) / widget.velocity * 1000)
            .clamp(2500, 12000)
            .round();
        _controller.duration = Duration(milliseconds: durationMs);
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx = -overflow * Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? SciFiColors.primaryYel
        : (_isHovered ? SciFiColors.textMain : SciFiColors.textDim);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: widget.isActive
                ? SciFiColors.primaryYelGlow
                : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? SciFiColors.primaryYel
                  : (_isHovered ? SciFiColors.gridLines : Colors.transparent),
              width: 1.0, // Strict orthogonal 1px border
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
