import 'profile_model.dart';

class DemoProfile {
  const DemoProfile._();

  static const profile = ProfileModel(
    id: 'demo-profile',
    name: 'Mahmoud Gohar',
    role: 'Student',
    level: 3,
    section: 'C & D',
    email: 'goharmahmoud987@gmail.com',
  );

  static const university = 'Egyptian E-Learning University';
  static const major = 'Information Technology';
  static const department = 'Information Technology';
  static const academicYear = '2026';
}
