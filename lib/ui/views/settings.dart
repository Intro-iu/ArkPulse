import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/neo_brutalism/nb_panel.dart';
import '../widgets/neo_brutalism/nb_button.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/app_state.dart';
import '../../models/webdav_config.dart';

// ---------------------------------------------------------------------------
// Root SettingsView : shows a list of settings categories
// ---------------------------------------------------------------------------
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  _SettingsPage _currentPage = _SettingsPage.root;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: switch (_currentPage) {
        _SettingsPage.root => _SettingsRoot(
          key: const ValueKey('settings-root'),
          onNavigate: (page) => setState(() => _currentPage = page),
        ),
        _SettingsPage.webdav => _WebDavSettingsPage(
          key: const ValueKey('settings-webdav'),
          onBack: () => setState(() => _currentPage = _SettingsPage.root),
        ),
      },
    );
  }
}

enum _SettingsPage { root, webdav }

// ---------------------------------------------------------------------------
// Root settings menu
// ---------------------------------------------------------------------------
class _SettingsRoot extends StatelessWidget {
  final Function(_SettingsPage) onNavigate;

  const _SettingsRoot({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsItem(
                icon: Icons.cloud_outlined,
                title: 'WEBDAV STORAGE NODES',
                subtitle: 'MANAGE REMOTE MUSIC LIBRARIES',
                onTap: () => onNavigate(_SettingsPage.webdav),
              ),
              const SizedBox(height: 12),
              _SettingsItem(
                icon: Icons.equalizer_outlined,
                title: 'AUDIO ENGINE',
                subtitle: 'PLAYBACK PREFERENCES // [AWAITING DEPLOYMENT]',
                onTap: null,
              ),
              const SizedBox(height: 12),
              _SettingsItem(
                icon: Icons.palette_outlined,
                title: 'INTERFACE',
                subtitle: 'VISUAL PREFERENCES // [AWAITING DEPLOYMENT]',
                onTap: null,
              ),
              const SizedBox(height: 12),
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'SYSTEM INFO',
                subtitle: 'ARKPULSE v0.3.0 // AUDIT LOG',
                onTap: null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return NbPanel(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      backgroundColor: SciFiColors.surfaceLight,
      shadowOffset: const Offset(8, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM.CONFIG // TERMINAL',
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.primaryYel,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          Text(
            'CONFIGURE APPLICATION PARAMETERS',
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 10,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return NbButton(
      onPressed: enabled ? widget.onTap : null,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: SciFiColors.surfaceLight,
      shadowOffset: const Offset(4, 4),
      child: Row(
        children: [
          Icon(
            widget.icon,
            color: enabled ? SciFiColors.textMain : SciFiColors.textDim,
            size: 24,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.shareTechMono(
                    color: enabled ? SciFiColors.textMain : SciFiColors.textDim,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.shareTechMono(
                    color: SciFiColors.textDim,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            const Icon(Icons.chevron_right, color: SciFiColors.textDim),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WebDAV Sub-Page
// ---------------------------------------------------------------------------
class _WebDavSettingsPage extends StatelessWidget {
  final VoidCallback onBack;

  const _WebDavSettingsPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with back button
            NbPanel(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              backgroundColor: SciFiColors.surfaceLight,
              shadowOffset: const Offset(8, 8),
              child: Row(
                children: [
                  _RectHeaderButton(onPressed: onBack, icon: Icons.arrow_back),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEBDAV STORAGE NODES',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.primaryYel,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Text(
                        'MANAGE REMOTE MUSIC LIBRARIES',
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textDim,
                          fontSize: 10,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListenableBuilder(
                listenable: AppState(),
                builder: (context, _) {
                  final configs = AppState().webDavConfigs;
                  if (configs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 64,
                            color: SciFiColors.textDim,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'NO NODES CONFIGURED',
                            style: GoogleFonts.shareTechMono(
                              color: SciFiColors.textMain,
                              fontSize: 18,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '> PRESS [+] TO DEPLOY A NEW WEBDAV NODE.',
                            style: GoogleFonts.shareTechMono(
                              color: SciFiColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.6,
                        ),
                    itemCount: configs.length,
                    itemBuilder: (context, index) =>
                        _WebDavCard(config: configs[index]),
                  );
                },
              ),
            ),
          ],
        ),
        // FAB
        Positioned(bottom: 24, right: 24, child: _AddNodeFab()),
      ],
    );
  }
}

class _WebDavCard extends StatefulWidget {
  final WebDavConfig config;
  const _WebDavCard({required this.config});

  @override
  State<_WebDavCard> createState() => _WebDavCardState();
}

class _WebDavCardState extends State<_WebDavCard> {
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmDialog(
        title: 'REMOVE WEBDAV NODE',
        message:
            'Delete "${widget.config.name}" and remove its cached tracks from local storage?',
        confirmLabel: 'REMOVE',
      ),
    );
    if (confirmed == true) {
      await AppState().removeWebDavConfig(widget.config.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NbButton(
      onPressed: () => showDialog(
        context: context,
        builder: (ctx) => _WebDavNodeDialog(config: widget.config),
      ),
      padding: const EdgeInsets.all(16),
      backgroundColor: SciFiColors.surfaceLight,
      shadowOffset: const Offset(6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.config.name,
                  style: GoogleFonts.shareTechMono(
                    color: SciFiColors.primaryYel,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: SciFiColors.gridLines, height: 1),
          const SizedBox(height: 8),
          Text(
            widget.config.url,
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textMain,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'PATH: ${widget.config.davPath}',
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            'USER: ${widget.config.username.isEmpty ? 'GUEST' : widget.config.username}',
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: _RectCardActionButton(
              icon: Icons.delete_outline,
              tooltip: 'REMOVE NODE',
              highlighted: false,
              onPressed: _confirmDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddNodeFab extends StatefulWidget {
  const _AddNodeFab();

  @override
  State<_AddNodeFab> createState() => _AddNodeFabState();
}

class _AddNodeFabState extends State<_AddNodeFab> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: NbButton(
        onPressed: () => _showAddNodeDialog(context),
        padding: EdgeInsets.zero,
        shadowOffset: const Offset(4, 4),
        child: const Center(
          child: Icon(Icons.add, color: SciFiColors.textMain, size: 28),
        ),
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const _WebDavNodeDialog());
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

class _RectCardActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool highlighted;
  final VoidCallback onPressed;

  const _RectCardActionButton({
    required this.icon,
    required this.tooltip,
    required this.highlighted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.14),
        splashColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.18),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(
              color: highlighted
                  ? SciFiColors.primaryYel
                  : SciFiColors.gridLines,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: highlighted ? SciFiColors.primaryYel : SciFiColors.textDim,
          ),
        ),
      ),
    );
  }
}

class _WebDavNodeDialog extends StatefulWidget {
  final WebDavConfig? config;
  const _WebDavNodeDialog({this.config});

  @override
  State<_WebDavNodeDialog> createState() => _WebDavNodeDialogState();
}

class _WebDavNodeDialogState extends State<_WebDavNodeDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _urlCtl;
  late final TextEditingController _userCtl;
  late final TextEditingController _passCtl;
  late final TextEditingController _pathCtl;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.config?.name ?? '');
    _urlCtl = TextEditingController(text: widget.config?.url ?? '');
    _userCtl = TextEditingController(text: widget.config?.username ?? '');
    _passCtl = TextEditingController(text: widget.config?.password ?? '');
    _pathCtl = TextEditingController(text: widget.config?.davPath ?? '/');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _urlCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    _pathCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.config != null;

    return AppDialogShell(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogTitle(
            title: isEdit ? 'UPDATE WEBDAV NODE' : 'DEPLOY NEW WEBDAV NODE',
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '> ERROR: $_errorMessage',
                style: GoogleFonts.shareTechMono(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),

          _DialogInput(
            label: 'NODE NAME',
            controller: _nameCtl,
            hint: 'My Music Library',
          ),
          const SizedBox(height: 16),
          _DialogInput(
            label: 'SERVER URL',
            controller: _urlCtl,
            hint: 'https://dav.example.com',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DialogInput(
                  label: 'USERNAME',
                  controller: _userCtl,
                  hint: 'admin',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DialogInput(
                  label: 'PASSWORD',
                  controller: _passCtl,
                  hint: '••••••••',
                  isObscured: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DialogInput(
            label: 'WEBDAV PATH',
            controller: _pathCtl,
            hint: '/music/',
          ),
          const SizedBox(height: 32),
          AppDialogActions(
            confirmLabel: isEdit ? 'UPDATE' : 'DEPLOY',
            isLoading: _isLoading,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _handleAction,
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_nameCtl.text.isEmpty || _urlCtl.text.isEmpty) {
      setState(() => _errorMessage = "NAME AND URL ARE REQUIRED");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = AppState();
    String? error;

    if (widget.config == null) {
      error = await appState.addWebDavConfig(
        name: _nameCtl.text.trim(),
        url: _urlCtl.text.trim(),
        username: _userCtl.text.trim(),
        password: _passCtl.text,
        davPath: _pathCtl.text.isEmpty ? '/' : _pathCtl.text.trim(),
      );
    } else {
      error = await appState.updateWebDavConfig(
        id: widget.config!.id,
        name: _nameCtl.text.trim(),
        url: _urlCtl.text.trim(),
        username: _userCtl.text.trim(),
        password: _passCtl.text,
        davPath: _pathCtl.text.isEmpty ? '/' : _pathCtl.text.trim(),
      );
    }

    if (mounted) {
      if (error != null) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      } else {
        Navigator.of(context).pop();
      }
    }
  }
}

class _DialogInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isObscured;

  const _DialogInput({
    required this.label,
    required this.hint,
    required this.controller,
    this.isObscured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.shareTechMono(
            color: SciFiColors.textDim,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isObscured,
          style: GoogleFonts.shareTechMono(color: SciFiColors.textMain),
          cursorColor: SciFiColors.primaryYel,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.shareTechMono(color: SciFiColors.gridLines),
            filled: true,
            fillColor: SciFiColors.background,
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: SciFiColors.gridLines),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: SciFiColors.primaryYel),
              borderRadius: BorderRadius.zero,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
