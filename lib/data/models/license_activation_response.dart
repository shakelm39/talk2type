class LicenseActivationResponse {
  final bool success;
  final String? token;
  final String? message;
  final String? planName;
  final String? expiresAt;

  LicenseActivationResponse({
    required this.success,
    this.token,
    this.message,
    this.planName,
    this.expiresAt,
  });

  factory LicenseActivationResponse.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return LicenseActivationResponse(
      success: json['success'] == true || json['status'] == 'success' || dataMap['token'] != null,
      token: (dataMap['token'] ?? dataMap['access_token'] ?? json['token']) as String?,
      message: (json['message'] ?? dataMap['message']) as String?,
      planName: (dataMap['plan_name'] ?? dataMap['plan'] ?? json['plan_name'] ?? json['plan']) as String?,
      expiresAt: (dataMap['expires_at'] ?? json['expires_at']) as String?,
    );
  }
}
