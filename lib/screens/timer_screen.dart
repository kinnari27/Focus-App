import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // Global audioHandler
import '../models/task.dart';
import '../models/focus_session.dart';
import '../theme/app_colors.dart';

enum PomodoroMode {
  focus(
    title: 'Deep Focus',
    defaultMinutes: 25,
    icon: Icons.center_focus_strong,
  ),
  shortBreak(
    title: 'Short Break',
    defaultMinutes: 5,
    icon: Icons.coffee_rounded,
  ),
  longBreak(title: 'Long Break', defaultMinutes: 15, icon: Icons.spa_rounded);

  final String title;
  final int defaultMinutes;
  final IconData icon;

  const PomodoroMode({
    required this.title,
    required this.defaultMinutes,
    required this.icon,
  });
}

class TimerScreen extends StatefulWidget {
  final Task? task;
  final Function(FocusSession session, Task? updatedTask) onSessionComplete;

  const TimerScreen({super.key, this.task, required this.onSessionComplete});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  PomodoroMode _currentMode = PomodoroMode.focus;
  int _sessionDurationSeconds = 25 * 60;
  int _secondsRemaining = 25 * 60;
  DateTime? _targetEndTime;
  Timer? _timer;
  bool _isRunning = false;

  late String _selectedCategory;
  late String _sessionTitle;

  // Pulse animation for breathing guide
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Audio configurations
  bool _isMuted = true;
  final double _volume = 0.5;
  int _selectedTrackIndex = 0;

  final List<Map<String, String>> _tracks = [
    {
      'name': 'Zen Rain 🌧️',
      'url': 'https://assets.mixkit.co/active_storage/sfx/2433/2433-84.wav',
    },
    {
      'name': 'Forest Echoes 🌲',
      'url': 'https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav',
    },
    {
      'name': 'Tibetan Bowls 🥣',
      'url': 'https://assets.mixkit.co/active_storage/sfx/123/123-84.wav',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _selectedCategory = widget.task?.category ?? 'Work';
    _sessionTitle = widget.task?.title ?? 'General Focus Session';

    // Pulse controller for breathing guide
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _applyMode(PomodoroMode.focus);
    _initAudio();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isRunning &&
        _targetEndTime != null) {
      // Sync remaining seconds with real wall-clock time
      final remaining = _targetEndTime!.difference(DateTime.now()).inSeconds;
      setState(() {
        if (remaining <= 0) {
          _secondsRemaining = 0;
          _completeSession();
        } else {
          _secondsRemaining = remaining;
        }
      });
    }
  }

  void _applyMode(PomodoroMode mode, [int? customMinutes]) {
    final minutes = customMinutes ?? mode.defaultMinutes;
    setState(() {
      _currentMode = mode;
      _sessionDurationSeconds = minutes * 60;
      _secondsRemaining = _sessionDurationSeconds;
      if (_isRunning) {
        _timer?.cancel();
        _isRunning = false;
        _targetEndTime = null;
        _updateAudioPlayback();
      }
    });
  }

  Future<void> _initAudio() async {
    try {
      final track = _tracks[_selectedTrackIndex];
      await audioHandler.setTrack(
        track['name']!,
        track['url']!,
        _selectedCategory,
      );
      await audioHandler.setVolume(_isMuted ? 0.0 : _volume);
    } catch (e) {
      debugPrint('AudioHandler init error: $e');
    }
  }

  Future<void> _updateAudioPlayback() async {
    try {
      if (_isRunning && !_isMuted) {
        await audioHandler.setVolume(_volume);
        final track = _tracks[_selectedTrackIndex];
        await audioHandler.setTrack(
          track['name']!,
          track['url']!,
          _selectedCategory,
        );
        await audioHandler.play();
      } else {
        await audioHandler.pause();
      }
    } catch (e) {
      debugPrint('AudioHandler playback update error: $e');
    }
  }

