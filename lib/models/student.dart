class Student {
  final String name;
  final String email;
  final String rollNumber;
  final String branch;

  Student({
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.branch,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      name: json['name'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      rollNumber: json['roll_no'] ?? 'N/A',
      branch: json['branch'] ?? 'N/A',
    );
  }
}
