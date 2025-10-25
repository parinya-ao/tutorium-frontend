/// Models for Flag system

/// Request model for flagging
class FlagRequest {
  final int id; // Teacher ID or Learner ID
  final int flagsToAdd;
  final String reason;

  FlagRequest({
    required this.id,
    required this.flagsToAdd,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'flags_to_add': flagsToAdd, 'reason': reason};
  }
}

/// Common reasons for flagging
class FlagReasons {
  static const String abusive = 'Abusive behavior';
  static const String inappropriate = 'Inappropriate content';
  static const String noShow = 'No show / Absent';
  static const String disruptive = 'Disruptive behavior';
  static const String spam = 'Spam / Advertisement';
  static const String cheating = 'Cheating / Plagiarism';
  static const String other = 'Other';

  /// For learners to flag teachers
  static const List<String> teacherReasons = [
    abusive,
    inappropriate,
    noShow,
    disruptive,
    other,
  ];

  /// For teachers to flag learners
  static const List<String> learnerReasons = [
    abusive,
    inappropriate,
    noShow,
    disruptive,
    cheating,
    spam,
    other,
  ];
}
