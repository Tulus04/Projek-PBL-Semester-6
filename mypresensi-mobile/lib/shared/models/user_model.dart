// lib/shared/models/user_model.dart
// Model data user mahasiswa — match 1:1 dengan response API /api/mobile/auth/login

import 'dart:convert';

class UserModel {
  final String id;
  final String fullName;
  final String nimNip;
  final String? email;
  final String role;
  final int? semester;
  final String? kelas;
  final String? phone;
  final String? avatarUrl;
  final bool isFaceRegistered;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.nimNip,
    this.email,
    required this.role,
    this.semester,
    this.kelas,
    this.phone,
    this.avatarUrl,
    this.isFaceRegistered = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      nimNip: json['nim_nip'] as String,
      email: json['email'] as String?,
      role: json['role'] as String,
      semester: json['semester'] as int?,
      kelas: json['kelas'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isFaceRegistered: json['is_face_registered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'nim_nip': nimNip,
      'email': email,
      'role': role,
      'semester': semester,
      'kelas': kelas,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_face_registered': isFaceRegistered,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonString) {
    return UserModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Inisial untuk avatar (huruf pertama nama)
  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName[0].toUpperCase();
  }

  /// Label semester dan kelas
  String get semesterKelasLabel {
    final parts = <String>[];
    if (semester != null) parts.add('Semester $semester');
    if (kelas != null) parts.add('Kelas $kelas');
    return parts.join(' · ');
  }
}
