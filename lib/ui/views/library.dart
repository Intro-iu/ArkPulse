import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/playlist.dart';
import '../../services/app_notifications.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/neo_brutalism/nb_panel.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  String? _selectedPlaylistId;
  final Set<String> _selectedTrackIds = {};

  void _toggleTrackSelection(String trackId) {
    setState(() {
      if (_selectedTrackIds.contains(trackId)) {
        _selectedTrackIds.remove(trackId);
      } else {
        _selectedTrackIds.add(trackId);
      }
    });
  }

  void _enterTrackSelection(String trackId) {
    setState(() {
      _selectedTrackIds.add(trackId);
    });
  }

  void _clearTrackSelection() {
    setState(() => _selectedTrackIds.clear());
  }

  Future<void> _removeSelectedTracks(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        title: 'REMOVE TRACKS',
        message:
            'Remove ${_selectedTrackIds.length} selected track(s) from "${playlist.name}"?',
        confirmLabel: 'REMOVE',
      ),
    );
    if (confirmed != true) {
      return;
    }
    final selectedIds = List<String>.from(_selectedTrackIds);
    for (final trackId in selectedIds) {
      await AppState().removePlaylistTrack(
        playlistId: playlist.id,
        trackId: trackId,
      );
    }
    if (!mounted) {
      return;
    }
    _clearTrackSelection();
    AppNotifications.instance.showInfo(
      'REMOVED ${selectedIds.length} TRACK(S) FROM PLAYLIST',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final playlists = AppState().playlists;
        if (_selectedPlaylistId == null && playlists.isNotEmpty) {
          _selectedPlaylistId = playlists.first.id;
        }
        if (playlists.every((playlist) => playlist.id != _selectedPlaylistId)) {
          _selectedPlaylistId = playlists.isEmpty ? null : playlists.first.id;
        }

        final selectedPlaylist = playlists
            .where((playlist) => playlist.id == _selectedPlaylistId)
            .cast<Playlist?>()
            .firstOrNull;
        if (selectedPlaylist == null) {
          _selectedTrackIds.clear();
        } else {
          _selectedTrackIds.removeWhere(
            (trackId) =>
                !selectedPlaylist.tracks.any((track) => track.id == trackId),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NbPanel(
                        height: 88,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: SciFiColors.surfaceLight,
                        shadowOffset: const Offset(8, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'LOCAL_COLLECTION // PLAYLISTS',
                                  style: GoogleFonts.shareTechMono(
                                    color: SciFiColors.primaryYel,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                Text(
                                  'VERSION 0.4.0 // LOCAL CURATION ONLINE',
                                  style: GoogleFonts.shareTechMono(
                                    color: SciFiColors.textDim,
                                    fontSize: 10,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${playlists.length} PLAYLISTS',
                              style: GoogleFonts.shareTechMono(
                                color: SciFiColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: playlists.isEmpty
                            ? const _EmptyLibraryState()
                            : Row(
                                children: [
                                  SizedBox(
                                    width: 320,
                                    child: _PlaylistListPanel(
                                      playlists: playlists,
                                      selectedPlaylistId: _selectedPlaylistId,
                                      onSelect: (playlistId) {
                                        setState(
                                          () =>
                                              _selectedPlaylistId = playlistId,
                                        );
                                      },
                                      onDelete: (playlistId) async {
                                        await AppState().deletePlaylist(
                                          playlistId,
                                        );
                                      },
                                      onAddTracks: (playlist) {
                                        showDialog<void>(
                                          context: context,
                                          builder: (context) =>
                                              _AddTracksToPlaylistDialog(
                                                playlist: playlist,
                                              ),
                                        );
                                      },
                                      onCreatePlaylist: () => showDialog<void>(
                                        context: context,
                                        builder: (context) =>
                                            const _CreatePlaylistDialog(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _PlaylistDetailPanel(
                                      playlist: selectedPlaylist,
                                      selectedTrackIds: _selectedTrackIds,
                                      onRemoveTrack: (trackId) async {
                                        if (selectedPlaylist == null) return;
                                        await AppState().removePlaylistTrack(
                                          playlistId: selectedPlaylist.id,
                                          trackId: trackId,
                                        );
                                      },
                                      onToggleTrackSelection:
                                          _toggleTrackSelection,
                                      onEnterTrackSelection:
                                          _enterTrackSelection,
                                      onRemoveSelectedTracks:
                                          selectedPlaylist == null
                                          ? null
                                          : () => _removeSelectedTracks(
                                              selectedPlaylist,
                                            ),
                                      onClearSelection: _clearTrackSelection,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    return NbPanel(
      backgroundColor: SciFiColors.surface.withValues(alpha: 0.5),
      shadowOffset: const Offset(4, 4),
      isFrosted: true,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.playlist_remove,
              size: 64,
              color: SciFiColors.textDim,
            ),
            const SizedBox(height: 24),
            Text(
              'NO LOCAL PLAYLISTS CONFIGURED',
              style: GoogleFonts.shareTechMono(
                color: SciFiColors.textMain,
                fontSize: 18,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '> Use the WEBDAV_HUB to scrape remote nodes and import tracks here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.shareTechMono(
                color: SciFiColors.textDim,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistListPanel extends StatelessWidget {
  final List<Playlist> playlists;
  final String? selectedPlaylistId;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String playlistId) onDelete;
  final void Function(Playlist playlist) onAddTracks;
  final VoidCallback onCreatePlaylist;

  const _PlaylistListPanel({
    required this.playlists,
    required this.selectedPlaylistId,
    required this.onSelect,
    required this.onDelete,
    required this.onAddTracks,
    required this.onCreatePlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NbPanel(
          padding: EdgeInsets.zero,
          backgroundColor: SciFiColors.surface,
          shadowOffset: const Offset(6, 6),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _PlaylistListRow(
                playlist: playlist,
                isSelected: playlist.id == selectedPlaylistId,
                onSelect: () => onSelect(playlist.id),
                onDelete: () => onDelete(playlist.id),
                onAddTracks: () => onAddTracks(playlist),
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: _AddPlaylistFab(onTap: onCreatePlaylist),
        ),
      ],
    );
  }
}

class _PlaylistDetailPanel extends StatelessWidget {
  final Playlist? playlist;
  final Set<String> selectedTrackIds;
  final Future<void> Function(String trackId) onRemoveTrack;
  final ValueChanged<String> onToggleTrackSelection;
  final ValueChanged<String> onEnterTrackSelection;
  final VoidCallback? onRemoveSelectedTracks;
  final VoidCallback onClearSelection;

  const _PlaylistDetailPanel({
    required this.playlist,
    required this.selectedTrackIds,
    required this.onRemoveTrack,
    required this.onToggleTrackSelection,
    required this.onEnterTrackSelection,
    required this.onRemoveSelectedTracks,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (playlist == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        NbPanel(
          padding: EdgeInsets.zero,
          backgroundColor: SciFiColors.surface,
          shadowOffset: const Offset(6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist!.name,
                            style: GoogleFonts.shareTechMono(
                              color: SciFiColors.primaryYel,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${playlist!.tracks.length} TRACKS // DOUBLE TAP TO PLAY',
                            style: GoogleFonts.shareTechMono(
                              color: SciFiColors.textDim,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: SciFiColors.gridLines),
              Expanded(
                child: playlist!.tracks.isEmpty
                    ? Center(
                        child: Text(
                          '> PLAYLIST IS EMPTY\n> IMPORT TRACKS FROM WEBDAV_HUB',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.shareTechMono(
                            color: SciFiColors.textDim,
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.only(
                          bottom: selectedTrackIds.isNotEmpty ? 88 : 0,
                        ),
                        itemCount: playlist!.tracks.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: SciFiColors.gridLines,
                        ),
                        itemBuilder: (context, index) {
                          final track = playlist!.tracks[index];
                          final queue = playlist!.tracks
                              .map((item) => item.toScrapedSong())
                              .toList();
                          return _PlaylistTrackRow(
                            track: track,
                            isSelected: selectedTrackIds.contains(track.id),
                            isMultiSelectMode: selectedTrackIds.isNotEmpty,
                            onPlay: () async {
                              final error = await AppState().playQueue(
                                queue,
                                startIndex: index,
                              );
                              if (error != null) {
                                AppNotifications.instance.showError(error);
                              }
                            },
                            onRemove: () => onRemoveTrack(track.id),
                            onToggleSelect: () =>
                                onToggleTrackSelection(track.id),
                            onEnterSelection: () =>
                                onEnterTrackSelection(track.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (selectedTrackIds.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: NbPanel(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              backgroundColor: SciFiColors.surface,
              shadowOffset: const Offset(4, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedTrackIds.length} SELECTED',
                    style: GoogleFonts.shareTechMono(
                      color: SciFiColors.primaryYel,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _BatchActionButton(
                    icon: Icons.delete_outline,
                    onPressed: onRemoveSelectedTracks ?? () {},
                  ),
                  const SizedBox(width: 8),
                  _BatchActionButton(
                    icon: Icons.close,
                    onPressed: onClearSelection,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaylistListRow extends StatefulWidget {
  final Playlist playlist;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onAddTracks;

  const _PlaylistListRow({
    required this.playlist,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
    required this.onAddTracks,
  });

  @override
  State<_PlaylistListRow> createState() => _PlaylistListRowState();
}

class _PlaylistListRowState extends State<_PlaylistListRow> {
  bool _isHovered = false;

  Future<void> _confirmDeletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        title: 'DELETE PLAYLIST',
        message:
            'Remove "${widget.playlist.name}" and all of its track references from the local playlist library?',
        confirmLabel: 'DELETE',
      ),
    );
    if (confirmed == true) {
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isSelected
        ? Color.lerp(
            SciFiColors.surfaceLight,
            SciFiColors.primaryYelGlow,
            0.08,
          )!
        : (_isHovered ? SciFiColors.surface : SciFiColors.surfaceLight);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: widget.isSelected
                  ? SciFiColors.primaryYel
                  : (_isHovered
                        ? SciFiColors.gridLines
                        : SciFiColors.gridLines.withValues(alpha: 0.3)),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.name,
                      style: GoogleFonts.shareTechMono(
                        color: widget.isSelected
                            ? SciFiColors.primaryYel
                            : SciFiColors.textMain,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.playlist.tracks.length} TRACKS',
                      style: GoogleFonts.shareTechMono(
                        color: _isHovered || widget.isSelected
                            ? SciFiColors.textMain
                            : SciFiColors.textDim,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _isHovered ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: AppMenuButton<_PlaylistRowMenuAction>(
                      highlighted: _isHovered,
                      items: const [
                        AppMenuEntry(
                          value: _PlaylistRowMenuAction.add,
                          label: 'Add Tracks',
                          icon: Icons.playlist_add,
                        ),
                        AppMenuEntry(
                          value: _PlaylistRowMenuAction.delete,
                          label: 'Delete',
                          icon: Icons.delete_outline,
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case _PlaylistRowMenuAction.add:
                            widget.onAddTracks();
                          case _PlaylistRowMenuAction.delete:
                            _confirmDeletePlaylist();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTrackRow extends StatefulWidget {
  final PlaylistTrack track;
  final bool isSelected;
  final bool isMultiSelectMode;
  final Future<void> Function() onPlay;
  final VoidCallback onRemove;
  final VoidCallback onToggleSelect;
  final VoidCallback onEnterSelection;

  const _PlaylistTrackRow({
    required this.track,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onPlay,
    required this.onRemove,
    required this.onToggleSelect,
    required this.onEnterSelection,
  });

  @override
  State<_PlaylistTrackRow> createState() => _PlaylistTrackRowState();
}

class _PlaylistTrackRowState extends State<_PlaylistTrackRow> {
  bool _isHovered = false;

  Future<void> _confirmRemoveTrack() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        title: 'REMOVE TRACK',
        message:
            'Remove "${widget.track.title}" from this playlist? The source file on WebDAV will not be deleted.',
        confirmLabel: 'REMOVE',
      ),
    );
    if (confirmed == true) {
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState();
    final isCurrentTrack =
        appState.currentTrack?.webDavHref == widget.track.webDavHref &&
        appState.currentTrack?.serverUrl == widget.track.serverUrl;
    final isLoadingTrack = isCurrentTrack && appState.isTrackLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onLongPress: widget.onEnterSelection,
        onTap: widget.isMultiSelectMode ? widget.onToggleSelect : null,
        onDoubleTap: widget.isMultiSelectMode ? null : widget.onPlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: widget.isSelected
              ? SciFiColors.primaryYelGlow.withValues(alpha: 0.2)
              : isCurrentTrack
              ? SciFiColors.primaryYelGlow.withValues(alpha: 0.14)
              : (_isHovered ? SciFiColors.background : Colors.transparent),
          child: ListTile(
            title: Row(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: widget.isMultiSelectMode
                      ? Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(
                            widget.isSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 16,
                            color: widget.isSelected
                                ? SciFiColors.primaryYel
                                : SciFiColors.textDim,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (isCurrentTrack)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: isLoadingTrack
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SciFiColors.primaryYel,
                            ),
                          )
                        : const Icon(
                            Icons.volume_up,
                            size: 14,
                            color: SciFiColors.primaryYel,
                          ),
                  ),
                Expanded(
                  child: Text(
                    widget.track.title,
                    style: GoogleFonts.shareTechMono(
                      color: isCurrentTrack
                          ? SciFiColors.primaryYel
                          : SciFiColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${widget.track.artist} // ${widget.track.album}',
              style: GoogleFonts.shareTechMono(
                color: isCurrentTrack
                    ? SciFiColors.primaryYel.withValues(alpha: 0.8)
                    : SciFiColors.textDim,
                fontSize: 10,
              ),
            ),
            trailing: SizedBox(
              width: 36,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _isHovered && !widget.isMultiSelectMode ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !(_isHovered && !widget.isMultiSelectMode),
                  child: AppMenuButton<_PlaylistTrackMenuAction>(
                    highlighted: _isHovered,
                    items: const [
                      AppMenuEntry(
                        value: _PlaylistTrackMenuAction.select,
                        label: 'Select',
                        icon: Icons.checklist,
                      ),
                      AppMenuEntry(
                        value: _PlaylistTrackMenuAction.remove,
                        label: 'Remove',
                        icon: Icons.delete_outline,
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case _PlaylistTrackMenuAction.select:
                          if (widget.isMultiSelectMode) {
                            widget.onToggleSelect();
                          } else {
                            widget.onEnterSelection();
                          }
                        case _PlaylistTrackMenuAction.remove:
                          _confirmRemoveTrack();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogTitle(title: 'PLAYLIST.BOOTSTRAP'),
          const SizedBox(height: 16),
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
          TextField(
            controller: _controller,
            style: GoogleFonts.shareTechMono(color: SciFiColors.textMain),
            decoration: InputDecoration(
              hintText: 'e.g. FAVORITES // REMOTE',
              hintStyle: GoogleFonts.shareTechMono(
                color: SciFiColors.gridLines,
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
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: AppDialogActions(
              confirmLabel: 'CREATE',
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _submit,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final error = await AppState().createPlaylist(_controller.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    Navigator.of(context).pop();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _AddPlaylistFab extends StatefulWidget {
  final VoidCallback onTap;

  const _AddPlaylistFab({required this.onTap});

  @override
  State<_AddPlaylistFab> createState() => _AddPlaylistFabState();
}

class _AddPlaylistFabState extends State<_AddPlaylistFab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovered ? SciFiColors.primaryYel : SciFiColors.gridLines,
              width: 1.5,
            ),
            color: _hovered
                ? SciFiColors.primaryYelGlow
                : SciFiColors.surfaceLight,
          ),
          child: Icon(
            Icons.add,
            color: _hovered ? SciFiColors.primaryYel : SciFiColors.textMain,
            size: 24,
          ),
        ),
      ),
    );
  }
}

enum _PlaylistRowMenuAction { add, delete }

enum _PlaylistTrackMenuAction { select, remove }

class _BatchActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _BatchActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: SciFiColors.gridLines),
          ),
          child: Icon(icon, size: 18, color: SciFiColors.textMain),
        ),
      ),
    );
  }
}

class _AddTracksToPlaylistDialog extends StatefulWidget {
  final Playlist playlist;

  const _AddTracksToPlaylistDialog({required this.playlist});

  @override
  State<_AddTracksToPlaylistDialog> createState() =>
      _AddTracksToPlaylistDialogState();
}

class _AddTracksToPlaylistDialogState
    extends State<_AddTracksToPlaylistDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedSongIds = {};
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final allSongs = AppState().getAllScrapedSongs();
    final songs = query.isEmpty
        ? allSongs
        : allSongs
              .where(
                (song) =>
                    song.title.toLowerCase().contains(query) ||
                    song.artist.toLowerCase().contains(query) ||
                    song.album.toLowerCase().contains(query),
              )
              .toList();

    return AppDialogShell(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogTitle(
            title: 'ADD TRACKS',
            subtitle: 'IMPORT TRACKS INTO "${widget.playlist.name}".',
          ),
          const SizedBox(height: 16),
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
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.shareTechMono(color: SciFiColors.textMain),
            decoration: InputDecoration(
              hintText: 'SEARCH TRACKS...',
              hintStyle: GoogleFonts.shareTechMono(
                color: SciFiColors.gridLines,
              ),
              filled: true,
              fillColor: SciFiColors.background,
              prefixIcon: const Icon(
                Icons.search,
                color: SciFiColors.primaryYel,
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: SciFiColors.gridLines),
                borderRadius: BorderRadius.zero,
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: SciFiColors.primaryYel),
                borderRadius: BorderRadius.zero,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              border: Border.all(color: SciFiColors.gridLines),
              color: SciFiColors.background,
            ),
            child: songs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '> NO TRACKS AVAILABLE',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textDim,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: songs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: SciFiColors.gridLines),
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final selected = _selectedSongIds.contains(song.id);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedSongIds.remove(song.id);
                            } else {
                              _selectedSongIds.add(song.id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                size: 16,
                                color: selected
                                    ? SciFiColors.primaryYel
                                    : SciFiColors.textDim,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: GoogleFonts.shareTechMono(
                                        color: SciFiColors.textMain,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${song.artist} // ${song.album}',
                                      style: GoogleFonts.shareTechMono(
                                        color: SciFiColors.textDim,
                                        fontSize: 10,
                                      ),
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
          const SizedBox(height: 20),
          AppDialogActions(
            confirmLabel: 'ADD',
            isLoading: _isSubmitting,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedSongIds.isEmpty) {
      setState(() => _errorMessage = 'Select at least one track.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final allSongs = AppState().getAllScrapedSongs();
    final selectedSongs = allSongs
        .where((song) => _selectedSongIds.contains(song.id))
        .toList();
    final error = await AppState().addSongsToPlaylist(
      playlistId: widget.playlist.id,
      songs: selectedSongs,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = error;
      });
      return;
    }
    Navigator.of(context).pop();
    AppNotifications.instance.showInfo(
      'ADDED ${selectedSongs.length} TRACK(S) TO PLAYLIST',
    );
  }
}
