class SignatureData {
  final String? dataUrl;
  final bool approved;
  final String? ts;
  final String? name;

  const SignatureData({
    this.dataUrl,
    this.approved = false,
    this.ts,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'dataUrl': dataUrl,
        'approved': approved,
        'ts': ts,
        'name': name,
      };

  factory SignatureData.fromJson(Map<String, dynamic> json) => SignatureData(
        dataUrl: json['dataUrl'] as String?,
        approved: json['approved'] as bool? ?? false,
        ts: json['ts'] as String?,
        name: json['name'] as String?,
      );
}
