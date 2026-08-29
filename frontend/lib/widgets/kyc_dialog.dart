import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class KycDialog extends StatefulWidget {
  const KycDialog({super.key});

  @override
  State<KycDialog> createState() => _KycDialogState();
}

class _KycDialogState extends State<KycDialog> {
  String _selectedDocType = 'PAN Card';
  final TextEditingController _docNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _docTypes = [
    'PAN Card',
    'Aadhaar Card',
    'Driving License',
  ];

  @override
  void dispose() {
    _docNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.accentGreenBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_outlined,
                              color: AppColors.accentGreen, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'KYC Verification',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text(
                  'Government regulations require KYC verification for initiating cash prize withdrawals.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Doc type
                const Text(
                  'DOCUMENT TYPE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _docTypes.map((type) {
                    final isSelected = _selectedDocType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedDocType = type),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Doc Number
                Text(
                  '$_selectedDocType Number'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _docNumberController,
                  decoration: InputDecoration(
                    hintText: _selectedDocType == 'PAN Card'
                        ? 'e.g. ABCDE1234F'
                        : _selectedDocType == 'Aadhaar Card'
                            ? 'e.g. 1234 5678 9012'
                            : 'e.g. DL-0420110012345',
                    prefixIcon:
                        const Icon(Icons.credit_card_outlined, size: 18),
                  ),
                  validator: (val) =>
                      val?.trim().isEmpty == true ? 'Document number is required' : null,
                ),
                const SizedBox(height: 16),

                // Safety badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '256-Bit SSL encrypted. Your documents are strictly used for regulatory KYC compliance.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() == true) {
                        provider.submitKyc(
                          _selectedDocType,
                          _docNumberController.text.trim().toUpperCase(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('KYC Verified successfully!'),
                            backgroundColor: AppColors.accentGreen,
                          ),
                        );
                      }
                    },
                    child: const Text('SUBMIT & VERIFY'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
