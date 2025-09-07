import 'dart:async';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../core/logging/app_logger.dart';

/// Enhanced debug icon widget that tracks errors and exceptions,
/// displays error count badge, and flashes red when errors occur
class DebugIconWidget extends StatefulWidget {
  const DebugIconWidget({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  State<DebugIconWidget> createState() => _DebugIconWidgetState();
}

class _DebugIconWidgetState extends State<DebugIconWidget>
    with TickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<Color?> _flashAnimation;
  late StreamSubscription<TalkerData> _talkerSubscription;
  
  int _errorCount = 0;
  int _warningCount = 0;
  bool _hasRecentError = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize flash animation controller
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _flashAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red.withValues(alpha: 0.8),
    ).animate(CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeInOut,
    ));

    // Initialize error counts from existing history
    _updateErrorCounts();
    
    // Listen to new Talker events
    _startListeningToTalkerEvents();
  }

  @override
  void dispose() {
    _flashController.dispose();
    _talkerSubscription.cancel();
    super.dispose();
  }

  /// Initialize error and warning counts from Talker history
  void _updateErrorCounts() {
    final history = AppLogger.getHistory();
    
    _errorCount = history.where((log) => 
      log.logLevel == LogLevel.error ||
      log.logLevel == LogLevel.critical ||
      log is TalkerException
    ).length;
    
    _warningCount = history.where((log) => 
      log.logLevel == LogLevel.warning
    ).length;
    
    if (mounted) {
      setState(() {});
    }
  }

  /// Listen to new Talker events to update counts and trigger animations
  void _startListeningToTalkerEvents() {
    _talkerSubscription = AppLogger.instance.stream.listen((data) {
      final isError = data.logLevel == LogLevel.error ||
          data.logLevel == LogLevel.critical ||
          data is TalkerException;
      
      final isWarning = data.logLevel == LogLevel.warning;
      
      if (isError) {
        _errorCount++;
        _triggerErrorFlash();
      } else if (isWarning) {
        _warningCount++;
      }
      
      if (mounted && (isError || isWarning)) {
        setState(() {});
      }
    });
  }

  /// Trigger red flash animation when error occurs
  void _triggerErrorFlash() {
    _hasRecentError = true;
    _flashController.forward().then((_) {
      _flashController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _hasRecentError = false;
          });
        }
      });
    });
  }

  /// Get total issues count (errors + warnings)
  int get _totalIssuesCount => _errorCount + _warningCount;

  /// Get badge color based on error/warning counts
  Color _getBadgeColor() {
    if (_errorCount > 0) {
      return Colors.red;
    } else if (_warningCount > 0) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  /// Get appropriate icon based on error state
  IconData _getIconData() {
    if (_errorCount > 0) {
      return Icons.bug_report; // Keep bug report for errors
    } else if (_warningCount > 0) {
      return Icons.warning_rounded; // Warning icon for warnings only
    }
    return Icons.developer_mode; // Default debug icon
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Main icon button with flash overlay
            Container(
              decoration: _hasRecentError
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: _flashAnimation.value,
                    )
                  : null,
              child: IconButton(
                onPressed: widget.onPressed ?? _openTalkerScreen,
                icon: Icon(_getIconData()),
                tooltip: 'Debug Logs${_totalIssuesCount > 0 ? ' ($_totalIssuesCount issues)' : ''}',
              ),
            ),
            
            // Error/Warning count badge
            if (_totalIssuesCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getBadgeColor(),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _totalIssuesCount > 99 ? '99+' : _totalIssuesCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Reset badge counts (called when history is cleared)
  void _resetCounts() {
    setState(() {
      _errorCount = 0;
      _warningCount = 0;
      _hasRecentError = false;
    });
  }

  /// Open Talker debug screen
  void _openTalkerScreen() {
    AppLogger.ui('Opening Talker logs viewer');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TalkerScreen(
          talker: AppLogger.instance,
          appBarTitle: 'OpenNoiseNet Debug Logs',
        ),
      ),
    ).then((_) {
      // When user returns from TalkerScreen, update counts in case history was cleared
      _updateErrorCounts();
    });
  }

}