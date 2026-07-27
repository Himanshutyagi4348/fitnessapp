import 'package:detection_app/excercise_config.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vision_ai_pose/vision_ai_pose.dart';

/// Live camera + skeleton overlay + rep counting screen.
///
/// SOURCE OF TRUTH: every call below on `PoseVision`, `PoseConfig`,
/// `PoseAngles`, `RepCounter`, `isPoseReliable`, `PostureClassifier`,
/// and `PoseCameraView` is copied verbatim (in spirit) from the
/// vision_ai_pose README / pub.dev docs as of package version 0.1.0.
/// That is the ENTIRE public surface the README documents.
///
/// UNVERIFIED: the README never shows a `camera:` parameter on
/// `PoseVision.create`, never names a `CameraConfig`/`CameraFacing`
/// type, and never shows a `switchCamera()` method. There is no way
/// to confirm these exist without the actual package source or
/// `flutter analyze`/`flutter pub deps` against a real checkout.
/// That block is isolated below behind `_kAttemptCameraFlip` — set it
/// to false (or delete the block) if analyze reports unknown
/// identifiers, and the rest of the app is unaffected.
const bool _kAttemptCameraFlip = true;

class PoseScreen extends StatefulWidget {
  const PoseScreen({super.key});

  @override
  State<PoseScreen> createState() => _PoseScreenState();
}

class _PoseScreenState extends State<PoseScreen> {
  PoseVision? _vision;
  int? _textureId;
  RepCounter? _repCounter;
  bool _useFrontCamera = true;

  ExerciseType _exercise = ExerciseType.squat;
  int _repCount = 0;
  String _phase = '-';
  String _posture = '-';
  bool _poseDetected = false;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _error = 'Camera permission is required for pose detection.';
          _starting = false;
        });
        return;
      }
      await _initVision();
    } catch (e) {
      setState(() {
        _error = 'Failed to request camera permission: $e';
        _starting = false;
      });
    }
  }

  Future<void> _initVision() async {
    try {
      // Verified: PoseVision.create(pose: const PoseConfig()) — README quick start.
      final vision = await PoseVision.create(pose: const PoseConfig());
      final textureId = await vision.start();

      if (!mounted) return;
      setState(() {
        _vision = vision;
        _textureId = textureId;
        _starting = false;
      });

      _setExercise(_exercise);

      // Verified: vision.results is a Stream<VisionResult>-like stream
      // per README (`vision.results.listen((result) { ... })`).
      vision.results.listen(
        _onResult,
        onError: (Object e, StackTrace st) {
          if (!mounted) return;
          setState(() {
            _error = 'Pose stream error: $e';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to start camera/pose engine: $e';
        _starting = false;
      });
    }
  }

  void _setExercise(ExerciseType type) {
    final config = kExercises[type]!;
    setState(() {
      _exercise = type;
      _repCount = 0;
      _phase = '-';
      // Verified: RepCounter(angleSelector:, downAngle:, upAngle:) — README.
      _repCounter = RepCounter(
        angleSelector: config.angleSelector,
        downAngle: config.downAngle,
        upAngle: config.upAngle,
      );
    });
  }

  void _onResult(dynamic result) {
    try {
      final pose = result.primaryPose;
      if (pose == null) {
        if (!mounted) return;
        setState(() => _poseDetected = false);
        return;
      }

      // Verified: isPoseReliable(pose) gate — README.
      final reliable = isPoseReliable(pose);

      // Verified: const PostureClassifier().classify(pose) — README.
      final posture = const PostureClassifier().classify(pose);

      dynamic repState;
      if (reliable && _repCounter != null) {
        // Verified: reps.update(pose) -> state.count, state.phase — README.
        repState = _repCounter!.update(pose);
      }

      if (!mounted) return;
      setState(() {
        _poseDetected = true;
        _posture = posture.toString().split('.').last;
        if (repState != null) {
          _repCount = repState.count as int;
          _phase = repState.phase.toString().split('.').last;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Frame processing error: $e');
    }
  }

  void _resetReps() {
    // Verified: RepCounter.reset() — README ("Stateful detectors ...
    // expose reset()").
    _repCounter?.reset();
    setState(() {
      _repCount = 0;
      _phase = '-';
    });
  }

  Future<void> _flipCamera() async {
    // UNVERIFIED BLOCK — see _kAttemptCameraFlip doc comment above.
    if (!_kAttemptCameraFlip || _vision == null) return;
    try {
      final v = _vision as dynamic;
      _useFrontCamera = !_useFrontCamera;
      await v.switchCamera(_useFrontCamera ? 'front' : 'back');
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      // Swallow silently rather than surface a full-screen error for
      // a nice-to-have feature that may not exist in the real API.
      _useFrontCamera = !_useFrontCamera; // revert optimistic flip
      if (!mounted) return;
      setState(() {
        _error = 'Camera flip is not supported by this package build.';
      });
    }
  }

  @override
  void dispose() {
    // Verified: vision.stop() / vision.dispose() — README quick start.
    _vision?.stop();
    _vision?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pose Detection')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _starting = true;
                    });
                    _bootstrap();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_starting || _vision == null || _textureId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = kExercises[_exercise]!;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Verified: PoseCameraView(results:, textureId:, mirrored:) — README.
          PoseCameraView(
            results: _vision!.results,
            textureId: _textureId!,
            mirrored: _useFrontCamera,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kExercises.entries.map((entry) {
                    final selected = entry.key == _exercise;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value.label),
                        avatar: Icon(entry.value.icon, size: 18),
                        selected: selected,
                        onSelected: (_) => _setExercise(entry.key),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$_repCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'reps',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatusChip(
                          label: _poseDetected ? 'Tracking' : 'No pose',
                          color: _poseDetected
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Phase: $_phase',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Posture: $_posture',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        if (_kAttemptCameraFlip)
                          OutlinedButton.icon(
                            onPressed: _flipCamera,
                            icon: Icon(
                              _useFrontCamera
                                  ? Icons.flip_camera_android
                                  : Icons.cameraswitch,
                              size: 16,
                            ),
                            label: const Text('Flip'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _resetReps,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
