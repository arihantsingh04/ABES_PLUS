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

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'rollNumber': rollNumber,
      'branch': branch,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      name: json['name'] ?? 'Student',
      email: json['email'] ?? 'N/A',
      rollNumber: json['rollNumber'] ?? '',
      branch: json['branch'] ?? 'Unknown',
    );
  }
}