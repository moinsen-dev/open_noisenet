import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/noise_monitoring/presentation/bloc/monitoring_bloc.dart';
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
                tooltip: 'Start Monitoring',
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
                tooltip: 'Stop Monitoring',
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
}