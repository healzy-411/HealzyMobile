import 'package:flutter/material.dart';

import '../Models/saved_card_model.dart';
import '../services/saved_card_api_service.dart';

class SavedCardsPage extends StatefulWidget {
  const SavedCardsPage({super.key});

  @override
  State<SavedCardsPage> createState() => _SavedCardsPageState();
}

class _SavedCardsPageState extends State<SavedCardsPage> {
  final _api = SavedCardApiService(baseUrl: "http://localhost:5009");

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

  void _showAddCardSheet() {
    final cardNameCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final monthCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Yeni Kart Ekle",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: cardNameCtrl,
                decoration: InputDecoration(
                  labelText: "Kart Adi",
                  hintText: "Orn: Is Kartim, Garanti Kartim",
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
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                decoration: InputDecoration(
                  labelText: "Kart Numarasi",
                  hintText: "1234 5678 9012 3456",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                maxLength: 19,
              ),
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
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      decoration: InputDecoration(
                        labelText: "Yil",
                        hintText: "YYYY",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final cardName = cardNameCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    final number = numberCtrl.text.trim();
                    final month = int.tryParse(monthCtrl.text.trim()) ?? 0;
                    final year = int.tryParse(yearCtrl.text.trim()) ?? 0;

                    if (cardName.isEmpty || name.isEmpty || number.length < 13 || month < 1 || month > 12 || year < 2026) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Lutfen tum alanlari dogru doldurun.")),
                      );
                      return;
                    }

                    try {
                      await _api.createCard(
                        cardName: cardName,
                        cardholderName: name,
                        cardNumber: number,
                        expiryMonth: month,
                        expiryYear: year,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadCards();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
                      );
                    }
                  },
                  child: const Text("Kaydet",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Kayitli Kartlarim"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCardSheet,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
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
                          Text("Kayitli kart yok",
                              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 8),
                          Text("Sag alttaki + butonuyla kart ekleyebilirsiniz.",
                              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cards.length,
                      itemBuilder: (context, i) {
                        final card = _cards[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: card.isDefault
                                ? Border.all(color: Colors.orange, width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2)),
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
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                    Text(
                                        "Son Kullanma: ${card.expiryMonth.toString().padLeft(2, '0')}/${card.expiryYear}",
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                    if (card.isDefault)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text("Varsayilan",
                                            style: TextStyle(
                                                color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'default') _setDefault(card.id);
                                  if (value == 'delete') _deleteCard(card.id);
                                },
                                itemBuilder: (_) => [
                                  if (!card.isDefault)
                                    const PopupMenuItem(
                                        value: 'default', child: Text("Varsayilan Yap")),
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
