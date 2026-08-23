class EncryptedData {
  // encrypted credential data
  final List<int> cipherText;
  // unique value used for this encryption operation
  final List<int> nonce;
  // authentication tag used to detect modification
  final List<int> mac;

  const EncryptedData({
    required this.cipherText,
    required this.nonce,
    required this.mac,
  });

  EncryptedData copyWith({
    List<int>? cipherText,
    List<int>? nonce,
    List<int>? mac,
  }) {
    return EncryptedData(
      cipherText: cipherText ?? this.cipherText,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
    );
  }

  Map<String, dynamic> toJson() {
    return {'cipherText': cipherText, 'nonce': nonce, 'mac': mac};
  }

  factory EncryptedData.fromJson(Map<String, dynamic> json) {
    return EncryptedData(
      cipherText: List<int>.from(json['cipherText']),
      nonce: List<int>.from(json['nonce']),
      mac: List<int>.from(json['mac']),
    );
  }
}
