/// Access status computed for a member. Precedence matters: not found ->
/// no app access -> pending -> deactivated -> expired -> ok.
///
/// [noAppAccess] has no equivalent in the web app's `computeStatus()` — the
/// website stays open to every membership type, but this native app is
/// scoped to online-PT/hybrid clients only (it's built around AI coaching,
/// food logging, and PT-plan reminders), so it's checked here and nowhere
/// else.
enum AccessStatus { ok, noAppAccess, pending, expired, deactivated, notFound }

/// Ports the web app's access-status computation, plus the app-only
/// [AccessStatus.noAppAccess] gym-membership check. Do not reorder the
/// checks below.
AccessStatus computeAccessStatus(Map<String, dynamic>? member) {
  if (member == null) return AccessStatus.notFound;
  if (member['client_type'] == 'gym') return AccessStatus.noAppAccess;
  if (member['approval_status'] == 'pending') return AccessStatus.pending;
  if (member['is_active'] == false) return AccessStatus.deactivated;
  final packageEndDate = member['package_end_date'] as String?;
  if (packageEndDate != null) {
    final endDate = DateTime.tryParse(packageEndDate);
    if (endDate != null && endDate.isBefore(DateTime.now())) {
      return AccessStatus.expired;
    }
  }
  return AccessStatus.ok;
}

/// Plain, hand-written model for the `members` row / member-login response.
/// No code generation is used anywhere in this app.
class Member {
  const Member({
    required this.id,
    required this.memberId,
    required this.fullName,
    required this.phone,
    this.email,
    this.address,
    this.weight,
    this.height,
    this.packageId,
    this.packageStartDate,
    this.packageEndDate,
    this.photoUrl,
    this.isActive,
    this.userId,
    this.dateOfBirth,
    required this.clientType,
    required this.approvalStatus,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String memberId;
  final String fullName;
  final String phone;
  final String? email;
  final String? address;
  final num? weight;
  final num? height;
  final String? packageId;
  final String? packageStartDate;
  final String? packageEndDate;
  final String? photoUrl;
  final bool? isActive;
  final String? userId;
  final String? dateOfBirth;
  final String clientType;
  final String approvalStatus;
  final String? createdAt;
  final String? updatedAt;

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      weight: json['weight'] as num?,
      height: json['height'] as num?,
      packageId: json['package_id'] as String?,
      packageStartDate: json['package_start_date'] as String?,
      packageEndDate: json['package_end_date'] as String?,
      photoUrl: json['photo_url'] as String?,
      isActive: json['is_active'] as bool?,
      userId: json['user_id'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      clientType: json['client_type'] as String? ?? '',
      approvalStatus: json['approval_status'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'address': address,
      'weight': weight,
      'height': height,
      'package_id': packageId,
      'package_start_date': packageStartDate,
      'package_end_date': packageEndDate,
      'photo_url': photoUrl,
      'is_active': isActive,
      'user_id': userId,
      'date_of_birth': dateOfBirth,
      'client_type': clientType,
      'approval_status': approvalStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
