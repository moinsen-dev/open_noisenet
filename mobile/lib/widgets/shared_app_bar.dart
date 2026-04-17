import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../features/noise_monitoring/presentation/bloc/monitoring_bloc.dart';
import '../services/backend_sync_service.dart';
import 'debug_icon_widget.dart';

class SharedAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SharedAppBar({
    super.key,
    this.pageTitle,
    this.actions = const [],
  });

  final String? pageTitle;
  final List<Widget> actions;

  @override
  State<SharedAppBar> createState() => _SharedAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SharedAppBarState extends State<SharedAppBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final BackendSyncService _backendService =
      GetIt.instance<BackendSyncService>();

  Map<String, dynamic>? _lastConnectionStatus;
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // Initial status check
    _updateConnectionStatus();

    // Periodic status updates every 30 seconds
    _statusUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _updateConnectionStatus(),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateConnectionStatus() async {
    try {
      final status = await _backendService.getBackendStatus();
      if (mounted) {
        setState(() {
          _lastConnectionStatus = status;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MonitoringBloc, MonitoringState>(
      builder: (context, state) {
        return AppBar(
          title: Row(
            children: [
              // App Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  image: const DecorationImage(
                    image: AssetImage('assets/noisenet-icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // App Name with monitoring status indicator
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.pageTitle ?? 'Open NoiseNet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Real-time monitoring status indicator
                    _buildMonitoringStatusIndicator(state),
                    const SizedBox(width: 8),
                    // Backend connection status indicator
                    _buildConnectionStatusIndicator(),
                  ],
                ),
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          actions: [
            // Dynamic Start/Stop Monitoring Button
            if (state is MonitoringInactive || state is MonitoringError)
              IconButton(
                onPressed: () {
                  context
                      .read<MonitoringBloc>()
                      .add(StartMonitoring(context: context));
                },
                icon: const Icon(Icons.play_arrow),
                tooltip: 'Start Sensor Mode',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              )
            else if (state is MonitoringActive)
              IconButton(
                onPressed: () {
                  context.read<MonitoringBloc>().add(const StopMonitoring());
                },
                icon: const Icon(Icons.stop),
                tooltip: 'Stop Sensor Mode',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              )
            else if (state is MonitoringStarting || state is MonitoringStopping)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),

            const SizedBox(width: 8),

            // Statistics Page Button
            IconButton(
              onPressed: () => context.push('/statistics'),
              icon: const Icon(Icons.analytics),
              tooltip: 'View detailed statistics',
            ),

            // Enhanced Debug Icon with Error Counter and Flash Animation
            const DebugIconWidget(),

            // Additional page-specific actions
            ...widget.actions,
          ],
        );
      },
    );
  }

  Widget _buildMonitoringStatusIndicator(MonitoringState state) {
    if (state is MonitoringActive) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: _pulseAnimation.value),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  spreadRadius: 2,
                  blurRadius: 4,
                ),
              ],
            ),
          );
        },
      );
    } else if (state is MonitoringStarting || state is MonitoringStopping) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildConnectionStatusIndicator() {
    if (_lastConnectionStatus == null) {
      return const SizedBox.shrink();
    }

    final mode = _lastConnectionStatus!['mode'] as String;
    final queuedEvents = (_lastConnectionStatus!['queued_events'] as int?) ?? 0;
    final lastHeartbeat =
        _lastConnectionStatus!['last_heartbeat_at'] as String?;
    final assignedSite = _lastConnectionStatus!['assigned_site_id'] as String?;
    final assignedSiteName =
        _lastConnectionStatus!['assigned_site_name'] as String?;
    final assignedOrganizationName =
        _lastConnectionStatus!['assigned_organization_name'] as String?;
    final assignedZoneName =
        _lastConnectionStatus!['assigned_zone_name'] as String?;
    final effectivePolicyName =
        _lastConnectionStatus!['effective_policy_name'] as String?;
    final effectivePolicyScope =
        _lastConnectionStatus!['effective_policy_scope'] as String?;
    final sensorModeActive =
        (_lastConnectionStatus!['sensor_mode_active'] as bool?) ?? false;
    final proContextState =
        _lastConnectionStatus!['pro_context_access_state'] as String?;
    final proContextRefreshedAt =
        _lastConnectionStatus!['pro_context_refreshed_at'] as String?;

    Color statusColor;
    IconData statusIcon;
    String tooltip;

    switch (mode) {
      case 'offline':
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_off;
        tooltip = queuedEvents > 0
            ? 'Offline - $queuedEvents events queued'
            : 'Running offline mode';
        break;
      case 'anonymous':
        statusColor = Colors.blue;
        statusIcon = Icons.cloud_queue;
        tooltip = 'Connected - Anonymous mode';
        break;
      case 'authenticated':
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done;
        tooltip = 'Connected and authenticated';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        tooltip = 'Unknown connection status';
    }

    final detailParts = <String>[
      tooltip,
      'Sensor mode: ${sensorModeActive ? 'active' : 'idle'}',
      if (assignedOrganizationName != null || assignedSite != null)
        'Pro: ${(assignedOrganizationName ?? 'org')} / ${(assignedSiteName ?? assignedSite ?? 'site')}',
      if (assignedZoneName != null) 'Zone: $assignedZoneName',
      if (effectivePolicyName != null)
        'Policy: $effectivePolicyName${effectivePolicyScope != null ? ' ($effectivePolicyScope)' : ''}',
      if (proContextState != null) 'Context: $proContextState',
      if (lastHeartbeat != null) 'Last heartbeat: $lastHeartbeat',
      if (proContextRefreshedAt != null)
        'Context refreshed: $proContextRefreshedAt',
    ];
    tooltip = detailParts.join(' • ');

    return GestureDetector(
      onTap: () async {
        // Refresh connection status when tapped
        await _updateConnectionStatus();
        if (mounted && context.mounted) {
          // Show connection details in a snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(statusIcon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tooltip)),
                ],
              ),
              backgroundColor: statusColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.3),
                spreadRadius: 1,
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
