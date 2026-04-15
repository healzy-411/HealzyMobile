import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Models/saved_card_model.dart';
import '../services/saved_card_api_service.dart';
import 'package:healzy_app/config/api_config.dart';
import '../widgets/healzy_bottom_nav.dart';

class SavedCardsPage extends StatefulWidget {
  const SavedCardsPage({super.key});

  @override
  State<SavedCardsPage> createState() => _SavedCardsPageState();
}

class _SavedCardsPageState extends State<SavedCardsPage> {
  final _api = SavedCardApiService(baseUrl: ApiConfig.baseUrl);

  List<SavedCardDto> _cards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _api.getMyCards();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst("Exception: ", "");
        _loading = false;
      });
    }
  }

  Future<void> _deleteCard(int id) async {
    try {
      await _api.deleteCard(id);
      await _loadCards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _setDefault(int id) async {
    try {
      await _api.setDefault(id);
      await _loadCards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  void _showCardSheet({SavedCardDto? editing}) {
    final cardNameCtrl = TextEditingController(text: editing?.cardName ?? '');
    final nameCtrl = TextEditingController(text: editing?.cardholderName ?? '');
    final numberCtrl = TextEditingController();
    final monthCtrl = TextEditingController(
        text: editing != null ? editing.expiryMonth.toString().padLeft(2, '0') : '');
    final yearCtrl = TextEditingController(
        text: editing != null ? editing.expiryYear.toString() : '');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? const Color(0xFF132B44) : const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? formError;
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(editing == null ? "Yeni Kart Ekle" : "Kartı Düzenle",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cardNameCtrl,
                      decoration: InputDecoration(
                        labelText: "Kart Adı",
                        hintText: "Örn: İş Kartım, Garanti Kartım",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: "Kart Sahibi",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü ]')),
                      ],
                    ),
                    if (editing == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: numberCtrl,
                        decoration: InputDecoration(
                          labelText: "Kart Numarası",
                          hintText: "1234 5678 9012 3456",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 19,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                          _CardNumberFormatter(),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: monthCtrl,
                            decoration: InputDecoration(
                              labelText: "Ay",
                              hintText: "MM",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              counterText: '',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: yearCtrl,
                            decoration: InputDecoration(
                              labelText: "Yıl",
                              hintText: "YYYY",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              counterText: '',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(formError!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 14)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: saving ? null : () async {
                          final cardName = cardNameCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          final numberDigits =
                              numberCtrl.text.replaceAll(RegExp(r'\s'), '');
                          final month = int.tryParse(monthCtrl.text.trim()) ?? 0;
                          final year = int.tryParse(yearCtrl.text.trim()) ?? 0;
                          final now = DateTime.now();

                          String? err;
                          if (cardName.isEmpty) err = "Kart adı zorunlu.";
                          else if (name.isEmpty) err = "Kart sahibi zorunlu.";
                          else if (editing == null && numberDigits.length != 16) {
                            err = "Kart numarası 16 haneli olmalı.";
                          } else if (month < 1 || month > 12) err = "Geçersiz ay.";
                          else if (year < now.year || year > now.year + 20) {
                            err = "Geçersiz yıl.";
                          } else if (year == now.year && month < now.month) {
                            err = "Kartın son kullanma tarihi geçmiş.";
                          }

                          if (err != null) {
                            setSheetState(() => formError = err);
                            return;
                          }

                          setSheetState(() {
                            saving = true;
                            formError = null;
                          });
                          try {
                            if (editing == null) {
                              await _api.createCard(
                                cardName: cardName,
                                cardholderName: name,
                                cardNumber: numberDigits,
                                expiryMonth: month,
                                expiryYear: year,
                              );
                            } else {
                              await _api.updateCard(
                                id: editing.id,
                                cardName: cardName,
                                cardholderName: name,
                                expiryMonth: month,
                                expiryYear: year,
                                isDefault: editing.isDefault,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadCards();
                          } catch (e) {
                            setSheetState(() {
                              saving = false;
                              formError = e.toString().replaceFirst("Exception: ", "");
                            });
                          }
                        },
                        child: Text(
                          saving ? "Kaydediliyor..." : "Kaydet",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(),
      appBar: AppBar(
        title: const Text("Kayıtlı Kartlarım"),
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCardSheet(),
        backgroundColor: const Color(0xFF102E4A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _cards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text("Kayıtlı kart yok",
                              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 8),
                          Text("Sağ alttaki + butonuyla kart ekleyebilirsiniz.",
                              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cards.length,
                      itemBuilder: (context, i) {
                        final card = _cards[i];
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final cardBg = isDark
                            ? const Color(0xFF132B44).withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.55);
                        final cardBorder = isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.55);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: card.isDefault
                                  ? const Color(0xFF102E4A)
                                  : cardBorder,
                              width: card.isDefault ? 2 : 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.credit_card, color: Colors.blue, size: 36),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(card.cardName,
                                        style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("**** **** **** ${card.maskedCardNumber}",
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.grey[700], letterSpacing: 1)),
                                    const SizedBox(height: 2),
                                    Text(card.cardholderName,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    Text(
                                        "Son Kullanma: ${card.expiryMonth.toString().padLeft(2, '0')}/${card.expiryYear}",
                                        style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                                    if (card.isDefault)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text("Varsayılan",
                                            style: TextStyle(
                                                color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showCardSheet(editing: card);
                                  if (value == 'default') _setDefault(card.id);
                                  if (value == 'delete') _deleteCard(card.id);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit', child: Text("Düzenle")),
                                  if (!card.isDefault)
                                    const PopupMenuItem(
                                        value: 'default', child: Text("Varsayılan Yap")),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text("Sil", style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\s'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
