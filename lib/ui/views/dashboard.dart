import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/webdav_config.dart';
import '../../services/app_notifications.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_menu_button.dart';
import '../widgets/neo_brutalism/nb_panel.dart';
import '../widgets/neo_brutalism/nb_button.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  String? _activeConfigId;
  final Set<String> _selectedSongIds = {};
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openConfig(String configId) {
    setState(() {
      _activeConfigId = configId;
      _selectedSongIds.clear();
      _isSearchExpanded = false;
      _searchController.clear();
    });
  }

  void _closeConfig() {
    setState(() {
      _activeConfigId = null;
      _selectedSongIds.clear();
      _isSearchExpanded = false;
      _searchController.clear();
    });
  }

  void _toggleSelection(String songId) {
    setState(() {
      if (_selectedSongIds.contains(songId)) {
        _selectedSongIds.remove(songId);
      } else {
        _selectedSongIds.add(songId);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedSongIds.clear());

  Future<void> _openAddToPlaylistDialog(List<ScrapedSong> songs) async {
    if (songs.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _AddToPlaylistDialog(songs: songs),
    );
    if (mounted && _selectedSongIds.isNotEmpty) _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final activeConfig = _activeConfigId == null
            ? null
            : AppState().webDavConfigs
                  .where((c) => c.id == _activeConfigId)
                  .firstOrNull;

        return Stack(
          children: [
            AnimatedSwitcher(
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
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: activeConfig == null
                  ? _DashboardHome(
                      key: const ValueKey('dashboard-home'),
                      configs: AppState().webDavConfigs,
                      onOpenConfig: _openConfig,
                    )
                  : _ConfigDetailView(
                      key: ValueKey('dashboard-detail-${activeConfig.id}'),
                      config: activeConfig,
                      selectedSongIds: _selectedSongIds,
                      isSearchExpanded: _isSearchExpanded,
                      searchController: _searchController,
                      onBack: _closeConfig,
                      onToggleSearch: () {
                        setState(() {
                          _isSearchExpanded = !_isSearchExpanded;
                          if (!_isSearchExpanded) _searchController.clear();
                        });
                      },
                      onToggleSelection: _toggleSelection,
                      onAddToPlaylist: _openAddToPlaylistDialog,
                    ),
            ),
            if (activeConfig != null && _selectedSongIds.isNotEmpty)
              Positioned(
                bottom: 16,
                right: 16,
                child: NbPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: SciFiColors.surface,
                  shadowOffset: const Offset(4, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selectedSongIds.length} SELECTED',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.primaryYel,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        hoverColor: SciFiColors.primaryYelGlow.withValues(
                          alpha: 0.2,
                        ),
                        icon: const Icon(
                          Icons.playlist_add,
                          color: SciFiColors.textMain,
                        ),
                        onPressed: () => _openAddToPlaylistDialog(
                          activeConfig.songs
                              .where((s) => _selectedSongIds.contains(s.id))
                              .toList(),
                        ),
                      ),
                      IconButton(
                        hoverColor: SciFiColors.errorRed.withValues(alpha: 0.2),
                        icon: const Icon(
                          Icons.close,
                          color: SciFiColors.textDim,
                        ),
                        onPressed: _clearSelection,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DashboardHome extends StatefulWidget {
  final List<WebDavConfig> configs;
  final ValueChanged<String> onOpenConfig;

  const _DashboardHome({
    super.key,
    required this.configs,
    required this.onOpenConfig,
  });

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = AppState().searchQuery;
    _isSearchExpanded = AppState().searchQuery.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NbPanel(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: SciFiColors.surfaceLight,
          shadowOffset: const Offset(8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ARK_PULSE // WEBDAV_HUB',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.primaryYel,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    Text(
                      'SELECT A NODE TO ENTER TRACK LIST VIEW',
                      style: GoogleFonts.shareTechMono(
                        color: SciFiColors.textDim,
                        fontSize: 10,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.configs.length} NODES',
                    style: GoogleFonts.shareTechMono(
                      color: SciFiColors.textDim,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isSearchExpanded ? Icons.close : Icons.search,
                      color: _isSearchExpanded
                          ? SciFiColors.primaryYel
                          : SciFiColors.textDim,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        if (!_isSearchExpanded) {
                          _searchController.clear();
                          AppState().clearSearch();
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _NbSearchBar(
          isExpanded: _isSearchExpanded,
          controller: _searchController,
          hintText:
              'GLOBAL DEEP SEARCH ACROSS ${appState.getAllScrapedSongs().length} TRACKS...',
          onChanged: (val) => appState.searchSongs(val),
          onClear: () {
            _searchController.clear();
            appState.clearSearch();
          },
          showClear: appState.searchQuery.isNotEmpty,
        ),
        Expanded(
          child: appState.searchQuery.isNotEmpty
              ? _buildSearchResults(appState, context)
              : widget.configs.isEmpty
              ? Center(
                  child: Text(
                    '> NO WEBDAV SOURCES CONFIGURED\n> PROCEED TO CONFIG PANEL',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.shareTechMono(
                      color: SciFiColors.textDim,
                      height: 1.5,
                    ),
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: widget.configs.length,
                  itemBuilder: (context, index) {
                    final config = widget.configs[index];
                    return _ConfigSummaryCard(
                      config: config,
                      onOpen: () => widget.onOpenConfig(config.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(AppState appState, BuildContext context) {
    if (appState.isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: SciFiColors.primaryYel),
      );
    }
    final results = appState.searchResults;
    if (results.isEmpty) {
      return Center(
        child: Text(
          '> 0 MATCHES FOUND ACROSS NETWORK',
          style: GoogleFonts.shareTechMono(color: SciFiColors.textDim),
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final song = results[index];
        return _SongListItem(
          song: song,
          isSelected: false,
          isMultiSelectMode: false,
          onToggle: () {},
          onPlay: () => appState.playSong(song, queue: results),
          onAddToPlaylist: () async {
            await showDialog<void>(
              context: context,
              builder: (context) => _AddToPlaylistDialog(songs: [song]),
            );
          },
        );
      },
    );
  }
}

class _ConfigSummaryCard extends StatefulWidget {
  final WebDavConfig config;
  final VoidCallback onOpen;

  const _ConfigSummaryCard({required this.config, required this.onOpen});

  @override
  State<_ConfigSummaryCard> createState() => _ConfigSummaryCardState();
}

class _ConfigSummaryCardState extends State<_ConfigSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return NbButton(
      onPressed: widget.onOpen,
      padding: const EdgeInsets.all(20),
      backgroundColor: SciFiColors.surfaceLight,
      shadowOffset: const Offset(6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                config.state == ScrapeState.success
                    ? Icons.dns
                    : Icons.cloud_off,
                color: config.state == ScrapeState.success
                    ? SciFiColors.primaryYel
                    : SciFiColors.textDim,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  config.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.shareTechMono(
                    color: SciFiColors.primaryYel,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _RectHeaderButton(
                onPressed: config.state == ScrapeState.loading
                    ? null
                    : () => AppState().triggerScrape(config.id),
                icon: Icons.sync,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            config.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PATH // ${config.davPath}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 10,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: 'TRACKS', value: '${config.songs.length}'),
              _InfoChip(
                label: 'STATE',
                value: switch (config.state) {
                  ScrapeState.idle => 'IDLE',
                  ScrapeState.loading => 'SYNC',
                  ScrapeState.success => 'READY',
                  ScrapeState.error => 'FAULT',
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigDetailView extends StatefulWidget {
  final WebDavConfig config;
  final Set<String> selectedSongIds;
  final bool isSearchExpanded;
  final TextEditingController searchController;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final void Function(String songId) onToggleSelection;
  final Future<void> Function(List<ScrapedSong> songs) onAddToPlaylist;

  const _ConfigDetailView({
    super.key,
    required this.config,
    required this.selectedSongIds,
    required this.isSearchExpanded,
    required this.searchController,
    required this.onBack,
    required this.onToggleSearch,
    required this.onToggleSelection,
    required this.onAddToPlaylist,
  });

  @override
  State<_ConfigDetailView> createState() => _ConfigDetailViewState();
}

class _ConfigDetailViewState extends State<_ConfigDetailView> {
  @override
  Widget build(BuildContext context) {
    final query = widget.searchController.text.trim().toLowerCase();
    final songs = query.isEmpty
        ? widget.config.songs
        : widget.config.songs.where((song) {
            return song.title.toLowerCase().contains(query) ||
                song.artist.toLowerCase().contains(query) ||
                song.album.toLowerCase().contains(query);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NbPanel(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: SciFiColors.surfaceLight,
          shadowOffset: const Offset(8, 8),
          child: Row(
            children: [
              _RectHeaderButton(
                onPressed: widget.onBack,
                icon: Icons.arrow_back,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.config.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.shareTechMono(
                        color: SciFiColors.primaryYel,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.8,
                      ),
                    ),
                    Text(
                      '${widget.config.songs.length} TRACKS // DOUBLE TAP TO PLAY',
                      style: GoogleFonts.shareTechMono(
                        color: SciFiColors.textDim,
                        fontSize: 10,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onToggleSearch,
                icon: Icon(
                  widget.isSearchExpanded ? Icons.close : Icons.search,
                  color: widget.isSearchExpanded
                      ? SciFiColors.primaryYel
                      : SciFiColors.textDim,
                ),
              ),
              IconButton(
                onPressed: widget.config.state == ScrapeState.loading
                    ? null
                    : () => AppState().triggerScrape(widget.config.id),
                icon: widget.config.state == ScrapeState.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SciFiColors.primaryYel,
                        ),
                      )
                    : const Icon(Icons.sync, color: SciFiColors.textMain),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _NbSearchBar(
          isExpanded: widget.isSearchExpanded,
          controller: widget.searchController,
          hintText: 'SEARCH TRACKS IN CURRENT NODE...',
          onChanged: (_) => setState(() {}),
          onClear: () {
            widget.searchController.clear();
            setState(() {});
          },
          showClear: query.isNotEmpty,
        ),
        Expanded(
          child: NbPanel(
            backgroundColor: SciFiColors.surface,
            padding: EdgeInsets.zero,
            shadowOffset: const Offset(8, 8),
            child: songs.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? '> NODE HAS NO TRACKS\n> RUN SYNC TO POPULATE CONTENT'
                          : '> NO MATCHES FOUND IN CURRENT NODE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                        color: SciFiColors.textDim,
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return _SongListItem(
                        song: song,
                        isSelected: widget.selectedSongIds.contains(song.id),
                        isMultiSelectMode: widget.selectedSongIds.isNotEmpty,
                        onToggle: () => widget.onToggleSelection(song.id),
                        onPlay: () =>
                            AppState().playQueue(songs, startIndex: index),
                        onAddToPlaylist: () => widget.onAddToPlaylist([song]),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _RectHeaderButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;

  const _RectHeaderButton({required this.onPressed, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.14),
        splashColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: SciFiColors.gridLines),
          ),
          child: Icon(icon, color: SciFiColors.primaryYel),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SciFiColors.background,
        border: Border.all(color: SciFiColors.gridLines),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.shareTechMono(fontSize: 10),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: SciFiColors.textDim),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: SciFiColors.primaryYel,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongListItem extends StatefulWidget {
  final ScrapedSong song;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onToggle;
  final Future<String?> Function() onPlay;
  final VoidCallback onAddToPlaylist;

  const _SongListItem({
    required this.song,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onToggle,
    required this.onPlay,
    required this.onAddToPlaylist,
  });

  @override
  State<_SongListItem> createState() => _SongListItemState();
}

class _SongListItemState extends State<_SongListItem> {
  bool _isHovered = false;

  void _handleMenuAction(_SongMenuAction action) {
    if (action == _SongMenuAction.select) {
      widget.onToggle();
    } else if (action == _SongMenuAction.addToPlaylist) {
      widget.onAddToPlaylist();
    } else if (action == _SongMenuAction.info) {
      AppNotifications.instance.showInfo('TRACK INFO OVERLAY NOT YET DEPLOYED');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState();
    final isCurrentTrack =
        appState.currentTrack?.webDavHref == widget.song.webDavHref &&
        appState.currentTrack?.serverUrl == widget.song.serverUrl;
    final isLoadingTrack = isCurrentTrack && appState.isTrackLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onLongPress: widget.onToggle,
        onTap: widget.isMultiSelectMode ? widget.onToggle : null,
        onDoubleTap: widget.isMultiSelectMode
            ? null
            : () async {
                final error = await widget.onPlay();
                if (error != null) {
                  AppNotifications.instance.showError(
                    'AUDIO ENGINE ERROR: $error',
                  );
                }
              },
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
                    widget.song.title,
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
              '${widget.song.artist} // ${widget.song.album}',
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
                  child: AppMenuButton<_SongMenuAction>(
                    highlighted: _isHovered,
                    items: const [
                      AppMenuEntry(
                        value: _SongMenuAction.select,
                        label: 'Select',
                        icon: Icons.checklist,
                      ),
                      AppMenuEntry(
                        value: _SongMenuAction.addToPlaylist,
                        label: 'Add to Playlist',
                        icon: Icons.playlist_add,
                      ),
                      AppMenuEntry(
                        value: _SongMenuAction.info,
                        label: 'Info',
                        icon: Icons.info_outline,
                      ),
                    ],
                    onSelected: _handleMenuAction,
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

class _AddToPlaylistDialog extends StatefulWidget {
  final List<ScrapedSong> songs;

  const _AddToPlaylistDialog({required this.songs});

  @override
  State<_AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<_AddToPlaylistDialog> {
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
          AppDialogTitle(
            title: 'PLAYLIST.ROUTER // IMPORT',
            subtitle:
                'QUEUE ${widget.songs.length} TRACKS INTO AN EXISTING PLAYLIST.',
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
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              border: Border.all(color: SciFiColors.gridLines),
              color: SciFiColors.background,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.songs.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: SciFiColors.gridLines),
              itemBuilder: (context, index) {
                final song = widget.songs[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    song.title,
                    style: GoogleFonts.shareTechMono(
                      color: SciFiColors.textMain,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    style: GoogleFonts.shareTechMono(
                      color: SciFiColors.textDim,
                      fontSize: 10,
                    ),
                  ),
                );
              },
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
    String? error;
    if (_selectedPlaylistId != null) {
      error = await AppState().addSongsToPlaylist(
        playlistId: _selectedPlaylistId!,
        songs: widget.songs,
      );
    } else {
      error = 'Select an existing playlist first.';
    }
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
      'IMPORTED ${widget.songs.length} TRACK(S) TO PLAYLIST',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

enum _SongMenuAction { select, addToPlaylist, info }

class _NbSearchBar extends StatelessWidget {
  final bool isExpanded;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback onClear;
  final bool showClear;

  const _NbSearchBar({
    required this.isExpanded,
    required this.controller,
    required this.hintText,
    this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: isExpanded
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: NbPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                backgroundColor: SciFiColors.surfaceLight,
                shadowOffset: const Offset(4, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: SciFiColors.primaryYel,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textMain,
                          fontSize: 16,
                        ),
                        cursorColor: SciFiColors.primaryYel,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: GoogleFonts.shareTechMono(
                            color: SciFiColors.textDim,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: onChanged,
                      ),
                    ),
                    Visibility(
                      visible: showClear,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: SciFiColors.textDim,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: onClear,
                        hoverColor: SciFiColors.errorRed.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
