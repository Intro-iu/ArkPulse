import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/webdav_config.dart';
import '../../services/app_notifications.dart';
import '../../src/rust/api/player_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/tech_panel.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SciFiColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AppState(),
          builder: (context, _) {
            final appState = AppState();
            final currentTrack = appState.currentTrack;
            final playbackError = appState.playbackErrorMessage;
            final playbackState = appState.playbackState;
            final isPlaying = playbackState is PlaybackState_Playing;
            final isLoading = appState.isTrackLoading;
            final progress = appState.playbackProgress;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      _RectControlButton(
                        icon: Icons.keyboard_arrow_down,
                        iconSize: 32,
                        color: SciFiColors.primaryYel,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'AUDIO_ENGINE // SYMPHONIA',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textDim,
                          fontSize: 14,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 1180;
                      final content = [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 24.0,
                              right: stacked ? 24.0 : 12.0,
                              bottom: stacked ? 12.0 : 24.0,
                            ),
                            child: _NowPlayingPanel(
                              currentTrack: currentTrack,
                              playbackState: playbackState,
                              isPlaying: isPlaying,
                              isLoading: isLoading,
                              progress: progress,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: stacked ? 24.0 : 12.0,
                              right: 24.0,
                              bottom: 24.0,
                              top: stacked ? 12.0 : 0.0,
                            ),
                            child: _LyricsPanel(
                              currentTrack: currentTrack,
                              playbackError: playbackError,
                              isLoading: isLoading,
                            ),
                          ),
                        ),
                      ];

                      return stacked
                          ? Column(children: content)
                          : Row(children: content);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  final ScrapedSong? currentTrack;
  final PlaybackState playbackState;
  final bool isPlaying;
  final bool isLoading;
  final double? progress;

  const _NowPlayingPanel({
    required this.currentTrack,
    required this.playbackState,
    required this.isPlaying,
    required this.isLoading,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppState();
    final title = currentTrack?.title ?? 'NO TRACK DEPLOYED';
    final subtitle = currentTrack == null
        ? 'SELECT A TRACK FROM WEBDAV_HUB TO START STREAMING'
        : '${currentTrack!.artist} // ${currentTrack!.album}';
    final status = isLoading
        ? 'BUFFERING'
        : playbackState.when(
            stopped: () => 'STOPPED',
            playing: () => 'PLAYING',
            paused: () => 'PAUSED',
            error: (_) => 'FAULT',
          );

    Future<void> openAddToPlaylistDialog() async {
      final track = currentTrack;
      if (track == null) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => _PlayerAddToPlaylistDialog(song: track),
      );
    }

    return TechPanel(
      delay: const Duration(milliseconds: 100),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: SciFiColors.gridLines),
                          color: SciFiColors.background,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (int i = 1; i <= 5; i++)
                              Container(
                                width: 50.0 * i,
                                height: 50.0 * i,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: SciFiColors.primaryYelGlow.withValues(
                                      alpha: 0.1 * i,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                            isLoading
                                ? const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: SciFiColors.primaryYel,
                                    ),
                                  )
                                : const Icon(
                                    Icons.album,
                                    size: 80,
                                    color: SciFiColors.primaryYelGlow,
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textMain,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textDim,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'ENGINE STATUS // $status',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.primaryYel,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 420,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 0,
                              child: _RectControlButton(
                                icon: Icons.playlist_add,
                                color: SciFiColors.primaryYel,
                                onPressed: currentTrack == null
                                    ? null
                                    : openAddToPlaylistDialog,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                _RectControlButton(
                                  icon: Icons.skip_previous,
                                  iconSize: 36,
                                  onPressed: currentTrack == null
                                      ? null
                                      : () => appState.playPrevious(),
                                ),
                                const SizedBox(width: 16),
                                _RectControlButton(
                                  icon: isLoading
                                      ? Icons.hourglass_top
                                      : (isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow),
                                  iconSize: 48,
                                  color: SciFiColors.primaryYel,
                                  backgroundColor: SciFiColors.primaryYelGlow,
                                  borderColor: SciFiColors.primaryYel,
                                  padding: const EdgeInsets.all(12),
                                  onPressed: currentTrack == null || isLoading
                                      ? null
                                      : () => appState.togglePlayPause(),
                                ),
                                const SizedBox(width: 16),
                                _RectControlButton(
                                  icon: Icons.skip_next,
                                  iconSize: 36,
                                  onPressed: currentTrack == null
                                      ? null
                                      : () => appState.playNext(),
                                ),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              child: _RectControlButton(
                                icon: switch (appState.playbackMode) {
                                  PlaybackMode.listLoop => Icons.repeat,
                                  PlaybackMode.singleLoop => Icons.repeat_one,
                                  PlaybackMode.shuffle => Icons.shuffle,
                                },
                                color: SciFiColors.primaryYel,
                                onPressed: currentTrack == null
                                    ? null
                                    : appState.cyclePlaybackMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _PlayerProgressSection(
                        hasTrack: currentTrack != null,
                        isLoading: isLoading,
                        progress: progress,
                        displayedPositionMs: appState.displayedPlaybackPositionMs,
                        durationMs: appState.playbackDurationMs,
                        onChangeStart: currentTrack == null
                            ? null
                            : (_) => appState.beginSeekPreview(),
                        onChanged: currentTrack == null
                            ? null
                            : (value) => appState.updateSeekPreview(value),
                        onChangeEnd: currentTrack == null
                            ? null
                            : (_) => appState.commitSeekPreview(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerProgressSection extends StatefulWidget {
  final bool hasTrack;
  final bool isLoading;
  final double? progress;
  final int displayedPositionMs;
  final int durationMs;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  const _PlayerProgressSection({
    required this.hasTrack,
    required this.isLoading,
    required this.progress,
    required this.displayedPositionMs,
    required this.durationMs,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
  });

  @override
  State<_PlayerProgressSection> createState() => _PlayerProgressSectionState();
}

class _PlayerProgressSectionState extends State<_PlayerProgressSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final progressValue = (widget.progress ?? 0).clamp(0.0, 1.0);
    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SizedBox(
            height: 24,
            child: widget.hasTrack
                ? Semantics(
                    container: true,
                    slider: true,
                    label: 'Player progress',
                    value:
                        '${_formatMs(widget.displayedPositionMs)} / ${_formatMs(widget.durationMs)}',
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
                            onTapDown: widget.onChanged == null
                                ? null
                                : (details) {
                                    final fraction =
                                        toFraction(details.localPosition.dx);
                                    widget.onChangeStart?.call(fraction);
                                    widget.onChanged?.call(fraction);
                                    widget.onChangeEnd?.call(fraction);
                                  },
                            onHorizontalDragStart: widget.onChanged == null
                                ? null
                                : (details) => widget.onChangeStart?.call(
                                      toFraction(details.localPosition.dx),
                                    ),
                            onHorizontalDragUpdate: widget.onChanged == null
                                ? null
                                : (details) => widget.onChanged?.call(
                                      toFraction(details.localPosition.dx),
                                    ),
                            onHorizontalDragEnd: widget.onChanged == null
                                ? null
                                : (_) =>
                                      widget.onChangeEnd?.call(progressValue),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOutCubic,
                              height: 8,
                              alignment: Alignment.center,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                height: _isHovered ? 5 : 3,
                                decoration: const BoxDecoration(
                                  color: SciFiColors.gridLines,
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progressValue,
                                  child: Container(
                                    color: SciFiColors.primaryYel,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : Container(
                    height: 2,
                    color: SciFiColors.gridLines,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '${_formatMs(widget.displayedPositionMs)}/${_formatMs(widget.durationMs)}',
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textMain,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
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

class _LyricsPanel extends StatelessWidget {
  final ScrapedSong? currentTrack;
  final String? playbackError;
  final bool isLoading;

  const _LyricsPanel({
    required this.currentTrack,
    required this.playbackError,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppState();
    final lines = playbackError != null
        ? <String>[
            '> AUDIO ENGINE ERROR',
            playbackError!,
            'VERIFY WEBDAV ACCESS, FILE AVAILABILITY, AND DECODER SUPPORT.',
          ]
        : isLoading
        ? <String>[
            '> TRACK REQUEST ACCEPTED',
            'REMOTE AUDIO BUFFERING IN PROGRESS.',
            'CURRENT STREAM HAS BEEN STOPPED.',
            'WAITING FOR NETWORK AND DECODER READINESS.',
          ]
        : currentTrack == null
        ? <String>[
            '> NO ACTIVE LYRIC FEED',
            'SELECT A TRACK TO ACTIVATE THE PLAYER VIEW.',
            'LYRIC SCRAPER INTEGRATION REMAINS PENDING.',
          ]
        : <String>[
            '> TRACK LINKED TO PLAYER STATE',
            'TITLE // ${currentTrack!.title}',
            'ARTIST // ${currentTrack!.artist}',
            'ALBUM // ${currentTrack!.album}',
            'REMOTE PATH // ${currentTrack!.path}',
            'QUEUE // ${appState.queueIndex + 1}/${appState.playbackQueue.length}',
            'PLAY MODE // ${switch (appState.playbackMode) { PlaybackMode.listLoop => 'LIST LOOP', PlaybackMode.singleLoop => 'SINGLE LOOP', PlaybackMode.shuffle => 'SHUFFLE', }}',
            'LYRIC SCRAPER INTEGRATION REMAINS PENDING.',
          ];

    return TechPanel(
      delay: const Duration(milliseconds: 200),
      backgroundColor: SciFiColors.surfaceLight.withValues(alpha: 0.5),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 36 * (1 - value)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: value,
                  child: Opacity(opacity: value.clamp(0, 1), child: child),
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LYRIC_FEED // TRACK_CONTEXT',
                style: GoogleFonts.shareTechMono(
                  color: SciFiColors.primaryYelGlow,
                  fontSize: 12,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final isActive = index == 0;
                    return Text(
                      lines[index],
                      style: GoogleFonts.shareTechMono(
                        color: isActive
                            ? SciFiColors.primaryYel
                            : SciFiColors.textDim,
                        fontSize: isActive ? 22 : 16,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RectControlButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onPressed;

  const _RectControlButton({
    required this.icon,
    this.iconSize = 24,
    this.color = SciFiColors.textMain,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(10),
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.12),
        splashColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor ?? Colors.transparent),
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

class _PlayerAddToPlaylistDialog extends StatefulWidget {
  final ScrapedSong song;

  const _PlayerAddToPlaylistDialog({required this.song});

  @override
  State<_PlayerAddToPlaylistDialog> createState() =>
      _PlayerAddToPlaylistDialogState();
}

class _PlayerAddToPlaylistDialogState extends State<_PlayerAddToPlaylistDialog> {
  String? _selectedPlaylistId;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final playlists = AppState().playlists;
    return AppDialogShell(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogTitle(
            title: 'PLAYLIST.ROUTER // IMPORT',
            subtitle: 'QUEUE CURRENT TRACK INTO AN EXISTING PLAYLIST.',
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.shareTechMono(
                  color: SciFiColors.errorRed,
                  fontSize: 11,
                ),
              ),
            ),
          if (playlists.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedPlaylistId,
              dropdownColor: SciFiColors.surfaceLight,
              style: GoogleFonts.shareTechMono(color: SciFiColors.textMain),
              decoration: InputDecoration(
                labelText: 'TARGET PLAYLIST',
                labelStyle: GoogleFonts.shareTechMono(
                  color: SciFiColors.textDim,
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: SciFiColors.gridLines),
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: SciFiColors.primaryYel),
                  borderRadius: BorderRadius.zero,
                ),
              ),
              items: playlists
                  .map(
                    (playlist) => DropdownMenuItem<String>(
                      value: playlist.id,
                      child: Text(playlist.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedPlaylistId = value),
            ),
          ] else
            Text(
              'NO PLAYLIST AVAILABLE. CREATE ONE IN THE PLAYLIST PAGE FIRST.',
              style: GoogleFonts.shareTechMono(
                color: SciFiColors.textDim,
                fontSize: 11,
                letterSpacing: 1.3,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: SciFiColors.gridLines),
              color: SciFiColors.background,
            ),
            child: ListTile(
              dense: true,
              title: Text(
                widget.song.title,
                style: GoogleFonts.shareTechMono(
                  color: SciFiColors.textMain,
                  fontSize: 12,
                ),
              ),
              subtitle: Text(
                widget.song.artist,
                style: GoogleFonts.shareTechMono(
                  color: SciFiColors.textDim,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppDialogActions(
            confirmLabel: 'IMPORT',
            isLoading: _isSubmitting,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final playlistId = _selectedPlaylistId;
    final error = playlistId == null
        ? 'Select an existing playlist first.'
        : await AppState().addSongsToPlaylist(
            playlistId: playlistId,
            songs: [widget.song],
          );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
      return;
    }
    Navigator.of(context).pop();
    AppNotifications.instance.showInfo('IMPORTED 1 TRACK TO PLAYLIST');
  }
}
