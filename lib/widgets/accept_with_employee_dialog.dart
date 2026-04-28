import 'package:flutter/material.dart';
import '../services/home_care_panel_api_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';

/// Web paneldeki "Çalışan atayarak kabul et" akışının mobil karşılığı.
/// Talep ID'si alır, başarılı olunca true döner.
Future<bool> showAcceptWithEmployeeDialog({
  required BuildContext context,
  required HomeCarePanelApiService api,
  required int requestId,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  List<Map<String, dynamic>> employees = [];
  String? loadError;
  try {
    employees = await api.getAvailableEmployees(requestId);
  } catch (e) {
    loadError = friendlyError(e);
  }

  if (!context.mounted) return false;

  String? selectedEmployeeId;
  bool saving = false;
  bool success = false;

  final titleC = isDark ? Colors.white : AppColors.midnight;
  final muted = isDark
      ? Colors.white.withValues(alpha: 0.7)
      : Colors.grey.shade700;
  final dialogBg = isDark ? const Color(0xFF132B44) : null;
  final fieldFill = isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.grey.shade50;
  final borderC =
      isDark ? Colors.white.withValues(alpha: 0.18) : Colors.grey.shade400;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: dialogBg,
            title: Text('Talebi Onayla', style: TextStyle(color: titleC)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Calisan Ata *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (loadError != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        loadError,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    )
                  else if (employees.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Bu tarih ve saatte musait calisan bulunmuyor. Tum calisanlarinizin bu saatte baska bir atamasi var.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.amber.shade200
                              : Colors.amber.shade900,
                        ),
                      ),
                    )
                  else
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<String>(
                      value: selectedEmployeeId,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF132B44) : null,
                      style: TextStyle(color: titleC, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: borderC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      hint: Text('-- Calisan secin --',
                          style: TextStyle(color: muted)),
                      items: employees.map((e) {
                        final name =
                            '${e['firstName'] ?? ''} ${e['lastName'] ?? ''}'
                                .trim();
                        final email = e['email'] ?? '';
                        return DropdownMenuItem<String>(
                          value: e['userId'] as String,
                          child: Text('$name — $email',
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedEmployeeId = v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text('Iptal', style: TextStyle(color: muted)),
              ),
              ElevatedButton.icon(
                onPressed: (saving ||
                        selectedEmployeeId == null ||
                        employees.isEmpty)
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await api.acceptRequestWithEmployee(
                            requestId,
                            selectedEmployeeId!,
                          );
                          success = true;
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e
                                  .toString()
                                  .replaceFirst('Exception: ', '')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(saving ? 'Kaydediliyor...' : 'Kabul Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    },
  );

  return success;
}
