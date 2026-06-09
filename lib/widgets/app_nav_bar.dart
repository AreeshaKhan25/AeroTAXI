import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';
import '../config/theme.dart';

class AppNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> {
  bool _supportLoading = false;

  static const _icons = [
    Icons.local_taxi_rounded,
    Icons.history_rounded,
    Icons.map_outlined,
    Icons.support_agent_rounded,
  ];
  static const _labels = ['Ride', 'History', 'Coverage', 'Support'];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom
                : 10,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: AppTheme.outlineVariant.withValues(alpha: 0.14),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (i) => _NavItem(
                icon: _icons[i],
                label: _labels[i],
                isActive: i == widget.currentIndex,
                isLoading: i == 3 && _supportLoading,
                onTap: () {
                  if (i == 3) {
                    _handleSupportTap();
                  } else {
                    widget.onTabSelected(i);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSupportTap() async {
    if (_supportLoading || !mounted) return;
    setState(() => _supportLoading = true);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _SupportConnectingSheet(),
    );

    if (mounted) setState(() => _supportLoading = false);
  }
}

// ── Connecting sheet ──────────────────────────────────────────────────────────

class _SupportConnectingSheet extends StatefulWidget {
  const _SupportConnectingSheet();

  @override
  State<_SupportConnectingSheet> createState() =>
      _SupportConnectingSheetState();
}

class _SupportConnectingSheetState extends State<_SupportConnectingSheet>
    with WidgetsBindingObserver {
  int? _pingMs;
  bool _noConnection = false;
  String _quality = '';
  bool _launched = false;
  final _browserVisible = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // When Chrome Custom Tabs / SFSafariViewController appears, the Flutter app
  // transitions to inactive. That's our signal the browser is on screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_launched &&
        !_browserVisible.isCompleted &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _browserVisible.complete();
    }
  }

  Future<void> _connect() async {
    final sw = Stopwatch()..start();
    bool ok = false;
    try {
      await http
          .head(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 6));
      ok = true;
    } catch (_) {
      ok = false;
    }
    sw.stop();

    if (!mounted) return;

    if (ok) {
      final ms = sw.elapsedMilliseconds;
      final q = ms < 100
          ? 'Excellent'
          : ms < 250
              ? 'Good'
              : ms < 500
                  ? 'Fair'
                  : 'Slow';
      setState(() {
        _pingMs = ms;
        _quality = q;
      });
    } else {
      setState(() => _noConnection = true);
    }

    // Brief pause so the user can read the result
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    // Fire the URL launch but don't await it — the browser appears asynchronously
    _launched = true;
    unawaited(launchUrl(
      Uri.parse(
          'https://go.crisp.chat/chat/embed/?website_id=${Env.crispWebsiteId}'),
      mode: LaunchMode.inAppBrowserView,
    ));

    // Keep the sheet visible until the browser is actually on screen
    // (lifecycle inactive) or until 6s safety timeout elapses
    await Future.any([
      _browserVisible.future,
      Future.delayed(const Duration(seconds: 6)),
    ]);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // Icon badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppTheme.onPrimaryContainer,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Connecting to Live Support',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
              ),
              const SizedBox(height: 10),

              // Connection status — animates between states
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _noConnection
                    ? _StatusRow(
                        key: const ValueKey('no-conn'),
                        icon: Icons.wifi_off_rounded,
                        color: AppTheme.error,
                        text: 'No internet connection',
                      )
                    : _pingMs == null
                        ? const _CheckingRow(key: ValueKey('checking'))
                        : _StatusRow(
                            key: ValueKey(_pingMs),
                            icon: _wifiIcon(_pingMs!),
                            color: _speedColor(_pingMs!),
                            text: '$_quality  •  ${_pingMs}ms',
                          ),
              ),

              const SizedBox(height: 28),

              // Indeterminate progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  backgroundColor:
                      AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryContainer),
                  minHeight: 5,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Opening live chat window…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.outlineVariant,
                    ),
              ),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  IconData _wifiIcon(int ms) {
    if (ms < 100) return Icons.wifi_rounded;
    if (ms < 250) return Icons.wifi_2_bar_rounded;
    return Icons.wifi_1_bar_rounded;
  }

  Color _speedColor(int ms) {
    if (ms < 100) return const Color(0xFF2ECC71);
    if (ms < 250) return AppTheme.primaryContainer;
    if (ms < 500) return Colors.orange;
    return AppTheme.error;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CheckingRow extends StatelessWidget {
  const _CheckingRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Measuring connection speed…',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondary,
              ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusRow({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color:
                    isActive ? AppTheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primaryContainer,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 22,
                      color: isActive
                          ? AppTheme.onPrimaryContainer
                          : AppTheme.outlineVariant,
                    ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppTheme.onSurface
                        : AppTheme.outlineVariant,
                  ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
