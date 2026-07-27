import 'package:flutter/material.dart';
import 'package:vision_ai_pose/vision_ai_pose.dart';

/// Which exercise the rep counter is currently tracking.
enum ExerciseType { squat, bicepCurl, pushUp }

/// Static configuration for one exercise: which joint angle to watch,
/// and the down/up thresholds (in degrees) that define one rep.
///
/// The README shows `RepCounter(angleSelector: (p) => PoseAngles.of(p).leftKnee, ...)`
/// but never names the type of `p` explicitly (only `PoseResult` for
/// `primaryPose`'s return type). Typed as `dynamic` here so this
/// compiles regardless; if `flutter analyze` flags it, swap in `PoseResult`.
class ExerciseConfig {
  final String label;
  final IconData icon;
  final double Function(dynamic pose) angleSelector;
  final double downAngle;
  final double upAngle;

  const ExerciseConfig({
    required this.label,
    required this.icon,
    required this.angleSelector,
    required this.downAngle,
    required this.upAngle,
  });
}

final Map<ExerciseType, ExerciseConfig> kExercises = {
  ExerciseType.squat: ExerciseConfig(
    label: 'Squats',
    icon: Icons.accessibility_new,
    angleSelector: (pose) => PoseAngles.of(pose).leftKnee ?? 180,
    downAngle: 90,
    upAngle: 160,
  ), //bicepcurl
  ExerciseType.bicepCurl: ExerciseConfig(
    label: 'Bicep Curls',
    icon: Icons.fitness_center,
    angleSelector: (pose) => PoseAngles.of(pose).leftElbow ?? 180,
    downAngle: 50,
    upAngle: 160,
  ),
  ExerciseType.pushUp: ExerciseConfig(
    label: 'Push-ups',
    icon: Icons.sports_gymnastics,
    angleSelector: (pose) => PoseAngles.of(pose).leftElbow ?? 180,
    downAngle: 80,
    upAngle: 160,
  ),
};
