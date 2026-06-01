import 'package:flutter/material.dart';

class VerifiedLocationBadge extends StatelessWidget {
  final bool isVerifying;
  final bool isVerified;
  final VoidCallback? onVerify;
  final bool enabled;

  const VerifiedLocationBadge({
    Key? key,
    required this.isVerifying,
    required this.isVerified,
    this.onVerify,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: enabled && !isVerifying ? onVerify : null,
          icon: isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Icon(Icons.location_searching, size: 18),
          label: const Text('Verify Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isVerified ? Colors.green : const Color(0xFFE94E1B),
            foregroundColor: Colors.white,
            disabledBackgroundColor: isVerified ? Colors.green.withOpacity(0.6) : null,
            disabledForegroundColor: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 12),
        if (isVerified)
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