  Future<void> _toggleMute() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });

    try {
      if (_isMuted) {
        await audioHandler.setVolume(0.0);
        await audioHandler.pause();
      } else {
        await audioHandler.setVolume(_volume);
        if (_isRunning) {
          final track = _tracks[_selectedTrackIndex];
          await audioHandler.setTrack(
            track['name']!,
            track['url']!,
            _selectedCategory,
          );
          await audioHandler.play();
        }
      }
    } catch (e) {
      debugPrint('AudioHandler toggle mute error: $e');
    }
  }

  Future<void> _changeTrack(int index) async {
    setState(() {
      _selectedTrackIndex = index;
    });

    try {
      final track = _tracks[index];
      await audioHandler.setTrack(
        track['name']!,
        track['url']!,
        _selectedCategory,
      );
      if (_isRunning && !_isMuted) {
        await audioHandler.play();
      }
    } catch (e) {
      debugPrint('AudioHandler change track error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseController.dispose();
    try {
      audioHandler.stop();
    } catch (e) {
      debugPrint('AudioHandler dispose error: $e');
    }
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.lightImpact();

    if (_isRunning) {
      // Pause
      _timer?.cancel();
      if (_targetEndTime != null) {
        final remaining = _targetEndTime!.difference(DateTime.now()).inSeconds;
        _secondsRemaining = remaining > 0 ? remaining : 0;
      }
      _targetEndTime = null;
      setState(() {
        _isRunning = false;
      });
      _updateAudioPlayback();
    } else {
      // Start or Resume
      setState(() {
        _isRunning = true;
      });
      _targetEndTime = DateTime.now().add(Duration(seconds: _secondsRemaining));
      _updateAudioPlayback();

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_targetEndTime == null) return;
        final remaining = _targetEndTime!.difference(DateTime.now()).inSeconds;

        if (remaining <= 0) {
          setState(() {
            _secondsRemaining = 0;
          });
          _completeSession();
        } else {
          setState(() {
            _secondsRemaining = remaining;
          });
        }
      });
    }
  }

  void _resetTimer() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _targetEndTime = null;
      _secondsRemaining = _sessionDurationSeconds;
    });
    _updateAudioPlayback();
  }

  void _completeSession() {
    _timer?.cancel();
    _isRunning = false;
    _targetEndTime = null;

    try {
      audioHandler.stop();
    } catch (e) {
      debugPrint('Audio stop failed: $e');
    }

    HapticFeedback.heavyImpact();

    final actualFocusSeconds = _sessionDurationSeconds - _secondsRemaining;
    final int recordedSeconds = actualFocusSeconds > 0
        ? actualFocusSeconds
        : _sessionDurationSeconds;

    final focusSession = FocusSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskId: widget.task?.id,
      taskTitle:
          widget.task?.title ??
          (_currentMode == PomodoroMode.focus
              ? _sessionTitle
              : _currentMode.title),
      category: _selectedCategory,
      durationSeconds: recordedSeconds,
      timestamp: DateTime.now(),
      sessionType: _currentMode.name,
    );

    Task? updatedTask;
    if (widget.task != null && _currentMode == PomodoroMode.focus) {
      final newCompletedSessions = widget.task!.completedSessions + 1;
      final isNowCompleted =
          newCompletedSessions >= widget.task!.estimatedSessions;
      updatedTask = widget.task!.copyWith(
        completedSessions: newCompletedSessions,
        focusSeconds: widget.task!.focusSeconds + recordedSeconds,
        isCompleted: isNowCompleted ? true : widget.task!.isCompleted,
      );
    }

    widget.onSessionComplete(focusSession, updatedTask);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final minutesText = (recordedSeconds / 60).round();
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Row(
            children: [
              Icon(
                _currentMode == PomodoroMode.focus
                    ? Icons.celebration
                    : Icons.spa,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _currentMode == PomodoroMode.focus
                      ? 'Mindful Focus Complete! 🧘'
                      : '${_currentMode.title} Finished ☕',
                ),
              ),
            ],
          ),
          content: Text(
            _currentMode == PomodoroMode.focus
                ? 'You dedicated $minutesText minutes of pure focus to "$_sessionTitle". Take a mindful breath or begin a short break.'
                : 'Your $minutesText-minute break is complete. Ready to resume deep focus?',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            if (_currentMode == PomodoroMode.focus)
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _applyMode(PomodoroMode.shortBreak);
                  _toggleTimer();
                },
                child: const Text(
                  'Start Short Break ☕',
                  style: TextStyle(color: AppColors.secondary),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Return to Stream'),
            ),
          ],
        );
      },
    );
  }

  void _confirmCancel() {
    if (_secondsRemaining == _sessionDurationSeconds) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('End Focus Session?'),
        content: const Text(
          'Would you like to record the time spent focusing so far or discard it?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return home
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _completeSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _sessionDurationSeconds > 0
        ? _secondsRemaining / _sessionDurationSeconds
        : 0.0;
    Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _confirmCancel,
        ),
        title: Text(
          widget.task != null ? 'Task Focus Stream' : 'Zen Focus Stream',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Column(
            children: [
              // Mode Selector Tabs (Focus, Short Break, Long Break)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: PomodoroMode.values.map((mode) {
                    final isSelected = _currentMode == mode;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _applyMode(mode);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                mode.icon,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mode.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Task / Session Info Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.task != null
                            ? Icons.laptop_mac
                            : Icons.self_improvement,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sessionTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Category: $_selectedCategory • ${_sessionDurationSeconds ~/ 60}m ${_currentMode.title}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Quick Custom Duration Chips (Focus Mode Only)
              if (_currentMode == PomodoroMode.focus) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [15, 25, 45, 60].map((mins) {
                    final isCurrent = _sessionDurationSeconds == mins * 60;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('${mins}m'),
                        selected: isCurrent,
                        onSelected: (selected) {
                          if (selected && !_isRunning) {
                            HapticFeedback.selectionClick();
                            _applyMode(PomodoroMode.focus, mins);
                          }
                        },
                        selectedColor: AppColors.secondary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? AppColors.background
                              : Colors.white60,
                        ),
                        side: BorderSide(
                          color: isCurrent
                              ? AppColors.secondary
                              : Colors.white10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Timer dial wrapper with pulsing breathing guides
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 250 * _pulseAnimation.value,
                    height: 250 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(
                            alpha: _isRunning
                                ? 0.09 * _pulseAnimation.value
                                : 0.02,
                          ),
                          blurRadius: 32,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        color: _currentMode == PomodoroMode.focus
                            ? AppColors.secondary
                            : AppColors.primary,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_secondsRemaining),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isRunning ? 'INHALE • EXHALE' : 'PAUSED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            color: _currentMode == PomodoroMode.focus
                                ? AppColors.secondary
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Quick categories selector (if general session)
              if (widget.task == null &&
                  _currentMode == PomodoroMode.focus) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['Mind', 'Work', 'Health', 'Personal'].map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected && !_isRunning) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.background
                              : Colors.white60,
                        ),
                        selectedColor: AppColors.secondary,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.secondary
                              : Colors.white10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Controls Actions: Reset, Play/Pause, Finish Early
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reset timer button
                  IconButton.filledTonal(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset session',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      foregroundColor: Colors.white70,
                    ),
                  ),

                  // Play / Pause Button
                  IconButton.filled(
                    onPressed: _toggleTimer,
                    icon: Icon(
                      _isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    tooltip: _isRunning ? 'Pause' : 'Start',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(22),
                      backgroundColor: _currentMode == PomodoroMode.focus
                          ? AppColors.primary
                          : AppColors.secondary,
                      foregroundColor: _currentMode == PomodoroMode.focus
                          ? Colors.white
                          : AppColors.background,
                    ),
                  ),

                  // Complete Session Early button
                  IconButton.filledTonal(
                    onPressed: _completeSession,
                    icon: const Icon(Icons.check_rounded),
                    tooltip: 'Complete session',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.secondary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Ambient Calm Music Bar
              const Divider(color: Colors.white12, height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calm Ambient Soundscape',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            _isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 14,
                            color: _isMuted
                                ? Colors.white30
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isMuted ? 'Muted' : 'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isMuted
                                  ? Colors.white30
                                  : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                        ),
                        onPressed: _toggleMute,
                        tooltip: _isMuted ? 'Unmute' : 'Mute',
                        style: IconButton.styleFrom(
                          backgroundColor: _isMuted
                              ? Colors.white.withValues(alpha: 0.04)
                              : AppColors.secondary.withValues(alpha: 0.15),
                          foregroundColor: _isMuted
                              ? Colors.white60
                              : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedTrackIndex,
                              isExpanded: true,
                              dropdownColor: AppColors.surfaceElevated,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              items: List.generate(_tracks.length, (index) {
                                return DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(_tracks[index]['name']!),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) {
                                  _changeTrack(val);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
