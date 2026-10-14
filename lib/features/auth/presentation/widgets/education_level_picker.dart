import 'package:flutter/material.dart';

import '../../../../shared/models/education_level.dart';

class EducationLevelPicker extends StatelessWidget {
  const EducationLevelPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final EducationLevel value;
  final ValueChanged<EducationLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<EducationLevel>(
      showSelectedIcon: false,
      segments: [
        for (final level in EducationLevel.values)
          ButtonSegment(value: level, label: Text(level.label)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
